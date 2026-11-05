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
  skip "/spec/"
  skip "/example-app/"
  enable_coverage :branch

  # Coverage gate, as in the poli-page SDK, but opt-in. The floors describe
  # the whole unit suite, so they are judged only when the run is the whole
  # unit suite: the unit job in ci.yml sets `SIMPLECOV_ENFORCE=1`. A partial run
  # (one spec file, or the live `spec/integration` job) measures a slice of lib/
  # and would fail the floors for a reason that is not a coverage regression.
  # To check the gate locally: `SIMPLECOV_ENFORCE=1 bundle exec rspec
  # --exclude-pattern "spec/integration/**/*"`.
  minimum_coverage line: 90, branch: 75 if ENV["SIMPLECOV_ENFORCE"] == "1"
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
