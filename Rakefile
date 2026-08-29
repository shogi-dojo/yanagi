# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require_relative "lib/yanagi"
require_relative "lib/yanagi/cli"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

namespace :translit do
  desc "Verify transliteration rules against gold glossary"
  task :gold do
    Yanagi::CLI.new(["verify-gold"]).run
  end
end

desc "Verify transliteration policy doc agreement with rules"
task :doc_sync do
  Yanagi::CLI.new(["doc-sync"]).run
end

task default: :test
