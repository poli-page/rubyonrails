# frozen_string_literal: true

require "simplecov"
require "simplecov-lcov"

# Emit both the HTML report (for local inspection) and a single LCOV file
# (consumed by the Codecov uploader in CI). Started before anything of the gem
# is loaded, so every line of lib/ is measured.
SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = "coverage/lcov.info"
end

# Assign the array of formatter classes directly; SimpleCov wraps them in a
# MultiFormatter internally.
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter
]

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/example-app/"
  enable_coverage :branch
end

require "dotenv"

# Why: a local .env.local or .env (both gitignored) can hold POLI_PAGE_API_KEY
# for the integration spec. Real shell exports always win — Dotenv.load (not
# Dotenv.overload) only sets vars not already present.
Dotenv.load(".env.local", ".env")

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random
  Kernel.srand(config.seed)
end
