# frozen_string_literal: true

SPEC_ROOT = Pathname(__FILE__).dirname

require "hanami/reloader"
require "hanami/devtools/integration"

require_relative "support/rspec"
SPEC_ROOT.glob("support/**/*.rb").each { |f| require(f) }
