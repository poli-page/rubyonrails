# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::FilenameEncoder do
  describe ".disposition" do
    context "with ASCII filename" do
      it "emits inline disposition" do
        result = described_class.disposition("invoice.pdf", inline: true)
        expect(result).to start_with("inline; ")
        expect(result).to include(%(filename="invoice.pdf"))
      end

      it "emits attachment disposition" do
        result = described_class.disposition("invoice.pdf", inline: false)
        expect(result).to start_with("attachment; ")
        expect(result).to include(%(filename="invoice.pdf"))
      end

      it "percent-escapes ASCII double quotes inside the filename" do
        result = described_class.disposition('weird"name.pdf', inline: false)
        expect(result).to start_with("attachment; ")
        expect(result).to include("weird%22name.pdf")
      end
    end

    context "with non-ASCII filename" do
      it "emits both filename= (ASCII fallback) and filename*= (UTF-8) for accented chars" do
        result = described_class.disposition("résumé.pdf", inline: false)
        expect(result).to start_with("attachment; ")
        expect(result).to include('filename="')
        expect(result).to include("filename*=UTF-8''")
        expect(result).to include("r%C3%A9sum%C3%A9.pdf")
      end

      it "handles CJK characters" do
        result = described_class.disposition("発票.pdf", inline: false)
        expect(result).to include("filename*=UTF-8''")
        expect(result).to include("%E7%99%BA%E7%A5%A8.pdf")
      end

      it "handles emoji" do
        result = described_class.disposition("🦀.pdf", inline: true)
        expect(result).to start_with("inline; ")
        expect(result).to include("filename*=UTF-8''")
      end
    end

    # Same cases as poli-page/django#1. Quoting/escaping is ActionDispatch's job (it
    # percent-escapes `"` and `\` inside filename="..."); control characters are stripped
    # before the name reaches it.
    {
      "double-quote-is-escaped" => [
        'say "hi".pdf',
        %(attachment; filename="say %22hi%22.pdf"; filename*=UTF-8''say%20%22hi%22.pdf)
      ],
      "backslash-is-escaped" => [
        'a\b.pdf',
        %(attachment; filename="a%5Cb.pdf"; filename*=UTF-8''a%5Cb.pdf)
      ],
      "crlf-is-stripped" => [
        "evil.pdf\r\nSet-Cookie: sid=1",
        %(attachment; filename="evil.pdfSet-Cookie%3A sid%3D1"; filename*=UTF-8''evil.pdfSet-Cookie%3A%20sid%3D1)
      ],
      "control-chars-are-stripped" => [
        "tab\there\u0000\u001f\u007f.pdf",
        %(attachment; filename="tabhere.pdf"; filename*=UTF-8''tabhere.pdf)
      ],
      "parameter-injection-stays-inside-the-quoted-string" => [
        'x.pdf"; filename="pwn.exe',
        %(attachment; filename="x.pdf%22%3B filename%3D%22pwn.exe"; ) +
          %(filename*=UTF-8''x.pdf%22%3B%20filename%3D%22pwn.exe)
      ],
      "non-ascii-uses-rfc5987-dual-notation" => [
        "résumé François.pdf",
        %(attachment; filename="resume Francois.pdf"; filename*=UTF-8''r%C3%A9sum%C3%A9%20Fran%C3%A7ois.pdf)
      ],
      "non-ascii-fallback-is-escaped" => [
        'résumé "final"\v2.pdf',
        %(attachment; filename="resume %22final%22%5Cv2.pdf"; filename*=UTF-8''r%C3%A9sum%C3%A9%20%22final%22%5Cv2.pdf)
      ],
      "non-ascii-control-chars-are-stripped-from-both-forms" => [
        "résumé\r\n\u0085.pdf",
        %(attachment; filename="resume.pdf"; filename*=UTF-8''r%C3%A9sum%C3%A9.pdf)
      ]
    }.each do |id, (filename, expected)|
      it "is RFC 6266 safe: #{id}" do
        expect(described_class.disposition(filename, inline: false)).to eq(expected)
      end
    end

    it "escapes and strips the inline disposition too" do
      expect(described_class.disposition("q\"\r\n.pdf", inline: true))
        .to eq(%(inline; filename="q%22.pdf"; filename*=UTF-8''q%22.pdf))
    end
  end
end
