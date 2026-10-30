# frozen_string_literal: true

Rails.application.routes.draw do
  get "renderable_test/pdf_attachment", to: "renderable_test#pdf_attachment"
  get "renderable_test/preview",        to: "renderable_test#preview"
  get "renderable_test/redirect_doc",   to: "renderable_test#redirect_doc"
  get "error_handler_test/pdf_first",   to: "error_handler_test#pdf_first"
  get "error_handler_test/:kind",       to: "error_handler_test#show"
  get "error_handler_live_test",        to: "error_handler_live_test#stream"
  get "error_handler_live_midstream",   to: "error_handler_live_midstream_test#stream"
  get "error_handler_api_test",         to: "error_handler_api_test#show"
end

# The example app's own routes, for spec/contract/impl_contract_spec.rb. The
# routes reloader keeps the route set open while it loads this file, so this
# second draw adds to the one above instead of replacing it.
load File.expand_path("../../../example-app/config/routes.rb", __dir__)
