# frozen_string_literal: true

require "test_helper"

class InflectionTest < Minitest::Test
  def split(token) = Yanagi::Inflection.split(token)

  def test_bare_token_comes_first
    assert_equal ["Хіросіму", ""], split("Хіросіму").first
  end

  def test_splits_every_matching_ending
    assert_includes split("Хіросіму"), ["Хіросім", "у"]
    assert_includes split("Хіросімою"), ["Хіросім", "ою"]
    assert_includes split("Хіросімою"), ["Хіросімо", "ю"]
    assert_includes split("самураями"), ["самура", "ями"]
    assert_includes split("ніхонові"), ["ніхон", "ові"]
  end

  def test_longer_endings_are_tried_first
    endings = split("самураями").map(&:last)
    assert_equal ["", "ями", "и"], endings
  end

  def test_keeps_a_minimum_stem
    assert_equal [["суші", ""], ["суш", "і"]], split("суші")
    assert_equal [["ґо", ""]], split("ґо")
  end

  def test_bases
    assert_equal ["хірошім", "хірошіма", "хірошімя", "хірошімй"], Yanagi::Inflection.bases("хірошім", "у")
    assert_equal ["суші"], Yanagi::Inflection.bases("суші", "")
  end

  REJOIN = [
    ["хірошіма", "у", "Хіросіму", "Хірошіму"],
    ["хірошіма", "ою", "ХІРОСІМОЮ", "ХІРОШІМОЮ"],
    ["Хірошіма", "і", "хіросімі", "хірошімі"],
    ["самурай", "ями", "самураями", "самураями"],
    ["ніхон", "у", "Ніхону", "Ніхону"],
    ["суші", "", "Сусі", "Суші"],
    ["шьочю", "", "сьочю", "шьочю"]
  ].freeze

  def test_rejoin_puts_the_ending_back_in_the_token_case
    REJOIN.each do |canonical, ending, token, expected|
      assert_equal expected, Yanagi::Inflection.rejoin(canonical, ending, case_of: token)
    end
  end
end
