# frozen_string_literal: true

class DemosController < ApplicationController
  def index
    @api_key_prefix = ENV.fetch("POLI_PAGE_API_KEY", "")[0, 8]
    @base_url       = Rails.application.config.poli_page.base_url || "https://api.poli.page"
  end
end
