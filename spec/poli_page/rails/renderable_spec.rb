# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::Renderable, type: :request do
  describe "#render_pdf" do
    context "with ASCII filename, default (attachment) disposition" do
      before { get "/renderable_test/pdf_attachment", params: { filename: "invoice.pdf" } }

      it "responds 200" do
        expect(response).to have_http_status(:ok)
      end

      it "sets Content-Type to application/pdf" do
        expect(response.content_type).to start_with("application/pdf")
      end

      it "sets Content-Disposition to attachment with the filename" do
        expect(response.headers["Content-Disposition"]).to include("attachment;")
        expect(response.headers["Content-Disposition"]).to include('filename="invoice.pdf"')
      end

      it "sets Cache-Control to private, no-store" do
        expect(response.headers["Cache-Control"]).to include("private")
        expect(response.headers["Cache-Control"]).to include("no-store")
      end

      it "sets X-Content-Type-Options to nosniff" do
        expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
      end

      it "returns the PDF bytes as the body" do
        expect(response.body).to eq("%PDF-1.4 fake pdf bytes")
      end
    end

    context "with inline: true" do
      before { get "/renderable_test/pdf_attachment", params: { filename: "invoice.pdf", inline: "true" } }

      it "uses inline disposition" do
        expect(response.headers["Content-Disposition"]).to include("inline;")
        expect(response.headers["Content-Disposition"]).not_to include("attachment;")
      end
    end

    context "with non-ASCII filename" do
      before { get "/renderable_test/pdf_attachment", params: { filename: "résumé.pdf" } }

      it "emits filename*=UTF-8''... with percent-encoded bytes (RFC 5987)" do
        expect(response.headers["Content-Disposition"]).to include("filename*=UTF-8''")
        expect(response.headers["Content-Disposition"]).to include("r%C3%A9sum%C3%A9.pdf")
      end

      it "also emits the ASCII fallback filename" do
        expect(response.headers["Content-Disposition"]).to include('filename="')
      end
    end
  end

  describe "#render_preview" do
    before { get "/renderable_test/preview" }

    it "responds 200" do
      expect(response).to have_http_status(:ok)
    end

    it "sets Content-Type to text/html; charset=utf-8" do
      expect(response.content_type).to include("text/html")
      expect(response.content_type).to include("charset=utf-8")
    end

    it "sets Cache-Control to private, no-store" do
      expect(response.headers["Cache-Control"]).to include("private")
      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "renders the .html attribute as the body" do
      expect(response.body).to eq("<h1>Hello</h1>")
    end
  end

  describe "#redirect_to_document" do
    before { get "/renderable_test/redirect_doc" }

    it "responds 302" do
      expect(response).to have_http_status(:found)
    end

    it "sets Location to the descriptor's presigned URL" do
      expect(response.headers["Location"]).to eq("https://example-cdn.example.com/doc.pdf?sig=abc")
    end

    it "sets Cache-Control to private, no-store" do
      expect(response.headers["Cache-Control"]).to include("private")
      expect(response.headers["Cache-Control"]).to include("no-store")
    end
  end
end
