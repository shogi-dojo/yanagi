# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] — 2026-11-08

### Added

- **`Yanagi::Checker`.** `Checker.new(anchors:, ukrainian:, overrides:)#check(text)`
  returns `Finding(start, stop, token, suggestion, kind, confidence, source)`
  for Japanese words spelled against the policy, with character offsets.
  `kind` is `override`, `dictionary` (an anchor matched by spelling key) or
  `rule` (forbidden sequences plus Japanese markers, all substituted at once,
  low confidence). Case endings and letter case are kept: «Хіросіму» →
  «Хірошіму», «ХІРОСІМОЮ» → «ХІРОШІМОЮ». Words in the Ukrainian list are left
  alone, and «ті» becomes «чі» only when an anchor confirms it.
- `Yanagi::Checker::MemoryAnchors` (rows, or `[kana, kanji]` pairs rendered with
  `Yanagi.cyrillic`) and `Yanagi::Checker::WordSet`. Any object with
  `lookup(key)` / `include?(word)` can stand in; the gem ships no data.
- `yanagi check FILE [--anchors x.yml] [--ukrainian words.txt] [--overrides x.yml] [--format json|human]`.
- **`Yanagi::Key.call(text)`**, the spelling-neutral key from Jibiki's search
  (`Jibiki::Search::CyrillicKey`), with folds taken from the `forbidden:`
  lists in `data/mora.yml` (дзі/зі→джі, тсу→цу, ху→фу, ё→ьо, …).
- **`Yanagi::Inflection`**: `split(token)` into stem + case ending candidates,
  `bases(stem, ending)` for dictionary forms, and `rejoin(canonical, ending, case_of:)`.
- A RuboCop config, with a todo file for the existing code.

## [0.2.0] — 2026-11-07

### Added

- **`Yanagi.kana(romaji, script: :hiragana | :katakana)`.** Public romaji→kana
  conversion for search input. Accepts Hepburn, Kunrei and wapuro spellings
  (shi/si, chi/ti, tsu/tu, fu/hu, ji/zi/di, sha/sya, cha/tya, ja/zya/jya),
  `n` before consonants, `n'`, `nn` and final `n` as ん, double consonants and
  `tch` as っ, `m` before b/p/m as ん, and long vowels (`ou`, `oo`, `ō`, `â`).
  Katakana output renders macrons, doubled vowels and `-` as ー. Input is
  case-insensitive and trimmed. Returns `nil` when the input is not romaji.

### Changed

- `Yanagi::Cyrillic.romaji_to_hiragana` delegates to `Yanagi::Kana`, so Mode A
  romaji input now understands Kunrei and wapuro spellings too. Input that
  cannot convert is still returned lowercased.

### Fixed

- ジェ / じぇ and イェ / いぇ romanize as `je` and `ye` (they came out as `jiぇ`
  and `iぇ`) and transliterate as «дже» and «є».

## [0.1.0] — 2026-08-29

First release. Yanagi (柳) turns the Japanese→Ukrainian transliteration policy
from prose into executable rules, so a violation fails a build instead of
reaching print.

### Added

- **Mode A — generation.** `Yanagi.cyrillic` and `Yanagi.romaji` render kana
  (or katakana, or a kanji + reading pair) into Ukrainian Cyrillic and Modified
  Hepburn. Both derive from a single mora tokenizer, so they cannot disagree
  about mora boundaries.
- **Mode B — audit.** `Yanagi::Audit` scans existing Ukrainian prose in three
  tiers. Only tokens anchored to a known Japanese lexical item are ever
  rewritten; pattern matches merely rank what a human reviews. Findings are
  reported by default and applied only from an approved findings file.
- **`Yanagi::DocSync`.** Parses the authoritative policy document and asserts it
  agrees with the rules data, so the doc and the engine cannot drift.
- **CLI** (`yanagi`): `romaji`, `cyrillic`, `audit`, `apply`, `doc-sync`,
  `lexicon`, `verify-gold`.
- **Rules as data** in `data/`: the mora table with its forbidden variants,
  combinatorial rules, exonyms, the lexicon, a native-Ukrainian allowlist, and
  an exceptions table.

### Policy encoded

- Mora table rejecting Polivanov: ші, чі, цу, фу, джі, дз, ґ.
- Palatalised syllables (yōon), including the soft sign before о: шьо, чьо, джьо.
- い after a vowel renders as «і», never «ї».
- ん renders as «м» before п and б, «н» elsewhere.
- Long vowels are not doubled.
- Sokuon っ doubles the following consonant before the plosives п and к, and is
  not rendered before sibilants and affricates.
- Established Ukrainian exonyms take precedence over derivation.

### Verification

- 377/377 hand-verified glossary pairs pass, with an empty exceptions table.
- Romaji output is byte-identical across 1496 dictionary readings, confirming
  the engine was extracted from its predecessor without behaviour change.
- Zero runtime dependencies; stdlib only.

[0.3.0]: https://github.com/shogi-dojo/yanagi/releases/tag/v0.3.0
[0.2.0]: https://github.com/shogi-dojo/yanagi/releases/tag/v0.2.0
[0.1.0]: https://github.com/shogi-dojo/yanagi/releases/tag/v0.1.0
