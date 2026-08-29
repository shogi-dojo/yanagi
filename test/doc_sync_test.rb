# frozen_string_literal: true

require "test_helper"

class DocSyncTest < Minitest::Test
  SHARED_DOC_PATH = File.expand_path("~/projects/meijin/shared/transliteration.md")

  def test_doc_sync_with_authoritative_transliteration_doc
    skip "Doc not found at #{SHARED_DOC_PATH}" unless File.exist?(SHARED_DOC_PATH)

    sync = Yanagi::DocSync.new(path: SHARED_DOC_PATH)
    differences = sync.diff

    assert_empty differences, "DocSync found policy discrepancies between doc and rules: #{differences.inspect}"
    assert sync.synced?
  end

  def test_doc_sync_detects_mismatches
    # Create temporary doc with a known mismatch
    temp_doc = <<~MD
      ## 1. Базова таблиця відповідностей
      | Японська мора | Кирилізація | Заборонено | Приклади |
      |---|---|---|---|
      | し (shi) | **сі** | ші | Сі |
    MD

    Tempfile.create(["translit", ".md"]) do |f|
      f.write(temp_doc)
      f.flush

      sync = Yanagi::DocSync.new(path: f.path)
      diff = sync.diff

      refute sync.synced?
      assert diff.any? { |d| d[:kind] == :mora_mismatch && d[:kana] == "し" }
    end
  end
end
