# frozen_string_literal: true

require "yaml"
require_relative "rules"
require_relative "normalize"
require_relative "cyrillic"

module Yanagi
  module Lexicon
    UKRAINIAN_SUFFIXES = %w[
      ами ями ах ях ів їв ою ею єю
      ом ем єм
      а е и і о у ю я ї й
    ].freeze

    MIN_STEM_LENGTH = 4

    def self.load_entries
      Rules.lexicon || {}
    end

    # Terms of non-Japanese origin (Chinese works, place names) are transliterated
    # by their own language's conventions, so Japanese mora rules must not apply.
    # Detected from the glossary note column, which states the provenance.
    NON_JP_NOTE_MARKERS = [
      "Китай", "китайськ", "конфуціанськ", "Даоськ", "даоськ", "Янцзи"
    ].freeze

    def self.detect_origin(note)
      text = note.to_s
      return "zh" if NON_JP_NOTE_MARKERS.any? { |m| text.include?(m) }

      "ja"
    end

    def self.build_from_glossary(glossary_path, out_path: nil)
      content = File.read(glossary_path, encoding: "UTF-8")
      lexicon = {}

      content.each_line do |line|
        next unless line.start_with?("|")
        parts = line.split("|").map(&:strip).reject(&:empty?)
        next if parts.empty? || parts[0].start_with?("-") || parts[0] =~ /Японське/i

        col0 = parts[0]
        col1 = parts[1]
        col2 = parts[2]

        kanji = nil
        reading = nil
        if col0 =~ /^(.+?)\s*\((.+?)\)$/
          kanji = Regexp.last_match(1).strip
          reading = Regexp.last_match(2).strip
        else
          kanji = col0.strip
          reading = nil
        end

        uk_clean = col1.gsub(/^[«"'\`]|["'\`»]$/, "").strip
        key = kanji.gsub(/^[«"'\`]|["'\`»]$/, "").strip
        next if key.empty?

        cyr = reading || uk_clean

        lexicon[key] = {
          "kanji" => kanji,
          "reading" => reading,
          "cyrillic" => cyr,
          "ukrainian" => col1,
          "note" => col2,
          "origin" => detect_origin(col2)
        }
      end

      out_file = out_path || Rules.path_for("lexicon.yml")
      File.write(out_file, YAML.dump(lexicon))
      reload!
      Rules.reload!
      lexicon
    end

    def self.merge_proposal(proposal_path, out_path: nil)
      proposals = YAML.safe_load_file(proposal_path, permitted_classes: [Symbol, Date], symbolize_names: true) || []
      proposals = [proposals] unless proposals.is_a?(Array)

      current_lexicon = Rules.lexicon ? Rules.lexicon.transform_keys(&:to_s) : {}
      new_lexicon = current_lexicon.dup

      errors = []

      proposals.each do |prop|
        status = prop[:status]&.to_s
        unless status == "accepted"
          errors << "Proposal #{prop[:term] || prop[:kanji]} status is '#{status}', must be 'accepted' to merge"
          next
        end

        kanji = prop[:kanji]&.to_s
        reading = prop[:reading]&.to_s
        cyrillic = prop[:cyrillic]&.to_s

        if reading && !reading.empty? && cyrillic && !cyrillic.empty?
          derived_cyr = Yanagi.cyrillic(reading).text
          if derived_cyr != cyrillic && prop[:override] != true
            errors << "Proposal #{kanji || reading} Cyrillic '#{cyrillic}' does not match engine derived '#{derived_cyr}'"
            next
          end
        end

        key = (kanji && !kanji.empty?) ? kanji : cyrillic
        new_lexicon[key] = {
          "kanji" => kanji,
          "reading" => reading,
          "cyrillic" => cyrillic,
          "ukrainian" => prop[:ukrainian] || cyrillic,
          "note" => prop[:note]
        }
      end

      unless errors.empty?
        raise Error, "Cannot merge proposals:\n- #{errors.join("\n- ")}"
      end

      out_file = out_path || Rules.path_for("lexicon.yml")
      File.write(out_file, YAML.dump(new_lexicon))
      reload!
      Rules.reload!
      new_lexicon
    end

    def self.strip_inflection(token)
      w = token.downcase.gsub(/^[«"'\`\(\[\{]|["'\`\)\]\}\.,;:!?—–]+$/, "")
      return [w, ""] if w.length <= MIN_STEM_LENGTH

      UKRAINIAN_SUFFIXES.each do |suffix|
        if w.end_with?(suffix) && (w.length - suffix.length) >= MIN_STEM_LENGTH
          stem = w[0...(w.length - suffix.length)]
          return [stem, suffix]
        end
      end

      [w, ""]
    end

    def self.reload!
      @exact_index = nil
      @stem_index = nil
    end

    def self.exact_index
      @exact_index ||= begin
        idx = {}
        load_entries.each do |k, entry|
          cyr = (entry[:cyrillic] || entry["cyrillic"])&.to_s&.downcase
          next unless cyr

          # Index full term
          idx[cyr] = { key: k.to_s, entry: entry, stem: cyr, suffix: "", exact: true }

          # Also index individual words of multi-word phrases (e.g. 'хонінбо', 'шюсай')
          words = cyr.split(/[\s-]+/).map(&:strip).reject(&:empty?)
          if words.length > 1
            words.each do |w|
              idx[w] ||= { key: k.to_s, entry: entry, stem: w, suffix: "", exact: true } if w.length >= MIN_STEM_LENGTH
            end
          end
        end
        idx
      end
    end

    def self.stem_index
      @stem_index ||= begin
        idx = {}
        load_entries.each do |k, entry|
          cyr = (entry[:cyrillic] || entry["cyrillic"])&.to_s&.downcase
          next unless cyr

          words = cyr.split(/[\s-]+/).map(&:strip).reject(&:empty?)
          words.each do |w|
            stem, _ = strip_inflection(w)
            idx[stem] ||= { key: k.to_s, entry: entry, stem: stem } if stem.length >= MIN_STEM_LENGTH
            idx[w] ||= { key: k.to_s, entry: entry, stem: w } if w.length >= MIN_STEM_LENGTH
          end
        end
        idx
      end
    end

    def self.find_by_stem(token)
      clean = token.downcase.gsub(/^[«"'\`\(\[\{]|["'\`\)\]\}\.,;:!?—–]+$/, "")
      return exact_index[clean] if exact_index.key?(clean)

      stem, suffix = strip_inflection(clean)
      return nil if stem.length < MIN_STEM_LENGTH

      if stem_index.key?(stem)
        info = stem_index[stem]
        return {
          key: info[:key],
          entry: info[:entry],
          stem: stem,
          suffix: suffix,
          exact: false
        }
      end

      nil
    end
  end
end
