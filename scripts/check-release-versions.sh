#!/usr/bin/env bash
# scripts/check-release-versions.sh: a release's major.minor must be the
# pinned API contract's and the required poli-page SDK's.
#
# Usage: scripts/check-release-versions.sh X.Y.Z   (or vX.Y.Z, or a prerelease)
#
# The gem shares its major.minor with the Poli Page API, and integration 0.N
# requires the poli-page SDK 0.N.x. This script:
#   - fails unless poli_page-rails.gemspec and example-app/Gemfile require
#     poli-page as `~> X.Y.Z` with the release's major.minor (RubyGems reads
#     `~> 0.13.0` as `>= 0.13.0, < 0.14`; `~> 0.13` would allow 0.14 and up);
#   - reads the contract commit pinned in .github/workflows/ci.yml (never its
#     `# vX.Y.Z` comment), checks that every workflow pins that same commit,
#     lists the contract repository's tags, and fails unless that commit
#     carries a stable tag vX.Y.Z with the release's major.minor.
# Patch numbers are free.
#
# Run by the release workflow. API_CONTRACT_REMOTE overrides the contract
# repository (to check against a local one).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
REMOTE="${API_CONTRACT_REMOTE:-https://github.com/poli-page/api-contract.git}"
PIN_PATTERN='s|.*uses: poli-page/api-contract@\([0-9a-f]\{40\}\).*|\1|p'

fail() { echo "check-release-versions: $1" >&2; exit 1; }

[ "$#" -eq 1 ] || fail "usage: $(basename "$0") X.Y.Z"
version="${1#v}"
if ! [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  fail "release version '$1' is not X.Y.Z"
fi
release_minor="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"

# The poli-page requirement of a gemspec or a Gemfile, as RubyGems prints it
# ("~> 0.13.0", ">= 0.13, < 0.14"), or nothing when it does not require it.
sdk_requirement() {
  ruby -rbundler - "$1" <<'RUBY'
    path = ARGV.fetch(0)
    deps = Dir.chdir(File.dirname(path)) do
      if path.end_with?(".gemspec")
        Gem::Specification.load(path).runtime_dependencies
      else
        Bundler::Dsl.new.tap { |dsl| dsl.eval_gemfile(path) }.dependencies
      end
    end
    dep = deps.find { |d| d.name == "poli-page" }
    print dep.requirement.to_s if dep
RUBY
}

# poli-page: `~> X.Y.Z` of the release's major.minor, in the gem and in the
# example app.
for manifest in poli_page-rails.gemspec example-app/Gemfile; do
  requirement="$(sdk_requirement "$REPO_ROOT/$manifest")" || fail "cannot read $manifest"
  [ -n "$requirement" ] || fail "$manifest does not require poli-page"
  if ! [[ "$requirement" =~ ^~\>\ ([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
    fail "release v$version needs poli-page ~> $release_minor.0, but $manifest requires '$requirement'"
  fi
  sdk_minor="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  if [ "$sdk_minor" != "$release_minor" ]; then
    fail "release v$version and the required poli-page $requirement ($manifest) differ in major.minor: require poli-page ~> $release_minor.0, or release v$sdk_minor.x"
  fi
done
echo "poli-page ~> $release_minor.0 is required, matching release v$version"

contract_sha="$(sed -n "$PIN_PATTERN" "$WORKFLOW" | head -n 1)"
[ -n "$contract_sha" ] || fail "no poli-page/api-contract pin found in .github/workflows/ci.yml"

# The release workflow runs the contract suite with its own pin: it must be
# the commit the check reads.
for workflow in "$REPO_ROOT"/.github/workflows/*.yml; do
  while IFS= read -r pin; do
    [ "$pin" = "$contract_sha" ] ||
      fail "$(basename "$workflow") pins the API contract ${pin:0:8}, but ci.yml pins ${contract_sha:0:8}: pin the same commit in both"
  done < <(sed -n "$PIN_PATTERN" "$workflow")
done

tags="$(git ls-remote --tags "$REMOTE")" || fail "cannot list the tags of $REMOTE"

# An annotated tag is listed twice: its own object, then `^{}` with the commit
# it points at. A lightweight tag is listed once, with its commit.
stable_tags="$(
  awk -v sha="$contract_sha" '$1 == sha { ref = $2; sub(/^refs\/tags\//, "", ref); sub(/\^\{\}$/, "", ref); print ref }' <<<"$tags" |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -u -V || true
)"
short_sha="${contract_sha:0:8}"
if [ -z "$stable_tags" ]; then
  fail "release v$version needs the API contract v$release_minor.x, but the pinned contract commit $short_sha has no stable vX.Y.Z tag: pin a released contract"
fi

while IFS= read -r tag; do
  if [[ "$tag" =~ ^v([0-9]+)\.([0-9]+)\. ]] && [ "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}" = "$release_minor" ]; then
    echo "API contract $tag ($short_sha) matches release v$version"
    exit 0
  fi
done <<<"$stable_tags"

pinned="$(tr '\n' ' ' <<<"$stable_tags" | sed 's/ $//')"
# The newest of the commit's tags (one commit may carry two, for an unchanged
# contract).
[[ "$(tail -n 1 <<<"$stable_tags")" =~ ^v([0-9]+)\.([0-9]+)\. ]]
fail "release v$version and the pinned API contract $pinned ($short_sha) differ in major.minor: pin the contract v$release_minor.x, or release v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.x"
