# poli_page-rails

[![Gem](https://img.shields.io/gem/v/poli_page-rails?style=flat&logo=ruby&logoColor=ffffff&label=Gem)](https://rubygems.org/gems/poli_page-rails)
[![Downloads](https://img.shields.io/gem/dt/poli_page-rails?style=flat&logo=ruby&logoColor=ffffff&label=Downloads)](https://rubygems.org/gems/poli_page-rails)
[![Ci](https://img.shields.io/github/actions/workflow/status/poli-page/rubyonrails/ci.yml?branch=main&style=flat&logo=githubactions&logoColor=ffffff&label=Ci)](https://github.com/poli-page/rubyonrails/actions/workflows/ci.yml)
[![Codeql](https://img.shields.io/github/actions/workflow/status/poli-page/rubyonrails/codeql.yml?branch=main&style=flat&logo=github&logoColor=ffffff&label=Codeql)](https://github.com/poli-page/rubyonrails/actions/workflows/codeql.yml)
[![Coverage](https://img.shields.io/codecov/c/github/poli-page/rubyonrails?style=flat&logo=codecov&logoColor=ffffff&label=Coverage)](https://codecov.io/gh/poli-page/rubyonrails)
[![Ruby](https://img.shields.io/badge/Ruby-3.2%20%7C%203.3%20%7C%203.4-blue?style=flat&logo=ruby&logoColor=ffffff)](https://github.com/poli-page/rubyonrails/blob/main/.github/workflows/ci.yml)
[![Rails](https://img.shields.io/badge/Rails-7.0%20%7C%207.1%20%7C%207.2%20%7C%208.0-blue?style=flat&logo=rubyonrails&logoColor=ffffff)](https://rubyonrails.org/)
[![Types](https://img.shields.io/badge/Types-RBS-blue?style=flat&logo=ruby&logoColor=ffffff)](https://github.com/poli-page/rubyonrails/tree/main/sig)
[![Style](https://img.shields.io/badge/Style-Rubocop-blue?style=flat&logo=ruby&logoColor=ffffff)](https://github.com/rubocop/rubocop)
[![Deps](https://img.shields.io/badge/Deps-up%20to%20date-brightgreen?style=flat&logo=ruby&logoColor=ffffff)](https://github.com/poli-page/rubyonrails/network/dependencies)
[![Docs](https://img.shields.io/badge/Docs-online-brightgreen?style=flat&logo=readthedocs&logoColor=ffffff)](https://poli-page.github.io/rubyonrails/)
[![License](https://img.shields.io/github/license/poli-page/rubyonrails?style=flat&logo=gnu&logoColor=ffffff&label=License)](LICENSE)

> Render Poli Page documents from Rails controllers.

→ **Documentation**: https://poli-page.github.io/rubyonrails/

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
- `poli-page` SDK 0.13.x (`~> 0.13.0`); Bundler installs it with the gem

## Install

Add the gem to your `Gemfile`:

```ruby
# Gemfile
gem "poli_page-rails", "~> 0.13.0"
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
| `error_handler` | `true` | Set to `false` to leave out the default error handler (see [Default error handler](#default-error-handler)). |

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
| `PoliPage::Rails::ErrorHandler` | Controller concern that answers a `PoliPage::Error` with JSON; included by default. |
| `PoliPage::Rails::Railtie` | Installs the configuration, the logger default, the notifications bridge, and the error handler. |
| `"poli_page.retry"` | `ActiveSupport::Notifications` event fired before each SDK retry. |
| `"poli_page.error"` | `ActiveSupport::Notifications` event fired on terminal SDK failure. |
| `rails generate poli_page:install` | Writes `config/initializers/poli_page.rb`. |

Full reference: [API reference](https://poli-page.github.io/rubyonrails/reference/api/).

## Errors

The SDK raises a fixed hierarchy under `PoliPage::Error`. The four categories you typically branch on:

- **Auth** — `PoliPage::AuthenticationError`, `PoliPage::PermissionDeniedError`. Bad or revoked key, blocked organization.
- **Rate limit** — `PoliPage::RateLimitError`. The API returned `429`; honour `Retry-After`.
- **Request rejected** — `PoliPage::ValidationError`. The template, project, or `data` payload was rejected at `400`.
- **Network / transport** — `PoliPage::ConnectionError`, `PoliPage::TimeoutError`. Network failure, DNS, TLS, or timeout.

Two more come from outside the API: `PoliPage::InvalidResponseError` (`invalid_response`) when a 2xx answer's body is not JSON, usually from a proxy between your app and the API, and `PoliPage::FileWriteError` (`io_error`) when `render_to_file` cannot write its file.

A `PoliPage::Error` you do not rescue reaches the [default error handler](#default-error-handler).

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

### Default error handler

The gem answers every `PoliPage::Error` a controller action raises without rescuing it. The Railtie includes `PoliPage::Rails::ErrorHandler` into `ActionController::Base` and `ActionController::API`, which `rescue_from PoliPage::Error` and render the SDK's `Error#to_payload` as JSON, as is:

```json
{ "code": "TEMPLATE_NOT_FOUND", "message": "Template 'does-not-exist' not found in project 'getting-started'.", "status": 404, "requestId": "req_…" }
```

- The HTTP status is the payload's `status`: the API's status for an API error, `503` for `network_error`, `504` for `timeout`, `502` for `invalid_response` (the 2xx a proxy sent never reaches your client). When the status is unknown (for example `configuration_error` or `io_error`), the answer is `500` and the body's `status` is `null`.
- `requestId` is the API's `x-request-id`, or `null` when there is none.
- The `Content-Type` is `application/json`, even when the action had set another one (a PDF route, say) before the error.
- The keys are the SDK's, spelled the same by every Poli Page SDK: your app's inflections (an `ID` acronym, for example) do not change them.

The handler cannot answer once a response is committed: an `ActionController::Live` stream is committed when it writes its first chunk or when it is closed. The handler then raises the error again, so Live logs it and calls the stream's `on_error`. After PDF bytes went out, the client gets a short `200` (the PDF cut where the error happened); compare the bytes received with the descriptor's `sizeBytes` if you need to detect it.

So that an error before the first byte still gets the JSON answer, in a Live action:

- set the PDF headers and write the first chunk only after the SDK call has started;
- close the stream only once you have written to it (`ensure response.stream.close if started`). The usual unconditional `ensure response.stream.close` commits an empty `200` before the handler runs, and the error then ends as that empty `200`.

The example app's `StreamsController` does both.

A `rescue_from` in your own controllers (for `PoliPage::Error`, one of its subclasses, or `StandardError`) takes precedence, as usual in Rails. To leave the handler out entirely:

```ruby
# config/initializers/poli_page.rb
Rails.application.config.poli_page.tap do |c|
  c.error_handler = false
end
```

The value must be `true` or `false`; the app refuses to boot with anything else.

## Example app

A runnable Rails 8 app lives in [`example-app/`](./example-app). It exercises every public SDK method behind a single-page UI and ships a `bin/rake demo:render_to_file` task for the `render_to_file` SDK path. It renders the `welcome` template of the `getting-started` project, which every organization has in its `sandbox` environment. Its routes follow the Poli Page demo contract: `GET /render/pdf` answers the PDF, `GET /documents/:id` redirects (`302`) to the document's presigned PDF URL, and `GET /errors/not-found` renders the template `does-not-exist`, so the default error handler answers `404` with the `TEMPLATE_NOT_FOUND` error's code, message, status and request id. If your organization renamed or removed `getting-started` from `sandbox`, the renders answer `404 PROJECT_NOT_FOUND` or `PROJECT_NOT_IN_ENVIRONMENT`: use a fresh organization.

```ruby
# shell
cd example-app
bundle install
export POLI_PAGE_API_KEY=pp_sandbox_...           # a sandbox key
# export POLI_PAGE_BASE_URL=https://api.poli.page  # optional
bin/rails server
```

## Going further

- ActiveSupport::Notifications — subscribe to `poli_page.retry` and `poli_page.error` for logging, metrics, and alerting ([Observability](https://poli-page.github.io/rubyonrails/production/observability/)).
- Filename encoding — how `PoliPage::Rails::FilenameEncoder` produces RFC 5987 `Content-Disposition` values for non-ASCII names ([Responses](https://poli-page.github.io/rubyonrails/concepts/responses/)).
- Background rendering — running renders through Active Job for slow templates ([Client access](https://poli-page.github.io/rubyonrails/concepts/client-access/) has a job example).
- Testing helpers — stubbing `PoliPage.client` in request specs and system tests ([Testing](https://poli-page.github.io/rubyonrails/production/testing/)).

## Compatibility

| Gem | `poli-page` SDK | Rails | Ruby |
|---|---|---|---|
| 0.13.x | 0.13.x | 7.0 / 7.1 / 7.2 / 8.0 | 3.2 – 3.4 |

The gem shares its major.minor with the Poli Page API and requires the SDK of the same minor (see [RELEASING.md](RELEASING.md#versions)).

You receive fixes for the latest two Rails majors. Older majors receive security fixes for six months after their upstream EOL.

## Contributing

Run the lint and the specs for one Rails version with Appraisal:

```sh
bundle install
bundle exec appraisal generate
BUNDLE_GEMFILE=gemfiles/rails_8.0.gemfile bundle install
bundle exec rubocop
bundle exec appraisal rails-8.0 rspec --exclude-pattern "spec/integration/**/*"
```

`spec/integration` renders against a real API and runs only with `POLI_PAGE_API_KEY` set to a `pp_sandbox_` key. It targets the SDK's default API, or the one in `POLI_PAGE_BASE_URL` when that is set. The live API CI job reads both from repository secrets: `POLI_PAGE_API_KEY` (a `pp_sandbox_` key) and the optional `POLI_PAGE_BASE_URL`.

### Contract tests

`spec/contract/impl_contract_spec.rb` runs the integration cases of the [Poli Page API contract](https://github.com/poli-page/api-contract) against the example app's controllers, routes and initializer, with the SDK pointed at a local mock server. CI runs them on every Ruby and Rails version of the matrix, against the contract version pinned in `.github/workflows/ci.yml`. Locally, download a `contract.json` and run:

```sh
POLI_CONTRACT=<path to contract.json> bundle exec rspec spec/contract
```

Without `POLI_CONTRACT` the cases are pending (and fail when `CI` is set). Cases allowed to fail are listed with a reason in `spec/contract-skip.json`.

### Releasing

Releases are published by pushing a `vX.Y.Z` tag; see [RELEASING.md](RELEASING.md).

## License

Released under the MIT License — see [LICENSE](LICENSE).
