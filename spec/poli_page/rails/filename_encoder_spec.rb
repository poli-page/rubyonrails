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
  end
end
