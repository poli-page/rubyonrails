# frozen_string_literal: true

require "rails/generators"
require "rails/generators/base"

module PoliPage
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Writes config/initializers/poli_page.rb with a commented template."

      # NOTE: Zero custom options on this generator. Rails::Generators::Base
      # inherits Thor-reserved flags (--force, --pretend, --quiet, --skip,
      # --skip-namespace, --skip-collision-check). Defining a custom option
      # with any of those names would silently shadow them and make the
      # generator appear broken. CLAUDE.md §10.1.

      argument :initializer_path, type: :string, required: false,
                                  default: "config/initializers/poli_page.rb",
                                  banner: "PATH"

      def copy_initializer
        template "poli_page.rb.tt", initializer_path
      end

      def show_post_install_hint
        say ""
        say "Created #{initializer_path}.", :green
        say "Set POLI_PAGE_API_KEY in your environment, then restart the app.", :green
      end
    end
  end
end
