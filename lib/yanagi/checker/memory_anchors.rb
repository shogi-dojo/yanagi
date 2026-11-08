# frozen_string_literal: true

require "yaml"
require_relative "../key"

module Yanagi
  class Checker
    # Dictionary anchors held in memory and indexed by Yanagi::Key. Rows are
    # { cyrillic:, kana:, kanji:, origin:, weight: }; build them from
    # dictionary [kana, kanji] pairs with .from_pairs, which renders each
    # reading with Yanagi.cyrillic. The gem ships no anchors: callers bring
    # their own (JMdict, JMnedict, a glossary).
    class MemoryAnchors
      FIELDS = %i[cyrillic kana kanji origin weight].freeze

      def self.from_pairs(pairs, origin: nil, weight: 1)
        new(pairs.map { |kana, kanji| pair_row(kana, kanji, origin: origin, weight: weight) })
      end

      # A YAML list whose items are rows (hashes) or [kana, kanji] pairs. A row
      # without «cyrillic» is rendered from its kana.
      def self.load(path)
        items = YAML.safe_load_file(path, symbolize_names: true) || []
        new(items.map { |item| item.is_a?(Array) ? pair_row(*item) : item })
      end

      def self.pair_row(kana, kanji = nil, origin: nil, weight: 1)
        { kana: kana, kanji: kanji, origin: origin, weight: weight }
      end

      def initialize(rows = [])
        @index = Hash.new { |hash, key| hash[key] = [] }
        rows.each { |row| add(row) }
        @index.default_proc = nil
        @index.each_value(&:freeze)
        @index.freeze
      end

      def lookup(key)
        @index.fetch(key, [])
      end

      def size
        @index.each_value.sum(&:size)
      end

      private

      def add(row)
        row = row.transform_keys(&:to_sym).slice(*FIELDS)
        row[:cyrillic] ||= Yanagi.cyrillic(row[:kana].to_s, kanji: row[:kanji]).text
        row[:weight] ||= 1
        return if row[:cyrillic].to_s.empty?

        @index[Key.call(row[:cyrillic])] << row.freeze
      end
    end
  end
end
