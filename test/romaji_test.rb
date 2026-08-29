# frozen_string_literal: true

require "test_helper"

class RomajiTest < Minitest::Test
  def test_basic_romaji
    assert_equal "ka", Yanagi.romaji("か")
    assert_equal "shuusai", Yanagi.romaji("しゅうさい")
    assert_equal "shuusai", Yanagi.romaji("シュウサイ")
    assert_equal "meijin", Yanagi.romaji("めいじん")
    assert_equal "toukyou", Yanagi.romaji("とうきょう")
  end

  def test_sokuon_romaji
    assert_equal "gakkou", Yanagi.romaji("がっこう")
    assert_equal "matchi", Yanagi.romaji("まっち")
    assert_equal "kitchan", Yanagi.romaji("きっちゃん")
    assert_equal "issho", Yanagi.romaji("いっしょ")
  end

  def test_chouonpu_romaji
    assert_equal "koohii", Yanagi.romaji("コーヒー")
    assert_equal "kaataa", Yanagi.romaji("カーター")
  end
end
