# frozen_string_literal: true

require_relative "deprecator"

module PoliPage
  module Rails
    class Configuration
      attr_accessor :api_key, :base_url, :timeout,
                    :max_retries, :retry_delay,
                    :logger, :on_retry, :on_error,
                    :proxy, :ca_file, :ca_path,
                    :notifications, :error_handler

      def initialize
        @api_key       = nil
        @base_url      = nil
        @timeout       = nil
        @max_retries   = nil
        @retry_delay   = nil
        @logger        = nil
        @on_retry      = nil
        @on_error      = nil
        @proxy         = nil
        @ca_file       = nil
        @ca_path       = nil
        @notifications = true
        @error_handler = true
      end

      USER_AGENT_DEPRECATION = "config.poli_page.user_agent has no effect, the Poli Page SDK sends " \
                               "its own User-Agent; remove it. It will be removed in a later minor release."

      # Deprecated no-op: the SDK takes no User-Agent option, so the value was
      # never passed on. Kept so that an initializer that sets it still boots.
      def user_agent=(_value)
        PoliPage::Rails.deprecator.warn(USER_AGENT_DEPRECATION)
      end

      # Deprecated no-op, see #user_agent=. Always nil.
      def user_agent
        PoliPage::Rails.deprecator.warn(USER_AGENT_DEPRECATION)
        nil
      end

      # Single source of truth for SDK kwargs. Compact drops every nil entry,
      # so the SDK's own defaults take over for every unset key.
      def to_client_kwargs
        {
          api_key:     api_key,
          base_url:    base_url,
          max_retries: max_retries,
          retry_delay: retry_delay,
          timeout:     timeout,
          logger:      logger,
          on_retry:    on_retry,
          on_error:    on_error,
          proxy:       proxy,
          ca_file:     ca_file,
          ca_path:     ca_path
        }.compact
      end
    end
  end
end
