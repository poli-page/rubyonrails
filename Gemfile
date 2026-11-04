# frozen_string_literal: true

source "https://rubygems.org"

gemspec

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
  gem "simplecov", "~> 1.2", require: false
  # Emits coverage/lcov.info for the Codecov uploader (CI step in
  # `.github/workflows/ci.yml`). The HTML report under coverage/ is still
  # produced for local inspection.
  gem "simplecov-lcov", "~> 0.8", require: false
end
