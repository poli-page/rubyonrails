# frozen_string_literal: true

# show and thumbnails use PoliPage.client directly (a hand-built 302 and
# JSON) to show that style works without the concern (spec §14.4); preview
# goes through the Renderable concern's render_preview.
class DocumentsController < ApplicationController
  include PoliPage::Rails::Renderable

  skip_forgery_protection

  # All Poli Page errors surface as JSON with the SDK's typed code +
  # request_id, instead of a 500 HTML error page. Same shape the demo UI
  # JS already knows how to render. Demo-only: a real app would handle
  # PermissionDeniedError, NotFoundError, etc. separately.
  rescue_from PoliPage::Error, with: :render_poli_page_error

  # GET /api/documents/:id  — SDK demo step 6
  def show
    descriptor = PoliPage.client.documents.get(params[:id])
    response.headers["Cache-Control"] = "private, no-store"
    redirect_to descriptor.presigned_pdf_url, status: :found, allow_other_host: true
  end

  # GET /api/documents/:id/thumbnails  — SDK demo step 7
  def thumbnails
    thumbs = PoliPage.client.documents.thumbnails(
      params[:id],
      width: 320, format: "png", pages: [1]
    )
    render json: thumbs.map(&:to_h)
  end

  # GET /api/documents/:id/preview  — SDK demo step 8
  def preview
    render_preview(PoliPage.client.documents.preview(params[:id]))
  end

  # DELETE /api/documents/:id  — SDK demo step 9
  def destroy
    PoliPage.client.documents.delete(params[:id])
    head :no_content
  end

  # GET /api/errors/not-found  — SDK demo step 10
  # Renders a template that does not exist: the API answers 404
  # TEMPLATE_NOT_FOUND and render_poli_page_error returns its code, status,
  # message and requestId.
  def not_found
    PoliPage.client.render.pdf(
      project: "getting-started", template: "does-not-exist", data: {}
    )
  end

  private

  def render_poli_page_error(err)
    payload = err.to_payload
    status = payload[:status] || 500
    render json: {
      code:      payload[:code],
      message:   payload[:message],
      status:    status,
      requestId: payload[:request_id]
    }, status: status
  end
end
