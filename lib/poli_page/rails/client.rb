# frozen_string_literal: true

require "monitor"
require "poli_page"

require_relative "configuration_validator"

module PoliPage
  # Re-opened from the SDK. Adds the Rails-friendly lazy accessor.
  class << self
    def client
      Rails::Client.instance
    end

    # Test-only: clear the memoised instance so the next #client call rebuilds.
    # Marked private API; do NOT use in application code.
    def reset_client!
      Rails::Client.reset!
    end
  end

  module Rails
    # Holds the lazy memoised PoliPage::Client. Thread-safe via a Monitor.
    # The SDK documents Client as thread-safe (sdk-ruby/lib/poli_page/client.rb
    # thread-safety note), so memoising a single instance and sharing it across
    # threads is correct.
    module Client
      LOCK = Monitor.new
      private_constant :LOCK

      class << self
        def instance
          LOCK.synchronize do
            @instance ||= build!
          end
        end

        def reset!
          LOCK.synchronize do
            @instance = nil
          end
        end

        private

        def build!
          config = ::Rails.application.config.poli_page
          ConfigurationValidator.validate!(config)
          PoliPage::Client.new(**config.to_client_kwargs)
        end
      end
    end
  end
end
