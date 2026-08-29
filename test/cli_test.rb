# frozen_string_literal: true

require "test_helper"
require "open3"
require "json"

class CLITest < Minitest::Test
  EXE_PATH = File.expand_path("../exe/yanagi", __dir__)

  def run_cli(*args)
    stdout, stderr, status = Open3.capture3(EXE_PATH, *args)
    [stdout.strip, stderr.strip, status]
  end

  def test_cli_version
    out, _, status = run_cli("version")
    assert status.success?
    assert_includes out, "yanagi 0.1.0"
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
end
