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

  it "exposes its own config namespace",
     pending: "plan §5.6 expected isolate_namespace to wire this; revisit when Railtie lands in Task 5" do
    expect(described_class.config).to respond_to(:poli_page)
  end
end
