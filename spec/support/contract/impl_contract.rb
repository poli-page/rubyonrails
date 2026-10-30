# frozen_string_literal: true

require "json"
require "time"

module PoliPage
  module Rails
    module Test
      # Reads the API contract at $POLI_CONTRACT for spec/contract/impl_contract_spec.rb:
      # its `impl` cases (the `sdk` cases are for the SDKs) and the skip list.
      module ImplContract
        SKIP_LIST = File.expand_path("../../contract-skip.json", __dir__)
        PLACEHOLDER = /\{\{([^}]*)\}\}/

        # The contract file is unusable (bad format or bad cases).
        class Invalid < StandardError; end

        module_function

        def path
          value = ENV.fetch("POLI_CONTRACT", "")
          value.empty? ? nil : value
        end

        # The `impl` cases; raises Invalid for a file this suite cannot run.
        def cases
          @cases ||= impl_cases(read(path))
        end

        # Why the contract file cannot be used, or nil.
        def load_error
          cases
          nil
        rescue Invalid, JSON::ParserError, KeyError, SystemCallError => e
          "#{path}: #{e.class}: #{e.message}"
        end

        def skip_list
          @skip_list ||= JSON.parse(File.read(SKIP_LIST))
        end

        # The skip-list ids that are not impl cases of the contract.
        def unknown_skip_ids
          skip_list.keys - cases.pluck("id")
        end

        def read(file)
          contract = JSON.parse(File.read(file))
          version = contract["formatVersion"]
          raise Invalid, "formatVersion #{version.inspect} is not supported (expected 1)" unless version == 1

          contract.fetch("cases")
        end

        def impl_cases(all)
          kinds = all.pluck("kind").uniq - %w[sdk impl]
          raise Invalid, "unknown case kind(s) #{kinds.inspect}" unless kinds.empty?

          impl = all.select { |c| c["kind"] == "impl" }
          raise Invalid, "the contract has no impl case" if impl.empty?

          impl
        end

        # `value` with `{{mock}}` and `{{httpDate+N}}` replaced in every string.
        # Any other placeholder is an error.
        def render(value, origin)
          case value
          when Hash then value.transform_values { |v| render(v, origin) }
          when Array then value.map { |v| render(v, origin) }
          when String then value.gsub(PLACEHOLDER) { placeholder(Regexp.last_match(1), origin) }
          else value
          end
        end

        def placeholder(name, origin)
          return origin if name == "mock"

          match = /\AhttpDate\+(\d+)\z/.match(name)
          raise Invalid, "unknown placeholder {{#{name}}}" unless match

          (Time.now.utc + match[1].to_i).httpdate
        end
      end
    end
  end
end
