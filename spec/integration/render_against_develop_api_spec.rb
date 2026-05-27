# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rendering against the develop API", :integration do
  before do
    skip "POLI_PAGE_API_KEY not set" if ENV["POLI_PAGE_API_KEY"].to_s.empty?
    skip "Refusing to run integration spec with a pp_live_* key (safety belt)" \
      if ENV["POLI_PAGE_API_KEY"].to_s.start_with?("pp_live_")
  end

  it "renders the canonical getting-started/welcome template" do
    config = Rails.application.config.poli_page
    snapshot = { api_key: config.api_key, base_url: config.base_url }

    config.api_key  = ENV.fetch("POLI_PAGE_API_KEY")
    config.base_url = ENV.fetch("POLI_PAGE_BASE_URL", "https://api-develop.poli.page")
    PoliPage.reset_client!

    bytes = PoliPage.client.render.pdf(
      project:  "getting-started",
      template: "welcome",
      version:  "1.0.0",
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
