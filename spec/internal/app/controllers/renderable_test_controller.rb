# frozen_string_literal: true

require "ostruct"

class RenderableTestController < ActionController::Base
  include PoliPage::Rails::Renderable

  def pdf_attachment
    render_pdf(
      "%PDF-1.4 fake pdf bytes",
      filename: params[:filename] || "doc.pdf",
      inline: params[:inline] == "true"
    )
  end

  def preview
    fake_preview = OpenStruct.new(html: "<h1>Hello</h1>", page_count: 1)
    render_preview(fake_preview)
  end

  def redirect_doc
    fake_descriptor = OpenStruct.new(
      presigned_pdf_url: "https://example-cdn.example.com/doc.pdf?sig=abc"
    )
    redirect_to_document(fake_descriptor)
  end
end
