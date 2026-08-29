# frozen_string_literal: true

require "test_helper"

class GoldGlossaryTest < Minitest::Test
  GLOSSARY_PATH = File.expand_path("~/projects/meijin/books/meijin/glossary.org")

  KANJI_ONLY_SKIP_LIST = [
    "うろこ屋",
    "東京日日新聞",
    "川奈ホテル",
    "富士コオス",
    "尺・寸・分",
    "鶴ヶ岡八幡宮",
    "コンタックス",
    "ゾナア",
    "大島のかすり",
    "ろ十三 / ろ十二",
    "大動脈弁不完全閉鎖"
  ].freeze

  CHINESE_TERMS_SKIP_LIST = [
    "太湖",
    "書経",
    "神仙通鑑",
    "呂祖全書"
  ].freeze

  FORBIDDEN_PATTERNS = [
    /сі/i, /ті/i, /тсу/i, /ху/i, /дзі/i,
    /ся/i, /ша/i, /сю/i, /шу/i, /сьо/i, /шо/i, /шё/i,
    /тя/i, /ча/i, /тю/i, /чу/i, /тьо/i, /чо/i, /чё/i,
    /дзя/i, /зя/i, /джа/i, /дзю/i, /зю/i, /джу/i, /дзьо/i, /зьо/i, /джо/i, /джё/i,
    /кё/i, /нё/i, /хё/i, /мё/i, /рё/i, /бё/i, /пё/i, /ґё/i,
    /[аеєиіїоуюя]ї/i
  ].freeze

  def test_exceptions_budget_cap
    exceptions = Yanagi::Rules.exceptions
    assert exceptions.is_a?(Array)
    # Budget cap: ~25 rows
    assert exceptions.length <= 25, "Exceptions list exceeded budget cap: #{exceptions.length} > 25"
  end

  def test_pending_exceptions_status
    # Verify pending exceptions are tracked
    pending = Yanagi::Rules.exceptions.select { |e| e[:status] == "pending" }
    assert pending.length >= 8, "Expected at least 8 pending exceptions, found #{pending.length}"
  end

  def test_glossary_inverse_well_formedness
    skip "Glossary not found at #{GLOSSARY_PATH}" unless File.exist?(GLOSSARY_PATH)

    content = File.read(GLOSSARY_PATH, encoding: "UTF-8")
    rows = []
    content.each_line do |line|
      next unless line.start_with?("|")
      parts = line.split("|").map(&:strip).reject(&:empty?)
      next if parts.empty? || parts[0].start_with?("-") || parts[0] == "Японське"

      col0 = parts[0]
      col1 = parts[1]
      col2 = parts[2]
      if col0 =~ /^(.+?)\s*\((.+?)\)$/
        rows << { kanji: $1.strip, reading: $2.strip, ukrainian: col1, note: col2 }
      end
    end

    assert rows.length >= 360, "Expected >= 360 gold pairs, parsed #{rows.length}"

    violations = []
    pending_terms = Yanagi::Rules.exceptions.select { |e| e[:status] == "pending" }.map { |e| e[:term] }

    rows.each do |row|
      reading = row[:reading]
      kanji = row[:kanji]

      next if CHINESE_TERMS_SKIP_LIST.include?(kanji)
      next if pending_terms.any? { |t| reading.include?(t) }

      # Check forbidden patterns
      FORBIDDEN_PATTERNS.each do |pat|
        if reading =~ pat
          violations << { kanji: kanji, reading: reading, violation: "Forbidden pattern #{pat}" }
        end
      end

      # Check double oo (unless pending exception)
      if reading =~ /оо/i && !pending_terms.any? { |t| reading.include?(t) }
        violations << { kanji: kanji, reading: reading, violation: "Unregistered double 'оо'" }
      end
    end

    assert_empty violations, "Well-formedness violations in gold glossary: #{violations.inspect}"
  end
end
