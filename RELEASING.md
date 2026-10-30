# Releasing

`poli_page-rails` is published to [RubyGems](https://rubygems.org/gems/poli_page-rails) by
`.github/workflows/release.yml` when a `vX.Y.Z` tag is pushed. The workflow uses RubyGems Trusted
Publishing (OIDC), so no API key is stored in the repository or in GitHub secrets.

What the workflow does on a tag push:

1. **verify**: fails unless the tag (without its `v`) equals `PoliPage::Rails::VERSION` in
   `lib/poli_page/rails/version.rb` and `CHANGELOG.md` has a `## [X.Y.Z]` section.
2. **gates**: the CI suite on every supported Ruby (3.2, 3.3, 3.4) and Rails (7.0, 7.1, 7.2, 8.0):
   RuboCop, then every spec except the live API one (`spec/integration`), including the API
   contract's cases with the contract pinned by `poli-page/api-contract`.
3. **publish**, in the `rubygems-release` GitHub Environment (waits for a required reviewer):
   `rubygems/release-gem` builds the gem from the gemspec and pushes it through Trusted Publishing,
   then the job creates the GitHub Release with the CHANGELOG section as notes and the `.gem`
   attached.

The gem contains `lib/`, `sig/`, `LICENSE`, `README.md` and `CHANGELOG.md` only (see `spec.files` in
`poli_page-rails.gemspec`). The example app and the specs are not shipped.

## One-time setup (before the first release)

The gem name `poli_page-rails` is not taken on RubyGems
(`curl -s https://rubygems.org/api/v1/gems/poli_page-rails.json` answers `This rubygem could not be
found.`), so the first publish creates it. A gem that does not exist yet gets a **pending** trusted
publisher.

1. Sign in to rubygems.org with the account that will own the gem (the one that owns `poli-page`).
   Multi-factor authentication must be on: the gemspec sets `rubygems_mfa_required`.
2. Open <https://rubygems.org/profile/oidc/pending_trusted_publishers>, choose **Create**, and fill
   in:
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

After the first publish, the pending publisher becomes a regular trusted publisher of the gem.
Add co-owners with `gem owner poli_page-rails --add <email>` if needed.

## Per release

1. On a branch off `main`, set the new version in `lib/poli_page/rails/version.rb`, move the
   `[Unreleased]` entries of `CHANGELOG.md` into a `## [X.Y.Z] - YYYY-MM-DD` section, leave an empty
   `## [Unreleased]` above it, and update the compare links at the bottom. Update the
   `poli_page-rails (X.Y.Z)` line of `example-app/Gemfile.lock` (`cd example-app && bundle lock`).
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

If `verify` fails, the tag does not match the version or the CHANGELOG has no section for it:
delete the tag (`git push origin :refs/tags/vX.Y.Z && git tag -d vX.Y.Z`), fix `main` through a PR,
and tag again. A version that reached RubyGems cannot be published again; release a new patch
version instead.
