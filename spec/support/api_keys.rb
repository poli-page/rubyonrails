# frozen_string_literal: true

module PoliPage
  module Rails
    module Test
      # A well-formed sandbox key (pp_{environment}_{32 lowercase hex}) for
      # specs that need a valid api_key and never reach the API.
      SECRET = "0123456789abcdef0123456789abcdef"
      SANDBOX_KEY = "pp_sandbox_#{SECRET}".freeze
    end
  end
end
