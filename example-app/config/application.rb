require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load .env.local, then .env, from the app directory. Real shell exports
# always win (Dotenv.load — not overload).
require "dotenv"
Dotenv.load(".env.local", ".env")

module ExampleApp
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    # No ActiveRecord — this app only consumes the Poli Page API.
    config.generators.system_tests = nil
  end
end
