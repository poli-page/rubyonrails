# frozen_string_literal: true

# Deliberately does NOT `include PoliPage::Rails::Renderable` — this
# controller demonstrates direct PoliPage.client use to show both styles
# work (spec §14.4).
class DocumentsController < ApplicationController
  skip_forgery_protection

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
  rescue PoliPage::ValidationError => e
    render json: { error: e.class.name, code: e.code, message: e.message,
                   status: e.status, request_id: e.request_id }, status: :bad_request
  end
end
