# frozen_string_literal: true

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
