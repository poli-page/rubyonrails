# frozen_string_literal: true

# Dedicated controller for SDK demo step 2 (streaming PDF render). Split
# out from RendersController because ActionController::Live changes the
# request lifecycle for ALL actions on the including controller (per-action
# threading), which makes mixing it with normal render_pdf / render_preview
# awkward. Spec §11.4 calls this out as the safer split.
class StreamsController < ApplicationController
  include ActionController::Live

  skip_forgery_protection

  # GET /api/render/stream  — SDK demo step 2
  def stream
    response.headers["Content-Type"]           = "application/pdf"
    response.headers["Content-Disposition"]    = PoliPage::Rails::FilenameEncoder.disposition(
      "welcome-streamed.pdf", inline: true
    )
    response.headers["Cache-Control"]          = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Last-Modified"]          = Time.now.httpdate

    PoliPage.client.render.pdf_stream(
      project:  "getting-started",
      template: "welcome",
      version:  "1.0.0",
      data:     { name: params.fetch(:name, "Rails User") }
    ) do |chunk|
      response.stream.write(chunk)
    end
  ensure
    response.stream.close
  end
end
