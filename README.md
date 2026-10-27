# poli_page-rails

> Render Poli Page documents from Rails controllers.

## About

This gem wires the official [`poli-page`](https://rubygems.org/gems/poli-page) Ruby SDK into a Rails app as an Engine. A Railtie installs a `Configuration` object on `Rails.application.config.poli_page`, `PoliPage.client` returns a lazy-memoised SDK client, and a `Renderable` controller concern turns SDK responses into PDF, HTML, or 302 responses with RFC 5987 `Content-Disposition` headers. Retry and terminal-error hooks on the SDK bridge into `ActiveSupport::Notifications` so subscribers like `lograge`, `appsignal`, or `scout_apm` pick them up without extra wiring.

**When to use this:**

- You render PDFs or HTML previews from a Rails controller and want `send_data`-shaped helpers that already set the right cache and content-disposition headers.
- You want SDK retry and error events on the standard `ActiveSupport::Notifications` bus.
- You want a generator that writes a fully commented `config/initializers/poli_page.rb`.

**When not to:**

- You are outside Rails — use the [`poli-page`](https://rubygems.org/gems/poli-page) SDK directly.
- You need to reimplement HTTP transport, retry policy, idempotency, or error mapping. Those live in the SDK; this gem deliberately does not duplicate them.

## Requirements

- Ruby 3.2 or newer
- Rails 7.0, 7.1, 7.2, or 8.0
- `poli-page` SDK: the release without template versions (after 0.9.1; until it is on RubyGems, this repo's `Gemfile` pins `sdk-ruby` main)

## Install

Add the gem to your `Gemfile`:

```ruby
# Gemfile
gem "poli_page-rails"
```

Then run:

```ruby
# shell
bundle install
bin/rails generate poli_page:install
```

The generator writes `config/initializers/poli_page.rb` with a commented template. Set `POLI_PAGE_API_KEY` in your environment, then restart the app.

### API keys

A key belongs to exactly one environment of your organization and reads `pp_{environment}_{32 lowercase hex}`. The key alone selects the environment, and so the published copy of each project that renders.

| Environment                           | Key            | Watermark | Counted |
| ------------------------------------- | -------------- | --------- | ------- |
| `sandbox` (every org)                 | `pp_sandbox_…` | yes       | no      |
| `live` (every org, deletable on Pro+) | `pp_live_…`    | no        | yes     |
| created on Pro+ (e.g. `staging`)      | `pp_staging_…` | no        | yes     |

"Counted" means the render counts toward the organization's monthly PDF quota.

The API is the only authority on keys. The gem raises `ConfigurationError` only when `api_key` is missing or empty. A value that does not match `pp_{environment}_{32 lowercase hex}` logs one warning through `config.logger` that names the expected format and shows no part of the key, then the client starts anyway and the API answers `401` if the key is wrong (`INVALID_API_KEY`, or `MISSING_API_KEY` for a value without `pp_`).

## Quick start

Return a generated PDF from any controller action.

```ruby
# app/controllers/invoices_controller.rb
class InvoicesController < ApplicationController
  include PoliPage::Rails::Renderable

  def show
    invoice = Invoice.find(params[:id])
    bytes = PoliPage.client.render.pdf(
      project:  "billing",
      template: "invoice",
      data:     invoice.to_template_data
    )
    render_pdf(bytes, filename: "#{invoice.number}.pdf", inline: false)
  end
end
```

`render_pdf` sets `Content-Type: application/pdf`, `Cache-Control: private, no-store`, `X-Content-Type-Options: nosniff`, and an RFC 5987 / RFC 6266 `Content-Disposition` that round-trips non-ASCII filenames.

## Configuration

Every key is optional except `api_key`. The SDK's own defaults apply when a value is left `nil`.

| Option | Default | Description |
|---|---|---|
| `api_key` | — | Required. A key for one environment: `pp_sandbox_…`, `pp_live_…`, or `pp_{environment}_…` (see [API keys](#api-keys)). |
| `base_url` | `https://api.poli.page` | Override for the develop environment or a private proxy. |
| `timeout` | SDK default | Request timeout in seconds. Must be in `1..600`. |
| `max_retries` | SDK default | Retry attempts on retryable failures. Must be in `0..10`. |
| `retry_delay` | SDK default | Base backoff delay in seconds. Must be in `0..30`. |
| `logger` | `Rails.logger` | Any `Logger`-compatible instance. |
| `proxy` | `nil` | HTTP proxy URL. Honoured by `Net::HTTP` via the SDK. |
| `ca_file` | `nil` | Path to a CA bundle for corporate egress. |
| `ca_path` | `nil` | Path to a CA directory. |
| `notifications` | `true` | Set to `false` to disable the `ActiveSupport::Notifications` bridge. |
| `on_retry` | bridge | Custom callable. Setting it replaces the notifications bridge. |
| `on_error` | bridge | Custom callable. Setting it replaces the notifications bridge. |

A minimal initializer:

```ruby
# config/initializers/poli_page.rb
Rails.application.config.poli_page.tap do |c|
  c.api_key = ENV.fetch("POLI_PAGE_API_KEY")
end
```

Configuration is validated lazily on the first `PoliPage.client` call, so `assets:precompile` and `db:create` keep working in containers that have no secrets at boot.

## API at a glance

| Symbol | Purpose |
|---|---|
| `PoliPage.client` | Lazy-memoised, thread-safe SDK `PoliPage::Client`. |
| `PoliPage::Rails::Renderable` | Controller concern exposing `render_pdf`, `render_preview`, `redirect_to_document`. |
| `PoliPage::Rails::Configuration` | The object behind `Rails.application.config.poli_page`. |
| `PoliPage::Rails::Engine` | Rails engine subclass auto-loaded from your `Gemfile`. |
| `PoliPage::Rails::Railtie` | Installs the configuration, the logger default, and the notifications bridge. |
| `"poli_page.retry"` | `ActiveSupport::Notifications` event fired before each SDK retry. |
| `"poli_page.error"` | `ActiveSupport::Notifications` event fired on terminal SDK failure. |
| `rails generate poli_page:install` | Writes `config/initializers/poli_page.rb`. |

Full reference: [docs/api.md](docs/api.md) (forthcoming).

## Errors

The SDK raises a fixed hierarchy under `PoliPage::Error`. The four categories you typically branch on:

- **Auth** — `PoliPage::AuthenticationError`, `PoliPage::PermissionDeniedError`. Bad or revoked key, blocked organization.
- **Rate limit** — `PoliPage::RateLimitError`. The API returned `429`; honour `Retry-After`.
- **Request rejected** — `PoliPage::ValidationError`. The template, project, or `data` payload was rejected at `400`.
- **Network / transport** — `PoliPage::ConnectionError`, `PoliPage::TimeoutError`. Network failure, DNS, TLS, or timeout.

This gem adds one Rails-specific error: `PoliPage::Rails::ConfigurationError`, raised by `ConfigurationValidator` on the first `PoliPage.client` call when the initializer is invalid. It inherits from `PoliPage::Error`, so a single `rescue PoliPage::Error` catches everything.

```ruby
# app/controllers/invoices_controller.rb
def show
  bytes = PoliPage.client.render.pdf(project: "billing", template: "invoice", data: invoice_data)
  render_pdf(bytes, filename: "invoice.pdf")
rescue PoliPage::ValidationError => e
  Rails.logger.warn("PoliPage validation failed: #{e.message}")
  head :unprocessable_entity
rescue PoliPage::RateLimitError
  head :too_many_requests
rescue PoliPage::AuthenticationError, PoliPage::PermissionDeniedError
  head :forbidden
rescue PoliPage::ConnectionError, PoliPage::TimeoutError
  head :bad_gateway
end
```

## Example app

A runnable Rails 8 app lives in [`example-app/`](./example-app). It exercises every public SDK method behind a single-page UI and ships a `bin/rake demo:render_to_file` task for the `render_to_file` SDK path. It renders the `welcome` template of the `getting-started` project, which every organization has in its `sandbox` environment, and `GET /api/errors/not-found` renders the template `does-not-exist` to show the `404 TEMPLATE_NOT_FOUND` error's code, status, message, and request id.

```ruby
# shell
cd example-app
bundle install
export POLI_PAGE_API_KEY=pp_sandbox_...           # a sandbox key
# export POLI_PAGE_BASE_URL=https://api.poli.page  # optional
bin/rails server
```

## Going further

- ActiveSupport::Notifications — subscribe to `poli_page.retry` and `poli_page.error` for logging, metrics, and alerting (forthcoming `docs/notifications.md`).
- Filename encoding — how `PoliPage::Rails::FilenameEncoder` produces RFC 5987 `Content-Disposition` values for non-ASCII names (forthcoming `docs/filenames.md`).
- Background rendering — running renders through Active Job for slow templates (forthcoming `docs/active_job.md`).
- Testing helpers — stubbing `PoliPage.client` in request specs and system tests (forthcoming `docs/testing.md`).
- Engine specification — the full design spec for v0.1.0 at [`docs/spec/rails-engine-specification.md`](docs/spec/rails-engine-specification.md).

## Compatibility

| Gem | Rails | Ruby |
|---|---|---|
| 0.1.x | 7.0 / 7.1 / 7.2 / 8.0 | 3.2 – 3.4 |

You receive fixes for the latest two Rails majors. Older majors receive security fixes for six months after their upstream EOL.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Released under the MIT License — see [LICENSE](LICENSE).
