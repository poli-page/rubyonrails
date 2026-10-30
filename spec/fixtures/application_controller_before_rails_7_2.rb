# frozen_string_literal: true

# The example app's ApplicationController adds only allow_browser (an HTML
# page guard), which Rails 7.0 and 7.1 do not have. On those versions the
# contract spec loads this stand-in instead; from Rails 7.2 it loads the
# example's own file (spec/support/contract/impl_case_runner.rb).
class ApplicationController < ActionController::Base
end
