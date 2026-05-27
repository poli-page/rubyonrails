# frozen_string_literal: true

require "rails/railtie"

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

      # Default logger fill-in. Task 8 extends this block to install the
      # ActiveSupport::Notifications bridges as default callables.
      config.after_initialize do |app|
        c = app.config.poli_page
        c.logger ||= ::Rails.logger
      end
    end
  end
end
