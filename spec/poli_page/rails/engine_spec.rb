# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::Engine do
  it "is loaded as a Rails::Engine subclass" do
    expect(described_class.ancestors).to include(Rails::Engine)
  end

  it "is registered with Rails.application as an engine" do
    engine_classes = Rails.application.railties.map(&:class)
    expect(engine_classes).to include(described_class)
  end
end

# The "exposes its own config namespace" assertion that originally lived here
# (plan §3.1, §5.6) was based on a misunderstanding: isolate_namespace scopes
# routes/models, not config. The user-facing namespace is on the application
# config, not the engine config — wired by the Railtie and verified in
# spec/poli_page/rails/client_spec.rb ("exposes Rails.application.config.poli_page
# as a Configuration").
