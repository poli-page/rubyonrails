# frozen_string_literal: true

module PoliPage
  module Rails
    module Test
      # Runs one `impl` case against the example app, from a request spec
      # (spec/contract/impl_contract_spec.rb).
      module ImplCaseRunner
        EXAMPLE_APP = File.expand_path("../../../example-app", __dir__)
        STAND_IN = File.expand_path("../../fixtures/application_controller_before_rails_7_2.rb", __dir__)
        ENV_NAMES = %w[POLI_PAGE_API_KEY POLI_PAGE_BASE_URL].freeze

        # The example app's controllers, on top of this suite's Rails app; its
        # routes come from spec/internal/config/routes.rb. Its own
        # ApplicationController needs allow_browser (Rails 7.2+); below that a
        # stand-in without it takes its place.
        def self.load_example_controllers
          if ::ActionController::Base.respond_to?(:allow_browser)
            require File.join(EXAMPLE_APP, "app/controllers/application_controller.rb")
          else
            require STAND_IN
          end
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
          handler = send_case_request(kase.fetch("request"), server.origin)
          server.close
          check_impl_case(kase.fetch("expect"), server) + check_error_handler(handler)
        ensure
          server&.close
        end

        private

        def check_impl_case(expect, server)
          check = ImplCaseCheck.new(expect, response, server.requests, SANDBOX_KEY)
          check.errors + server.errors.map { |e| "mock server: #{e.class}: #{e.message}" }
        end

        # The Railtie decides about the error handler once, at boot, so a
        # value the example initializer sets cannot take effect here: the
        # case fails instead of passing on a handler the example app turned off.
        def check_error_handler(value)
          return [] if value == true

          ["example-app/config/initializers/poli_page.rb sets config.poli_page.error_handler to " \
           "#{value.inspect}: the example app would not answer errors through the default handler"]
        end

        # Returns config.poli_page.error_handler as the example initializer left it.
        def send_case_request(request, base_url)
          with_example_app_config(SANDBOX_KEY, base_url) do |config|
            process(request.fetch("method").downcase.to_sym, request.fetch("path"))
            config.error_handler
          end
        end

        # Configures the SDK the way the example app does: its initializer
        # reads POLI_PAGE_API_KEY and POLI_PAGE_BASE_URL.
        def with_example_app_config(api_key, base_url)
          config = ::Rails.application.config.poli_page
          saved_env = ENV_NAMES.index_with { |name| ENV.fetch(name, nil) }
          saved_config = [config.api_key, config.base_url, config.error_handler]
          ENV.update("POLI_PAGE_API_KEY" => api_key, "POLI_PAGE_BASE_URL" => base_url)
          load File.join(EXAMPLE_APP, "config/initializers/poli_page.rb")
          PoliPage.reset_client!
          yield config
        ensure
          restore(config, saved_env, saved_config)
        end

        def restore(config, saved_env, saved_config)
          ENV.update(saved_env)
          config.api_key, config.base_url, config.error_handler = saved_config
          PoliPage.reset_client!
        end
      end
    end
  end
end
