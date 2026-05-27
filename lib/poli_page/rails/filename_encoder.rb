# frozen_string_literal: true

require "action_dispatch/http/content_disposition"

module PoliPage
  module Rails
    # Builds a Content-Disposition header value with RFC 5987 / RFC 6266
    # encoding for non-ASCII filenames. Thin wrapper over Rails's own
    # ActionDispatch::Http::ContentDisposition.format — what ActiveStorage
    # uses to set the same header for downloaded blobs.
    #
    # Why a wrapper at all: single seam if Rails changes the formatting API
    # across versions (stable since Rails 5.2; one place to patch if it
    # changes).
    module FilenameEncoder
      module_function

      def disposition(filename, inline:)
        disposition_type = inline ? "inline" : "attachment"
        ::ActionDispatch::Http::ContentDisposition.format(
          disposition: disposition_type,
          filename: filename
        )
      end
    end
  end
end
