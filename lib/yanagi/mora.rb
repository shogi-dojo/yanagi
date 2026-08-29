# frozen_string_literal: true

require_relative "normalize"
require_relative "rules"

module Yanagi
  Mora = Struct.new(:kana, :kind, :onset, :nucleus, keyword_init: true) do
    def sokuon?
      kind == :sokuon
    end

    def chouonpu?
      kind == :chouonpu
    end

    def moraic_n?
      kind == :moraic_n
    end

    def syllable?
      kind == :syllable
    end

    def passthrough?
      kind == :passthrough
    end
  end

  module Tokenizer
    def self.tokenize(input)
      hira = Normalize.to_hiragana(Normalize.nfkc(input.to_s))
      moras = []
      mora_map = Rules.mora_map

      i = 0
      len = hira.length
      while i < len
        c1 = hira[i]
        c2 = hira[i, 2]

        if c1 == "っ"
          moras << Mora.new(kana: "っ", kind: :sokuon, onset: nil, nucleus: nil)
          i += 1
        elsif c1 == "ー"
          moras << Mora.new(kana: "ー", kind: :chouonpu, onset: nil, nucleus: nil)
          i += 1
        elsif c1 == "ん"
          moras << Mora.new(kana: "ん", kind: :moraic_n, onset: "n", nucleus: "n")
          i += 1
        elsif c2 && mora_map.key?(c2.to_sym)
          info = mora_map[c2.to_sym]
          moras << Mora.new(
            kana: c2,
            kind: :syllable,
            onset: info[:onset]&.to_s || "",
            nucleus: info[:nucleus]&.to_s || ""
          )
          i += 2
        elsif mora_map.key?(c1.to_sym)
          info = mora_map[c1.to_sym]
          moras << Mora.new(
            kana: c1,
            kind: :syllable,
            onset: info[:onset]&.to_s || "",
            nucleus: info[:nucleus]&.to_s || ""
          )
          i += 1
        else
          moras << Mora.new(kana: c1, kind: :passthrough, onset: nil, nucleus: nil)
          i += 1
        end
      end

      moras
    end
  end

  def self.tokenize(input)
    Tokenizer.tokenize(input)
  end
end
