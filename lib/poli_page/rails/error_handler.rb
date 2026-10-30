# frozen_string_literal: true

require "json"
require "active_support/concern"

module PoliPage
  module Rails
    # Turns every PoliPage::Error a controller action raises into a JSON answer:
    #
    #   status: the payload's status, or 500 when it is nil
    #   body:   { "code", "message", "status", "requestId" }
    #
    # The body is the SDK's Error#to_payload, with its keys renamed to the
    # wire's camelCase (request_id becomes requestId) and its values untouched.
    # The Content-Type is application/json even when the action had set
    # another one before the error (a PDF route, for example). Its status is the API status,
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

      # Fixed names, so the host app's inflections (an "ID" acronym, say)
      # cannot change the wire keys.
      WIRE_KEYS = { code: "code", message: "message", status: "status", request_id: "requestId" }.freeze

      included do
        rescue_from ::PoliPage::Error, with: :render_poli_page_error
      end

      # The JSON body for `error`: its to_payload with the wire's key names.
      def self.body(error)
        error.to_payload.to_h { |key, value| [WIRE_KEYS.fetch(key), value] }
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
        render json: JSON.generate(ErrorHandler.body(error)),
               status: ErrorHandler.status(error),
               content_type: "application/json"
      end
    end
  end
end
