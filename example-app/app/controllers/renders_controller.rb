# frozen_string_literal: true

# Non-streaming demo endpoints — SDK demo steps 1, 4, 5.
# The streaming endpoint (step 2) lives in StreamsController because
# ActionController::Live alters the entire controller's request lifecycle.
class RendersController < ApplicationController
  include PoliPage::Rails::Renderable

  # GET /api/render/pdf  — SDK demo step 1
  def pdf
    bytes = PoliPage.client.render.pdf(**canonical_kwargs)
    render_pdf(bytes, filename: "welcome.pdf", inline: true)
  end

  # GET /api/render/preview  — SDK demo step 4
  def preview
    result = PoliPage.client.render.preview(**canonical_kwargs)
    render_preview(result)
  end

  # POST /api/documents  — SDK demo step 5
  def document
    descriptor = PoliPage.client.render.document(**canonical_kwargs)
    render json: descriptor.to_h
  end

  private

  def canonical_kwargs
    {
      project:  "getting-started",
      template: "welcome",
      version:  "1.0.0",
      data:     { name: params.fetch(:name, "Rails User") }
    }
  end
end
