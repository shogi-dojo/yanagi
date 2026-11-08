# frozen_string_literal: true

require_relative "key"
require_relative "inflection"
require_relative "checker/word_set"
require_relative "checker/memory_anchors"

module Yanagi
  # Finds Japanese words in Ukrainian text that break the transliteration
  # policy and suggests the canonical spelling, ending and case kept:
  # «Хіросіму» → «Хірошіму», «сьочю» → «шьочю».
  #
  #   checker = Yanagi::Checker.new(anchors: anchors, ukrainian: words)
  #   checker.check(text) # => [Finding, ...]
  #
  # Each Cyrillic token goes through, in order:
  # 1. +overrides+ ({ wrong => right }), exact or stem + ending;
  # 2. the +ukrainian+ word list (#include?, lower case): such words are skipped;
  # 3. the +anchors+ (#lookup(Key) → rows), via every stem + ending split:
  #    a canonical spelling means the token is correct, otherwise the
  #    heaviest row wins;
  # 4. a +rule+ finding when the token holds forbidden sequences and Japanese
  #    markers: every forbidden sequence is substituted at once.
  class Checker
    Finding = Struct.new(:start, :stop, :token, :suggestion, :kind, :confidence, :source, keyword_init: true)

    # Letters, apostrophes inside a word, and inner hyphens.
    TOKEN = /\p{Cyrillic}+(?:['ʼ’]\p{Cyrillic}+)*(?:-\p{Cyrillic}+(?:['ʼ’]\p{Cyrillic}+)*)*/

    CONFIDENCE = { override: 1.0, dictionary: 0.9, rule: 0.3 }.freeze

    # Sequences that only the Japanese rows produce. Unlike Audit::JP_MARKERS
    # this leaves out C + я/ю/ьо (ня, ря, ньо), which are everyday Ukrainian.
    MARKERS = %w[
      ші чі джі ґ дза дзу дзе дзо
      шя шю шьо чя чю чьо джя джю джьо
      дзі дзя дзю дзьо тсу ё
    ].freeze
    MARKER_PATTERN = Regexp.union(MARKERS)

    def initialize(anchors: MemoryAnchors.new, ukrainian: WordSet.new, overrides: {})
      @anchors = anchors
      @ukrainian = ukrainian
      @overrides = overrides.to_h { |wrong, right| [wrong.to_s.downcase, right.to_s] }
    end

    def check(text)
      findings = []
      text.scan(TOKEN) do
        match = Regexp.last_match
        findings.concat(check_token(match[0], match.begin(0)))
      end
      findings
    end

    private

    # A hyphenated token is checked whole first; unless an override or the
    # dictionary knows it whole, its parts win over a rule guess.
    def check_token(token, start)
      whole = check_word(token, start)
      return [whole].compact if !token.include?("-") || (whole && whole.kind != :rule)

      parts = check_parts(token, start)
      parts.empty? ? [whole].compact : parts
    end

    def check_parts(token, start)
      offset = start
      token.split("-").filter_map do |part|
        found = check_word(part, offset)
        offset += part.length + 1
        found
      end
    end

    def check_word(token, start)
      return if token.length < 2

      forms = Inflection.split(token)
      found = override(token, forms)
      return finding(token, start, *found) if found
      return if @ukrainian.include?(token.downcase)

      found = dictionary(token, forms)
      return if found == :correct

      found ||= rule(token)
      finding(token, start, *found) if found
    end

    def finding(token, start, suggestion, kind, source)
      return if suggestion == token

      Finding.new(start: start, stop: start + token.length, token: token, suggestion: suggestion,
                  kind: kind, confidence: CONFIDENCE.fetch(kind), source: source)
    end

    def override(token, forms)
      each_base(forms) do |base, ending|
        right = @overrides[base.downcase]
        next unless right

        return [Inflection.rejoin(right, ending, case_of: token), :override, source_of(origin: "override")]
      end
      nil
    end

    def dictionary(token, forms)
      hits = []
      each_base(forms) do |base, ending|
        lookup_keys(base).each do |key|
          @anchors.lookup(key).each { |row| hits << [row, Inflection.rejoin(row[:cyrillic], ending, case_of: token)] }
        end
      end
      return if hits.empty?
      return :correct if hits.any? { |_, word| word.downcase == token.downcase }

      row, word = hits.each_with_index.max_by { |(hit_row, _), index| [hit_row[:weight].to_f, -index] }.first
      [word, :dictionary, source_of(**row.slice(:kana, :kanji, :origin))]
    end

    def rule(token)
      lower = token.downcase
      return unless Key.forbidden?(lower) && MARKER_PATTERN.match?(lower)

      [Inflection.apply_case(Key.respell(lower), like: token), :rule, source_of(origin: "rule")]
    end

    def each_base(forms)
      forms.each do |stem, ending|
        Inflection.bases(stem, ending).each { |base| yield base, ending }
      end
    end

    # The key leaves «ті» alone, since yanagi writes ティ so; an anchor may
    # still confirm that it stands for ち.
    def lookup_keys(base)
      lower = base.downcase
      keys = [Key.call(lower)]
      keys << Key.call(lower.gsub("ті", "чі")) if lower.include?("ті")
      keys.uniq
    end

    def source_of(kana: nil, kanji: nil, origin: nil)
      { kana: kana, kanji: kanji, origin: origin }
    end
  end
end
