# Releasing

`poli_page-rails` is published to [RubyGems](https://rubygems.org/gems/poli_page-rails) by
`.github/workflows/release.yml` when a `vX.Y.Z` tag is pushed. The workflow uses RubyGems Trusted
Publishing (OIDC), so no API key is stored in the repository or in GitHub secrets.

## Versions

`poli_page-rails` shares its major.minor with the Poli Page API: gem `0.13.x` talks to API `0.13`,
passes the [API contract](https://github.com/poli-page/api-contract) `v0.13.0`, and requires the
`poli-page` SDK of the same minor (`~> 0.13.0`, which RubyGems reads as `>= 0.13.0, < 0.14`; a
bare `~> 0.13` would allow every later 0.x). Patch numbers are free: a fix to the gem alone is a
patch, whatever the API's or the SDK's patch. A change of the API contract, a new feature, and a
raise of the minimum Ruby or Rails version are each a minor. The gem may skip minors when it has
nothing to ship for one. The release workflow refuses a tag whose major.minor differs from the
contract version pinned in `.github/workflows/ci.yml` or from the `poli-page` requirement in
`poli_page-rails.gemspec` and `example-app/Gemfile`.

## How a release runs

What the workflow does on a tag push:

1. **verify**: fails unless the tag (without its `v`) equals `PoliPage::Rails::VERSION` in
   `lib/poli_page/rails/version.rb`, `CHANGELOG.md` has a `## [X.Y.Z]` section, and
   `example-app/Gemfile.lock` locks `poli_page-rails (X.Y.Z)`. Then
   `scripts/check-release-versions.sh` requires the pinned API contract commit to carry a stable
   tag `vX.Y.Z` of the tag's major.minor (the `# vX.Y.Z` comment next to the pin is not trusted,
   and every workflow must pin the same commit), and `poli-page` to be required as `~> X.Y.Z` of
   the tag's major.minor. The error names both versions.
2. **gates**: the CI suite on every supported Ruby (3.2, 3.3, 3.4) and Rails (7.0, 7.1, 7.2, 8.0):
   RuboCop, then every spec except the live API one (`spec/integration`), including the API
   contract's cases with the contract pinned by `poli-page/api-contract`.
3. **publish**, in the `rubygems-release` GitHub Environment (waits for a required reviewer):
   `scripts/exchange-rubygems-oidc-token.sh` exchanges the job's GitHub OIDC token for a
   RubyGems.org API key, naming the owner account (see the one-time setup), then
   `rubygems/release-gem` builds the gem from the gemspec and pushes it with that key, with sigstore
   attestations. The job then creates the GitHub Release with the CHANGELOG section as notes and the
   `.gem` attached.

The gem contains `lib/`, `sig/`, `LICENSE`, `README.md` and `CHANGELOG.md` only (see `spec.files` in
`poli_page-rails.gemspec`). The example app and the specs are not shipped.

## One-time setup (before the first release)

The gem name `poli_page-rails` is not taken on RubyGems
(`curl -s https://rubygems.org/api/v1/gems/poli_page-rails.json` answers `This rubygem could not be
found.`), so the first publish creates it. A gem that does not exist yet gets a **pending** trusted
publisher.

1. Sign in to rubygems.org as the account that will own the gem: `poli-page`, ID `247441`, the
   account the workflow asserts (step 4). Multi-factor authentication must be on: the gemspec sets
   `rubygems_mfa_required`.
2. Open <https://rubygems.org/profile/oidc/pending_trusted_publishers>, choose **Create**, and fill
   in the fields below. A pending trusted publisher expires 12 hours after it is created, so create
   it less than 12 hours before you push the tag, and approve the `publish` job within that window.
   - Gem name: `poli_page-rails`
   - Repository owner: `poli-page`
   - Repository name: `rubyonrails`
   - Workflow filename: `release.yml`
   - Environment: `rubygems-release`
3. In GitHub, `poli-page/rubyonrails` → Settings → Environments → **New environment** named
   `rubygems-release`:
   - Required reviewers: add the maintainers who approve releases.
   - Deployment branches and tags: **Selected branches and tags**, add the tag rule `v*.*.*`.
   - No secrets or variables are needed.
4. The publish job asserts the account that will own the gem: `RUBYGEMS_OWNER_ID` in the `env` of
   the `publish` job of `.github/workflows/release.yml`, set to `247441`, the ID of the RubyGems.org
   account `poli-page` (see `https://rubygems.org/api/v1/gems/poli-page/owners.json`). It is not a
   secret. RubyGems.org creates a new gem through trusted publishing only when the token exchange
   names the account whose pending trusted publisher allows it; without it the push is refused
   with "Trusted publishing can only create a new gem when the workflow declares which RubyGems.org
   account will own it". `rubygems/release-gem` and `rubygems/configure-rubygems-credentials`
   cannot send that account yet, so `scripts/exchange-rubygems-oidc-token.sh` does the exchange
   (`POST /api/v1/oidc/trusted_publisher/exchange_token` with `{"jwt": ..., "owner": "247441"}`)
   and `release-gem` runs with `setup-trusted-publisher: false`. The value is an ID, not the
   handle, because a handle can be renamed and taken again. If another account owns the pending
   trusted publisher, set its ID here.

If the pending trusted publisher has expired, or was created by an account other than
`RUBYGEMS_OWNER_ID`, the push fails with the generic "You are not allowed to push this gem.",
which names neither cause. Create the pending trusted publisher again from the `poli-page` account
(step 2), then re-run the failed `publish` job: a re-run gets a fresh OIDC token.

After the first publish, the pending publisher becomes a regular trusted publisher of the gem.
From then on that trusted publisher authorizes each push and RubyGems.org ignores the asserted
owner, so sending it on every release does no harm. Add co-owners with
`gem owner poli_page-rails --add <email>` if needed.

## Per release

1. On a branch off `main`, set the new version in `lib/poli_page/rails/version.rb`, move the
   `[Unreleased]` entries of `CHANGELOG.md` into a `## [X.Y.Z] - YYYY-MM-DD` section, leave an empty
   `## [Unreleased]` above it, and update the compare links at the bottom. Update the
   `poli_page-rails (X.Y.Z)` line of `example-app/Gemfile.lock` (`cd example-app && bundle lock`).
   For a new minor `X.Y`: require `poli-page` `~> X.Y.0` in `poli_page-rails.gemspec` and
   `example-app/Gemfile` (then `bundle lock` again), pin the API contract's `vX.Y.Z` commit in
   `.github/workflows/ci.yml` and `.github/workflows/release.yml`, update the compatibility table
   in `README.md`, and check it all with `./scripts/check-release-versions.sh X.Y.Z` (it needs Ruby
   and network access to list the contract's tags).
2. Open a PR, wait for CI to pass, and merge it into `main`.
3. Tag the merge commit and push the tag:

   ```sh
   git checkout main && git pull
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

4. Watch the `release` workflow run. When `verify` and `gates` pass, approve the `publish` job
   (Review deployments → `rubygems-release` → Approve).
5. Check the gem at <https://rubygems.org/gems/poli_page-rails> and the GitHub Release for the tag.

If `verify` fails, the tag does not match the version, the CHANGELOG or the example app's
lockfile, or its major.minor is not the pinned contract's or the required SDK's: delete the tag
(`git push origin :refs/tags/vX.Y.Z && git tag -d vX.Y.Z`), fix `main` through a PR, and tag
again. A version that reached RubyGems cannot be published again; release a new patch
version instead.

If `publish` fails before the push reached RubyGems, re-run the failed job once the cause is
fixed outside the repository (an expired pending trusted publisher, an unapproved deployment). If
the fix is a change to the repository, such as the workflow itself, a re-run replays the tagged
commit's workflow: delete the tag as above, merge the fix into `main`, and tag the new merge
commit with the same version.
