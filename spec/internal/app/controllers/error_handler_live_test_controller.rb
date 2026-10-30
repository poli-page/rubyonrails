# frozen_string_literal: true

# A streaming action that sets a PDF Content-Type, then the SDK call fails
# before the first chunk. Nothing closes the stream: closing would commit the
# response before the error handler runs.
class ErrorHandlerLiveTestController < ActionController::Base
  include ActionController::Live

  def stream
    response.headers["Content-Type"] = "application/pdf"
    raise PoliPage::ConnectionError
  end
end
