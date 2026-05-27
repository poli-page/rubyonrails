# frozen_string_literal: true

require "rails/railtie"

require_relative "notifications"

module PoliPage
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "poli_page.configure", before: :load_config_initializers do |app|
        # Why: Rails::Application::Configuration#method_missing raises
        # NoMethodError on read when the key has never been set, so the
        # idiomatic `||=` expansion (which reads first) blows up at boot.
        # Assign unconditionally — user code in config/initializers/poli_page.rb
        # runs AFTER this (we use before: :load_config_initializers) and
        # mutates the existing Configuration object, it never reassigns.
        app.config.poli_page = Configuration.new
      end

      config.after_initialize do |app|
        c = app.config.poli_page
        c.logger ||= ::Rails.logger

        if c.notifications
          c.on_retry ||= PoliPage::Rails::Notifications.retry_bridge
          c.on_error ||= PoliPage::Rails::Notifications.error_bridge
        end
      end
    end
  end
end
