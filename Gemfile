# frozen_string_literal: true

source "https://rubygems.org"

eval_gemfile "Gemfile.devtools"

gemspec

unless ENV["CI"]
  gem "yard", require: false
end

gem "hanami-utils", github: "hanami/utils", branch: "main"
gem "hanami-cli", github: "hanami/cli", branch: "main"
gem "hanami", github: "hanami/hanami", branch: "main"

gem "hanami-devtools", github: "hanami/devtools", branch: "main"

group :test do
  gem "rspec", "~> 3.7"
end
