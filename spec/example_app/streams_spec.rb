# frozen_string_literal: true

# The example app's streaming route (GET /render/stream, ActionController::Live)
# against a local mock API: an error before the first PDF byte must still reach
# the default error handler as JSON, not a committed 200 application/pdf.

require "rails_helper"

PoliPage::Rails::Test::ImplCaseRunner.load_example_controllers

RSpec.describe "Example app: GET /render/stream", type: :request do
  include PoliPage::Rails::Test::ImplCaseRunner

  let(:pdf) { "%PDF-1.4\n% stream test\n%%EOF\n" }

  # A render descriptor, as the API answers POST /v1/render.
  def descriptor(origin)
    {
      "documentId" => "doc_1", "apiKeyId" => "3b9e1f2a-4c5d-4e6f-8a7b-9c0d1e2f3a4b",
      "organizationId" => "org_xyz", "environment" => "sandbox",
      "projectId" => "8f1c2d4e-1b2a-4c3d-9e8f-0a1b2c3d4e5f", "projectSlug" => "getting-started",
      "templateId" => "5d2a7c9e-3f4b-4a1c-8d2e-6f7a8b9c0d1e", "templateSlug" => "welcome",
      "format" => "A4", "orientation" => "portrait", "locale" => "en-US", "pageCount" => 1, "sizeBytes" => 30,
      "metadata" => {}, "diagnostics" => [], "createdAt" => "2026-09-29T09:45:22.000Z",
      "expiresAt" => "2026-09-29T10:00:22.000Z", "presignedPdfUrl" => "#{origin}/storage/doc_1.pdf"
    }
  end

  def stream_with(responses)
    server = PoliPage::Rails::Test::ContractMockServer.new { |origin| responses.call(origin) }
    send_case_request({ "method" => "GET", "path" => "/render/stream" }, server.origin)
    server.close
    server.requests
  ensure
    server&.close
  end

  it "streams the PDF when the render and the download succeed" do
    requests = stream_with(lambda do |origin|
      [{ "status" => 200, "json" => descriptor(origin) },
       { "status" => 200, "headers" => { "content-type" => "application/pdf" }, "base64" => [pdf].pack("m0") }]
    end)

    expect(response).to have_http_status(200)
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to include("welcome-streamed.pdf")
    expect(response.body).to eq(pdf)
    expect(requests.map(&:target)).to eq(["/v1/render", "/storage/doc_1.pdf"])
  end

  it "answers a render 404 as the handler's JSON" do
    stream_with(lambda do |_origin|
      [{ "status" => 404, "headers" => { "x-request-id" => "req_stream_404" },
         "json" => { "error" => "TEMPLATE_NOT_FOUND", "detail" => "Template 'welcome' not found.",
                     "requestId" => "req_stream_404" } }]
    end)

    expect(response).to have_http_status(404)
    expect(response.media_type).to eq("application/json")
    expect(response.headers["Content-Disposition"]).to be_nil
    expect(JSON.parse(response.body)).to eq(
      "code" => "TEMPLATE_NOT_FOUND", "message" => "Template 'welcome' not found.", "status" => 404,
      "requestId" => "req_stream_404"
    )
  end

  it "answers a network error as the handler's JSON with 503" do
    requests = stream_with(->(_origin) { Array.new(3) { { "fault" => "drop" } } })

    expect(response).to have_http_status(503)
    expect(response.media_type).to eq("application/json")
    expect(response.headers["Content-Disposition"]).to be_nil
    expect(JSON.parse(response.body)).to eq(
      "code" => "network_error", "message" => "Network request failed", "status" => 503, "requestId" => nil
    )
    expect(requests.size).to eq(3)
  end
end
