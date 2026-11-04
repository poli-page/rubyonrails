# frozen_string_literal: true

# Raises the SDK's errors without a rescue of its own, so the answers come
# from the default PoliPage::Rails::ErrorHandler.
class ErrorHandlerTestController < ActionController::Base
  ERRORS = {
    "api" => lambda {
      PoliPage::NotFoundError.new("Template 'x' not found in project 'p'.",
                                  code: "TEMPLATE_NOT_FOUND", status: 404, request_id: "req_123")
    },
    "server" => lambda {
      PoliPage::APIError.new("Unexpected server error.", code: "INTERNAL_ERROR", status: 500, request_id: "req_5xx")
    },
    "network" => -> { PoliPage::ConnectionError.new },
    "timeout" => -> { PoliPage::TimeoutError.new(timeout: 60) },
    "no_status" => -> { PoliPage::InvalidOptionsError.new("apiKey is required") },
    # A proxy answered the render with a 200 HTML page.
    "invalid_response" => -> { PoliPage::InvalidResponseError.new(status: 200, request_id: "req_proxy") },
    # render_to_file could not write its file.
    "io_error" => lambda {
      PoliPage::FileWriteError.new(cause: Errno::EACCES.new("/srv/out/welcome.pdf"))
    }
  }.freeze

  def show
    raise ERRORS.fetch(params[:kind]).call
  end

  # Sets a PDF Content-Type first, as a PDF route does before its SDK call.
  def pdf_first
    response.headers["Content-Type"] = "application/pdf"
    raise PoliPage::ConnectionError
  end
end
