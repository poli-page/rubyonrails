# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::Notifications do
  describe ".retry_bridge" do
    it "returns a memoised callable" do
      a = described_class.retry_bridge
      b = described_class.retry_bridge
      expect(a).to be(b)
      expect(a).to respond_to(:call)
    end

    it "fires ActiveSupport::Notifications.instrument('poli_page.retry') with the event payload" do
      received = nil
      subscriber = ActiveSupport::Notifications.subscribe("poli_page.retry") do |*args|
        received = ActiveSupport::Notifications::Event.new(*args)
      end

      event = PoliPage::RetryEvent.new(
        attempt: 2, delay: 0.5,
        reason: PoliPage::TimeoutError.new(timeout: 30)
      )
      described_class.retry_bridge.call(event)

      expect(received).not_to be_nil
      expect(received.name).to eq("poli_page.retry")
      expect(received.payload[:attempt]).to eq(2)
      expect(received.payload[:delay]).to eq(0.5)
      expect(received.payload[:reason]).to be_a(PoliPage::TimeoutError)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end

  describe ".error_bridge" do
    it "returns a memoised callable" do
      a = described_class.error_bridge
      b = described_class.error_bridge
      expect(a).to be(b)
      expect(a).to respond_to(:call)
    end

    it "fires ActiveSupport::Notifications.instrument('poli_page.error') with the error" do
      received = nil
      subscriber = ActiveSupport::Notifications.subscribe("poli_page.error") do |*args|
        received = ActiveSupport::Notifications::Event.new(*args)
      end

      err = PoliPage::ValidationError.new("nope", code: "VALIDATION_ERROR",
                                                  status: 400, request_id: "req_1")
      described_class.error_bridge.call(err)

      expect(received.name).to eq("poli_page.error")
      expect(received.payload[:error]).to be(err)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end

  describe "Railtie default-on behaviour" do
    it "installs the retry bridge as the default on_retry callable" do
      expect(Rails.application.config.poli_page.on_retry).to be(described_class.retry_bridge)
    end

    it "installs the error bridge as the default on_error callable" do
      expect(Rails.application.config.poli_page.on_error).to be(described_class.error_bridge)
    end
  end
end
