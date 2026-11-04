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
# The repository's Actions logs are public, so this script never prints an
# answer body. It masks every token or key it finds in one before anything
# else, even when the request failed, and on a failure prints only curl's exit
# code, the HTTP status and the answer's `error`/`errors`/`message` field.
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

# Answer bodies go to files in a private directory, never to the log.
work="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/rubygems-oidc.XXXXXX")"
chmod 700 "$work"
trap 'rm -rf "$work"' EXIT

# mask VALUE: masks each line of VALUE (`::add-mask::` covers one line).
mask() {
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && echo "::add-mask::${line}"
  done <<<"$1"
  return 0
}

# mask_secrets_in FILE JQ_PATH: masks the value at JQ_PATH when FILE parses
# as JSON, and anything in FILE shaped like a RubyGems.org key (`rubygems_`
# and hex digits), which also covers a truncated answer that does not parse.
mask_secrets_in() {
  local value
  value="$(jq -r "${2} // empty | strings" "$1" 2>/dev/null)" || value=""
  [ -n "$value" ] && mask "$value"
  { grep -aoE 'rubygems_[0-9a-f]{16,}' "$1" 2>/dev/null || true; } | while IFS= read -r value; do mask "$value"; done
  return 0
}

# request_failed WHAT CURL_EXIT STATUS FILE: fails with curl's exit code, the
# HTTP status and, when the body is JSON, its error field. Never the body.
request_failed() {
  local detail
  detail="$(jq -rc '.error // .errors // .message // empty' "$4" 2>/dev/null)" || detail=""
  fail "${1} failed (curl exit ${2}, HTTP ${3})${detail:+: ${detail}}"
}

# -q: no ~/.curlrc. Timeouts, so a hung endpoint fails the step in a minute.
curl_opts=(-q -sS --fail-with-body --connect-timeout 10 --max-time 60 -H "Accept: application/json")

# 1. The GitHub OIDC token. The request URL already carries a query string;
# the request token goes in on stdin, not on the command line.
oidc_body="${work}/oidc.json"
oidc_exit=0
oidc_status="$(printf 'Authorization: bearer %s\n' "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  | curl "${curl_opts[@]}" -H @- -o "$oidc_body" -w '%{http_code}' \
      "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${AUDIENCE}")" || oidc_exit=$?
touch "$oidc_body"
mask_secrets_in "$oidc_body" '.value'
if [ "$oidc_exit" -ne 0 ] || [[ "$oidc_status" != 2?? ]]; then
  request_failed "The GitHub OIDC token request" "$oidc_exit" "${oidc_status:-000}" "$oidc_body"
fi
jwt="$(jq -er '.value | strings | select(length > 0)' "$oidc_body" 2>/dev/null)" \
  || fail "GitHub's OIDC answer has no token."

# 2. The exchange. jq builds the body from the environment and it goes in on
# stdin: neither the JWT nor the body is on a command line. No retry: a JWT
# can be exchanged only once.
exchange_body="${work}/exchange.json"
exchange_exit=0
exchange_status="$(JWT="$jwt" OWNER="$RUBYGEMS_OWNER_ID" jq -n '{jwt: $ENV.JWT, owner: $ENV.OWNER}' \
  | curl "${curl_opts[@]}" -H "Content-Type: application/json" --data-binary @- \
      -o "$exchange_body" -w '%{http_code}' \
      "${GEM_SERVER}/api/v1/oidc/trusted_publisher/exchange_token")" || exchange_exit=$?
touch "$exchange_body"
mask_secrets_in "$exchange_body" '.rubygems_api_key'
if [ "$exchange_exit" -ne 0 ] || [[ "$exchange_status" != 2?? ]]; then
  request_failed "The token exchange with ${GEM_SERVER}" "$exchange_exit" "${exchange_status:-000}" "$exchange_body"
fi
key="$(jq -er '.rubygems_api_key | strings | select(length > 0)' "$exchange_body" 2>/dev/null)" \
  || fail "${GEM_SERVER} answered the exchange (HTTP ${exchange_status}) without an API key."

# RubyGems.org keys are `rubygems_` and hex digits. Holding to letters, digits,
# `_` and `-` keeps the key one line in $GITHUB_ENV and a plain YAML scalar.
[[ "$key" =~ ^[A-Za-z0-9_-]+$ ]] || fail "the API key ${GEM_SERVER} returned has characters other than letters, digits, '_' and '-'."

owner_handle="$(jq -r '.owner // empty | strings' "$exchange_body")"
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
