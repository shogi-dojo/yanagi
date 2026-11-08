# Yanagi (柳)

Deterministic Japanese → Ukrainian transliteration and policy enforcement gem.

柳 (*yanagi* = willow / верба) — a symbol of Ukraine and a tree equally at home in Japanese poetry.

## Features
- **Zero runtime dependencies** — standard library only (`yaml`, `json`, `set`, `unicode_normalize`).
- **Mode A (Generation)**: Deterministic kana and romaji to Ukrainian Cyrillic rendering.
- **Mode B (Audit)**: Lexicon-anchored prose audit and policy violation detector:
  - **Tier 1**: AUTOFIX-eligible (matches lexicon entry via forbidden Polivanov/anglicism substitution).
  - **Tier 2**: High-confidence report for unknown Japanese terms (contains JP markers, unanchored in lexicon/allowlist).
  - **Tier 3**: Polivanov markers check (off by default).
- **Checker**: Finds Japanese words in Ukrainian text spelled against the policy (Polivanov, Russian ё, case endings included) and suggests the canonical form, anchored by a dictionary you supply.
- **Policy Synchronization (`DocSync`)**: Asserts agreement between markdown policy documents (`shared/transliteration.md`) and executable YAML rules.

## Corpus data

The gem ships the **policy rules** only: the mora table, combinatorial rules,
exonyms and the exceptions table.

Mode B additionally needs two files generated from a specific translation
project — a lexicon of known Japanese terms and an allowlist of native
Ukrainian vocabulary. These are **not distributed**, because they are one
project's editorial research rather than transliteration policy.

Mode A (`cyrillic`, `romaji`) needs neither and works out of the box. Without
them Mode B simply reports nothing, since it only ever rewrites tokens anchored
to a known lexical item.

To use Mode B, generate the files and point the gem at them:

```bash
export YANAGI_DATA_DIR=/path/to/your/data
yanagi lexicon build --glossary /path/to/glossary.org
```


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'yanagi'
```

Or reference via git repository:

```ruby
gem 'yanagi', git: 'https://github.com/shogi-dojo/yanagi.git', tag: 'v0.1.0'
```

## Ruby API Usage

### Mode A: Transliteration

```ruby
require 'yanagi'

# Kana to Cyrillic
Yanagi.cyrillic("しゅうさい")
# => #<Yanagi::Result text="шюсай" source=:derived confidence=1.0>

Yanagi.cyrillic("シュウサイ")
# => #<Yanagi::Result text="шюсай" source=:derived confidence=1.0>

# Exonyms
Yanagi.cyrillic("とうきょう")
# => #<Yanagi::Result text="Токіо" source=:exonym confidence=1.0>

# Kana to Modified Hepburn Romaji
Yanagi.romaji("しゅうさい")
# => "shuusai"

# From Romaji to Cyrillic
Yanagi.from_romaji("shuusai")
# => "шюсай"
```

### Romaji to kana (search input)

```ruby
Yanagi.kana("Tōkyō")                       # => "とうきょう"
Yanagi.kana("kon'nichiha")                 # => "こんにちは"
Yanagi.kana("shimbun")                     # => "しんぶん"
Yanagi.kana("kitte")                       # => "きって"
Yanagi.kana("ra-men", script: :katakana)   # => "ラーメン"
Yanagi.kana("taberu日本")                  # => nil (not romaji)
```

Hepburn, Kunrei and wapuro spellings are all accepted (`shi`/`si`, `chi`/`ti`,
`tsu`/`tu`, `fu`/`hu`, `ji`/`zi`, `sha`/`sya`, `ja`/`zya`/`jya`). Case and
surrounding whitespace are ignored. `nn` before a vowel is read as ん plus the
n-row kana (`konnichi` → こんにち); type `nnn` or `n'` to force ん + vowel.
`di`/`du` give ぢ/づ, so callers matching a dictionary may want to fold them to
じ/ず. In katakana, `ō`, `â`, doubled vowels and `-` give ー, while `ou` stays
オウ. Anything that is not plain romaji returns `nil`.

