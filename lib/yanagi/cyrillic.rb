# frozen_string_literal: true

require_relative "normalize"
require_relative "rules"
require_relative "mora"

module Yanagi
  Result = Struct.new(:text, :source, :confidence, :notes, keyword_init: true) do
    def to_s
      text.to_s
    end

    def to_str
      text.to_s
    end

    def ==(other)
      if other.is_a?(String)
        text == other
      else
        super
      end
    end

    def inspect
      "#<Yanagi::Result text=#{text.inspect} source=#{source.inspect} confidence=#{confidence.inspect}>"
    end
  end

  module Cyrillic
    O_COLUMN = %w[
      お こ そ と の ほ も よ ろ を
      ご ぞ ど ぼ ぽ
      きょ しょ ちょ にょ ひょ みょ りょ ぎょ じょ びょ ぴょ
      ふぉ ゔぉ
    ].freeze

    U_COLUMN = %w[
      う く す つ ぬ ふ む ゆ る
      ぐ ず づ ぶ ぷ
      しゅ ちゅ じゅ きゅ ぎゅ にゅ ひゅ みゅ りゅ びゅ ぴゅ
      ゔ どぅ とぅ
    ].freeze

    A_COLUMN = %w[
      あ か さ た な は ま や ら わ
      が ざ だ ば ぱ
      きゃ しゃ ちゃ にゃ ひゃ みゃ りゃ ぎゃ じゃ びゃ ぴゃ
      ふぁ ゔぁ
    ].freeze

    E_COLUMN = %w[
      え け せ て ね へ め れ ゑ
      げ ぜ で べ ぺ
      しぇ ちぇ つぇ ふぇ うぇ ゔぇ
    ].freeze

    I_COLUMN = %w[
      い き し ち に ひ み り ゐ
      ぎ じ ぢ び ぴ
      ふぃ ゔぃ てぃ でぃ
    ].freeze

    def self.call(input = nil, kanji: nil, reading: nil)
      raw_str = (reading || input).to_s.strip
      kanji_str = kanji.to_s.strip

      # 1. Whole-word exonym check
      exonyms = Rules.exonyms
      norm_key = Normalize.to_hiragana(Normalize.nfkc(raw_str))
      if exonyms.key?(norm_key.to_sym)
        entry = exonyms[norm_key.to_sym]
        return Result.new(
          text: entry[:cyrillic],
          source: :exonym,
          confidence: 1.0,
          notes: entry[:note] || "Exonym"
        )
      end

      # 2. Check exceptions table
      exceptions = Rules.exceptions
      if exceptions.is_a?(Array)
        match = exceptions.find do |e|
          (!kanji_str.empty? && e[:kanji] == kanji_str) ||
            e[:term] == raw_str ||
            e[:expected] == raw_str
        end
        if match
          return Result.new(
            text: match[:canonical] || match[:expected],
            source: :exception_table,
            confidence: 1.0,
            notes: match[:reason]
          )
        end
      end

      # 3. Check lexicon (if present)
      lexicon = Rules.lexicon
      if lexicon.is_a?(Hash) && !kanji_str.empty? && lexicon.key?(kanji_str.to_sym)
        entry = lexicon[kanji_str.to_sym]
        return Result.new(
          text: entry[:cyrillic] || entry[:reading_cyrillic],
          source: :lexicon,
          confidence: 1.0,
          notes: entry[:gloss]
        )
      end

      # 4. If input is romaji (only ASCII letters and apostrophes/hyphens/spaces)
      if raw_str.match?(/\A[a-zA-Z'\- ]+\z/)
        converted_kana = romaji_to_hiragana(raw_str)
        return render_kana(converted_kana)
      end

      # 5. Derived Cyrillic transliteration from kana
      render_kana(raw_str)
    end

    def self.render_kana(kana_input)
      moras = Tokenizer.tokenize(kana_input)
      mora_map = Rules.mora_map

      # Step 1: Render each mora into candidate text (handling long vowel collapse and i diphthongs)
      rendered_segments = []

      moras.each_with_index do |mora, idx|
        prev_mora = idx > 0 ? moras[idx - 1] : nil

        case mora.kind
        when :passthrough
          rendered_segments << { mora: mora, text: mora.kana.to_s, kind: :passthrough }

        when :chouonpu
          # Long vowel mark collapses under policy
          rendered_segments << { mora: mora, text: "", kind: :chouonpu }

        when :sokuon
          # Sokuon is resolved in Step 2 with lookahead
          rendered_segments << { mora: mora, text: nil, kind: :sokuon }

        when :moraic_n
          # Moraic n is resolved in Step 2 with lookahead
          rendered_segments << { mora: mora, text: nil, kind: :moraic_n }

        when :syllable
          kana = mora.kana
          base_cyr = mora_map.dig(kana.to_sym, :cyrillic)&.to_s || kana

          # Long vowel collapse rules:
          # - う after O-column or U-column collapses
          if kana == "う" && prev_mora && prev_mora.syllable?
            if O_COLUMN.include?(prev_mora.kana) || U_COLUMN.include?(prev_mora.kana)
              rendered_segments << { mora: mora, text: "", kind: :collapsed_long_vowel }
              next
            end
          end

          # - お after O-column collapses (e.g. おおたけ -> Отаке)
          if kana == "お" && prev_mora && prev_mora.syllable? && O_COLUMN.include?(prev_mora.kana)
            rendered_segments << { mora: mora, text: "", kind: :collapsed_long_vowel }
            next
          end

          # - あ after A-column collapses
          if kana == "あ" && prev_mora && prev_mora.syllable? && A_COLUMN.include?(prev_mora.kana)
            rendered_segments << { mora: mora, text: "", kind: :collapsed_long_vowel }
            next
          end

          # - え after E-column collapses
          if kana == "え" && prev_mora && prev_mora.syllable? && E_COLUMN.include?(prev_mora.kana)
            rendered_segments << { mora: mora, text: "", kind: :collapsed_long_vowel }
            next
          end

          # - い diphthong vs vowel:
          #   い after E-column -> 'й' (e.g. めい -> мей, せんせい -> сенсей)
          #   い after A-column -> 'й' (e.g. しゅうさい -> шюсай, たい -> тай)
          #   い after U-column -> 'і' (e.g. かるいざわ -> каруідзава, ぬいもん -> нуімон)
          #   い after O-column -> 'і' (e.g. ごい -> ґоі, どい -> доі)
          #   い after I-column -> 'і' (e.g. きいん -> кіін, いいだ -> ііда, りいち -> ріічі)
          if kana == "い" && prev_mora && prev_mora.syllable?
            if E_COLUMN.include?(prev_mora.kana) || A_COLUMN.include?(prev_mora.kana)
              rendered_segments << { mora: mora, text: "й", kind: :syllable }
              next
            end
          end

          rendered_segments << { mora: mora, text: base_cyr, kind: :syllable }
        end
      end

      # Step 2: Resolve sokuon (っ) and moraic n (ん) based on next rendered segment
      final_parts = []
      rendered_segments.each_with_index do |seg, idx|
        if seg[:kind] == :sokuon
          # Find next non-empty rendered segment
          next_seg = rendered_segments[(idx + 1)..].find { |s| s[:text] && !s[:text].empty? }
          if next_seg
            next_text = next_seg[:text]
            geminated = geminate_consonant(next_text)
            final_parts << geminated if geminated
          end
        elsif seg[:kind] == :moraic_n
          # Find next non-empty rendered segment
          next_seg = rendered_segments[(idx + 1)..].find { |s| s[:text] && !s[:text].empty? }
          if next_seg && starts_with_labial?(next_seg[:text])
            final_parts << "м"
          else
            final_parts << "н"
          end
        else
          final_parts << seg[:text]
        end
      end

      Result.new(
        text: final_parts.join,
        source: :derived,
        confidence: 1.0,
        notes: nil
      )
    end

    # Sokuon doubles only before the plosives «п» and «к», which Ukrainian
    # carries comfortably (Іппекі, кеппекі, Ніккай, Хоккекьо). Before the
    # sibilants and affricates it is not rendered: шш, чч and ддж read as
    # foreign, so шічяку, Тешю, доджін-дзаші.
    GEMINATING_CONSONANTS = %w[п к].freeze

    def self.geminate_consonant(next_rendered_text)
      return "" if next_rendered_text.nil? || next_rendered_text.empty?

      first_char = next_rendered_text[0]
      GEMINATING_CONSONANTS.include?(first_char) ? first_char : ""
    end

    def self.starts_with_labial?(text)
      return false if text.nil? || text.empty?
      # Labials: 'п', 'б'
      text.start_with?("п", "б")
    end

    # Simple romaji to hiragana conversion for Mode A romaji input
    def self.romaji_to_hiragana(str)
      norm = str.downcase.gsub("'", "'")
      mora_map = Rules.mora_map

      # Build inverted map from romaji -> hiragana kana
      @romaji_to_hira_table ||= begin
        table = {}
        mora_map.each do |kana_sym, data|
          rom = data[:romaji]&.to_s
          table[rom] = kana_sym.to_s if rom
        end
        # Sort by romaji length descending to match longest substrings first
        table.sort_by { |k, _v| -k.length }.to_h
      end

      res = []
      i = 0
      len = norm.length
      while i < len
        matched = false

        # Check sokuon in romaji (e.g. kk, pp, tt, ss, tch, ssh, etc.)
        c = norm[i]
        c_next = norm[i + 1]
        c3 = norm[i, 3]

        if c3 == "tch"
          res << "っ"
          i += 1
          next
        elsif c == c_next && c =~ /[bcdfghjklmpqrstvwxyz]/ && c != "n"
          res << "っ"
          i += 1
          next
        end

        # Match table
        @romaji_to_hira_table.each do |rom, kana|
          if norm[i..].start_with?(rom)
            res << kana
            i += rom.length
            matched = true
            break
          end
        end

        unless matched
          res << norm[i]
          i += 1
        end
      end

      res.join
    end
  end

  def self.cyrillic(input = nil, kanji: nil, reading: nil)
    Cyrillic.call(input, kanji: kanji, reading: reading)
  end

  def self.from_romaji(romaji_str)
    Cyrillic.call(romaji_str)
  end
end
