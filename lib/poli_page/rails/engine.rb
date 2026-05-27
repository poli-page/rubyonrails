# frozen_string_literal: true

require "rails/engine"

module PoliPage
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace PoliPage::Rails

      # config.poli_page is wired by the Railtie (Task 5). This Engine class
      # exists primarily so future routes / generators / assets can ship as
      # part of v0.2 without re-architecting.
    end
  end
end
