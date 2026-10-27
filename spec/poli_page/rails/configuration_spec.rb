# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::Configuration do
  it "defaults every option except api_key to nil" do
    config = described_class.new

    expect(config.api_key).to be_nil
    expect(config.base_url).to be_nil
    expect(config.timeout).to be_nil
    expect(config.max_retries).to be_nil
    expect(config.retry_delay).to be_nil
    expect(config.user_agent).to be_nil
    expect(config.logger).to be_nil
    expect(config.on_retry).to be_nil
    expect(config.on_error).to be_nil
    expect(config.proxy).to be_nil
    expect(config.ca_file).to be_nil
    expect(config.ca_path).to be_nil
  end

  it "defaults notifications to true (default-on, opt-out per spec §10.5)" do
    expect(described_class.new.notifications).to be true
  end

  it "is mutable via attr_accessor for the config block idiom" do
    config = described_class.new
    config.api_key = PoliPage::Rails::Test::SANDBOX_KEY
    config.timeout = 42.0

    expect(config.api_key).to eq(PoliPage::Rails::Test::SANDBOX_KEY)
    expect(config.timeout).to eq(42.0)
  end

  describe "#to_client_kwargs" do
    it "drops nil values so the SDK's own defaults apply" do
      config = described_class.new
      config.api_key = PoliPage::Rails::Test::SANDBOX_KEY
      config.timeout = 30.0

      kwargs = config.to_client_kwargs
      expect(kwargs).to eq(api_key: PoliPage::Rails::Test::SANDBOX_KEY, timeout: 30.0)
      expect(kwargs).not_to have_key(:base_url)
      expect(kwargs).not_to have_key(:max_retries)
    end

    it "passes through proxy / ca_file / ca_path when set" do
      config = described_class.new
      config.api_key = PoliPage::Rails::Test::SANDBOX_KEY
      config.proxy = "http://proxy.example.com:8080"
      config.ca_file = "/etc/ssl/corp.pem"

      kwargs = config.to_client_kwargs
      expect(kwargs[:proxy]).to eq("http://proxy.example.com:8080")
      expect(kwargs[:ca_file]).to eq("/etc/ssl/corp.pem")
    end

    it "does not include user_agent (the SDK does not currently accept it)" do
      config = described_class.new
      config.api_key = PoliPage::Rails::Test::SANDBOX_KEY
      config.user_agent = "MyApp/1.0"

      expect(config.to_client_kwargs).not_to have_key(:user_agent)
    end
  end
end

