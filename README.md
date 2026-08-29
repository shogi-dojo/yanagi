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
- **Policy Synchronization (`DocSync`)**: Asserts agreement between markdown policy documents (`shared/transliteration.md`) and executable YAML rules.

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

### Mode B: Prose Audit & Correction

```ruby
# Scan files or directories
findings = Yanagi.audit(["path/to/chapter.org"], tier2: true, tier3: false)

# Apply approved findings
Yanagi::Audit.apply("audit/findings.yml")
```

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

# Document synchronization & gold verification
yanagi doc-sync shared/transliteration.md
yanagi verify-gold
```

## License

MIT License. Copyright (c) 2026 shogi-dojo.
