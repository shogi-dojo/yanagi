# frozen_string_literal: true

require_relative "yanagi/version"
require_relative "yanagi/normalize"
require_relative "yanagi/rules"
require_relative "yanagi/mora"
require_relative "yanagi/romaji"
require_relative "yanagi/cyrillic"
require_relative "yanagi/doc_sync"

module Yanagi
  class Error < StandardError; end
end
