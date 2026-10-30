# frozen_string_literal: true

require "json"

module PoliPage
  module Rails
    module Test
      # Compares the app's answer to one `impl` case, and the requests the mock
      # server recorded, with the case's `expect`. #errors lists every
      # difference; empty means the case passes.
      class ImplCaseCheck
        UUID_V4 = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

        attr_reader :errors

        # @param expect   [Hash] the case's `expect`, placeholders replaced
        # @param response [ActionDispatch::TestResponse] the app's answer
        # @param recorded [Array<ContractMockServer::Recorded>]
        # @param api_key  [String] the key the app's SDK was given
        def initialize(expect, response, recorded, api_key)
          @expect = expect
          @response = response
          @recorded = recorded
          @api_key = api_key
          @errors = []
          check_status
          check_location
          check_content_type
          check_json
          check_requests
        end

        private

        def check_status
          return if @response.status == @expect["status"]

          fail_with "status: expected #{@expect["status"]}, got #{@response.status}", body_excerpt
        end

        def check_location
          return unless @expect.key?("location")

          compare("location", @expect["location"], @response.headers["Location"])
        end

        # The media type only: parameters such as charset are ignored.
        def check_content_type
          return unless @expect.key?("contentType")

          compare("contentType", @expect["contentType"], @response.media_type)
        end

        # Deep equality, so the key sets must match exactly.
        def check_json
          return unless @expect.key?("json")

          expected = @expect["json"]
          actual = JSON.parse(@response.body)
          fail_with "json: expected #{JSON.generate(expected)}, got #{JSON.generate(actual)}" unless actual == expected
        rescue JSON::ParserError
          fail_with "json: expected #{JSON.generate(expected)}, got a body that is not JSON", body_excerpt
        end

        def check_requests
          expected = @expect["requests"]
          return if expected.nil?

          check_request_count(expected)
          expected.zip(@recorded).each_with_index do |(want, got), i|
            check_request(want, got, "requests[#{i}]") if got
          end
          check_stable_key(expected)
        end

        def check_request_count(expected)
          return if @recorded.size == expected.size

          seen = @recorded.map { |r| "#{r.verb} #{r.target}" }
          fail_with "requests: expected #{expected.size}, got #{@recorded.size} #{seen.inspect}"
        end

        def check_request(want, got, label)
          compare("#{label}.method", want["method"], got.verb)
          compare("#{label}.path", want["path"], got.target)
          check_auth(want["auth"], got.headers["authorization"], label)
          check_idempotency(want["idempotencyKey"], got.headers["idempotency-key"], label)
        end

        def check_auth(want, header, label)
          case want
          when "bearer"
            return if header == "Bearer #{@api_key}"

            fail_with "#{label}.auth: expected Bearer <test key>, got #{header.inspect}"
          when "none" then compare("#{label}.auth", nil, header)
          else fail_with "#{label}.auth: unknown expectation #{want.inspect}"
          end
        end

        def check_idempotency(want, header, label)
          case want
          when "stable"
            return if header&.match?(UUID_V4)

            fail_with "#{label}.idempotencyKey: expected a lowercase UUID v4, got #{header.inspect}"
          when "absent" then compare("#{label}.idempotencyKey", nil, header)
          else fail_with "#{label}.idempotencyKey: unknown expectation #{want.inspect}"
          end
        end

        # `stable`: the same key on every attempt of the call.
        def check_stable_key(expected)
          keys = expected.zip(@recorded).filter_map do |want, got|
            got.headers["idempotency-key"] if got && want["idempotencyKey"] == "stable"
          end
          return if keys.uniq.size <= 1

          fail_with "idempotencyKey: expected one key across the attempts, got #{keys.inspect}"
        end

        def compare(label, expected, actual)
          fail_with "#{label}: expected #{expected.inspect}, got #{actual.inspect}" unless actual == expected
        end

        def fail_with(*parts)
          @errors << parts.join(" ")
        end

        def body_excerpt
          "(body #{@response.body[0, 300].inspect})"
        end
      end
    end
  end
end
