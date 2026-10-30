# frozen_string_literal: true

# The same handler on an ActionController::API controller.
class ErrorHandlerApiTestController < ActionController::API
  def show
    raise PoliPage::ConnectionError
  end
end
