# Changelog

All notable changes to `poli_page-rails` are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Breaking:** requires the `poli-page` SDK release without template
  versions (after 0.9.1). Render calls take no `version:`: a key belongs to
  one environment (`pp_{environment}_{32 lowercase hex}`, for example
  `pp_sandbox_…`, `pp_live_…`, `pp_staging_…`), and the key alone selects the
  environment and so the published copy that renders. Until that release is
  on RubyGems, the `Gemfile` and `example-app/Gemfile` pin `sdk-ruby` main by
  git ref instead of a sibling `path:` checkout.
- `ConfigurationValidator` accepts any environment key. It raises
  `ConfigurationError` only for a missing or empty `api_key`; a value that does
  not match `pp_{environment}_{32 lowercase hex}` logs one warning through
  `config.logger` that names the expected format and shows no part of the
  key, not even its `pp_{environment}_` prefix, and the client starts anyway,
  leaving the verdict to the API.
  `API_KEY_PATTERN` is replaced by `API_KEY_FORMAT`.
- `render_preview` now documents `DocumentPreviewResult` (`documents.preview`)
  only.
- Example app: `GET /api/errors/bad-version` (`INVALID_VERSION_FORMAT`) is
  replaced by `GET /api/errors/not-found`, which renders the template
  `does-not-exist` and answers `404 TEMPLATE_NOT_FOUND` with the error's code,
  status, message and request id. `GET /api/documents/:id/preview` now goes
  through `render_preview`.
- The integration spec runs only with a `pp_sandbox_` key.

### Removed

- Example app: `GET /api/render/preview` (`render.preview`) and its "HTML
  preview" button; the SDK no longer has `render.preview`.

### Fixed

- `render_pdf` / `FilenameEncoder.disposition`: control characters (CR/LF, TAB,
  DEL, C1) are now stripped from the `Content-Disposition` filename before
  `ActionDispatch::Http::ContentDisposition` formats it, instead of surviving as
  `%0D%0A`-style escapes that clients decode back into the saved filename.
- Example app: the demo page's status row no longer shows the first 8
  characters of `POLI_PAGE_API_KEY`; no part of the key is shown.

## [0.1.0] — 2026-05-27

### Added

- Initial release. Rails engine + Railtie wrapping the official `poli-page`
  Ruby SDK.
- `PoliPage.client` — lazy memoised class-level accessor (Monitor-guarded;
  shared across threads per the SDK's thread-safety guarantee).
  `PoliPage.reset_client!` clears the memo (test-only).
- `Rails.application.config.poli_page` — `Configuration` object exposing every
  SDK kwarg as an `attr_accessor` plus a `notifications` opt-out switch.
  `to_client_kwargs.compact` lets the SDK's own defaults apply for `nil` keys.
- `PoliPage::Rails::ConfigurationValidator` — validates `api_key`
  (`pp_test_` / `pp_live_` prefix), `base_url` (http/https), `timeout`
  (1..600), `max_retries` (0..10), `retry_delay` (0..30), `notifications`
  (boolean), and `on_retry` / `on_error` (callable). Runs lazily on first
  `PoliPage.client` call — keeps `assets:precompile` and `db:create` working
  in containers without secrets at boot.
- `PoliPage::Rails::Renderable` — controller concern providing `render_pdf`,
  `render_preview`, `redirect_to_document`. Sets `Cache-Control: private,
  no-store`, `X-Content-Type-Options: nosniff`, and an RFC 5987 / RFC 6266
  `Content-Disposition` that handles ASCII + non-ASCII filenames (`résumé.pdf`,
  `発票.pdf`, `🦀.pdf`).
- `PoliPage::Rails::FilenameEncoder` — thin wrapper over
  `ActionDispatch::Http::ContentDisposition.format`; single seam if Rails
  changes the formatting API across versions.
- `ActiveSupport::Notifications` bridge for the SDK's retry/error hooks
  (`poli_page.retry`, `poli_page.error`). **Default-on**, opt-out via
  `c.notifications = false`. Zero overhead with no subscribers.
- `rails generate poli_page:install` — writes
  `config/initializers/poli_page.rb` with a commented template documenting
  every configuration key. Zero custom options to avoid Thor-reserved-name
  shadowing (`--force`, `--skip`, `--pretend`, `--quiet`, etc.).
- Example Rails 8 app at [`example-app/`](./example-app) with an interactive
  single-page demo UI covering every SDK method (`render.pdf`,
  `render.pdf_stream`, `render.preview`, `render.document`, `documents.get`,
  `documents.thumbnails`, `documents.preview`, `documents.delete`, a
  deliberate `ValidationError` trigger, and a `bin/rake demo:render_to_file`
  task for `render_to_file`).
- RBS signatures in `sig/` mirroring the public API surface.

[Unreleased]: https://github.com/poli-page/rails/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/poli-page/rails/releases/tag/v0.1.0
