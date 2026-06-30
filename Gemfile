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

# Work around RDoc/JRuby incompatibiltiy: rdoc 8 depends on rbs 4, whose native C extension can't
# build on JRuby.
#
# Remove this once https://github.com/ruby/rdoc/issues/1746 is resolved.
gem "rdoc", "< 8.0"

group :test do
  gem "rspec", "~> 3.7"
end
