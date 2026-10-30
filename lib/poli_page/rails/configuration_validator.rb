# frozen_string_literal: true

require "uri"

require_relative "errors"

module PoliPage
  module Rails
    module ConfigurationValidator
      module_function

      # pp_{environment}_{32 lowercase hex}. Only drives a startup warning: the
      # API is the authority on keys, so a mismatch never blocks the client.
      API_KEY_FORMAT = /\App_(?=[a-z][a-z0-9-]{0,19}_)[a-z][a-z0-9]*(?:-[a-z0-9]+)*_[0-9a-f]{32}\z/

      def validate!(config)
        validate_api_key!(config.api_key, config.logger)
        validate_base_url!(config.base_url)
        validate_timeout!(config.timeout)
        validate_max_retries!(config.max_retries)
        validate_retry_delay!(config.retry_delay)
        validate_notifications!(config.notifications)
        validate_callable!(config.on_retry, "on_retry")
        validate_callable!(config.on_error, "on_error")
      end

      def validate_api_key!(value, logger)
        unless value.is_a?(String) && !value.empty?
          raise ConfigurationError, "Poli Page api_key is required (a non-empty String). " \
                                    "Get one at https://app.poli.page/settings/api-keys."
        end
        return if API_KEY_FORMAT.match?(value)

        # No part of the key reaches the log: even a well-formed pp_{environment}_
        # can be a pasted secret fragment.
        logger&.warn("Poli Page api_key does not match the expected format " \
                     "pp_{environment}_{32 lowercase hex characters}; starting anyway, " \
                     "the API will reject it if it is not a valid key.")
      end

      def validate_base_url!(value)
        return if value.nil?

        uri = URI.parse(value.to_s)
        return if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

        raise ConfigurationError, "Poli Page base_url must be an http or https URL (got #{value.inspect})."
      rescue URI::InvalidURIError
        raise ConfigurationError, "Poli Page base_url must be an http or https URL (got #{value.inspect})."
      end

      def validate_timeout!(value)
        return if value.nil?

        unless value.is_a?(Numeric) && value.positive?
          raise ConfigurationError, "Poli Page timeout must be a positive number (got #{value.inspect})."
        end

        return if value <= 600

        raise ConfigurationError, "Poli Page timeout must be <= 600 seconds (got #{value.inspect})."
      end

      def validate_max_retries!(value)
        return if value.nil?
        return if value.is_a?(Integer) && (0..10).cover?(value)

        raise ConfigurationError,
              "Poli Page max_retries must be an integer between 0 and 10 (got #{value.inspect})."
      end

      def validate_retry_delay!(value)
        return if value.nil?
        return if value.is_a?(Numeric) && (0..30).cover?(value)

        raise ConfigurationError, "Poli Page retry_delay must be a number between 0 and 30 seconds " \
                                  "(got #{value.inspect})."
      end

      def validate_notifications!(value)
        return if value.is_a?(TrueClass) || value.is_a?(FalseClass)

        raise ConfigurationError, "Poli Page notifications must be true or false (got #{value.inspect})."
      end

      # Checked at boot by the Railtie, when it decides whether to install the
      # error handler (not in validate!, which runs when the client is built).
      def validate_error_handler!(value)
        return if value.is_a?(TrueClass) || value.is_a?(FalseClass)

        raise ConfigurationError, "Poli Page error_handler must be true or false (got #{value.inspect})."
      end

      def validate_callable!(value, name)
        return if value.nil?
        return if value.respond_to?(:call) && !value.is_a?(String) && !value.is_a?(Symbol)

        raise ConfigurationError, "Poli Page #{name} must respond to #call (got #{value.class})."
      end
    end
  end
end
