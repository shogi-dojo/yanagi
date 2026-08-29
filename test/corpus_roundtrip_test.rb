# frozen_string_literal: true

require "test_helper"

class CorpusRoundtripTest < Minitest::Test
  JISHO_ENTRIES_DIR = File.expand_path("~/projects/jisho/entries")

  # 2 known entries in jisho where ROMAJI header deviates from kana reading:
  # - 1204960-kakkou.org: reading is 'かくこう' (kakukou) but header is 'kakkou'
  # - 1586850-aruiwa.org: reading is 'あるいは' (aruiha) but header is 'aruiwa'
  KNOWN_JISHO_DISCREPANCIES = %w[
    1204960-kakkou.org
    1586850-aruiwa.org
  ].freeze

  def test_1496_jisho_entries_romaji_roundtrip
    skip "jisho repo not found at #{JISHO_ENTRIES_DIR}" unless Dir.exist?(JISHO_ENTRIES_DIR)

    files = Dir.glob(File.join(JISHO_ENTRIES_DIR, "*", "*.org"))
    assert files.length >= 1400, "Expected at least 1400 entries, found #{files.length}"

    failures = []
    checked = 0

    files.each do |file|
      content = File.read(file, encoding: "UTF-8")
      reading_match = content.match(/^#\+PRIMARY_READING:\s*(.+)$/)
      romaji_match = content.match(/^#\+ROMAJI:\s*(.+)$/)

      next unless reading_match && romaji_match

      primary_reading = reading_match[1].strip
      expected_romaji = romaji_match[1].strip
      filename = File.basename(file)

      checked += 1
      next if KNOWN_JISHO_DISCREPANCIES.include?(filename)

      unless Yanagi.romaji_matches?(primary_reading, expected_romaji)
        failures << {
          file: filename,
          reading: primary_reading,
          expected: expected_romaji,
          actual: Yanagi.romaji(primary_reading)
        }
      end
    end

    assert_equal 1496, checked
    assert_empty failures, "Failed #{failures.length} / #{checked} entries: #{failures.first(10).inspect}"
  end
end
