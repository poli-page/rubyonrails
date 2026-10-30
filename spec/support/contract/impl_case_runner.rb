# frozen_string_literal: true

module PoliPage
  module Rails
    module Test
      # Runs one `impl` case against the example app, from a request spec
      # (spec/contract/impl_contract_spec.rb).
      module ImplCaseRunner
        EXAMPLE_APP = File.expand_path("../../../example-app", __dir__)
        ENV_NAMES = %w[POLI_PAGE_API_KEY POLI_PAGE_BASE_URL].freeze

        # The example app's controllers, on top of this suite's Rails app; its
        # routes come from spec/internal/config/routes.rb.
        def self.load_example_controllers
          %w[renders documents streams].each do |name|
            require File.join(EXAMPLE_APP, "app/controllers/#{name}_controller.rb")
          end
        end

        # Sends the case's request to the app, its SDK pointed at a mock server
        # answering the case's responses; returns the differences with `expect`.
        def run_impl_case(raw)
          kase = nil
          server = ContractMockServer.new do |origin|
            kase = ImplContract.render(raw, origin)
            kase.fetch("responses")
          end
          send_case_request(kase.fetch("request"), server.origin)
          server.close
          check_impl_case(kase.fetch("expect"), server)
        ensure
          server&.close
        end

        private

        def check_impl_case(expect, server)
          check = ImplCaseCheck.new(expect, response, server.requests, SANDBOX_KEY)
          check.errors + server.errors.map { |e| "mock server: #{e.class}: #{e.message}" }
        end

        def send_case_request(request, base_url)
          with_example_app_config(SANDBOX_KEY, base_url) do
            process(request.fetch("method").downcase.to_sym, request.fetch("path"))
          end
        end

        # Configures the SDK the way the example app does: its initializer
        # reads POLI_PAGE_API_KEY and POLI_PAGE_BASE_URL.
        def with_example_app_config(api_key, base_url)
          config = ::Rails.application.config.poli_page
          saved_env = ENV_NAMES.index_with { |name| ENV.fetch(name, nil) }
          saved_config = [config.api_key, config.base_url]
          ENV.update("POLI_PAGE_API_KEY" => api_key, "POLI_PAGE_BASE_URL" => base_url)
          load File.join(EXAMPLE_APP, "config/initializers/poli_page.rb")
          PoliPage.reset_client!
          yield
        ensure
          restore(config, saved_env, saved_config)
        end

        def restore(config, saved_env, saved_config)
          ENV.update(saved_env)
          config.api_key, config.base_url = saved_config
          PoliPage.reset_client!
        end
      end
    end
  end
end
