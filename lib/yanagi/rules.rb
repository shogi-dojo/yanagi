# frozen_string_literal: true

require "yaml"

module Yanagi
  module Rules
    DATA_DIR = File.expand_path("../../data", __dir__).freeze

    @mutex = Mutex.new

    # Policy rules ship with the gem. Corpus-derived data (the lexicon and the
    # native-Ukrainian allowlist) is generated from a specific translation
    # project and is NOT distributed: point YANAGI_DATA_DIR at a directory
    # holding those files, or build them with `yanagi lexicon build`.
    CORPUS_FILES = %w[lexicon.yml native_ua_allowlist.yml].freeze

    def self.data_dir
      DATA_DIR
    end

    # Where corpus-derived files are read from. Defaults to the gem's data
    # directory so a local checkout keeps working without configuration.
    def self.corpus_dir
      ENV.fetch("YANAGI_DATA_DIR", DATA_DIR)
    end

    def self.path_for(filename)
      dir = CORPUS_FILES.include?(filename) ? corpus_dir : DATA_DIR
      File.join(dir, filename)
    end

    def self.load_yaml(filename)
      path = path_for(filename)
      return {}.freeze unless File.exist?(path)

      data = YAML.safe_load_file(path, permitted_classes: [Symbol, Date], symbolize_names: true) || {}
      deep_freeze(data)
    end

    def self.mora_map
      @mora_map ||= load_yaml("mora.yml")
    end

    def self.combinatorial
      @combinatorial ||= load_yaml("combinatorial.yml")
    end

    def self.exonyms
      @exonyms ||= load_yaml("exonyms.yml")
    end

    def self.lexicon
      @lexicon ||= load_yaml("lexicon.yml")
    end

    def self.native_ua_allowlist
      @native_ua_allowlist ||= load_yaml("native_ua_allowlist.yml")
    end

    def self.exceptions
      @exceptions ||= load_yaml("exceptions.yml")
    end

    def self.reload!
      @mutex.synchronize do
        @mora_map = nil
        @combinatorial = nil
        @exonyms = nil
        @lexicon = nil
        @native_ua_allowlist = nil
        @exceptions = nil
      end
    end

    def self.deep_freeze(obj)
      case obj
      when Hash
        obj.transform_keys(&:freeze).transform_values { |v| deep_freeze(v) }.freeze
      when Array
        obj.map { |v| deep_freeze(v) }.freeze
      when String
        obj.dup.freeze
      else
        obj.freeze
      end
    end
    private_class_method :deep_freeze
  end
end