RSpec.describe PoliPage::Rails::ConfigurationValidator do
  subject(:validator) { described_class }

  let(:logger) { instance_spy(Logger) }

  def config(**overrides)
    PoliPage::Rails::Configuration.new.tap do |c|
      c.api_key = PoliPage::Rails::Test::SANDBOX_KEY
      c.logger = logger
      overrides.each { |k, v| c.public_send("#{k}=", v) }
    end
  end

  context "with api_key" do
    hex = PoliPage::Rails::Test::SECRET

    it "rejects nil" do
      expect { validator.validate!(config(api_key: nil)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /api_key is required/)
    end

    it "rejects empty string" do
      expect { validator.validate!(config(api_key: "")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /api_key is required/)
    end

    it "rejects a non-String value" do
      expect { validator.validate!(config(api_key: 12_345)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /api_key is required/)
    end

    {
      "a sandbox key" => "pp_sandbox_#{hex}",
      "a live key" => "pp_live_#{hex}",
      "a key for a created environment with a hyphen" => "pp_eu-prod_#{hex}",
      "a 20-character environment name" => "pp_#{"a" * 20}_#{hex}"
    }.each do |label, key|
      it "accepts #{label} without a warning" do
        expect { validator.validate!(config(api_key: key)) }.not_to raise_error
        expect(logger).not_to have_received(:warn)
      end
    end

    {
      "a key whose secret is not 32 hex" => %w[pp_sandbox_x pp_sandbox_],
      "a key whose secret has a 33rd hex character" => ["pp_sandbox_#{hex}0", "pp_sandbox_"],
      "a key whose secret is upper-case hex" => ["pp_sandbox_#{hex.upcase}", "pp_sandbox_"],
      "a sandbox key with a trailing newline" => ["pp_sandbox_#{hex}\n", "pp_sandbox_"],
      "a sandbox key after a leading line" => ["x\npp_sandbox_#{hex}", nil],
      "a malformed key with a 20-character environment name" => ["pp_#{"a" * 20}_x", "pp_#{"a" * 20}_"],
      "an upper-case environment name" => ["pp_Sandbox_#{hex}", nil],
      "an environment name starting with a digit" => ["pp_2fa_#{hex}", nil],
      "an environment name with a double hyphen" => ["pp_a--b_#{hex}", nil],
      "a 21-character environment name" => ["pp_#{"a" * 21}_#{hex}", nil],
      "a token without the pp_ prefix" => ["abc_definitely_a_token", nil],
      "a well-shaped key without the pp_ prefix" => ["sandbox_#{hex}", nil]
    }.each do |label, (key, shown_prefix)|
      it "accepts #{label} with exactly one warning that hides the secret" do
        expect { validator.validate!(config(api_key: key)) }.not_to raise_error
        expect(logger).to have_received(:warn).once do |message|
          expect(message).not_to include(key)
          expect(message).not_to include(PoliPage::Rails::Test::SECRET)
          if shown_prefix
            expect(message).to start_with("Poli Page api_key #{shown_prefix}… does not match")
          else
            expect(message).to start_with("Poli Page api_key does not match")
          end
        end
      end
    end

    it "accepts a malformed key without a configured logger" do
      expect { validator.validate!(config(api_key: "pp_sandbox_x", logger: nil)) }.not_to raise_error
    end
  end

  context "with base_url" do
    it "accepts nil" do
      expect { validator.validate!(config(base_url: nil)) }.not_to raise_error
    end

    it "accepts http URLs" do
      expect { validator.validate!(config(base_url: "http://example.com")) }.not_to raise_error
    end

    it "accepts https URLs" do
      expect { validator.validate!(config(base_url: "https://api.poli.page")) }.not_to raise_error
    end

    it "rejects non-http schemes" do
      expect { validator.validate!(config(base_url: "ftp://example.com")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /base_url must be an http or https URL/)
    end

    it "rejects garbage strings" do
      expect { validator.validate!(config(base_url: "not a url")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /base_url must be an http or https URL/)
    end
  end

  context "with timeout" do
    it "accepts nil" do
      expect { validator.validate!(config(timeout: nil)) }.not_to raise_error
    end

    it "accepts a positive Float" do
      expect { validator.validate!(config(timeout: 30.5)) }.not_to raise_error
    end

    it "accepts a positive Integer" do
      expect { validator.validate!(config(timeout: 30)) }.not_to raise_error
    end

    it "rejects zero" do
      expect { validator.validate!(config(timeout: 0)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /timeout must be a positive number/)
    end

    it "rejects negative numbers" do
      expect { validator.validate!(config(timeout: -1)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /timeout must be a positive number/)
    end

    it "rejects values > 600" do
      expect { validator.validate!(config(timeout: 601)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /timeout must be <= 600/)
    end

    it "rejects non-numeric values" do
      expect { validator.validate!(config(timeout: "30")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /timeout must be a positive number/)
    end
  end

  context "with max_retries" do
    it "accepts nil" do
      expect { validator.validate!(config(max_retries: nil)) }.not_to raise_error
    end

    it "accepts 0" do
      expect { validator.validate!(config(max_retries: 0)) }.not_to raise_error
    end

    it "accepts 10" do
      expect { validator.validate!(config(max_retries: 10)) }.not_to raise_error
    end

    it "rejects negative integers" do
      expect { validator.validate!(config(max_retries: -1)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /max_retries must be an integer between 0 and 10/)
    end

    it "rejects values > 10" do
      expect { validator.validate!(config(max_retries: 11)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /max_retries must be an integer between 0 and 10/)
    end

    it "rejects Float" do
      expect { validator.validate!(config(max_retries: 3.5)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /max_retries must be an integer between 0 and 10/)
    end
  end

  context "with retry_delay" do
    it "accepts nil" do
      expect { validator.validate!(config(retry_delay: nil)) }.not_to raise_error
    end

    it "accepts 0" do
      expect { validator.validate!(config(retry_delay: 0)) }.not_to raise_error
    end

    it "accepts a positive Float" do
      expect { validator.validate!(config(retry_delay: 0.5)) }.not_to raise_error
    end

    it "rejects negative numbers" do
      expect { validator.validate!(config(retry_delay: -0.1)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /retry_delay must be a number between 0 and 30/)
    end

    it "rejects values > 30" do
      expect { validator.validate!(config(retry_delay: 31)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /retry_delay must be a number between 0 and 30/)
    end
  end

  context "with notifications" do
    it "accepts true" do
      expect { validator.validate!(config(notifications: true)) }.not_to raise_error
    end

    it "accepts false" do
      expect { validator.validate!(config(notifications: false)) }.not_to raise_error
    end

    it "rejects nil" do
      expect { validator.validate!(config(notifications: nil)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /notifications must be true or false/)
    end

    it "rejects truthy non-boolean values" do
      expect { validator.validate!(config(notifications: "yes")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /notifications must be true or false/)
    end
  end

  context "with on_retry / on_error" do
    it "accepts nil" do
      expect { validator.validate!(config(on_retry: nil, on_error: nil)) }.not_to raise_error
    end

    it "accepts any object responding to #call" do
      callable = ->(_event) {} # standard Proc
      expect { validator.validate!(config(on_retry: callable)) }.not_to raise_error
    end

    it "rejects String (no const_get indirection — pass an actual callable)" do
      expect { validator.validate!(config(on_retry: "MyCallback")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /on_retry must respond to #call/)
    end

    it "rejects Symbol" do
      expect { validator.validate!(config(on_error: :my_callback)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /on_error must respond to #call/)
    end
  end
end
