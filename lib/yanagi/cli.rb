# frozen_string_literal: true

require "optparse"
require "json"
require "yaml"
require_relative "../yanagi"

module Yanagi
  class CLI
    def self.start(args = ARGV)
      # Output is Ukrainian/Japanese text; emit UTF-8 regardless of the caller's locale.
      $stdout.set_encoding(Encoding::UTF_8)
      $stderr.set_encoding(Encoding::UTF_8)
      new(args).run
    end

    def initialize(args)
      @args = args.dup
    end

    def run
      cmd = @args.shift
      case cmd
      when "romaji"
        cmd_romaji
      when "cyrillic"
        cmd_cyrillic
      when "audit"
        cmd_audit
      when "apply"
        cmd_apply
      when "doc-sync", "doc_sync"
        cmd_doc_sync
      when "lexicon"
        cmd_lexicon
      when "verify-gold", "verify_gold"
        cmd_verify_gold
      when "-v", "--version", "version"
        puts "yanagi #{Yanagi::VERSION}"
      when "-h", "--help", "help", nil
        print_help
      else
        warn "Unknown command: #{cmd}"
        print_help
        exit 1
      end
    end

    private

    def cmd_romaji
      input = @args.join(" ").strip
      if input.empty?
        warn "Usage: yanagi romaji <kana>"
        exit 1
      end
      puts Yanagi.romaji(input)
    end

    def cmd_cyrillic
      format = "human"
      kanji = nil
      reading = nil

      parser = OptionParser.new do |opts|
        opts.on("--format FORMAT", %w[human json], "Output format (human or json)") { |v| format = v }
        opts.on("--kanji KANJI", "Kanji writing") { |v| kanji = v }
        opts.on("--reading READING", "Kana reading") { |v| reading = v }
      end
      remaining = parser.parse!(@args)

      input = reading || remaining.join(" ").strip
      if input.empty? && kanji.nil?
        warn "Usage: yanagi cyrillic <kana> [--format json|human] [--kanji <kanji>]"
        exit 1
      end

      res = Yanagi.cyrillic(input, kanji: kanji, reading: reading)
      if format == "json"
        puts JSON.pretty_generate({
          text: res.text,
          source: res.source,
          confidence: res.confidence,
          notes: res.notes
        })
      else
        puts res.text
      end
    end

    def cmd_audit
      tier2 = true
      tier3 = false
      format = "human"
      out_path = nil

      parser = OptionParser.new do |opts|
        opts.on("--[no-]tier2", "Enable/disable Tier 2 reporting (default: true)") { |v| tier2 = v }
        opts.on("--tier3", "Enable Tier 3 Polivanov reporting (default: false)") { |v| tier3 = v }
        opts.on("--format FORMAT", %w[human json yaml], "Output format") { |v| format = v }
        opts.on("--out FILE", "Output file for findings") { |v| out_path = v }
      end
      paths = parser.parse!(@args)

      if paths.empty?
        paths = ["."]
      end

      findings = Yanagi.audit(paths, tier2: tier2, tier3: tier3)

      if out_path
        data = { "findings" => findings.map(&:to_h) }
        content = format == "json" ? JSON.pretty_generate(data) : YAML.dump(data)
        File.write(out_path, content)
        puts "Wrote #{findings.length} findings to #{out_path}"
      elsif format == "json"
        puts JSON.pretty_generate(findings.map(&:to_h))
      elsif format == "yaml"
        puts YAML.dump(findings.map(&:to_h))
      else
        tier1_count = findings.count { |f| f.tier == 1 }
        tier2_count = findings.count { |f| f.tier == 2 }
        tier3_count = findings.count { |f| f.tier == 3 }

        puts "Yanagi Audit Results:"
        puts "--------------------"
        puts "Tier 1 (AUTOFIX): #{tier1_count}"
        puts "Tier 2 (REPORT):  #{tier2_count}"
        puts "Tier 3 (NOISE):   #{tier3_count}"
        puts "Total:            #{findings.length}"
        puts ""

        findings.each do |f|
          loc = f.file ? "#{f.file}:#{f.line}:#{f.col}" : "line #{f.line}:#{f.col}"
          puts "[Tier #{f.tier}] #{loc} - '#{f.token}' #{f.canonical ? "-> '#{f.canonical}'" : ""}"
          puts "        #{f.message}"
        end
      end

      # Exit non-zero if Tier 1 findings exist
      exit 1 if findings.any? { |f| f.tier == 1 }
    end

    def cmd_apply
      findings_file = @args.first
      unless findings_file && File.exist?(findings_file)
        warn "Usage: yanagi apply <findings.yml>"
        exit 1
      end

      applied = Yanagi::Audit.apply(findings_file)
      puts "Applied #{applied} approved corrections."
    end

    def cmd_doc_sync
      path = @args.first
      sync = Yanagi::DocSync.new(path: path)

      diffs = sync.diff
      if diffs.empty?
        puts "Transliteration policy doc (#{sync.path}) is in sync with rules."
        exit 0
      else
        warn "Discrepancies found in policy doc (#{sync.path}):"
        diffs.each do |d|
          warn "  - #{d.inspect}"
        end
        exit 1
      end
    end

    def cmd_lexicon
      subcmd = @args.shift
      case subcmd
      when "build"
        glossary_path = nil
        out_path = nil

        parser = OptionParser.new do |opts|
          opts.on("--glossary FILE", "Path to glossary.org") { |v| glossary_path = v }
          opts.on("--out FILE", "Output path for lexicon.yml") { |v| out_path = v }
        end
        parser.parse!(@args)

        glossary_path ||= File.expand_path("~/projects/meijin/books/meijin/glossary.org")
        unless File.exist?(glossary_path)
          warn "Glossary file not found: #{glossary_path}"
          exit 1
        end

        lex = Yanagi::Lexicon.build_from_glossary(glossary_path, out_path: out_path)
        puts "Built lexicon with #{lex.length} entries."

      when "merge"
        out_path = nil
        parser = OptionParser.new do |opts|
          opts.on("--out FILE", "Output path for lexicon.yml") { |v| out_path = v }
        end
        remaining = parser.parse!(@args)
        proposal_file = remaining.first

        unless proposal_file && File.exist?(proposal_file)
          warn "Usage: yanagi lexicon merge <proposal.yml> [--out <file>]"
          exit 1
        end

        lex = Yanagi::Lexicon.merge_proposal(proposal_file, out_path: out_path)
        puts "Successfully merged proposals. Lexicon now contains #{lex.length} entries."

      else
        warn "Usage: yanagi lexicon [build|merge] [options]"
        exit 1
      end
    end

    # Forbidden Cyrillic sequences: Polivanov leftovers and yoon/long-vowel
    # violations. Derived from the rules data so the doc, the audit and this
    # check cannot drift apart.
    def gold_forbidden_patterns
      pats = []
      (Rules.mora_map || {}).each_value do |data|
        canonical = data[:cyrillic].to_s
        Array(data[:forbidden]).each do |forb|
          f = forb.to_s
          next if f.empty?

          # A forbidden sequence is only a violation when it is not already part
          # of the canonical rendering: «за» is wrong on its own but correct
          # inside «дза», and «ху» is wrong except inside a longer correct form.
          prefix = canonical.end_with?(f) ? canonical[0...-f.length] : nil
          pats << if prefix && !prefix.empty?
                    Regexp.new("(?<!#{Regexp.escape(prefix)})#{Regexp.escape(f)}", Regexp::IGNORECASE)
                  else
                    Regexp.new(Regexp.escape(f), Regexp::IGNORECASE)
                  end
        end
      end
      pats << /оо/  # long vowels are never doubled (see transliteration.md 3.3)
      pats.uniq { |r| r.source }
    end

    def cmd_verify_gold
      glossary_path = @args.first || File.expand_path("~/projects/meijin/books/meijin/glossary.org")
      unless File.exist?(glossary_path)
        warn "Glossary file not found: #{glossary_path}"
        exit 1
      end

      content = File.read(glossary_path, encoding: "UTF-8")
      rows = []
      content.each_line do |line|
        next unless line.start_with?("|")
        parts = line.split("|").map(&:strip).reject(&:empty?)
        next if parts.empty? || parts[0].start_with?("-") || parts[0] =~ /Японське/i

        col0 = parts[0]
        next unless col0 =~ /^(.+?)\s*\((.+?)\)$/

        rows << {
          kanji: Regexp.last_match(1).strip,
          reading: Regexp.last_match(2).strip,
          ukrainian: parts[1],
          note: parts[2]
        }
      end

      puts "Verifying #{rows.length} gold glossary terms against Yanagi rules..."

      exceptions = Rules.exceptions || []
      pending = exceptions.select { |e| e[:status].to_s == "pending" }
      accepted_terms = exceptions.select { |e| e[:status].to_s == "accepted" }.map { |e| e[:term].to_s }

      patterns = gold_forbidden_patterns
      passed = 0
      failures = []

      rows.each do |row|
        reading = row[:reading]

        # Non-Japanese entries carry their own language's transliteration.
        entry = Rules.lexicon[row[:kanji].to_sym] || Rules.lexicon[row[:kanji]]
        if entry && entry[:origin].to_s == "zh"
          passed += 1
          next
        end

        if accepted_terms.any? { |t| reading.include?(t) }
          passed += 1
          next
        end

        hit = patterns.find { |pat| reading =~ pat }
        if hit
          failures << { kanji: row[:kanji], reading: reading, reason: "Forbidden sequence #{hit.source}" }
        else
          passed += 1
        end
      end

      pass_rate = rows.empty? ? 100.0 : (passed.to_f / rows.length * 100).round(1)
      puts "Gold Verification Summary:"
      puts "-------------------------"
      puts "Total Terms:    #{rows.length}"
      puts "Passed:         #{passed} (#{pass_rate}%)"
      puts "Failures:       #{failures.length}"
      puts "Pending defect: #{pending.length}"

      unless failures.empty?
        warn "\nFailures:"
        failures.each { |f| warn "  - #{f[:kanji]} (#{f[:reading]}): #{f[:reason]}" }
      end

      # A pending exception is an uncorrected data defect: fail so it stays visible.
      unless pending.empty?
        warn "\nPending defects in data/exceptions.yml (correct the source data or reclassify):"
        pending.each { |e| warn "  - #{e[:term]} (#{e[:kanji]}): #{e[:reason]}" }
      end

      if failures.empty? && pending.empty?
        puts "All gold pairs verified successfully!"
        exit 0
      end

      exit 1
    end

    def print_help
      puts <<~HELP
        Yanagi (柳) - Deterministic Japanese -> Ukrainian transliteration & policy tool

        Usage:
          yanagi romaji <kana>
          yanagi cyrillic <kana> [--format json|human] [--kanji <kanji>]
          yanagi audit <paths...> [--tier2] [--tier3] [--format json|human|yaml] [--out <file>]
          yanagi apply <findings.yml>
          yanagi doc-sync [path/to/transliteration.md]
          yanagi lexicon build --glossary <glossary.org> [--out <file>]
          yanagi lexicon merge <proposal.yml> [--out <file>]
          yanagi verify-gold [path/to/glossary.org]
          yanagi version
          yanagi help
      HELP
    end
  end
end
