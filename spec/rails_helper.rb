# frozen_string_literal: true

require_relative "spec_helper"

ENV["RAILS_ENV"] ||= "test"

require "combustion"
Combustion.path = "spec/internal"
Combustion.initialize! :action_controller, :action_dispatch do
  config.eager_load = false
  config.logger = Logger.new(IO::NULL)
end

require "rspec/rails"
require "poli_page-rails"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.include PoliPage::Rails::Test::NotificationsLeakDetector
end
