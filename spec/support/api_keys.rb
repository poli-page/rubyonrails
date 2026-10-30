# frozen_string_literal: true

module PoliPage
  module Rails
    module Test
      # A well-formed sandbox key (pp_{environment}_{32 lowercase hex}) for
      # specs that need a valid api_key and never reach the API.
      SECRET = "0123456789abcdef0123456789abcdef"
      SANDBOX_KEY = "pp_sandbox_#{SECRET}".freeze
      # The whole malformed-key warning: it names the format, never any key text.
      MALFORMED_KEY_WARNING = "Poli Page api_key does not match the expected format " \
                              "pp_{environment}_{32 lowercase hex characters}; starting anyway, " \
                              "the API will reject it if it is not a valid key."
    end
  end
end
