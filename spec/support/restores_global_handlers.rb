# frozen_string_literal: true

module PoliPage
  module Rails
    module Test
      # Snapshots Signal.trap('INT') / Signal.trap('TERM') handlers per spec.
      # Rails.application.initialize! (called by combustion) and various
      # framework boot paths can leave signal handlers installed; this support
      # module restores the snapshot in after(:each). CLAUDE.md §10.2.
      module RestoresGlobalHandlers
        SIGNALS = %w[INT TERM].freeze

        def self.included(base)
          base.before do
            @signal_baseline = SIGNALS.to_h do |sig|
              # Signal.trap returns the previous handler; immediately re-install
              # the same to read it without changing state.
              previous = Signal.trap(sig, "DEFAULT")
              Signal.trap(sig, previous)
              [sig, previous]
            end
          end

          base.after do
            SIGNALS.each do |sig|
              Signal.trap(sig, @signal_baseline[sig])
            end
          end
        end
      end
    end
  end
end
