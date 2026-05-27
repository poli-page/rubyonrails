# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Why: poli-page (the SDK) is not yet on RubyGems. Path override lives in the
# Gemfile so the gemspec stays Packagist-ready. Delete this line once
# poli-page publishes; everything else continues to work unchanged.
gem "poli-page", path: "../sdk-ruby"

group :development, :test do
  gem "rake",        "~> 13.2"
  gem "rspec-rails", "~> 6.1"
  gem "combustion",  "~> 1.5"
  gem "appraisal",   "~> 2.5"
  gem "rubocop",             require: false
  gem "rubocop-rails",       require: false
  gem "rubocop-rspec",       require: false
  gem "rubocop-performance", require: false
  gem "dotenv", "~> 3.1"
end
