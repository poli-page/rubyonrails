# frozen_string_literal: true

# show and thumbnails use PoliPage.client directly (a hand-built 302 and
# JSON) to show that style works without the concern; preview goes through
# the Renderable concern's render_preview.
#
# No rescue here: a PoliPage::Error raised by any action is answered by the
# gem's default error handler (PoliPage::Rails::ErrorHandler) with the
# error's payload status and { code, message, status, requestId }.
class DocumentsController < ApplicationController
  include PoliPage::Rails::Renderable

  skip_forgery_protection

  # GET /documents/:id  — SDK demo step 6
  def show
    descriptor = PoliPage.client.documents.get(params[:id])
    response.headers["Cache-Control"] = "private, no-store"
    redirect_to descriptor.presigned_pdf_url, status: :found, allow_other_host: true
  end

  # GET /documents/:id/thumbnails  — SDK demo step 7
  def thumbnails
    thumbs = PoliPage.client.documents.thumbnails(
      params[:id],
      width: 320, format: "png", pages: [1]
    )
    render json: thumbs.map(&:to_h)
  end

  # GET /documents/:id/preview  — SDK demo step 8
  def preview
    render_preview(PoliPage.client.documents.preview(params[:id]))
  end

  # DELETE /documents/:id  — SDK demo step 9
  def destroy
    PoliPage.client.documents.delete(params[:id])
    head :no_content
  end

  # GET /errors/not-found  — SDK demo step 10
  # Renders a template that does not exist: the API answers 404
  # TEMPLATE_NOT_FOUND, and the default error handler answers 404 with its
  # code, message, status and requestId.
  def not_found
    PoliPage.client.render.pdf(
      project: "getting-started", template: "does-not-exist", data: {}
    )
  end
end