### Mode B: Prose Audit & Correction

```ruby
# Scan files or directories
findings = Yanagi.audit(["path/to/chapter.org"], tier2: true, tier3: false)

# Apply approved findings
Yanagi::Audit.apply("audit/findings.yml")
```

### Checker

`Yanagi::Checker` finds Japanese words in Ukrainian prose that break the
policy and suggests the canonical spelling with the case ending and letter case
kept: «сьочю» → «шьочю», «Хіросіму» → «Хірошіму», «Мейдзі» → «Мейджі».

```ruby
anchors = Yanagi::Checker::MemoryAnchors.from_pairs(
  [%w[しょうちゅう 焼酎], %w[ひろしま 広島], %w[めいじ 明治]], origin: "jmdict"
)
words = Yanagi::Checker::WordSet.load("uk_words.txt")
checker = Yanagi::Checker.new(anchors: anchors, ukrainian: words, overrides: { "токіо" => "Токіо" })

checker.check("Ми пили сьочю в Хіросімі.")
# => [#<struct Finding start=8, stop=13, token="сьочю", suggestion="шьочю",
#       kind=:dictionary, confidence=0.9, source={kana: "しょうちゅう", kanji: "焼酎", origin: "jmdict"}>,
#     #<struct Finding start=16, stop=24, token="Хіросімі", suggestion="Хірошімі", ...>]
```

`start` and `stop` are character offsets (`text[start...stop] == token`). Each
Cyrillic token (letters, inner apostrophes and hyphens) is checked in order:

1. **`override`** — `overrides` (`{ wrong => right }`) match the token exactly or
   as stem + case ending, and win over everything else.
2. Words in the **Ukrainian word list** are skipped («сьогодні», «сім», «тісто»).
3. **`dictionary`** — every stem + ending split (`Yanagi::Inflection.split`) is
   looked up by its spelling key (`Yanagi::Key`). A canonical spelling means
   the token is correct; otherwise the heaviest anchor is suggested.
4. **`rule`** — a token with forbidden sequences *and* Japanese markers gets
   every forbidden sequence substituted at once, at low confidence.

The gem ships no word lists or dictionaries. Anchors are any object with
`lookup(key) → [{ cyrillic:, kana:, kanji:, origin:, weight: }]`, and the
word list any object with `include?(lower_case_word)`; `MemoryAnchors` and
`WordSet` are simple in-memory ones. Build anchors from JMdict / JMnedict
readings with `MemoryAnchors.from_pairs`, which renders each with
`Yanagi.cyrillic`.

`Yanagi::Key.call(text)` is the spelling-neutral key on its own, for search
indexes: «Фудзі», «фуджі» and «ФУДЖІ» share one. Its folds come from the
`forbidden:` lists in `data/mora.yml`; «ті» stays, since yanagi writes ティ so.

### Policy Agreement Check

```ruby
sync = Yanagi.doc_sync(path: "shared/transliteration.md")
sync.synced? # => true
sync.diff    # => []
```

## CLI Usage

```bash
# Romaji & Cyrillic generation
yanagi romaji しゅうさい
yanagi cyrillic しゅうさい
yanagi cyrillic しゅうさい --format json

# Prose auditing
yanagi audit books/meijin/translation/ua --format human
yanagi audit books/meijin/translation/ua --out audit/findings.yml

# Applying approved findings
yanagi apply audit/findings.yml

# Checking a text against your own anchors and word list (exit 1 on findings)
yanagi check chapter.md --anchors anchors.yml --ukrainian uk_words.txt
yanagi check chapter.md --overrides overrides.yml --format json

# Document synchronization & gold verification
yanagi doc-sync shared/transliteration.md
yanagi verify-gold
```

## License

MIT License. Copyright (c) 2026 shogi-dojo.
