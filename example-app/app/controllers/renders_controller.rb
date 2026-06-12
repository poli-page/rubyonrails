# frozen_string_literal: true

# Non-streaming demo endpoints — SDK demo steps 1, 4, 5.
# The streaming endpoint (step 2) lives in StreamsController because
# ActionController::Live alters the entire controller's request lifecycle.
class RendersController < ApplicationController
  include PoliPage::Rails::Renderable

  # JSON / binary API surface — no HTML forms here. Same-origin fetches from
  # the demo UI don't send the CSRF token; for a true public JSON API we'd
  # use signed JWTs anyway. Skip the framework-default CSRF check.
  skip_forgery_protection

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
    warm_up_preview_and_thumbnails(descriptor.document_id)
    render json: descriptor.to_h
  end

  # POST /api/render/file  — SDK demo step 3 (render_to_file)
  # Streams the PDF straight to disk under tmp/poli-page/welcome.pdf —
  # memory-bounded regardless of output size.
  def render_file
    output = Rails.root.join("tmp", "poli-page", "welcome.pdf")
    FileUtils.mkdir_p(output.dirname)
    PoliPage.client.render_to_file(
      output.to_s,
      **canonical_kwargs.merge(data: { name: "render_to_file demo" })
    )
    render json: { path: output.to_s, sizeBytes: File.size(output) }
  end

  private

  # Demo flows hit /documents/:id/preview and /documents/:id/thumbnails
  # almost immediately after document.create returns. Backend rendering
  # races with those requests; warming both endpoints in a fire-and-forget
  # thread lets the first probe paint the cache instead of paying the cold
  # path inline. Best-effort: warmup failures are swallowed.
  def warm_up_preview_and_thumbnails(id)
    return unless id

    Thread.new do
      PoliPage.client.documents.preview(id)
    rescue StandardError
      # ignore — warm-up is best-effort
    end
    Thread.new do
      PoliPage.client.documents.thumbnails(id, width: 320, format: "png", pages: [1])
    rescue StandardError
      # ignore — warm-up is best-effort
    end
  end

  def canonical_kwargs
    {
      project:  "getting-started",
      template: "welcome",
      version:  "1.0.0",
      data:     { name: params.fetch(:name, "Rails User") }
    }
  end
end
