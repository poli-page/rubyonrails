# frozen_string_literal: true

require "active_support"
require "active_support/deprecation"

require_relative "version"

module PoliPage
  module Rails
    # The gem's deprecation warnings. The Railtie registers it in
    # Rails.application.deprecators (Rails 7.1+), so the app's
    # config.active_support.deprecation setting applies to it.
    def self.deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("0.14", "poli_page-rails")
    end
  end
end
