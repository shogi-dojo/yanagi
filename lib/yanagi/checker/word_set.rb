# frozen_string_literal: true

require "set"

module Yanagi
  class Checker
    # A plain Ukrainian word list: one word per line, «#» starts a comment.
    # Lookups ignore case and the apostrophe variant.
    class WordSet
      APOSTROPHES = /['ʼ’`]/

      def self.load(path)
        new(File.foreach(path, encoding: "UTF-8").map { |line| line.sub(/#.*/, "").strip }.reject(&:empty?))
      end

      def self.normalize(word)
        word.downcase.gsub(APOSTROPHES, "'")
      end

      def initialize(words = [])
        @words = words.to_set { |word| self.class.normalize(word) }.freeze
      end

      def include?(word)
        @words.include?(self.class.normalize(word))
      end

      def size
        @words.size
      end
    end
  end
end
