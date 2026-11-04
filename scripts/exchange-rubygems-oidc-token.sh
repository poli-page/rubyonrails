#!/usr/bin/env bash
# scripts/exchange-rubygems-oidc-token.sh: RubyGems Trusted Publishing, with
# the owner account asserted.
#
# Usage (in a GitHub Actions job with `id-token: write`):
#   RUBYGEMS_OWNER_ID=<account id> scripts/exchange-rubygems-oidc-token.sh
#
# Does what rubygems/configure-rubygems-credentials does for trusted
# publishing, plus the `owner` field that action cannot send yet:
#   1. requests a GitHub OIDC token for the audience `rubygems.org`;
#   2. POSTs {"jwt": <token>, "owner": <RUBYGEMS_OWNER_ID>} to
#      <GEM_SERVER>/api/v1/oidc/trusted_publisher/exchange_token, which answers
#      with a push-only API key that expires after 15 minutes;
#   3. masks the key, exports it as RUBYGEMS_API_KEY, BUNDLE_GEM__PUSH_KEY and
#      GEM_HOST_API_KEY through $GITHUB_ENV, and writes it to
#      ~/.gem/credentials, so `gem push` and `bundle exec rake release` in
#      later steps use it.
#
# RubyGems.org creates a new gem through a pending trusted publisher only when
# the exchange names the account that owns that pending publisher. For a gem
# that already exists the owner is not used: the gem's own trusted publisher
# authorizes the push.
#
# Inputs (environment):
#   RUBYGEMS_OWNER_ID   required, the all-digit RubyGems.org account ID. An ID,
#                       not a handle: handles can be renamed and taken again.
#   GEM_SERVER          optional, default https://rubygems.org.
#   ACTIONS_ID_TOKEN_REQUEST_URL, ACTIONS_ID_TOKEN_REQUEST_TOKEN, GITHUB_ENV
#                       set by GitHub Actions.

set -euo pipefail

AUDIENCE="rubygems.org"
GEM_SERVER="${GEM_SERVER:-https://rubygems.org}"
GEM_SERVER="${GEM_SERVER%/}"

fail() { echo "::error::exchange-rubygems-oidc-token: $1" >&2; exit 1; }

[ -n "${RUBYGEMS_OWNER_ID:-}" ] || fail "RUBYGEMS_OWNER_ID is empty: set it to the RubyGems.org account ID that owns the pending trusted publisher."
[[ "$RUBYGEMS_OWNER_ID" =~ ^[0-9]+$ ]] || fail "RUBYGEMS_OWNER_ID must be an all-digit account ID, got '${RUBYGEMS_OWNER_ID}'."
[ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] && [ -n "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ] \
  || fail "no GitHub OIDC token available: the job needs 'permissions: id-token: write'."
[ -n "${GITHUB_ENV:-}" ] || fail "GITHUB_ENV is not set."
# Without spaces or `#`, the URL is a plain YAML key in ~/.gem/credentials.
[[ "$GEM_SERVER" =~ ^https?://[A-Za-z0-9.:/_-]+$ ]] \
  || fail "GEM_SERVER must be an http(s) URL of letters, digits and '.:/_-', got '${GEM_SERVER}'."

# 1. The GitHub OIDC token. The request URL already carries a query string.
if ! oidc_response="$(curl -sS --fail-with-body \
    -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
    -H "Accept: application/json" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${AUDIENCE}")"; then
  fail "GitHub refused the OIDC token request: ${oidc_response}"
fi
jwt="$(jq -er '.value | strings | select(length > 0)' <<<"$oidc_response" 2>/dev/null)" \
  || fail "GitHub's OIDC answer has no token."
echo "::add-mask::${jwt}"

# 2. The exchange. jq builds the body; it goes in on stdin, not on the command
# line.
exchange_url="${GEM_SERVER}/api/v1/oidc/trusted_publisher/exchange_token"
if ! exchange_response="$(jq -n --arg jwt "$jwt" --arg owner "$RUBYGEMS_OWNER_ID" '{jwt: $jwt, owner: $owner}' \
    | curl -sS --fail-with-body \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        --data-binary @- \
        "$exchange_url")"; then
  fail "${GEM_SERVER} refused the token exchange: ${exchange_response}"
fi

# Nothing below prints the answer: on success it carries the key.
key="$(jq -er '.rubygems_api_key | strings | select(length > 0)' <<<"$exchange_response" 2>/dev/null)" \
  || fail "${GEM_SERVER} answered the exchange without an API key."
echo "::add-mask::${key}"

# RubyGems.org keys are `rubygems_` and hex digits. Holding to letters, digits,
# `_` and `-` keeps the key one line in $GITHUB_ENV and a plain YAML scalar.
[[ "$key" =~ ^[A-Za-z0-9_-]+$ ]] || fail "the API key ${GEM_SERVER} returned has characters other than letters, digits, '_' and '-'."

owner_handle="$(jq -r '.owner // empty' <<<"$exchange_response")"
if [ -n "$owner_handle" ]; then
  echo "${GEM_SERVER} recorded owner '${owner_handle}' (ID ${RUBYGEMS_OWNER_ID}) for a gem this key creates."
else
  echo "::warning::${GEM_SERVER} did not echo the asserted owner: a push that creates a new gem may be refused."
fi

# 3. Export the key as rubygems/configure-rubygems-credentials does.
{
  printf 'RUBYGEMS_API_KEY=%s\n' "$key"
  printf 'BUNDLE_GEM__PUSH_KEY=%s\n' "$key"
  printf 'GEM_HOST_API_KEY=%s\n' "$key"
} >>"$GITHUB_ENV"

# The credentials file names rubygems.org's key `:rubygems_api_key` and any
# other server's key by its URL.
if [ "$GEM_SERVER" = "https://rubygems.org" ]; then
  credentials_key=":rubygems_api_key"
else
  credentials_key="$GEM_SERVER"
fi

gem_dir="${HOME}/.gem"
credentials="${gem_dir}/credentials"
mkdir -p "$gem_dir"
if [ -e "$credentials" ]; then
  # Fresh runners have none; refuse to guess how to merge into one.
  fail "${credentials} already exists."
fi
(
  umask 077
  printf -- '---\n%s: %s\n' "$credentials_key" "$key" >"$credentials"
)

echo "RubyGems API key exported for ${GEM_SERVER}."
