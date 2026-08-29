# frozen_string_literal: true

require "test_helper"

class MoraTest < Minitest::Test
  def test_tokenize_basic_syllables
    moras = Yanagi::Tokenizer.tokenize("かきく")
    assert_equal 3, moras.length
    assert_equal %w[か き く], moras.map(&:kana)
    assert_equal [:syllable, :syllable, :syllable], moras.map(&:kind)
  end

  def test_tokenize_yoon_digraphs
    moras = Yanagi::Tokenizer.tokenize("しゅうさい")
    assert_equal 4, moras.length
    assert_equal %w[しゅ う さ い], moras.map(&:kana)
    assert_equal "sh", moras[0].onset
    assert_equal "yu", moras[0].nucleus
  end

  def test_tokenize_sokuon_and_chouonpu
    moras = Yanagi::Tokenizer.tokenize("がっこう・コーヒー")
    assert_equal 9, moras.length
    assert_equal %w[が っ こ う ・ こ ー ひ ー], moras.map(&:kana)
    kinds = moras.map(&:kind)
    assert_includes kinds, :sokuon
    assert_includes kinds, :chouonpu
  end

  def test_tokenize_moraic_n
    moras = Yanagi::Tokenizer.tokenize("ほんいんぼう")
    assert_equal 6, moras.length
    assert_equal %w[ほ ん い ん ぼ う], moras.map(&:kana)
    assert moras[1].moraic_n?
    assert moras[3].moraic_n?
  end
end
