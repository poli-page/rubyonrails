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
    #
    # Control characters are stripped before formatting: ContentDisposition
    # percent-escapes them (%0D%0A), which keeps the header intact but hands
    # CR/LF/TAB back to any client that decodes filename*.
    module FilenameEncoder
      # C0 controls (incl. TAB, CR, LF), DEL and C1 controls.
      CONTROL_CHARS = /[\u0000-\u001F\u007F-\u009F]/

      module_function

      def disposition(filename, inline:)
        disposition_type = inline ? "inline" : "attachment"
        ::ActionDispatch::Http::ContentDisposition.format(
          disposition: disposition_type,
          filename: filename.gsub(CONTROL_CHARS, "")
        )
      end
    end
  end
end
