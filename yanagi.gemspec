# frozen_string_literal: true

require_relative "lib/yanagi/version"

Gem::Specification.new do |spec|
  spec.name          = "yanagi"
  spec.version       = Yanagi::VERSION
  spec.authors       = ["shogi-dojo"]
  spec.email         = ["dev@shogi-dojo.org"]

  spec.summary       = "Deterministic Japanese to Ukrainian transliteration engine"
  spec.description   = "Zero-dependency Japanese to Ukrainian transliteration and policy enforcement gem."
  spec.homepage      = "https://github.com/shogi-dojo/yanagi"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/shogi-dojo/yanagi"
  spec.metadata["changelog_uri"] = "https://github.com/shogi-dojo/yanagi/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib,data,exe}/**/*", "LICENSE*", "README*", "yanagi.gemspec"]
  end
  spec.bindir        = "exe"
  spec.executables   = ["yanagi"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", ">= 5.16"
  spec.add_development_dependency "rake", "~> 13.0"
end
