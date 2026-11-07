# frozen_string_literal: true

module Yanagi
  # Romaji (Hepburn, Kunrei-shiki and wapuro/IME spellings) to kana, meant for
  # search input. Pure and table-driven; independent of the transliteration
  # rules so that accepting more spellings never changes generated output.
  module Kana
    VOWELS = %w[a i u e o].freeze

    def self.build_table
      t = {}
      add = lambda do |kana, *romaji|
        romaji.each { |r| t[r] = kana }
      end

      %w[あ a い i う u え e お o].each_slice(2) { |k, r| add.call(k, r) }
      [
        ["k", %w[か き く け こ]], ["g", %w[が ぎ ぐ げ ご]],
        ["s", %w[さ し す せ そ]], ["z", %w[ざ じ ず ぜ ぞ]],
        ["t", %w[た ち つ て と]], ["d", %w[だ ぢ づ で ど]],
        ["n", %w[な に ぬ ね の]], ["h", %w[は ひ ふ へ ほ]],
        ["b", %w[ば び ぶ べ ぼ]], ["p", %w[ぱ ぴ ぷ ぺ ぽ]],
        ["m", %w[ま み む め も]], ["r", %w[ら り る れ ろ]]
      ].each do |c, kanas|
        VOWELS.each_with_index { |v, i| add.call(kanas[i], "#{c}#{v}") }
      end
      add.call("や", "ya")
      add.call("ゆ", "yu")
      add.call("よ", "yo")
      add.call("いぇ", "ye")
      add.call("わ", "wa")
      add.call("を", "wo")
      add.call("うぃ", "wi")
      add.call("うぇ", "we")
      add.call("ゐ", "wyi")
      add.call("ゑ", "wye")

      # Alternative spellings of the base syllables.
      add.call("し", "shi")
      add.call("ち", "chi")
      add.call("つ", "tsu")
      add.call("ふ", "fu")
      add.call("じ", "ji")

      # Digraphs: consonant + small ya/yu/yo.
      {
        "き" => %w[ky], "ぎ" => %w[gy], "し" => %w[sy sh], "じ" => %w[zy j jy],
        "ち" => %w[ty ch cy], "ぢ" => %w[dy], "に" => %w[ny], "ひ" => %w[hy],
        "び" => %w[by], "ぴ" => %w[py], "み" => %w[my], "り" => %w[ry]
      }.each do |base, prefixes|
        prefixes.each do |pre|
          { "a" => "ゃ", "u" => "ゅ", "o" => "ょ" }.each do |v, small|
            add.call("#{base}#{small}", "#{pre}#{v}")
          end
        end
      end
      # (sha/shu/sho, cha/chu/cho and ja/ju/jo come from the bare prefixes
      # above.) The e-row and foreign sounds follow.
      add.call("しぇ", "she", "sye")
      add.call("ちぇ", "che", "tye")
      add.call("じぇ", "je", "zye", "jye")
      add.call("きぇ", "kye")
      add.call("にぇ", "nye")
      add.call("ひぇ", "hye")

      add.call("ふぁ", "fa")
      add.call("ふぃ", "fi")
      add.call("ふぇ", "fe")
      add.call("ふぉ", "fo")
      add.call("ふゅ", "fyu")
      add.call("ふ", "hu")
      add.call("ゔぁ", "va")
      add.call("ゔぃ", "vi")
      add.call("ゔ", "vu")
      add.call("ゔぇ", "ve")
      add.call("ゔぉ", "vo")
      add.call("つぁ", "tsa")
      add.call("つぃ", "tsi")
      add.call("つぇ", "tse")
      add.call("つぉ", "tso")
      add.call("づ", "dzu")
      add.call("てぃ", "thi")
      add.call("てゅ", "thu")
      add.call("でぃ", "dhi")
      add.call("でゅ", "dhu")
      add.call("とぅ", "twu")
      add.call("どぅ", "dwu")
      add.call("くぁ", "kwa")
      add.call("ぐぁ", "gwa")

      # Explicit small kana (IME style).
      %w[a i u e o].zip(%w[ぁ ぃ ぅ ぇ ぉ]).each do |v, k|
        add.call(k, "x#{v}", "l#{v}")
      end
      add.call("ゃ", "xya", "lya")
      add.call("ゅ", "xyu", "lyu")
      add.call("ょ", "xyo", "lyo")
      add.call("っ", "xtu", "ltu", "xtsu", "ltsu")
      add.call("ゎ", "xwa", "lwa")

      t.freeze
    end

    TABLE = build_table
    MAX_KEY = TABLE.keys.map(&:length).max
    CONSONANT_CHARS = /[bcdfghjklmpqrstvwxyz]/
    # Characters allowed through the tokenizer untouched.
    LONG_MARK = "ー"
    MARKER = "̄"

    SCRIPTS = %i[hiragana katakana].freeze

    module_function

    # Returns kana for +input+, or nil when it is not romaji.
    def convert(input, script: :hiragana)
      raise ArgumentError, "unknown script: #{script.inspect}" unless SCRIPTS.include?(script)
      return nil unless input.is_a?(String)

      s = normalize(input, script)
      return nil if s.nil? || s.empty?

      hira = tokenize(s)
      return nil if hira.nil? || hira.strip.empty?

      script == :katakana ? to_katakana(hira) : hira
    end

    def normalize(input, script)
      s = input.unicode_normalize(:nfkc).strip.downcase
      s = s.gsub(/[‘’ʼ`´]/, "'").gsub(/[‐-―−ｰ]/, "-")
      s = s.unicode_normalize(:nfd).gsub(/[̂̄]/, MARKER)
      return nil unless s.match?(/\A[a-z'\- ̄]+\z/)

      # Long vowels: macron/circumflex always, doubled vowels in katakana.
      if script == :katakana
        s = s.gsub(/([aiueo])#{MARKER}/, '\1-').gsub(/([aiueo])\1/, '\1-')
      else
        s = s.gsub(/o#{MARKER}/, "ou").gsub(/([aiue])#{MARKER}/, '\1\1')
      end
      return nil if s.include?(MARKER)

      s.gsub(/\s+/, " ")
    end

    def tokenize(s)
      out = +""
      i = 0
      n = s.length
      while i < n
        c = s[i]
        nxt = s[i + 1]

        if c == " "
          out << " "
          i += 1
        elsif c == "-"
          return nil if out.empty? || out.end_with?(" ")

          out << LONG_MARK
          i += 1
        elsif c == "'"
          return nil
        elsif c == "n"
          if nxt == "'"
            out << "ん"
            i += 2
          elsif nxt == "n"
            after = s[i + 2]
            if after && (VOWELS.include?(after) || after == "y")
              out << "ん"
              i += 1
            else
              out << "ん"
              i += 2
            end
          elsif nxt.nil? || !(VOWELS.include?(nxt) || nxt == "y")
            out << "ん"
            i += 1
          else
            i = take(s, i, out) or return nil
          end
        elsif c == "m" && nxt && "bpm".include?(nxt)
          out << "ん"
          i += 1
        elsif c == "t" && s[i, 3] == "tch"
          out << "っ"
          i += 1
        elsif nxt == c && c.match?(CONSONANT_CHARS)
          out << "っ"
          i += 1
        else
          i = take(s, i, out) or return nil
        end
      end
      out
    end

    def take(s, i, out)
      MAX_KEY.downto(1) do |len|
        kana = TABLE[s[i, len]]
        next unless kana && s[i, len].length == len

        out << kana
        return i + len
      end
      nil
    end

    def to_katakana(hira)
      hira.gsub(/[ぁ-ゖ]/) { |ch| (ch.ord + 0x60).chr(Encoding::UTF_8) }
    end
  end

  # Convert romaji (Hepburn, Kunrei or wapuro) to kana. Returns nil if the
  # input is not romaji. See README for details.
  def self.kana(romaji, script: :hiragana)
    Kana.convert(romaji, script: script)
  end
end
