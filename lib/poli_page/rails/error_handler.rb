# frozen_string_literal: true

require "json"
require "active_support/concern"
require "active_support/core_ext/string/inflections"

module PoliPage
  module Rails
    # Turns every PoliPage::Error a controller action raises into a JSON answer:
    #
    #   status: the payload's status, or 500 when it is nil
    #   body:   { "code", "message", "status", "requestId" }
    #
    # The body is the SDK's Error#to_payload, with its keys in the wire's
    # camelCase (request_id becomes requestId). Its status is the API status,
    # 503 for network_error and 504 for timeout, and null when unknown; the
    # HTTP status falls back to 500 only in that last case.
    #
    # The Railtie includes this concern into ActionController::Base and
    # ActionController::API unless the app sets
    # `config.poli_page.error_handler = false`. A rescue_from declared later in
    # a controller (for PoliPage::Error, a subclass, or StandardError) takes
    # precedence over this one, as usual in Rails.
    module ErrorHandler
      extend ::ActiveSupport::Concern

      included do
        rescue_from ::PoliPage::Error, with: :render_poli_page_error
      end

      # The JSON body for `error`: its to_payload with camelCase keys.
      def self.body(error)
        error.to_payload.transform_keys { |key| key.to_s.camelize(:lower) }
      end

      # The HTTP status for `error`: the payload's status, or 500 when unknown.
      def self.status(error)
        error.to_payload[:status] || 500
      end

      private

      # Why JSON.generate: the body holds only strings, integers and nil, and
      # it keeps the answer independent of ActiveSupport's JSON encoder (whose
      # Rails 7.0, 7.1 and 8.0 releases pass an option the json 3 gem refuses).
      def render_poli_page_error(error)
        render json: JSON.generate(ErrorHandler.body(error)), status: ErrorHandler.status(error)
      end
    end
  end
end
