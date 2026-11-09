# frozen_string_literal: true

require "test_helper"

class CheckerTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures/checker", __dir__)
  Checker = Yanagi::Checker

  def anchors
    @anchors ||= Checker::MemoryAnchors.load(File.join(FIXTURES, "anchors.yml"))
  end

  def words
    @words ||= Checker::WordSet.load(File.join(FIXTURES, "ukrainian.txt"))
  end

  def checker(**options)
    Checker.new(anchors: anchors, ukrainian: words, **options)
  end

  def suggestions(text, **options)
    checker(**options).check(text).map { |f| [f.token, f.suggestion, f.kind] }
  end

  CORRECTIONS = [
    ["сьочю", "шьочю", :dictionary],
    ["Хіросіму", "Хірошіму", :dictionary],
    ["Хіросіма", "Хірошіма", :dictionary],
    ["ХІРОСІМОЮ", "ХІРОШІМОЮ", :dictionary],
    ["Мейдзі", "Мейджі", :dictionary],
    ["Фудзі", "Фуджі", :dictionary],
    ["Сідзуока", "Шідзуока", :dictionary],
    ["Сідзуокою", "Шідзуокою", :dictionary],
    ["сусі", "суші", :dictionary],
    ["Тсусіма", "Цушіма", :dictionary], # two errors: тсу and сі
    ["Мітіко", "Мічіко", :dictionary], # ті → чі only because an anchor says so
    ["Сіндзюку", "Шінджюку", :dictionary],
    ["сьогунат", "шьоґунат", :dictionary], # a Ukrainian word built on 将軍
    ["сьогунатом", "шьоґунатом", :dictionary],
    ["Хіросімський", "Хірошімський", :dictionary],
    ["хіросімської", "хірошімської", :dictionary],
    ["Кйото", nil, nil],
    ["Хіґасі", "Хіґаші", :rule],
    ["Сімадзу", "Шімадзу", :rule],
    ["Ісідзімаґава", "Ішіджімаґава", :rule] # every forbidden sequence at once
  ].freeze

  def test_corrections
    CORRECTIONS.each do |token, suggestion, kind|
      expected = suggestion ? [[token, suggestion, kind]] : []
      assert_equal expected, suggestions(token), token
    end
  end

  def test_canonical_spellings_are_left_alone
    %w[шьочю Хірошіму Мейджі Фуджі Шідзуока суші Цушіма Мічіко Шінджюку Кіото шьоґунат хірошімський
       самурайський].each do |token|
      assert_empty suggestions(token), token
    end
  end

  # A rare name in some case can spell a Polivanov form exactly («Суса» → «сусі»); the heavier,
  # common word still wins. An equally heavy exact spelling keeps the token.
  def test_a_heavier_anchor_beats_a_light_exact_match
    rows = [
      { kana: "すし", kanji: "寿司", origin: "jmdict", weight: 2 },
      { kana: "すさ", kanji: "須佐", origin: "jmnedict", weight: 0.5 },
      { kana: "めいじ", kanji: "明治", origin: "jmdict", weight: 2 },
      { kana: "めいざ", origin: "jmnedict", weight: 0.5 }
    ]
    found = Checker.new(anchors: Checker::MemoryAnchors.new(rows)).check("сусі за Мейдзі")
    pairs = found.map { |f| [f.token, f.suggestion] }
    assert_equal [%w[сусі суші], %w[Мейдзі Мейджі]], pairs

    names = Checker.new(anchors: Checker::MemoryAnchors.new([{ kana: "すさ", weight: 1 }, { kana: "すし", weight: 1 }]))
    assert_empty names.check("Сусою"), "a name in its own case stays when nothing outweighs it"
  end

  def test_a_hyphenated_ukrainian_word_is_left_alone_whole
    rows = [{ kana: "ごだ", origin: "jmdict", weight: 1 }, { kana: "ごでぃ", origin: "jmdict", weight: 1 }]
    words = Checker::WordSet.new(%w[вряди-годи])
    assert_empty Checker.new(anchors: Checker::MemoryAnchors.new(rows), ukrainian: words).check("вряди-годи")
  end

  def test_an_exonym_outweighs_a_polivanov_reading
    rows = [{ kana: "ろしあ", origin: "exonym", cyrillic: "Росія", weight: 5 },
            { kana: "ろしや", origin: "jmnedict", weight: 0.5 }]
    assert_empty Checker.new(anchors: Checker::MemoryAnchors.new(rows)).check("Росія і Росією")
  end

  def test_ukrainian_words_are_left_alone
    assert_empty suggestions("Сьогодні сім разів сюди вчиться ліпити тісто, а сусіди на засіданні.")
  end

  def test_ukrainian_words_are_left_alone_without_a_word_list
    assert_empty Checker.new(anchors: anchors).check("сьогодні сім сюди вчиться тісто")
  end

  def test_override_beats_the_word_list
    found = suggestions("Сім самураїв", overrides: { "сім" => "Шім" })
    assert_equal [["Сім", "Шім", :override]], found
  end

  def test_override_with_an_ending
    found = suggestions("про Ніппону", overrides: { "ніппон" => "Ніхон" })
    assert_equal [["Ніппону", "Ніхону", :override]], found
  end

  def test_override_beats_the_dictionary
    assert_equal [["Сусі", "Суші", :override]], suggestions("Сусі", overrides: { "сусі" => "суші" })
  end

  def test_highest_weight_wins
    heavy = Checker::MemoryAnchors.new(
      [{ cyrillic: "шіма", kana: "しま", origin: "jmdict", weight: 1 },
       { cyrillic: "Шіма", kana: "しま", origin: "glossary", weight: 3 }]
    )
    finding = Checker.new(anchors: heavy).check("сіма").first
    assert_equal "glossary", finding.source[:origin]
  end

  def test_offsets_with_punctuation_and_newlines
    text = "Ми пили «сьочю»,\nа потім — у Хіросіму!\n(Фудзі)"
    findings = checker.check(text)
    assert_equal(%w[сьочю Хіросіму Фудзі], findings.map(&:token))
    findings.each { |f| assert_equal f.token, text[f.start...f.stop] }
    assert_equal [9, 14], [findings[0].start, findings[0].stop]
  end

  def test_finding_fields
    finding = checker.check("сусі").first
    assert_equal 0.9, finding.confidence
    assert_equal({ kana: "すし", kanji: "寿司", origin: nil }, finding.source)
  end

  def test_hyphenated_parts
    text = "Сіндзюку-сі"
    found = checker.check(text).map { |f| [f.token, f.suggestion, f.kind, f.start] }
    assert_equal [["Сіндзюку", "Шінджюку", :dictionary, 0]], found
  end

  def test_apostrophes_stay_inside_the_token
    found = suggestions("п'ять «Сін'іті»", overrides: { "сін'іті" => "Шін'ічі" })
    assert_equal [["Сін'іті", "Шін'ічі", :override]], found
  end

  def test_memory_anchors_from_pairs
    pairs = Checker::MemoryAnchors.from_pairs([%w[すし 寿司]], origin: "jmdict")
    assert_equal [{ kana: "すし", kanji: "寿司", origin: "jmdict", weight: 1, cyrillic: "суші" }],
                 pairs.lookup(Yanagi::Key.call("сусі"))
  end

  def test_word_set_ignores_case_and_apostrophe_variants
    set = Checker::WordSet.new(["м'ята"])
    assert set.include?("М’ята")
    refute set.include?("мята")
  end
end
