# frozen_string_literal: true

# A Live stream that sends a first PDF chunk, then fails with an SDK error.
# The stream's on_error callback records the errors Live reports.
class ErrorHandlerLiveMidstreamTestController < ActionController::Base
  include ActionController::Live

  REPORTED = Queue.new

  def stream
    response.stream.on_error { REPORTED << :on_error }
    response.headers["Content-Type"] = "application/pdf"
    response.stream.write("%PDF-1.4 partial")
    raise PoliPage::ConnectionError
  ensure
    response.stream.close
  end
end
