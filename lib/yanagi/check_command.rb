# frozen_string_literal: true

require "optparse"
require "json"
require "yaml"
require_relative "checker"

module Yanagi
  # `yanagi check FILE [--anchors x.yml] [--ukrainian words.txt]
  # [--overrides x.yml] [--format human|json]`. #run returns the exit status:
  # 1 when there are findings.
  class CheckCommand
    USAGE = "Usage: yanagi check <file> [--anchors <anchors.yml>] [--ukrainian <words.txt>] " \
            "[--overrides <overrides.yml>] [--format json|human]"

    def initialize(args)
      @args = args.dup
      @options = { format: "human" }
    end

    def run
      path = parser.parse!(@args).first
      unless path && File.file?(path)
        warn USAGE
        return 1
      end

      text = File.read(path, encoding: "UTF-8")
      findings = checker.check(text)
      @options[:format] == "json" ? print_json(findings) : print_human(path, text, findings)
      findings.empty? ? 0 : 1
    end

    private

    def parser
      OptionParser.new do |opts|
        opts.on("--anchors FILE", "YAML anchors: rows or [kana, kanji] pairs") { |v| @options[:anchors] = v }
        opts.on("--ukrainian FILE", "Ukrainian word list, one word per line") { |v| @options[:ukrainian] = v }
        opts.on("--overrides FILE", "YAML map of wrong => right spellings") { |v| @options[:overrides] = v }
        opts.on("--format FORMAT", %w[human json], "Output format (human or json)") { |v| @options[:format] = v }
      end
    end

    def checker
      Checker.new(
        anchors: load(:anchors) { |path| Checker::MemoryAnchors.load(path) } || Checker::MemoryAnchors.new,
        ukrainian: load(:ukrainian) { |path| Checker::WordSet.load(path) } || Checker::WordSet.new,
        overrides: load(:overrides) { |path| YAML.safe_load_file(path) } || {}
      )
    end

    def load(option)
      path = @options[option]
      yield path if path
    end

    def print_json(findings)
      puts JSON.pretty_generate(findings.map(&:to_h))
    end

    def print_human(path, text, findings)
      findings.each do |f|
        line = text[0...f.start].count("\n") + 1
        col = f.start - (f.start.zero? ? -1 : text.rindex("\n", f.start - 1) || -1)
        puts "#{path}:#{line}:#{col}: #{f.token} -> #{f.suggestion} (#{f.kind}, #{f.confidence})"
      end
    end
  end
end
