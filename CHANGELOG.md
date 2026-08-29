# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/shogi-dojo/yanagi/releases/tag/v0.1.0
