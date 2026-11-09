# frozen_string_literal: true

module Yanagi
  # Ukrainian case endings on Japanese loanwords: «Хірошіму», «Хірошімою»,
  # «ніхону». The checker looks words up by their dictionary form, so a token
  # is split into stem and ending, and the canonical form gets the ending back.
  module Inflection
    # Longest first, so «ами» is tried before «и».
    ENDINGS = %w[
      ами ями ові еві
      ою ею єю ам ям ах ях ом ем ів
      и і ї у ю а я
    ].sort_by { |ending| -ending.length }.freeze

    # Ukrainian words built on a Japanese one: «сьогунат», «сьогунату», «хіросімський». The
    # suffix with each ending it takes; the base keeps its last letter unless that is а or я
    # (Хірошім-а → хірошім-ський, but самурай → самурай-ський).
    DERIVED = {
      "ат" => %w[ами ам ах ом ів а у і и],
      "ськ" => %w[ими ого ому ий им ім их ої ій ою а е і у]
    }.freeze
    DERIVED_ENDINGS = DERIVED.flat_map { |suffix, tails| [suffix, *tails.map { |tail| suffix + tail }] }
                             .reject { |ending| ending == "ськ" }
                             .sort_by { |ending| -ending.length }.freeze
    DERIVED_THEME_LETTERS = %w[а я].freeze

    # The shortest stem worth looking up.
    MIN_STEM_LENGTH = 3

    # Final letters a declined word loses before its ending: Хірошім-а → Хірошім-у,
    # самура-й → самура-ю.
    THEME_LETTERS = %w[а я й].freeze

    module_function

    # [stem, ending] candidates for +token+, the bare token first. The stem
    # keeps the token's own case.
    def split(token)
      lower = token.downcase
      candidates = [[token, ""]]
      (ENDINGS + DERIVED_ENDINGS).each do |ending|
        next unless lower.end_with?(ending) && lower.length - ending.length >= MIN_STEM_LENGTH

        candidates << [token[0...(token.length - ending.length)], token[(token.length - ending.length)..]]
      end
      candidates
    end

    # Dictionary forms a +stem+ may come from: itself, or with the theme letter
    # its ending replaced. A bare token is its own dictionary form.
    def bases(stem, ending)
      return [stem] if ending.empty?
      return [stem] + DERIVED_THEME_LETTERS.map { |letter| stem + letter } if derived?(ending)

      [stem] + THEME_LETTERS.map { |letter| stem + letter }
    end

    # +canonical+ with +ending+ in place of its theme letter, in the case of
    # +case_of+ (Title, UPPER or lower).
    def rejoin(canonical, ending, case_of:)
      word = canonical
      unless ending.empty?
        theme = derived?(ending) ? DERIVED_THEME_LETTERS : THEME_LETTERS
        word = word[0...-1] if theme.include?(word[-1]&.downcase)
        word += ending.downcase
      end
      apply_case(word, like: case_of)
    end

    def derived?(ending) = DERIVED_ENDINGS.include?(ending.downcase)

    def apply_case(word, like:)
      letters = like.scan(/\p{L}/).join
      if letters.length > 1 && letters == letters.upcase
        word.upcase
      elsif letters[0] && letters[0] == letters[0].upcase
        word.downcase.sub(/\p{L}/, &:upcase)
      else
        word.downcase
      end
    end
  end
end
