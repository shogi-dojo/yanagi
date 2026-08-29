# frozen_string_literal: true

require "test_helper"
require "tempfile"

class AuditTest < Minitest::Test
  def test_tier1_autofix_detection
    sample_text = "Тут виступав відомий мейдзін."
    findings = Yanagi::Audit.scan_text(sample_text)

    t1 = findings.find { |f| f.tier == 1 }
    refute_nil t1
    assert_equal "мейдзін", t1.token
    assert_equal "мейджін", t1.canonical
    assert t1.approved
  end

  def test_tier1_ignores_non_lexicon_native_words
    sample_text = "Він запалив сірник і подивився на вісім годин."
    findings = Yanagi::Audit.scan_text(sample_text, tier2: true, tier3: false)

    t1 = findings.select { |f| f.tier == 1 }
    assert_empty t1, "Native words like 'сірник' or 'вісім' must NOT trigger Tier 1"
  end

  def test_tier2_unanchored_jp_markers
    sample_text = "Він згадав термін шімейджіна якого немає в словнику."
    findings = Yanagi::Audit.scan_text(sample_text, tier2: true, tier3: false)

    t2 = findings.select { |f| f.tier == 2 }
    assert t2.any? { |f| f.token.include?("шімейджін") }
  end

  def test_tier3_off_by_default
    sample_text = "Полівановське невідоме слово дзіка без словника."
    findings_default = Yanagi::Audit.scan_text(sample_text, tier3: false)
    assert_empty findings_default.select { |f| f.tier == 3 }

    findings_tier3 = Yanagi::Audit.scan_text(sample_text, tier3: true)
    refute_empty findings_tier3.select { |f| f.tier == 3 }
  end

  # Regression: Chinese-origin glossary terms (e.g. 呂祖全書 «Люйцзу цюаньшу»)
  # are transliterated by Chinese conventions, so Japanese mora rules such as
  # шу -> шю must never fire on them.
  def test_tier1_skips_non_japanese_origin_terms
    findings = Yanagi::Audit.scan_text("Даоське зібрання «Люйцзу цюаньшу» згадане тут.")
    tier1 = findings.select { |f| f.tier == 1 }
    assert_empty tier1, "Chinese-origin term must not be rewritten by Japanese rules"
  end

  def test_audit_apply
    Tempfile.create(["sample", ".txt"]) do |sample_f|
      sample_f.write("Великий мейдзін прибув до Токіо.")
      sample_f.flush

      findings = Yanagi::Audit.scan(sample_f.path)
      assert_equal 1, findings.length

      Tempfile.create(["findings", ".yml"]) do |findings_f|
        findings_f.write(YAML.dump(findings.map(&:to_h)))
        findings_f.flush

        count = Yanagi::Audit.apply(findings_f.path)
        assert_equal 1, count

        updated_text = File.read(sample_f.path, encoding: "UTF-8")
        assert_equal "Великий мейджін прибув до Токіо.", updated_text
      end
    end
  end

  def test_meijin_corpus_tier1_is_zero
    meijin_ua = File.expand_path("~/projects/meijin/books/meijin/translation/ua")
    skip "meijin translation directory not found" unless Dir.exist?(meijin_ua)

    findings = Yanagi::Audit.scan(meijin_ua, tier2: false, tier3: false)
    tier1_findings = findings.select { |f| f.tier == 1 }

    assert_empty tier1_findings, "Expected 0 Tier 1 violations in meijin corpus: #{tier1_findings.inspect}"
  end
end
