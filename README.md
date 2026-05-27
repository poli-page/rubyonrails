# poli_page-rails

[![CI](https://github.com/poli-page/rails/actions/workflows/ci.yml/badge.svg)](https://github.com/poli-page/rails/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/poli_page-rails.svg)](https://rubygems.org/gems/poli_page-rails)

Rails engine for the [Poli Page](https://poli.page) PDF rendering API. Thin
wrapper over the official [`poli-page`](https://rubygems.org/gems/poli-page)
Ruby SDK with idiomatic Rails wiring: lazy-memoised client, controller concern
for PDF/HTML responses with RFC 5987 `Content-Disposition`, install generator,
and an `ActiveSupport::Notifications` bridge for the SDK's retry / error hooks.

- **Rails**: 7.0, 7.1, 7.2, 8.0
- **Ruby**: 3.2+
- **SDK**: `poli-page ~> 1.0` (the gem is a wrapper, not a reimplementation)

## Install

```ruby
# Gemfile
gem "poli_page-rails"
```

```bash
bundle install
bin/rails generate poli_page:install
```

That writes `config/initializers/poli_page.rb` with a commented template.
Set `POLI_PAGE_API_KEY` in your environment, then restart the app.

## Render a PDF from a controller

```ruby
class InvoicesController < ApplicationController
  include PoliPage::Rails::Renderable

  def show
    invoice = Invoice.find(params[:id])
    bytes = PoliPage.client.render.pdf(
      project:  "billing",
      template: "invoice",
      version:  "2.1.0",
      data:     invoice.to_template_data
    )
    render_pdf(bytes, filename: "#{invoice.number}.pdf", inline: false)
  end
end
```

`render_pdf` sets `Content-Type: application/pdf`, `Cache-Control: private,
no-store`, `X-Content-Type-Options: nosniff`, and an RFC 5987 / RFC 6266
`Content-Disposition` that round-trips non-ASCII filenames correctly (`résumé.pdf`,
`発票.pdf`, `🦀.pdf`, …).

Two more helpers ship in the same concern:

```ruby
# HTML preview (no PDF round-trip)
def preview
  result = PoliPage.client.render.preview(project: "billing", template: "invoice",
                                          version: "2.1.0", data: invoice_data)
  render_preview(result)
end

# 302 to a presigned URL for a previously-stored document
def download
  descriptor = PoliPage.client.documents.get(params[:id])
  redirect_to_document(descriptor)
end
```

## Configuration

Every key is optional except `api_key`. SDK defaults apply when a value is `nil`.

```ruby
# config/initializers/poli_page.rb
Rails.application.config.poli_page.tap do |c|
  c.api_key      = ENV.fetch("POLI_PAGE_API_KEY")
  c.base_url     = ENV["POLI_PAGE_BASE_URL"]            # default: https://api.poli.page
  c.timeout      = 30.0                                  # seconds, 1..600
  c.max_retries  = 3                                     # 0..10
  c.retry_delay  = 0.5                                   # seconds, 0..30
  c.logger       = Rails.logger                          # default
  c.proxy        = ENV["POLI_PAGE_HTTP_PROXY"]
  c.ca_file      = ENV["POLI_PAGE_CA_FILE"]
  c.ca_path      = ENV["POLI_PAGE_CA_PATH"]
  c.notifications = true                                 # default: opt-out
  c.on_retry     = ->(event) { Rails.logger.info("PoliPage retry: #{event.attempt}") }
  c.on_error     = ->(err)   { Sentry.capture_exception(err) }
end
```

Setting `on_retry` / `on_error` **replaces** the default
`ActiveSupport::Notifications` bridge. To layer custom behaviour on top of
the bridge, subscribe instead (next section).

## Notifications

By default, every SDK retry fires `ActiveSupport::Notifications.instrument
"poli_page.retry"`, and every terminal error fires `"poli_page.error"`. Zero
overhead when nothing subscribes, so subscribers like `lograge`, `appsignal`,
or `scout_apm` just work without further config.

```ruby
ActiveSupport::Notifications.subscribe("poli_page.retry") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.warn("PoliPage retry attempt=#{event.payload[:attempt]} " \
                    "delay=#{event.payload[:delay]} reason=#{event.payload[:reason].class}")
end

ActiveSupport::Notifications.subscribe("poli_page.error") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Sentry.capture_exception(event.payload[:error])
end
```

Opt out entirely with `c.notifications = false`.

## Example app

A runnable Rails 8 app lives in [`example-app/`](./example-app) with an
interactive single-page UI hitting every public SDK method:

```bash
cd example-app
bundle install
bin/rails server
open http://localhost:3000
```

## What this gem deliberately does *not* do

- It does **not** reimplement HTTP transport, retries, error mapping, or
  `Idempotency-Key` generation. Those live in the SDK.
- It does **not** ship a Rake task for rendering — the example app's
  `bin/rake demo:render_to_file` shows the pattern; copy it into your own
  `lib/tasks/` if useful.
- It does **not** expose `Engine.config.poli_page` (that's just an artefact
  of how `isolate_namespace` works). The user-facing namespace is
  `Rails.application.config.poli_page`.

## Development

```bash
bundle install
bundle exec rspec                            # unit specs
bundle exec rspec spec/integration           # integration spec (needs POLI_PAGE_API_KEY)
bundle exec rubocop
bundle exec appraisal install                # set up the Rails matrix
bundle exec appraisal rails-8.0 rspec        # one matrix cell
```

The full design spec is in [`docs/spec/rails-engine-specification.md`](docs/spec/rails-engine-specification.md);
the implementation plan and the per-task commits are at
[`docs/plan/2026-05-27-implementation.md`](docs/plan/2026-05-27-implementation.md).

## License

MIT — see [LICENSE](LICENSE).
