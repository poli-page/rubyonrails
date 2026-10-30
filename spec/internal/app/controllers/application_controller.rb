# frozen_string_literal: true

# Stands in for the example app's ApplicationController, whose only addition
# (allow_browser, an HTML-page guard) needs Rails 7.2. The example app's
# RendersController, DocumentsController and StreamsController inherit from
# it in spec/contract/impl_contract_spec.rb.
class ApplicationController < ActionController::Base
end
