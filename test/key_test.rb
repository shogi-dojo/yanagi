# frozen_string_literal: true

require "test_helper"

class KeyTest < Minitest::Test
  def key(text) = Yanagi::Key.call(text)

  # Ported from japan_dojo_games Jibiki::Search::CyrillicKey.
  SAME_KEY = {
    "джесучя" => "джесуча", "чя" => "ча", "шьоґацу" => "шогацу", "суші" => "сусі",
    "фуджі" => "Фудзі", "ґенкі" => "генкі", "кіте" => "кітте", "ніппон" => "ніпон",
    "джюдо" => "дзюдо"
  }.freeze

  # Extended from the forbidden lists in data/mora.yml.
  FORBIDDEN_FOLDS = {
    "мейджі" => "мейзі", "цушіма" => "тсусіма", "фуку" => "хуку", "шьочю" => "сьочю",
    "хірошіма" => "Хіросіма", "мічя" => "мітя", "кьото" => "кёто", "дзаші" => "засі",
    "дзудзу" => "зузу", "шінджюку" => "Сіндзюку", "джьо" => "зьо", "ґьоза" => "гёдза"
  }.freeze

  # Spellings found missing against Warodai's Polivanov readings.
  WARODAI_FOLDS = {
    "суіка" => "суйка", "сусухарай" => "сусухараі", "кавайі" => "каваї", "мукайнамі" => "мукаінамі",
    "енмей" => "еммей", "шімбун" => "шінбун", "кікембуцу" => "кікенбуцу"
  }.freeze

  def test_yanagi_and_everyday_spellings_share_a_key
    SAME_KEY.merge(FORBIDDEN_FOLDS, WARODAI_FOLDS).each do |yanagi, typed|
      assert_equal key(yanagi), key(typed), "#{typed} should key like #{yanagi}"
    end
  end

  def test_keeps_spellings_yanagi_tells_apart
    refute_equal key("паті"), key("пачі")
    assert_equal "сакура", key("сакура")
    assert_equal "токіо", key("Токіо")
  end

  def test_keeps_short_i_before_a_vowel
    assert_equal "майа", key("майа")
    refute_equal key("йокай"), key("іокай")
  end

  def test_dza_is_not_folded_twice
    assert_equal "дзаші", key("дзаші")
    assert_equal "дзудзу", key("дзудзу")
  end

  def test_drops_apostrophes
    assert_equal key("шінічі"), key("шін'ічі")
  end

  def test_respell_substitutes_every_forbidden_sequence_at_once
    assert_equal "шінджюку", Yanagi::Key.respell("сіндзюку")
    assert_equal "шідзуока", Yanagi::Key.respell("сідзуока")
    assert_equal "паті", Yanagi::Key.respell("паті")
  end

  def test_forbidden
    assert Yanagi::Key.forbidden?("сусі")
    refute Yanagi::Key.forbidden?("суші")
    refute Yanagi::Key.forbidden?("дзаші")
  end
end
