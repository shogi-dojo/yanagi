# frozen_string_literal: true

require "test_helper"
require "open3"
require "json"
require "tmpdir"

class CLITest < Minitest::Test
  EXE_PATH = File.expand_path("../exe/yanagi", __dir__)

  def run_cli(*args)
    stdout, stderr, status = Open3.capture3(EXE_PATH, *args)
    # capture3 returns binary strings; the CLI emits UTF-8.
    [stdout.dup.force_encoding(Encoding::UTF_8).strip,
     stderr.dup.force_encoding(Encoding::UTF_8).strip,
     status]
  end

  def test_cli_version
    out, _, status = run_cli("version")
    assert status.success?
    assert_includes out, "yanagi #{Yanagi::VERSION}"
  end

  def test_cli_romaji
    out, _, status = run_cli("romaji", "しゅうさい")
    assert status.success?
    assert_equal "shuusai", out
  end

  def test_cli_cyrillic
    out, _, status = run_cli("cyrillic", "しゅうさい")
    assert status.success?
    assert_equal "шюсай", out
  end

  def test_cli_cyrillic_json
    out, _, status = run_cli("cyrillic", "しゅうさい", "--format", "json")
    assert status.success?
    json = JSON.parse(out)
    assert_equal "шюсай", json["text"]
    assert_equal "derived", json["source"]
  end

  def test_cli_doc_sync
    doc_path = File.expand_path("~/projects/meijin/shared/transliteration.md")
    skip "Doc not found" unless File.exist?(doc_path)

    out, _, status = run_cli("doc-sync", doc_path)
    assert status.success?
    assert_includes out, "in sync"
  end

  def test_cli_verify_gold
    glossary_path = File.expand_path("~/projects/meijin/books/meijin/glossary.org")
    skip "Glossary not found" unless File.exist?(glossary_path)

    out, _, status = run_cli("verify-gold", glossary_path)
    assert status.success?
    assert_includes out, "All gold pairs verified successfully!"
  end

  def test_cli_check
    Dir.mktmpdir do |dir|
      path = File.join(dir, "text.txt")
      File.write(path, "Ми пили сьочю.\nУ Хіросіму, сьогодні!\n")
      anchors = File.expand_path("fixtures/checker/anchors.yml", __dir__)
      words = File.expand_path("fixtures/checker/ukrainian.txt", __dir__)
      out, _, status = run_cli("check", path, "--anchors", anchors, "--ukrainian", words)
      refute status.success?
      assert_equal ["#{path}:1:9: сьочю -> шьочю (dictionary, 0.9)",
                    "#{path}:2:3: Хіросіму -> Хірошіму (dictionary, 0.9)"], out.lines.map(&:chomp)
    end
  end

  def test_cli_check_clean_file_json
    Dir.mktmpdir do |dir|
      path = File.join(dir, "text.txt")
      File.write(path, "Суші в Хірошімі.\n")
      out, _, status = run_cli("check", path, "--format", "json")
      assert status.success?
      assert_equal [], JSON.parse(out)
    end
  end
end
