# frozen_string_literal: true

require_relative "yanagi/version"
require_relative "yanagi/normalize"
require_relative "yanagi/rules"
require_relative "yanagi/mora"
require_relative "yanagi/romaji"

module Yanagi
  class Error < StandardError; end
end
