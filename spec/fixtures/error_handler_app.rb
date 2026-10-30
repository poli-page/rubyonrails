# frozen_string_literal: true

# Boots a bare Rails app rooted at ARGV[0] (whose config/initializers/ may set
# config.poli_page.error_handler), then calls an action that raises a
# PoliPage::Error, and writes what happened as JSON to ARGV[1]. Run in a child
# process by spec/poli_page/rails/error_handler_spec.rb: one Rails app per
# process.

require "json"
require "logger"
require "rails"
require "action_controller/railtie"
require "poli_page-rails"

class ErrorHandlerApp < Rails::Application
  config.root = ARGV.fetch(0)
  config.eager_load = false
  config.logger = Logger.new(IO::NULL)
  config.secret_key_base = "error_handler_app_secret_key_base_at_least_32_characters"
end
ErrorHandlerApp.initialize!

class RaisingController < ActionController::Base
  def show
    raise PoliPage::NotFoundError.new("not found", code: "TEMPLATE_NOT_FOUND", status: 404, request_id: "req_1")
  end
end

result = { "included" => ActionController::Base.include?(PoliPage::Rails::ErrorHandler) }
begin
  status, _headers, body = RaisingController.action(:show).call(Rack::MockRequest.env_for("/"))
  result["status"] = status
  result["body"] = JSON.parse(body.each.to_a.join)
rescue PoliPage::Error => e
  result["raised"] = e.class.name
end
File.write(ARGV.fetch(1), JSON.generate(result))
