# frozen_string_literal: true

require "test_helper"

class NormalizeTest < Minitest::Test
  def test_nfkc_normalization
    assert_equal "か", Yanagi::Normalize.nfkc("か")
    assert_equal "カ", Yanagi::Normalize.nfkc("カ")
  end

  def test_to_hiragana_conversion
    assert_equal "しゅうさい", Yanagi::Normalize.to_hiragana("シュウサイ")
    assert_equal "とうきょう", Yanagi::Normalize.to_hiragana("トウキョウ")
    assert_equal "めいじん", Yanagi::Normalize.to_hiragana("めいじん")
    assert_equal "abc-123", Yanagi::Normalize.to_hiragana("abc-123")
  end
end
