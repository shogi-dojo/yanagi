# frozen_string_literal: true

require "test_helper"

class CyrillicTest < Minitest::Test
  def test_basic_kana_to_cyrillic
    res = Yanagi.cyrillic("しゅうさい")
    assert_equal "шюсай", res.text
    assert_equal :derived, res.source
    assert_equal "шюсай", res # string comparison
  end

  def test_katakana_normalization
    assert_equal "шюсай", Yanagi.cyrillic("シュウサイ")
    assert_equal "мейджін", Yanagi.cyrillic("メイジン")
  end

  def test_exonyms
    res = Yanagi.cyrillic("とうきょう")
    assert_equal "Токіо", res.text
    assert_equal :exonym, res.source

    assert_equal "Кіото", Yanagi.cyrillic("きょうと").text
    assert_equal "Осака", Yanagi.cyrillic("おおさか").text
  end

  def test_long_vowels_policy
    # Never double 'о', collapse long vowels
    assert_equal "отаке", Yanagi.cyrillic("おおたけ")
    assert_equal "ошіма", Yanagi.cyrillic("おおしま")
    assert_equal "шюсай", Yanagi.cyrillic("しゅうさい")
    assert_equal "шіншю", Yanagi.cyrillic("しんしゅう")
    assert_equal "кюдан", Yanagi.cyrillic("きゅうだん")

    # Preserve genuine i+i mora collisions
    assert_equal "кіін", Yanagi.cyrillic("きいん")
    assert_equal "ііда", Yanagi.cyrillic("いいだ")
    assert_equal "ріічі", Yanagi.cyrillic("りいち")
  end

  def test_i_after_vowels
    # Never 'ї', always 'і' or diphthong 'й'
    assert_equal "каруідзава", Yanagi.cyrillic("かるいざわ")
    assert_equal "ґоі", Yanagi.cyrillic("ごい")
    assert_equal "нуімон", Yanagi.cyrillic("ぬいもん")
    assert_equal "отеай", Yanagi.cyrillic("おてあい")
    assert_equal "мейджін", Yanagi.cyrillic("めいじん")
    assert_equal "сенсей", Yanagi.cyrillic("せんせい")
  end

  # Sokuon doubles before the plosives п and к, which Ukrainian carries
  # comfortably.
  def test_sokuon_geminates_before_plosives
    assert_equal "іппекі", Yanagi.cyrillic("いっぺき")
    assert_equal "кеппекі", Yanagi.cyrillic("けっぺき")
    assert_equal "ґоджюппо", Yanagi.cyrillic("ごじゅっぽ")
    assert_equal "ніккай", Yanagi.cyrillic("にっかい")
    assert_equal "ґаккай", Yanagi.cyrillic("がっかい")
    assert_equal "хоккекьо", Yanagi.cyrillic("ほっけきょう")
    assert_equal "джяккоджі", Yanagi.cyrillic("じゃっこうじ")
  end

  # Before sibilants and affricates it is not rendered: шш, чч and ддж read
  # as foreign in Ukrainian.
  def test_sokuon_not_rendered_before_sibilants
    assert_equal "шічяку", Yanagi.cyrillic("しっちゃく")
    assert_equal "тешю", Yanagi.cyrillic("てっしゅう")
    assert_equal "доджіндзаші", Yanagi.cyrillic("どうじんざっし")
  end

  # 紅葉 has no sokuon at all, so じ renders as a plain джі.
  def test_no_sokuon_no_gemination
    assert_equal "моміджі", Yanagi.cyrillic("もみじ")
  end

  def test_moraic_n
    # 'м' before p and b
    assert_equal "момпуку", Yanagi.cyrillic("もんぷく")
    assert_equal "самбо", Yanagi.cyrillic("さんぼう")
    assert_equal "шімбун", Yanagi.cyrillic("しんぶん")

    # 'н' before m and all others
    assert_equal "ранма", Yanagi.cyrillic("らんま")
    assert_equal "санмайкьо", Yanagi.cyrillic("さんまいきょう")
    assert_equal "шіншю", Yanagi.cyrillic("しんしゅう")
    assert_equal "хонімбо", Yanagi.cyrillic("ほんいんぼう")
    assert_equal "сенсей", Yanagi.cyrillic("せんせい")
  end

  def test_from_romaji
    assert_equal "шюсай", Yanagi.from_romaji("shuusai")
    assert_equal "мейджін", Yanagi.from_romaji("meijin")
  end

  # 妙手 (myoushu) was one of the long-vowel defects: the glossary read «мьоошю»
  # against the no-doubling rule. It is corrected at source, so the engine now
  # derives the right form directly instead of routing through an exception.
  def test_long_vowel_not_doubled
    assert_equal "мьошю", Yanagi.cyrillic("みょうしゅ").text
    assert_equal "кокоя", Yanagi.cyrillic("こうこうや").text
    assert_equal "торіма", Yanagi.cyrillic("とおりま").text
  end
end
