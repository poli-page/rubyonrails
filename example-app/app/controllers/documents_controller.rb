# frozen_string_literal: true

# Deliberately does NOT `include PoliPage::Rails::Renderable` — this
# controller demonstrates direct PoliPage.client use to show both styles
# work (spec §14.4).
class DocumentsController < ApplicationController
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
    result = PoliPage.client.documents.preview(params[:id])
    response.headers["Cache-Control"] = "private, no-store"
    render body: result.html, content_type: "text/html; charset=utf-8"
  end

  # DELETE /api/documents/:id  — SDK demo step 9
  def destroy
    PoliPage.client.documents.delete(params[:id])
    head :no_content
  end

  # GET /api/errors/bad-version  — SDK demo step 10
  def bad_version
    PoliPage.client.render.pdf(
      project: "getting-started", template: "welcome",
      version: "not-a-valid-semver", data: {}
    )
  end

  private

  def render_poli_page_error(err)
    render json: {
      error:      err.class.name,
      code:       err.code,
      message:    err.message,
      status:     err.status,
      request_id: err.request_id
    }, status: (err.status || 500)
  end
end
