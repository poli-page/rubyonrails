# frozen_string_literal: true

# Dedicated controller for SDK demo step 2 (streaming PDF render). Split
# out from RendersController because ActionController::Live changes the
# request lifecycle for ALL actions on the including controller (per-action
# threading), which makes mixing it with normal render_pdf / render_preview
# awkward, so this controller keeps it apart.
#
# The PDF headers are set when the first chunk arrives, after the SDK has
# rendered the document and started the download. An error before that (a
# 404 from the render, a network error) leaves the response uncommitted, so
# the gem's default error handler answers it as JSON with its own status. An
# error after the first chunk cannot change the 200 already sent: the handler
# raises it again, Live logs it, and the client gets a short PDF.
class StreamsController < ApplicationController
  include ActionController::Live

  skip_forgery_protection

  # GET /render/stream  — SDK demo step 2
  def stream
    started = false
    PoliPage.client.render.pdf_stream(
      project:  "getting-started",
      template: "welcome",
      data:     { name: params.fetch(:name, "Rails User") }
    ) do |chunk|
      start_pdf_response unless started
      started = true
      response.stream.write(chunk)
    end
    unless started # an empty PDF
      start_pdf_response
      started = true
    end
  ensure
    # Only a started stream is closed here: closing commits the response, and
    # an error before the first chunk must reach the error handler (or Rails'
    # usual 500) uncommitted.
    response.stream.close if started
  end

  private

  def start_pdf_response
    response.headers["Content-Type"]           = "application/pdf"
    response.headers["Content-Disposition"]    = PoliPage::Rails::FilenameEncoder.disposition(
      "welcome-streamed.pdf", inline: true
    )
    response.headers["Cache-Control"]          = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Last-Modified"]          = Time.now.httpdate
  end
end
