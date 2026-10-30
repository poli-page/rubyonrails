# frozen_string_literal: true

# Conformance with the Poli Page API contract (https://github.com/poli-page/api-contract):
# its integration cases (`kind: "impl"`), against the example app.
#
# CI copies the pinned contract.json with the poli-page/api-contract action and
# sets POLI_CONTRACT to its path. The app under test is this suite's Rails app
# with the example app's controllers, routes and PoliPage initializer loaded
# into it (spec/support/contract/impl_case_runner.rb), so the cases run on
# every Rails version of the CI matrix. Per case, a local server
# (spec/support/contract/mock_server.rb) answers the case's `responses` in
# order and records the SDK's requests; the example initializer points the
# SDK at it through POLI_PAGE_BASE_URL; the case's request goes through the
# Rails test client; and the answer and the recorded requests are compared
# with the case's `expect` (spec/support/contract/impl_case_check.rb). The SDK
# keeps its default retry settings.
#
# spec/contract-skip.json maps the case ids allowed to fail to the reason. A
# listed case that passes, or a listed id that is not an impl case of the
# contract, fails the run.
#
# Locally: POLI_CONTRACT=/path/to/contract.json bundle exec rspec. Without it
# the cases are pending, except in CI, where a missing contract is an error.

require "rails_helper"

PoliPage::Rails::Test::ImplCaseRunner.load_example_controllers

RSpec.describe "API contract: integration cases", type: :request do
  include PoliPage::Rails::Test::ImplCaseRunner

  contract = PoliPage::Rails::Test::ImplContract

  if contract.path.nil?
    it "needs POLI_CONTRACT in CI, and is pending without it locally" do
      skip "API contract: set POLI_CONTRACT to a contract.json path to run it" if ENV.fetch("CI", "").empty?

      message = 'POLI_CONTRACT is not set: in CI the "API contract" step must provide contract.json ' \
                "(poli-page/api-contract action, output `path`)"
      expect(PoliPage::Rails::Test::ImplContract.path).not_to be_nil, message
    end
  elsif contract.load_error
    it "reads the contract file" do
      expect(PoliPage::Rails::Test::ImplContract.load_error).to be_nil
    end
  else
    it "lists only impl case ids of the contract in contract-skip.json" do
      unknown = PoliPage::Rails::Test::ImplContract.unknown_skip_ids
      expect(unknown).to be_empty, "contract-skip.json lists ids that are not impl cases of the contract: " \
                                   "#{unknown.inspect}"
    end

    contract.cases.each do |kase|
      it kase["id"], impl_case: kase do |example|
        id = example.metadata[:impl_case]["id"]
        errors = run_impl_case(example.metadata[:impl_case])
        reason = PoliPage::Rails::Test::ImplContract.skip_list[id]

        if reason
          raise "#{id} passes: remove it from contract-skip.json" if errors.empty?

          skip "contract-skip.json: #{reason}"
        end
        expect(errors).to be_empty, "#{id}:\n  #{errors.join("\n  ")}"
      end
    end
  end
end
