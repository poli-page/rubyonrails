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
    # The body is the SDK's Error#to_payload as is: the SDK names its keys
    # code, message, status and requestId, the same in every Poli Page SDK.
    # The Content-Type is application/json even when the action had set
    # another one before the error (a PDF route, for example). Its status is
    # the API status, 503 for network_error, 504 for timeout, 502 for
    # invalid_response, and null when unknown (io_error, for example); the
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

      # The JSON body for `error`: its to_payload, forwarded as is. JSON.generate
      # writes the Symbol keys as they are spelled, so the host app's
      # inflections (an "ID" acronym, say) cannot change them.
      def self.body(error)
        error.to_payload
      end

      # The HTTP status for `error`: the payload's status, or 500 when unknown.
      def self.status(error)
        error.to_payload[:status] || 500
      end

      private

      # A response already committed (an ActionController::Live stream that
      # sent its first chunk) cannot change its status or body: the error is
      # raised again so Live logs it and calls the stream's on_error, instead
      # of being reported as an answer that was never sent.
      #
      # Why JSON.generate: the body holds only strings, integers and nil, and
      # it keeps the answer independent of ActiveSupport's JSON encoder (whose
      # Rails 7.0, 7.1 and 8.0 releases pass an option the json 3 gem refuses).
      def render_poli_page_error(error)
        raise error if response.committed?

        render json: JSON.generate(ErrorHandler.body(error)),
               status: ErrorHandler.status(error),
               content_type: "application/json"
      end
    end
  end
end
