# frozen_string_literal: true

require "yaml"
require_relative "rules"
require_relative "normalize"
require_relative "lexicon"
require_relative "cyrillic"

module Yanagi
  module Audit
    JP_MARKERS = %w[
      ші чі джі ґ
      дза дзу дзе дзо
      шя шю шьо
      чя чю чьо
      джя джю джьо
      кя кю кьо
      ря рю рьо
      ня ню ньо
      хя хю хьо
      мя мю мьо
      бя бю бьо
      пя пю пьо
      ґя ґю ґьо
    ].freeze

    POLIVANOV_MARKERS = %w[
      сі ті дзі зі
      ся сю сьо
      тя тю тьо
      дзя дзю дзьо зя зю зьо
    ].freeze

    Finding = Struct.new(
      :file,
      :line,
      :col,
      :token,
      :tier,
      :message,
      :canonical,
      :approved,
      keyword_init: true
    ) do
      def to_h
        {
          "file" => file,
          "line" => line,
          "col" => col,
          "token" => token,
          "tier" => tier,
          "message" => message,
          "canonical" => canonical,
          "approved" => approved || false
        }
      end
    end

    def self.allowlist
      @allowlist ||= begin
        data = Rules.native_ua_allowlist
        data.is_a?(Array) ? Set.new(data.map(&:to_s).map(&:downcase)) : Set.new
      end
    end

    def self.reload_allowlist!
      @allowlist = nil
    end

    def self.scan_text(text, file_path: nil, tier2: true, tier3: false)
      findings = []
      allow = allowlist
      lines = text.lines

      lines.each_with_index do |line_text, line_idx|
        line_text.scan(/(?<![\w\p{Cyrillic}])([\p{Cyrillic}'’\`-]+)(?![\w\p{Cyrillic}])/) do
          match_data = Regexp.last_match
          raw_tok = match_data[1]
          col = match_data.begin(0) + 1

          clean = raw_tok.downcase.gsub(/^[-'\`"]+|[-'\`"]+$/, "")
          next if clean.length < 2

          # 1. Skip if allowlisted native Ukrainian word
          next if allow.include?(clean)
          stem, _ = Lexicon.strip_inflection(clean)
          next if stem.length >= 3 && allow.include?(stem)

          # 2. Tier 1 Check (AUTOFIX-eligible)
          # Does this un-allowlisted token match a lexicon entry via forbidden substitution?
          t1 = check_tier1(raw_tok, clean, file_path, line_idx + 1, col)
          if t1
            findings << t1
            next
          end

          # 3. Skip if known in lexicon
          lex_match = Lexicon.find_by_stem(clean)
          next if lex_match

          # 4. Tier 2 Check (JP markers present, absent from allowlist & lexicon)
          if tier2 && has_jp_markers?(clean)
            findings << Finding.new(
              file: file_path,
              line: line_idx + 1,
              col: col,
              token: raw_tok,
              tier: 2,
              message: "Contains Japanese transliteration markers; unanchored in lexicon",
              canonical: nil,
              approved: false
            )
            next
          end

          # 5. Tier 3 Check (Polivanov markers present, off by default)
          if tier3 && has_polivanov_markers?(clean)
            findings << Finding.new(
              file: file_path,
              line: line_idx + 1,
              col: col,
              token: raw_tok,
              tier: 3,
              message: "Contains Polivanov digraph marker; expected mostly noise",
              canonical: nil,
              approved: false
            )
          end
        end
      end

      findings
    end

    def self.scan(paths, tier2: true, tier3: false)
      paths = [paths] unless paths.is_a?(Array)
      all_findings = []

      paths.each do |p|
        if File.directory?(p)
          Dir.glob(File.join(p, "**", "*.{org,md,txt}")).each do |f|
            next if f.include?("glossary.org") || f.include?("transliteration.md")
            content = File.read(f, encoding: "UTF-8")
            all_findings.concat(scan_text(content, file_path: f, tier2: tier2, tier3: tier3))
          end
        elsif File.file?(p)
          content = File.read(p, encoding: "UTF-8")
          all_findings.concat(scan_text(content, file_path: p, tier2: tier2, tier3: tier3))
        end
      end

      all_findings
    end

    def self.apply(findings_file)
      data = YAML.safe_load_file(findings_file, permitted_classes: [Symbol, Date], symbolize_names: true) || []
      data = data[:findings] if data.is_a?(Hash) && data.key?(:findings)
      data = [data] unless data.is_a?(Array)

      by_file = {}
      data.each do |f|
        next unless f[:approved] == true && f[:canonical] && !f[:canonical].empty? && f[:file]
        by_file[f[:file]] ||= []
        by_file[f[:file]] << f
      end

      applied_count = 0

      by_file.each do |file_path, file_findings|
        next unless File.exist?(file_path)
        content = File.read(file_path, encoding: "UTF-8")

        file_findings.sort_by { |f| [-f[:line].to_i, -f[:col].to_i] }.each do |f|
          tok = f[:token]
          canon = f[:canonical]
          replacement = if tok == tok.upcase
                          canon.upcase
                        elsif tok == tok.capitalize
                          canon.capitalize
                        else
                          canon
                        end

          if content.include?(tok)
            content = content.sub(tok, replacement)
            applied_count += 1
          end
        end

        File.write(file_path, content, encoding: "UTF-8")
      end

      applied_count
    end

    def self.check_tier1(raw_tok, clean_tok, file_path, line, col)
      mora_map = Rules.mora_map
      return nil unless mora_map
      return nil if clean_tok.length < Lexicon::MIN_STEM_LENGTH

      mora_map.each do |_kana, data|
        forbidden_list = data[:forbidden] || []
        canonical_cyr = data[:cyrillic]&.to_s
        next unless canonical_cyr && !forbidden_list.empty?

        forbidden_list.each do |forb|
          next unless clean_tok.include?(forb)

          candidate = clean_tok.gsub(forb, canonical_cyr)
          lex_match = Lexicon.find_by_stem(candidate)

          # Japanese mora rules apply only to Japanese-origin terms. Chinese works
          # and place names in the glossary carry their own transliteration.
          next if lex_match && lex_match[:entry] && lex_match[:entry][:origin].to_s == "zh"

          if lex_match && lex_match[:stem].length >= Lexicon::MIN_STEM_LENGTH
            canonical_word = if raw_tok == raw_tok.capitalize
                               candidate.capitalize
                             elsif raw_tok == raw_tok.upcase
                               candidate.upcase
                             else
                               candidate
                             end

            return Finding.new(
              file: file_path,
              line: line,
              col: col,
              token: raw_tok,
              tier: 1,
              message: "Forbidden transliteration '#{forb}' for '#{canonical_cyr}' matching lexicon '#{lex_match[:key]}'",
              canonical: canonical_word,
              approved: true
            )
          end
        end
      end

      nil
    end

    def self.has_jp_markers?(text)
      JP_MARKERS.any? { |m| text.include?(m) }
    end

    def self.has_polivanov_markers?(text)
      POLIVANOV_MARKERS.any? { |m| text.include?(m) }
    end

    def self.build_allowlist_from_corpus(corpus_dir, out_path: nil)
      allow = Set.new

      seed = %w[
        інші наші ваші перші більші менші кращі довші вищі нижчі тиші чаші аркуші гроші душі пізніші давніші старші молодші зовнішні свіжіші
        вночі очі плечі ключі речі ночі двічі тричі уночі поночі тисячі зустрічі чіпляти
        бджіл бджілка джунглі джерело джерела джерел
        ґанок ґрунт ґудзик ґава ґрати дзиґа ґвалт ґречний ґедзь
        дзвонити дзвін дзвінок дзвіночок дзеркало дзеркальний дзьоб кукурудза дзенькіт дзвеніти задзвеніти
        сірник сірники зовсім вісім досі сіль сільський сусід сусідка сусіди сіно січень сірий сідати сісти засідання весілля постійний постійно
        партії кімнаті статті миті житті святі почутті тяглості тіло тінь тікати тітка тільки потім тієї тією
        зір зірка зірки зібрати зіграти зійти поїздці нозі дорозі книзі підлозі зілля
        сьогодні сьомий всього всьому третього цього якому того цього
      ]
      seed.each { |w| allow << w.downcase }

      if Dir.exist?(corpus_dir)
        books_dir = File.join(corpus_dir, "books")
        shared_dir = File.join(corpus_dir, "shared")
        files = []
        files.concat(Dir.glob(File.join(books_dir, "**", "*.{org,md,txt}"))) if Dir.exist?(books_dir)
        files.concat(Dir.glob(File.join(shared_dir, "**", "*.{org,md,txt}"))) if Dir.exist?(shared_dir)
        files.reject! { |f| f.include?("glossary.org") || f.include?("transliteration.md") }

        files.each do |f|
          content = File.read(f, encoding: "UTF-8")
          content.scan(/[\p{Cyrillic}'’\`-]+/) do |tok|
            clean = tok.downcase.gsub(/^[-'\`"]+|[-'\`"]+$/, "")
            next if clean.length < 2

            # Do not allowlist Tier-1 forbidden forms or explicit Polivanov markers
            next if check_tier1(clean, clean, nil, 0, 0)
            next if clean.include?("дзі") || clean.include?("тсу") || clean.include?("сьо")
            next if Lexicon.find_by_stem(clean)

            allow << clean
          end
        end
      end

      out_file = out_path || File.join(Rules.data_dir, "native_ua_allowlist.yml")
      File.write(out_file, YAML.dump(allow.to_a.sort))
      reload_allowlist!
      Rules.reload!
      allow
    end
  end

  def self.audit(paths, tier2: true, tier3: false)
    Audit.scan(paths, tier2: tier2, tier3: tier3)
  end
end
