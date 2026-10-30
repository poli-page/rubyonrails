# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rendering against the develop API", :integration do
  before do
    # Test-only guard: never spend a counted environment's quota from CI.
    skip "POLI_PAGE_API_KEY is not a pp_sandbox_ key" unless ENV["POLI_PAGE_API_KEY"].to_s.start_with?("pp_sandbox_")
  end

  it "renders the canonical getting-started/welcome template" do
    config = Rails.application.config.poli_page
    snapshot = { api_key: config.api_key, base_url: config.base_url }

    config.api_key = ENV.fetch("POLI_PAGE_API_KEY")
    # The SDK default API, unless the live job sets POLI_PAGE_BASE_URL.
    base_url = ENV["POLI_PAGE_BASE_URL"].to_s
    config.base_url = base_url unless base_url.empty?
    PoliPage.reset_client!

    bytes = PoliPage.client.render.pdf(
      project:  "getting-started",
      template: "welcome",
      data:     { name: "Rails CI" }
    )

    expect(bytes).to be_a(String)
    expect(bytes.bytesize).to be > 1024
    expect(bytes[0, 5]).to eq("%PDF-")
  ensure
    config.api_key  = snapshot[:api_key]
    config.base_url = snapshot[:base_url]
    PoliPage.reset_client!
  end
end
