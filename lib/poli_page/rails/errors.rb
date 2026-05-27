# frozen_string_literal: true

require "poli_page/errors"

module PoliPage
  module Rails
    # Raised by ConfigurationValidator when Rails.application.config.poli_page
    # contains an invalid value. Inherits from PoliPage::Error so existing
    # `rescue PoliPage::Error` clauses catch it.
    class ConfigurationError < PoliPage::Error
      def initialize(message)
        super(message, code: "configuration_error", status: nil, request_id: nil)
      end
    end
  end
end
