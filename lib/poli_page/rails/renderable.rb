# frozen_string_literal: true

require "active_support/concern"

require_relative "filename_encoder"

module PoliPage
  module Rails
    module Renderable
      extend ::ActiveSupport::Concern

      # Sends raw PDF bytes with PDF headers + RFC 5987 Content-Disposition.
      #
      # @param bytes    [String]  raw PDF bytes (binary-encoded)
      # @param filename [String]  used in Content-Disposition; ASCII and
      #                           non-ASCII both handled per RFC 5987 / RFC 6266
      # @param inline   [Boolean] inline (browser viewer) vs attachment (download)
      def render_pdf(bytes, filename: "document.pdf", inline: false)
        send_data(
          bytes,
          type: "application/pdf",
          disposition: inline ? "inline" : "attachment",
          filename: filename
        )
        # Why: send_data sets Content-Disposition using Rails's plain ASCII
        # formatting. Overwrite with our RFC 5987 encoder so non-ASCII filenames
        # survive. Cache-Control + nosniff are independent additions.
        response.headers["Content-Disposition"]    = FilenameEncoder.disposition(filename, inline: inline)
        response.headers["Cache-Control"]          = "private, no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
      end

      # Renders the .html attribute of a PreviewResult or DocumentPreviewResult.
      # The HTML is a complete document from the Poli Page render pipeline; use
      # render body: to skip template processing and layouts entirely — no
      # html_safe needed (Rails only escapes inside templates, not for body:).
      def render_preview(result)
        html = result.respond_to?(:html) ? result.html : result.to_s
        response.headers["Cache-Control"]          = "private, no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        render body: html, content_type: "text/html; charset=utf-8"
      end

      # 302 to the descriptor's presigned URL. Adds Cache-Control so the
      # redirect itself never gets intermediary-cached.
      def redirect_to_document(descriptor, status: :found)
        response.headers["Cache-Control"] = "private, no-store"
        redirect_to descriptor.presigned_pdf_url, status: status, allow_other_host: true
      end
    end
  end
end
