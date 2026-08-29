# frozen_string_literal: true

require_relative "rules"

module Yanagi
  class DocSync
    attr_reader :path

    def self.default_path
      candidates = [
        File.expand_path("~/projects/meijin/shared/transliteration.md"),
        File.expand_path("shared/transliteration.md", Dir.pwd),
        File.expand_path("../../shared/transliteration.md", __dir__)
      ]
      candidates.find { |p| File.exist?(p) } || candidates.first
    end

    def initialize(path: nil)
      @path = path || self.class.default_path
    end

    def diff(rules = nil)
      rules ||= Rules.mora_map
      return [{ kind: :file_not_found, path: @path }] unless File.exist?(@path)

      content = File.read(@path, encoding: "UTF-8")
      differences = []

      # 1. Parse §1 table
      table_1_entries = parse_section_1_table(content)
      table_1_entries.each do |entry|
        entry[:kanas].each do |kana|
          rule_data = rules[kana.to_sym]
          next unless rule_data

          expected_cyr = rule_data[:cyrillic]
          expected_forb = rule_data[:forbidden] || []

          # Check if doc Cyrillic matches expected (either exact mora, base consonant prefix, or included in listed items)
          matched_cyr = entry[:cyrillic_items].include?(expected_cyr) ||
                        (entry[:base_cyrillic] && expected_cyr.start_with?(entry[:base_cyrillic]))

          unless matched_cyr
            differences << {
              kind: :mora_mismatch,
              section: 1,
              kana: kana,
              doc: entry[:base_cyrillic] || entry[:cyrillic_items].join(", "),
              rules: expected_cyr
            }
          end

          # Check forbidden variants
          if entry[:forbidden_items].any?
            # At least one forbidden form or base prefix in doc should match rule's forbidden
            matched_forb = entry[:forbidden_items].any? do |df|
              expected_forb.any? { |rf| rf == df || rf.start_with?(df) }
            end || (entry[:base_forbidden] && expected_forb.any? { |rf| rf.start_with?(entry[:base_forbidden]) })

            unless matched_forb
              differences << {
                kind: :forbidden_mismatch,
                section: 1,
                kana: kana,
                doc_forbidden: entry[:forbidden_items].join(", "),
                rules_forbidden: expected_forb
              }
            end
          end
        end
      end

      # 2. Parse §2 bullet points (Yōon)
      yoon_entries = parse_section_2_yoon(content)
      yoon_entries.each do |entry|
        entry[:kanas].each_with_index do |kana, idx|
          expected_cyr = rules.dig(kana.to_sym, :cyrillic)
          next unless expected_cyr

          doc_cyr = entry[:cyrillics][idx] || entry[:cyrillics].first
          if doc_cyr && doc_cyr != expected_cyr
            differences << {
              kind: :mora_mismatch,
              section: 2,
              kana: kana,
              doc: doc_cyr,
              rules: expected_cyr
            }
          end
        end
      end

      differences
    end

    def synced?(rules = nil)
      diff(rules).empty?
    end

    private

    def clean_markdown_markup(str)
      str.to_s.gsub(/\*\*/, "").gsub(/__/, "").gsub(/`/, "").strip
    end

    def parse_section_1_table(content)
      entries = []
      in_sec_1 = false

      content.each_line do |line|
        if line =~ /^##\s+1\.\s+/
          in_sec_1 = true
          next
        elsif line =~ /^##\s+2\.\s+/
          break
        end

        next unless in_sec_1
        next unless line.start_with?("|")
        parts = line.split("|").map(&:strip).reject(&:empty?)
        next if parts.empty? || parts[0].start_with?("-") || parts[0] =~ /Японська/i

        kana_col = parts[0]
        cyr_col = parts[1]
        forb_col = parts[2]

        kanas = extract_kanas(kana_col)

        clean_cyr = clean_markdown_markup(cyr_col)
        clean_forb = clean_markdown_markup(forb_col)

        base_cyr = clean_cyr.split(/[\s(]/).first
        base_forb = clean_forb.split(/[\s(]/).first

        cyr_items = if clean_cyr =~ /\((.+?)\)/
                      $1.split(",").flat_map { |s| s.split("/") }.map(&:strip).reject(&:empty?)
                    else
                      [base_cyr]
                    end

        forb_items = if clean_forb =~ /\((.+?)\)/
                       $1.split(",").flat_map { |s| s.split("/") }.map(&:strip).reject(&:empty?)
                     else
                       clean_forb.split(",").flat_map { |s| s.split("/") }.map(&:strip).reject(&:empty?)
                     end

        entries << {
          kanas: kanas,
          base_cyrillic: base_cyr,
          cyrillic_items: cyr_items,
          base_forbidden: base_forb,
          forbidden_items: forb_items
        }
      end

      entries
    end

    def parse_section_2_yoon(content)
      entries = []
      in_sec_2 = false

      content.each_line do |line|
        if line =~ /^##\s+2\.\s+/
          in_sec_2 = true
          next
        elsif line =~ /^##\s+3\.\s+/
          break
        end

        next unless in_sec_2
        if line =~ /^\s*-\s+(.+?)\s*→\s*(.+?)(?:\(|$)/
          left = $1.strip
          right = $2.strip

          kanas = extract_kanas(left)
          cyrillics = clean_markdown_markup(right).split(/[\s\/]+/).map(&:strip).reject(&:empty?)

          entries << { kanas: kanas, cyrillics: cyrillics }
        end
      end

      entries
    end

    def extract_kanas(str)
      str.scan(/[\u3040-\u309F]+/)
    end
  end

  def self.doc_sync(path: nil)
    DocSync.new(path: path)
  end
end
