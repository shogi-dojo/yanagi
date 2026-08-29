# frozen_string_literal: true

module Yanagi
  module Normalize
    KATA_START = 0x30A1
    KATA_END   = 0x30F6
    KATA_SHIFT = 0x60

    # NFKC-normalise a string (compatibility decomposition then canonical composition).
    # Input may arrive tagged ASCII-8BIT (e.g. from ARGV), which unicode_normalize
    # rejects, so coerce to UTF-8 first.
    def self.nfkc(str)
      s = str.to_s
      s = s.dup.force_encoding(Encoding::UTF_8) unless s.encoding == Encoding::UTF_8
      s.unicode_normalize(:nfkc)
    end

    # Convert a katakana string to hiragana (passthrough for everything else).
    def self.to_hiragana(str)
      str.to_s.chars.map do |ch|
        cp = ch.ord
        (cp >= KATA_START && cp <= KATA_END) ? (cp - KATA_SHIFT).chr(Encoding::UTF_8) : ch
      end.join
    end
  end
end
