# frozen_string_literal: true

module PoliPage
  module Rails
    class Configuration
      attr_accessor :api_key, :base_url, :timeout, :user_agent,
                    :max_retries, :retry_delay,
                    :logger, :on_retry, :on_error,
                    :proxy, :ca_file, :ca_path,
                    :notifications

      def initialize
        @api_key       = nil
        @base_url      = nil
        @timeout       = nil
        @user_agent    = nil
        @max_retries   = nil
        @retry_delay   = nil
        @logger        = nil
        @on_retry      = nil
        @on_error      = nil
        @proxy         = nil
        @ca_file       = nil
        @ca_path       = nil
        @notifications = true
      end

      # Single source of truth for SDK kwargs. Compact drops every nil entry,
      # so the SDK's own defaults take over for every unset key. user_agent
      # is intentionally NOT included — the SDK's Client#initialize does not
      # accept it as of poli-page 1.0.0.rc.1 (sdk-ruby/lib/poli_page/client.rb).
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
