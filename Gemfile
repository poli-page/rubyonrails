# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Why: the poli-page release without template versions and render.preview is
# not on RubyGems yet. Pin sdk-ruby main at that change (poli-page/sdk-ruby#27)
# until the release ships, then delete this line.
gem "poli-page", git: "https://github.com/poli-page/sdk-ruby", ref: "a139f43f9bd12fe4a40e8f7edb6ea97c0af25c2d"

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
