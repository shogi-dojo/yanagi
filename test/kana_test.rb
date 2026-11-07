# frozen_string_literal: true

require "test_helper"

class KanaTest < Minitest::Test
  HIRAGANA = {
    # Hepburn / Kunrei / wapuro variants of the same kana
    "shi" => "し", "si" => "し",
    "chi" => "ち", "ti" => "ち",
    "tsu" => "つ", "tu" => "つ",
    "fu" => "ふ", "hu" => "ふ",
    "ji" => "じ", "zi" => "じ", "di" => "ぢ", "du" => "づ",
    "sha" => "しゃ", "sya" => "しゃ", "shu" => "しゅ", "syo" => "しょ",
    "cha" => "ちゃ", "tya" => "ちゃ", "cho" => "ちょ", "tyu" => "ちゅ",
    "ja" => "じゃ", "zya" => "じゃ", "jya" => "じゃ", "ju" => "じゅ", "jyo" => "じょ",
    "kya" => "きゃ", "ryo" => "りょ", "nya" => "にゃ",
    "wo" => "を", "ya" => "や", "fa" => "ふぁ", "ve" => "ゔぇ", "xtu" => "っ",
    # moraic n
    "kan" => "かん", "kanji" => "かんじ", "kon'ya" => "こんや", "konya" => "こにゃ",
    "kann" => "かん", "kanna" => "かんな", "konnnichi" => "こんにち",
    "shinbun" => "しんぶん", "shimbun" => "しんぶん", "kempou" => "けんぽう",
    # sokuon
    "kitte" => "きって", "kekka" => "けっか", "zasshi" => "ざっし", "sappari" => "さっぱり",
    "matcha" => "まっちゃ", "kokku" => "こっく", "ippai" => "いっぱい",
    # long vowels
    "ou" => "おう", "oo" => "おお", "aa" => "ああ", "ō" => "おう", "â" => "ああ",
    "ī" => "いい", "ū" => "うう", "ē" => "ええ",
    # real words
    "taberu" => "たべる", "toukyou" => "とうきょう", "tōkyō" => "とうきょう",
    "tôkyô" => "とうきょう", "kon'nichiha" => "こんにちは", "konnichiha" => "こんにちは",
    "nihongo" => "にほんご", "gakkou" => "がっこう", "kyouto" => "きょうと",
    # case and whitespace
    "TABERU" => "たべる", "Tabe" => "たべ", "  taberu \n" => "たべる",
    "tabe ru" => "たべ る", "Ｔａｂｅｒｕ" => "たべる", "kon’nichiha" => "こんにちは",
    # long mark in hiragana
    "ra-men" => "らーめん"
  }.freeze

  KATAKANA = {
    "taberu" => "タベル", "toukyou" => "トウキョウ", "tōkyō" => "トーキョー",
    "tôkyô" => "トーキョー", "koohii" => "コーヒー", "kōhī" => "コーヒー",
    "ra-men" => "ラーメン", "raamen" => "ラーメン", "rāmen" => "ラーメン",
    "suupaa" => "スーパー", "kitte" => "キッテ", "shimbun" => "シンブン",
    "kon'nichiha" => "コンニチハ", "chokoreeto" => "チョコレート",
    "paathii" => "パーティー", "BIIRU" => "ビール", "sya" => "シャ", "tu" => "ツ"
  }.freeze

  NOT_ROMAJI = [
    "", "   ", nil, 42, "日本", "たべる", "taberu1", "ta be!ru", "k", "tabek", "xyz",
    "-", "-a", "'", "a'", "ny", "qa", "tabe?"
  ].freeze

  def test_hiragana_table
    HIRAGANA.each do |input, expected|
      assert_equal expected, Yanagi.kana(input), "kana(#{input.inspect})"
    end
  end

  def test_katakana_table
    KATAKANA.each do |input, expected|
      assert_equal expected, Yanagi.kana(input, script: :katakana), "kana(#{input.inspect}, :katakana)"
    end
  end

  def test_not_romaji_returns_nil
    NOT_ROMAJI.each do |input|
      assert_nil Yanagi.kana(input), "kana(#{input.inspect})"
    end
  end

  def test_unknown_script_raises
    assert_raises(ArgumentError) { Yanagi.kana("ka", script: :kanji) }
  end

  def test_every_spelling_variant_agrees
    [
      %w[shi si], %w[chi ti], %w[tsu tu], %w[fu hu], %w[ji zi],
      %w[sha sya], %w[cha tya cya], %w[ja zya jya]
    ].each do |group|
      assert_equal 1, group.map { |r| Yanagi.kana(r) }.uniq.size, group.inspect
    end
  end
end
