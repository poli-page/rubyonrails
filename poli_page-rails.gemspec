# frozen_string_literal: true

require_relative "lib/poli_page/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "poli_page-rails"
  spec.version     = PoliPage::Rails::VERSION
  spec.summary     = "Rails engine for the Poli Page PDF rendering API"
  spec.description = "Rails engine + controller concern + ActiveSupport::Notifications " \
                     "bridge over the official poli-page Ruby SDK. Lazy-memoised " \
                     "PoliPage.client, RFC 5987 Content-Disposition handling, opt-out " \
                     "notifications instrumentation, and a rails generate poli_page:install " \
                     "generator that writes config/initializers/poli_page.rb."
  spec.authors     = ["Poli Page"]
  spec.email       = "support@poli.page"
  spec.homepage    = "https://poli.page"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri"          => "https://poli.page",
    "source_code_uri"       => "https://github.com/poli-page/rails",
    "changelog_uri"         => "https://github.com/poli-page/rails/blob/main/CHANGELOG.md",
    "bug_tracker_uri"       => "https://github.com/poli-page/rails/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.{rb,tt}"] + Dir["sig/**/*.rbs"] +
               %w[LICENSE README.md CHANGELOG.md].select { |f| File.exist?(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "poli-page",     "~> 0.9"
  spec.add_dependency "railties",      ">= 7.0", "< 9"
  spec.add_dependency "actionpack",    ">= 7.0", "< 9"
  spec.add_dependency "activesupport", ">= 7.0", "< 9"
end
