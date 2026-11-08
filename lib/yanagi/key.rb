# frozen_string_literal: true

require_relative "rules"

module Yanagi
  # A spelling-neutral key for Ukrainian renderings of Japanese words, so one
  # word matches however it is spelled. yanagi writes ちゃ «чя», しょ «шьо»,
  # じ «джі», が «ґа», and keeps long vowels and most doubled consonants
  # single; people also type «ча», «шо», the Polivanov «сусі» and «Фудзі»,
  # «г» for «ґ», «кітте» and «ніппон». Both sides of a comparison go through
  # #call.
  #
  # The folds come from the `forbidden:` lists in data/mora.yml, so the key and
  # the policy cannot drift apart. Only folds that cannot merge two different
  # yanagi spellings are made: «ті» stays, since yanagi writes ティ that way.
  module Key
    # Forbidden sequences that are also correct yanagi output.
    AMBIGUOUS = %w[ті].freeze

    # Ukrainian spelling writes а / у / е / о after ж, ч, ш, щ, where yanagi
    # keeps я / ю / є / ьо.
    HUSHED = { "я" => "а", "ю" => "у", "є" => "е", "ьо" => "о" }.freeze
    HUSHED_PATTERN = /([жчшщ])(ьо|я|ю|є)/
    APOSTROPHES = "'ʼ’`"

    # い after a vowel: yanagi writes «ай», «суі»; people also write «аі», «суй», «аї». The key
    # reads them all as vowel + «і».
    VOWEL_I = /(?<=[аеиоуяюєі])(?:йі|ї|й(?![аеиоуяюєії]))/

    # ん before б, п, м: yanagi writes «м» only before п and б («шімбун», «енмей»); Polivanov
    # also has «еммей». The key reads «м» before a labial as «н».
    LABIAL_N = /м(?=[бпм])/

    module_function

    # The key: lower case, no apostrophes, forbidden spellings folded to the
    # canonical ones, ґ read as г, hushed vowels plain, い after a vowel as «і»,
    # «м» before a labial as «н», doubled letters single.
    def call(text)
      key = respell(text.downcase.delete(APOSTROPHES)).tr("ґ", "г")
      key = key.gsub(HUSHED_PATTERN) { "#{Regexp.last_match(1)}#{HUSHED.fetch(Regexp.last_match(2))}" }
      key.gsub(VOWEL_I, "і").gsub(LABIAL_N, "н").squeeze
    end

    # Replaces every forbidden sequence in a lower-case +text+ with its
    # canonical spelling in one pass, so «сіндзюку» becomes «шінджюку».
    def respell(text)
      text.gsub(fold_pattern) { |seq| folds.fetch(seq) }
    end

    # True when lower-case +text+ holds any forbidden sequence.
    def forbidden?(text)
      fold_pattern.match?(text)
    end

    # { forbidden => canonical } from data/mora.yml.
    def folds
      @folds ||= Rules.mora_map.each_value.with_object({}) do |data, map|
        canonical = data[:cyrillic].to_s
        Array(data[:forbidden]).each do |seq|
          seq = seq.to_s
          next if seq.empty? || AMBIGUOUS.include?(seq)

          map[seq] ||= canonical
        end
      end.freeze
    end

    # Longest sequences first. A forbidden sequence that ends the canonical
    # one («за» in «дза») only counts when it is not already part of it.
    def fold_pattern
      @fold_pattern ||= Regexp.union(
        folds.keys.sort_by { |seq| [-seq.length, seq] }.map do |seq|
          prefix = folds[seq].delete_suffix(seq)
          if prefix != folds[seq] && !prefix.empty?
            /(?<!#{Regexp.escape(prefix)})#{Regexp.escape(seq)}/
          else
            /#{Regexp.escape(seq)}/
          end
        end
      )
    end
  end
end
