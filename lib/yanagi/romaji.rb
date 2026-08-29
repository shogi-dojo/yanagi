# frozen_string_literal: true

require_relative "mora"
require_relative "rules"

module Yanagi
  module Romaji
    def self.call(input)
      moras = input.is_a?(Array) ? input : Tokenizer.tokenize(input)
      mora_map = Rules.mora_map
      res = []

      moras.each_with_index do |mora, idx|
        case mora.kind
        when :sokuon
          # Find next non-sokuon/chouonpu mora
          next_mora = moras[(idx + 1)..].find { |m| m.syllable? || m.moraic_n? }
          if next_mora
            next_rom = mora_map.dig(next_mora.kana.to_sym, :romaji)&.to_s || next_mora.kana.to_s
            consonant = next_rom.start_with?("ch") ? "t" : next_rom[0]
            res << consonant if consonant
          end
        when :chouonpu
          prev_char = res.last&.chars&.last
          res << prev_char if prev_char
        when :moraic_n
          res << "n"
        when :syllable
          rom = mora_map.dig(mora.kana.to_sym, :romaji)&.to_s || mora.kana.to_s
          res << rom
        else
          res << mora.kana.to_s
        end
      end

      res.join
    end
    def self.matches?(reading, romaji)
      expected = call(reading)
      return true if romaji == expected

      norm_actual = romaji.to_s.gsub(/\d+$/, "").gsub(/([aeiou])-/, '\1\1').gsub("oo", "ou").gsub("dewa", "deha")
      norm_exp = expected.gsub("oo", "ou")
      norm_actual == norm_exp
    end
  end

  def self.romaji(input)
    Romaji.call(input)
  end

  def self.romaji_matches?(reading, romaji)
    Romaji.matches?(reading, romaji)
  end
end
