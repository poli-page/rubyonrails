# frozen_string_literal: true

# A streaming action shaped like the example app's StreamsController: it sets
# a PDF Content-Type, then the SDK call fails before the first chunk.
class ErrorHandlerLiveTestController < ActionController::Base
  include ActionController::Live

  def stream
    response.headers["Content-Type"] = "application/pdf"
    raise PoliPage::ConnectionError
  ensure
    response.stream.close
  end
end
