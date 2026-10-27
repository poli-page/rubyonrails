# frozen_string_literal: true

class DemosController < ApplicationController
  def index
    @base_url = Rails.application.config.poli_page.base_url || "https://api.poli.page"
  end
end
