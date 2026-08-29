# frozen_string_literal: true

require "test_helper"
require "tempfile"

class LexiconTest < Minitest::Test
  def test_lexicon_loaded
    lex = Yanagi::Lexicon.load_entries
    refute_empty lex
    assert lex.key?("名人") || lex.key?(:名人)
  end

  def test_exact_lookup
    match = Yanagi::Lexicon.find_by_stem("мейджін")
    refute_nil match
    assert match[:exact]
  end

  def test_inflected_lookup
    match1 = Yanagi::Lexicon.find_by_stem("мейджіном")
    refute_nil match1
    assert_equal "мейджін", match1[:stem]

    match2 = Yanagi::Lexicon.find_by_stem("шюсая")
    refute_nil match2
  end

  def test_short_stem_collision_protection
    # 'Отаке' (kanji: 大竹) has stem 'отаке' / 'отак'.
    # Word 'отакий' should not collide as an inflection of 'Отаке'.
    match = Yanagi::Lexicon.find_by_stem("отакий")
    assert_nil match
  end

  def test_merge_proposal_validation
    valid_proposal = [
      {
        term: "テスト",
        kanji: "テスト",
        reading: "てすと",
        cyrillic: "тесуто", # Note: 'て' -> 'те', 'す' -> 'су', 'と' -> 'то'
        status: "accepted"
      }
    ]

    Tempfile.create(["prop", ".yml"]) do |prop_f|
      prop_f.write(YAML.dump(valid_proposal))
      prop_f.flush

      Tempfile.create(["lex", ".yml"]) do |lex_f|
        lex_f.write(YAML.dump({}))
        lex_f.flush

        res = Yanagi::Lexicon.merge_proposal(prop_f.path, out_path: lex_f.path)
        assert res.key?("テスト")
      end
    end
  end

  def test_merge_proposal_rejects_pending_or_invalid_cyrillic
    pending_prop = [{ kanji: "未定", reading: "みてい", cyrillic: "мітей", status: "pending" }]
    mismatch_prop = [{ kanji: "秀哉", reading: "しゅうさい", cyrillic: "шусай", status: "accepted" }]

    Tempfile.create(["prop", ".yml"]) do |f|
      f.write(YAML.dump(pending_prop))
      f.flush
      assert_raises(Yanagi::Error) do
        Yanagi::Lexicon.merge_proposal(f.path)
      end
    end

    Tempfile.create(["prop2", ".yml"]) do |f|
      f.write(YAML.dump(mismatch_prop))
      f.flush
      assert_raises(Yanagi::Error) do
        Yanagi::Lexicon.merge_proposal(f.path)
      end
    end
  end
end
