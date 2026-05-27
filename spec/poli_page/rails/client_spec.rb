# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage, ".client (lazy memoised accessor)" do
  before { described_class.reset_client! }
  after  { described_class.reset_client! }

  def with_config(**overrides)
    config = Rails.application.config.poli_page
    snapshot = config.instance_variables.index_with { |iv| config.instance_variable_get(iv) }
    overrides.each { |k, v| config.public_send("#{k}=", v) }
    yield
  ensure
    snapshot.each { |iv, v| config.instance_variable_set(iv, v) }
  end

  it "exposes Rails.application.config.poli_page as a Configuration" do
    expect(Rails.application.config.poli_page).to be_a(PoliPage::Rails::Configuration)
  end

  it "returns a PoliPage::Client when api_key is valid" do
    with_config(api_key: "pp_test_unit") do
      client = described_class.client
      expect(client).to be_a(PoliPage::Client)
    end
  end

  it "memoises the client across calls" do
    with_config(api_key: "pp_test_unit") do
      a = described_class.client
      b = described_class.client
      expect(a).to be(b)
    end
  end

  it "raises ConfigurationError on first access when api_key is missing" do
    with_config(api_key: nil) do
      expect { described_class.client }.to raise_error(PoliPage::Rails::ConfigurationError, /api_key/)
    end
  end

  it "does not raise at engine boot when api_key is missing (lazy validation)" do
    # If validation ran at boot, the rails_helper require would have already raised.
    # Reaching this assertion proves boot was lazy.
    with_config(api_key: nil) do
      expect(Rails.application.config.poli_page.api_key).to be_nil
    end
  end

  it "memoises the SAME instance across threads (SDK is thread-safe)" do
    with_config(api_key: "pp_test_unit") do
      seen = []
      mutex = Mutex.new
      threads = Array.new(8) do
        Thread.new do
          c = described_class.client
          mutex.synchronize { seen << c }
        end
      end
      threads.each(&:join)
      expect(seen.uniq.size).to eq(1)
    end
  end

  describe "PoliPage.reset_client!" do
    it "clears the memoised instance" do
      with_config(api_key: "pp_test_unit") do
        a = described_class.client
        described_class.reset_client!
        b = described_class.client
        expect(a).not_to be(b)
      end
    end
  end

  describe "Railtie defaults applied in after_initialize" do
    it "sets config.logger to Rails.logger when the user did not set one" do
      expect(Rails.application.config.poli_page.logger).to eq(Rails.logger)
    end

    it "installs the notifications retry bridge by default" do
      expect(Rails.application.config.poli_page.on_retry).to respond_to(:call)
    end

    it "installs the notifications error bridge by default" do
      expect(Rails.application.config.poli_page.on_error).to respond_to(:call)
    end
  end
end
