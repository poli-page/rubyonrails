# frozen_string_literal: true

require "active_support/notifications"

module PoliPage
  module Rails
    module Test
      # Snapshots ActiveSupport::Notifications subscriber counts for poli_page.*
      # event names. If a spec leaks a subscriber (forgets to unsubscribe), we
      # catch it in the after(:each) assertion rather than discovering it as
      # cross-spec interference much later. CLAUDE.md §10.2.
      module NotificationsLeakDetector
        EVENTS = %w[poli_page.retry poli_page.error].freeze

        def self.included(base)
          base.before do
            @notifications_baseline = EVENTS.index_with do |name|
              ::ActiveSupport::Notifications.notifier.listeners_for(name).size
            end
          end

          base.after do
            EVENTS.each do |name|
              now = ::ActiveSupport::Notifications.notifier.listeners_for(name).size
              if now > @notifications_baseline[name]
                raise "Subscriber leak on #{name}: #{@notifications_baseline[name]} → #{now}"
              end
            end
          end
        end
      end
    end
  end
end
