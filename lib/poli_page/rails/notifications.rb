# frozen_string_literal: true

require "active_support/notifications"

module PoliPage
  module Rails
    # Bridges the SDK's on_retry / on_error Closure hooks into Rails-idiomatic
    # ActiveSupport::Notifications events.
    #
    # Event names follow Rails conventions (sql.active_record, deliver.action_mailer):
    #   - "poli_page.retry"  — fired before each retry attempt
    #   - "poli_page.error"  — fired on terminal failure (post-retries)
    #
    # Default-on: the Railtie installs the bridges as the default on_retry /
    # on_error config values, so retries and failures reach the usual Rails
    # instrumentation subscribers without extra wiring. Users opt out via
    # c.notifications = false in the initializer.
    module Notifications
      RETRY_EVENT_NAME = "poli_page.retry"
      ERROR_EVENT_NAME = "poli_page.error"

      def self.retry_bridge
        @retry_bridge ||= lambda do |event|
          ::ActiveSupport::Notifications.instrument(
            RETRY_EVENT_NAME,
            attempt:  event.attempt,
            delay_ms: event.delay_ms,
            reason:   event.reason
          )
        end
      end

      def self.error_bridge
        @error_bridge ||= lambda do |error|
          ::ActiveSupport::Notifications.instrument(
            ERROR_EVENT_NAME,
            error: error
          )
        end
      end
    end
  end
end
