# frozen_string_literal: true

require "rails_helper"
require "json"
require "open3"
require "tmpdir"

RSpec.describe PoliPage::Rails::ErrorHandler, type: :request do
  def json_body
    JSON.parse(response.body)
  end

  describe "on by default" do
    it "defaults config.poli_page.error_handler to true" do
      expect(PoliPage::Rails::Configuration.new.error_handler).to be(true)
      expect(Rails.application.config.poli_page.error_handler).to be(true)
    end

    it "is included into ActionController::Base and ActionController::API" do
      expect(ActionController::Base.ancestors).to include(described_class)
      expect(ActionController::API.ancestors).to include(described_class)
    end
  end

  describe "the answer" do
    it "answers an API error with its status and the to_payload body" do
      get "/error_handler_test/api"

      expect(response).to have_http_status(404)
      expect(response.media_type).to eq("application/json")
      expect(json_body).to eq(
        "code" => "TEMPLATE_NOT_FOUND",
        "message" => "Template 'x' not found in project 'p'.",
        "status" => 404,
        "requestId" => "req_123"
      )
    end

    it "answers a 5xx API error with its status" do
      get "/error_handler_test/server"

      expect(response).to have_http_status(500)
      expect(json_body).to eq(
        "code" => "INTERNAL_ERROR", "message" => "Unexpected server error.", "status" => 500, "requestId" => "req_5xx"
      )
    end

    it "answers network_error with 503" do
      get "/error_handler_test/network"

      expect(response).to have_http_status(503)
      expect(response.media_type).to eq("application/json")
      expect(json_body).to eq(
        "code" => "network_error", "message" => "Network request failed", "status" => 503, "requestId" => nil
      )
    end

    it "answers timeout with 504" do
      get "/error_handler_test/timeout"

      expect(response).to have_http_status(504)
      expect(json_body).to eq(
        "code" => "timeout", "message" => "Request timed out after 60000ms", "status" => 504, "requestId" => nil
      )
    end

    it "answers an SDK error with no status with 500 and a null status in the body" do
      get "/error_handler_test/no_status"

      expect(response).to have_http_status(500)
      expect(json_body).to eq(
        "code" => "invalid_options", "message" => "apiKey is required", "status" => nil, "requestId" => nil
      )
    end

    it "answers from an ActionController::API controller too" do
      get "/error_handler_api_test"

      expect(response).to have_http_status(503)
      expect(response.media_type).to eq("application/json")
      expect(json_body["code"]).to eq("network_error")
    end

    it "builds the body from the SDK's to_payload, keys in camelCase" do
      error = PoliPage::ConnectionError.new
      expect(described_class.body(error)).to eq(error.to_payload.transform_keys { |k| k.to_s.camelize(:lower) })
      expect(described_class.body(error).keys).to eq(%w[code message status requestId])
    end
  end

  describe "booting an app" do
    # Each boot is its own process: Rails allows one application per process.
    def boot(initializer)
      Dir.mktmpdir do |root|
        if initializer
          FileUtils.mkdir_p(File.join(root, "config/initializers"))
          File.write(File.join(root, "config/initializers/poli_page.rb"), initializer)
        end
        script = File.expand_path("../../fixtures/error_handler_app.rb", __dir__)
        result = File.join(root, "result.json")
        output, status = Open3.capture2e(RbConfig.ruby, script, root, result)
        raise "the app failed to boot:\n#{output}" unless status.success?

        JSON.parse(File.read(result))
      end
    end

    it "handles the error when the app sets nothing" do
      result = boot(nil)

      expect(result["included"]).to be(true)
      expect(result["status"]).to eq(404)
      expect(result["body"]).to eq(
        "code" => "TEMPLATE_NOT_FOUND", "message" => "not found", "status" => 404, "requestId" => "req_1"
      )
    end

    it "lets the error through when config.poli_page.error_handler is false" do
      result = boot("Rails.application.config.poli_page.error_handler = false\n")

      expect(result["included"]).to be(false)
      expect(result).not_to have_key("status")
      expect(result["raised"]).to eq("PoliPage::NotFoundError")
    end

    it "refuses a value that is not true or false" do
      expect { boot("Rails.application.config.poli_page.error_handler = \"no\"\n") }
        .to raise_error(RuntimeError, /error_handler must be true or false/)
    end
  end
end
