# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "action_dispatch/railtie"

require "poli_page-rails"

module Internal
  class Application < ::Rails::Application
    config.load_defaults ::Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.secret_key_base = "test_secret_key_base_at_least_32_characters_long_for_rails_8"
    config.session_store :cookie_store, key: "_internal_session"
    config.active_support.test_order = :random
  end
end
