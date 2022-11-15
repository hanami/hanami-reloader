# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hanami/reloader/version"

Gem::Specification.new do |spec|
  spec.name          = "hanami-reloader"
  spec.version       = Hanami::Reloader::VERSION
  spec.authors       = ["Luca Guidi"]
  spec.email         = ["me@lucaguidi.com"]

  spec.summary       = "Hanami reloader"
  spec.description   = "Code reloading for Hanami"
  spec.homepage      = "http://hanamirb.org"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files         = `git ls-files -- lib/* CHANGELOG.md LICENSE.md README.md hanami-reloader.gemspec`.split($INPUT_RECORD_SEPARATOR) # rubocop:disable Layout/LineLength
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "hanami-cli", "~> 2.0.rc"
  spec.add_dependency "zeitwerk", "~> 2.6"

  spec.add_development_dependency "bundler", ">= 1.6", "< 3"
  spec.add_development_dependency "rake",    "~> 13.0"
  spec.add_development_dependency "rspec",   "~> 3.7"
  spec.add_development_dependency "rubocop", "~> 1.11"
end
