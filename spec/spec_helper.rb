# frozen_string_literal: true

require "dotenv"

# Why: single root .env across the entire integrations workspace (no per-app
# .env.local). Real shell exports always win — Dotenv.load (not Dotenv.overload)
# only sets vars not already present.
#
# Workspace root: /Users/mickael/Projects/symfony-bundle/.env is the de-facto
# shared root (the symfony-bundle was scaffolded first and owns the file).
Dotenv.load(
  File.expand_path("../../symfony-bundle/.env", __dir__),
  ".env.local",
  ".env"
)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random
  Kernel.srand(config.seed)
end
