# `poli_page-rails` — Specification

> Self-contained specification for **v0.1.0** of the Poli Page Rails engine + gem. A new agent should be able to read this document end-to-end and implement the gem without consulting external chat history.

**Status**: approved design, ready to implement.
**Roadmap slot**: new — closes the Rails gap that `INTEGRATIONS_PLAN.md` did not originally include (the Ruby SDK landed after that plan was written). Sits alongside `symfony-bundle` / `laravel` as a "strong yes" framework integration.
**Last updated**: 2026-05-27.

---

## 1. What this gem is, and what it isn't

**Is**: a thin Rails engine + gem that wraps the official Poli Page Ruby SDK (`poli-page`, source at `/Users/mickael/Projects/sdk-ruby/`) so that a Rails application can `bundle add poli_page-rails`, set one env var, and use the configured `PoliPage::Client` from any controller / job / mailer / rake task via the `PoliPage.client` lazy accessor or the `PoliPage::Rails::Renderable` controller concern. Also ships an install generator for the initializer template, RFC 5987-compliant response helpers for PDF / HTML preview / document redirect, and an `ActiveSupport::Notifications` bridge for the SDK's retry/error hooks.

**Is not**:
- A reimplementation of HTTP, retries, error mapping, idempotency keys, or `Net::HTTP` plumbing — that all lives in the SDK and is exhaustively tested there. The gem's job is **wiring, not behaviour**.
- A "kitchen sink" engine. ActiveJob job wrappers, Action Mailer `attach_pdf` helpers, Turbo Frame partials, ActionCable channels, Sidekiq middleware, named/multi-tenant config — all deferred to v0.2 (see §17).
- A standalone Rails app — it is a mountable engine, but it does not actually mount any routes into the host. The `example-app/` is a separate Rails app for demonstration.

**Quality bar**: match what these gems deliver today: `sentry-rails`, `stripe-rails` (community) + `stripe-ruby`, `aws-sdk-rails`, `appsignal-ruby`, `pundit`, `devise` (engine shape only — Devise's scope is far larger). If our shape differs from theirs, we have a reason.

---

## 2. Required reading (concrete file paths)

Before writing code, read:

| File | Why |
|---|---|
| `/Users/mickael/Projects/sdk-ruby/lib/poli_page/client.rb` | The client class we are wiring. Note the `#initialize` keyword arguments (§7.2 below). |
| `/Users/mickael/Projects/sdk-ruby/lib/poli_page/render.rb` | The `client.render` namespace: `pdf`, `pdf_stream`, `document`, `preview`. |
| `/Users/mickael/Projects/sdk-ruby/lib/poli_page/documents.rb` | The `client.documents` namespace: `get`, `preview`, `thumbnails`, `delete`. |
| `/Users/mickael/Projects/sdk-ruby/lib/poli_page/retry_event.rb` | `Data.define(:attempt, :delay, :reason)`. Payload the `on_retry` hook receives. |
| `/Users/mickael/Projects/sdk-ruby/lib/poli_page/errors.rb` | Error hierarchy. `PoliPage::Error < StandardError`, then `ValidationError`, `AuthenticationError`, `PermissionDeniedError`, `NotFoundError`, `GoneError`, `RateLimitError`, `APIError`, `ConnectionError`, `TimeoutError`, `DownloadError`, `InvalidOptionsError`, `InternalError`. The gem does not catch or remap these — they propagate. |
| `/Users/mickael/Projects/sdk-ruby/lib/poli_page/models/document_descriptor.rb` | `Data.define(...)` — the descriptor `render.document` and `documents.get` return; carries `presigned_pdf_url`, `download_pdf`. |
| `/Users/mickael/Projects/sdk-ruby/lib/poli_page/models/preview_result.rb` and `document_preview_result.rb` | Preview return shapes. `Renderable#render_preview` accepts either. |
| `/Users/mickael/Projects/sdk-ruby/lib/poli_page/render_to_file.rb` | `Client#render_to_file(path, **kwargs)` — used by the example app's demo rake task. |
| `/Users/mickael/Projects/sdk-ruby/poli-page.gemspec` | SDK's gemspec — confirms gem name (`poli-page`) and constant root (`PoliPage`). Required Ruby version: `>= 3.2`. |
| `/Users/mickael/Projects/sdk-ruby/examples/demo.rb` (if present) or `sdk-ruby-plan.md` § "Examples" | The canonical 10-step demo we mirror in `example-app/`. |
| `/Users/mickael/Projects/symfony-bundle/docs/spec/bundle-specification.md` | Closest sister integration. Same SDK family, sister framework. Design parallels are explicit (this document calls out where it diverges). |
| `/Users/mickael/Projects/laravel/docs/spec/laravel-package-specification.md` | Second-closest sister integration. ServiceProvider parallels Railtie. |
| `/Users/mickael/Projects/nextjs/docs/spec/nextjs-implementation.md` | Cross-cutting decision log (§18 "Resolved decisions"). |
| `/Users/mickael/Projects/symfony-bundle/example-app/templates/demo.html` | The interactive single-page demo UI we replicate (§14.3). |
| `/Users/mickael/Projects/INTEGRATIONS_PLAN.md` | Cross-repo verdict and order. §"Cross-cutting DX patterns" lists 5 non-negotiable constraints applied here. |

Reference gems to compare patterns against (open on GitHub):

- `getsentry/sentry-ruby` (especially `sentry-rails/`) — closest in shape: third-party SDK + Rails engine wrapper, ships Railtie + initializer + `ActiveSupport::Notifications` bridges. **Primary reference.**
- `stripe/stripe-ruby` + community `stripe-rails` — gem shape (config block + lazy client). Demonstrates an opinionated `Stripe.api_key = ...` accessor; we differ slightly (Rails-style `config.poli_page` block).
- `aws/aws-sdk-rails` — engine that wires a vendor SDK into Rails (logger, ActiveJob queue adapter, error handler). Closest "engine wrapping a multi-resource SDK" pattern.
- `appsignal/appsignal-ruby` — `Railtie` + ActiveSupport instrumentation bridge.
- `pundit-community/pundit` and `varvet/pundit` — a small, focused Rails engine with a controller concern. Good shape reference for the `Renderable` concern.
- `rails/rails` itself — Engine docs at `railties/lib/rails/engine.rb` are the canonical reference for Railtie initializers and config namespacing.

---

## 3. Version targets

| Dimension | Constraint | Rationale |
|---|---|---|
| Ruby | `>= 3.1, < 4` | SDK requires `>= 3.2`; we relax to 3.1 only if a CI cell shows it works (Rails 7.0 supports 3.1+). If the SDK's `3.2+` floor proves brittle on 3.1, drop 3.1 from the matrix — do NOT vendor compatibility shims. **Decided: match SDK floor at 3.2 if 3.1 testing reveals issues. Default to advertising 3.2+ in the gemspec to avoid surprise.** |
| Rails | `>= 7.0, < 9` | 7.0 covers the LTS-equivalent slot (security through 2025-Q2); 7.1, 7.2, and 8.0 are the active releases. Matches `sentry-rails`'s range. |
| Bundler | `>= 2.4` | Required for `path:` repository symlink behavior used in §12. |
| RSpec | `~> 3.13` | Standard. |
| Combustion | `~> 1.5` | Engine-test app helper for RSpec — used to boot a minimal Rails app inside `spec/`. |
| Appraisal | `~> 2.5` | Multi-Rails matrix runner; gemspec hosts the SDK constraint, Appraisal gemfiles pin Rails versions. |

CI matrix: Ruby `{3.1, 3.2, 3.3, 3.4}` × Rails `{7.0, 7.1, 7.2, 8.0}` with exclusions:

- Rails `8.0` requires Ruby `>= 3.2` (exclude Ruby `3.1` × Rails `8.0`).
- Ruby `3.4` × Rails `7.0` is tested but tagged as "best-effort" — Rails 7.0 EOL is approaching.

That yields ~14 active matrix cells. See §15.

---

## 4. Architecture style

Use the **standard Rails engine + Railtie pattern**. One `PoliPage::Rails::Engine < ::Rails::Engine` class (declared in `lib/poli_page/rails/engine.rb`); one `PoliPage::Rails::Railtie < ::Rails::Railtie` class (declared in `lib/poli_page/rails/railtie.rb`); a top-level `lib/poli_page-rails.rb` that requires the engine. Bundler discovers `lib/poli_page-rails.rb` via the gemspec; the engine and Railtie register themselves on `require`.

**Why both Engine and Railtie**:

- The **Engine** establishes the gem as a mountable Rails component (gives us `PoliPage::Rails::Engine.config`, allows future routes/assets/migrations without re-architecting).
- The **Railtie** holds the boot-time hooks: `initializer "poli_page.configure"`, `config.before_configuration`, `config.after_initialize`. Railties run earlier than engine initializers and are how `sentry-rails` and `appsignal-ruby` register their hooks.

Splitting them is cheap (~10 lines each) and matches what every battle-tested Rails wrapper does. Combining into a single class works but loses the "mountable" optionality. We take the small-cost-now / no-pain-later trade.

Configuration declared **in pure Ruby**. The `Configuration` object is a plain Ruby class with `attr_accessor`s, NOT a `Struct` (we want a clear constructor with safe defaults) and NOT a `Data.define` (mutable during the `config.poli_page do |c| ... end` block in the host app's initializer, frozen thereafter).

---

## 5. File layout

```
rails/
├── lib/
│   ├── poli_page-rails.rb                       # Top-level entry; matches gem name
│   └── poli_page/
│       └── rails/
│           ├── engine.rb                        # class Engine < ::Rails::Engine
│           ├── railtie.rb                       # class Railtie < ::Rails::Railtie (initializers)
│           ├── configuration.rb                 # Configuration object (api_key, base_url, ...)
│           ├── client.rb                        # PoliPage.client lazy memoised accessor
│           ├── renderable.rb                    # ActiveSupport::Concern for controllers
│           ├── notifications.rb                 # SDK hook → AS::Notifications bridge
│           ├── filename_encoder.rb              # RFC 5987 helper for Content-Disposition
│           ├── errors.rb                        # ConfigurationError < PoliPage::Error
│           └── version.rb                       # VERSION constant
├── lib/generators/
│   └── poli_page/
│       └── install/
│           ├── install_generator.rb             # rails generate poli_page:install
│           └── templates/
│               └── poli_page.rb.tt              # Initializer template
├── sig/                                         # RBS signatures (mirrors lib/ tree)
│   └── poli_page/
│       └── rails/
│           ├── configuration.rbs
│           ├── client.rbs
│           ├── renderable.rbs
│           ├── notifications.rbs
│           └── filename_encoder.rbs
├── spec/
│   ├── spec_helper.rb                           # RSpec config + dotenv root-.env loading
│   ├── rails_helper.rb                          # combustion bootstrap of spec/internal/
│   ├── internal/                                # Minimal Rails app for engine specs
│   │   ├── app/
│   │   ├── config/
│   │   │   ├── application.rb
│   │   │   └── routes.rb
│   │   └── log/
│   ├── support/
│   │   ├── restores_global_handlers.rb          # Signal.trap + AS::Notifications snapshot
│   │   └── notifications_leak_detector.rb       # Asserts no leaked subscribers per spec
│   ├── poli_page/
│   │   └── rails/
│   │       ├── engine_spec.rb                   # Boot, config block, autoload
│   │       ├── configuration_spec.rb            # Validation rules
│   │       ├── client_spec.rb                   # Lazy memoised accessor
│   │       ├── renderable_spec.rb               # Concern: render_pdf / render_preview / redirect_to_document
│   │       ├── notifications_spec.rb            # Bridge on/off, payload shape
│   │       └── filename_encoder_spec.rb         # RFC 5987 ASCII + non-ASCII
│   ├── generators/
│   │   └── poli_page/
│   │       └── install/
│   │           └── install_generator_spec.rb    # File written, --force semantics
│   └── integration/
│       └── render_against_develop_api_spec.rb   # Gated on POLI_PAGE_API_KEY
├── example-app/                                 # See §14 — interactive UI demo
├── poli_page-rails.gemspec                      # Gemspec (gem name with hyphen, constant with double colon)
├── Gemfile                                      # Includes path: '../sdk-ruby' workaround (§12)
├── Gemfile.lock                                 # Committed (Rails convention for apps; for gems we follow sentry-rails: not committed)
├── Appraisals                                   # Rails 7.0 / 7.1 / 7.2 / 8.0 cells
├── Rakefile                                     # rake spec, rake rubocop, rake build
├── .rubocop.yml                                 # rubocop + rubocop-rails + rubocop-rspec
├── .github/workflows/ci.yml
├── README.md
├── CHANGELOG.md                                 # Keep a Changelog format
├── LICENSE                                      # MIT
└── CLAUDE.md                                    # Integration-flavored agent guide
```

**File count**: 9 source files in `lib/` + 1 generator file + 1 generator template = 11 files. That is the entire gem. Anything beyond is scope creep — refer to §17 before adding.

### 5.1 Gem name vs. constant root

- Gem name on RubyGems: `poli_page-rails` (snake_case + hyphen — Bundler convention for sub-gems like `sentry-rails`, `rspec-rails`).
- Top-level constant: `PoliPage::Rails` (nested under the SDK's `PoliPage` module).
- Top-level public accessor: `PoliPage.client` (defined inside `lib/poli_page/rails/client.rb`; re-opens the SDK's `PoliPage` module to add a class-level method).

Why `PoliPage.client` and not `PoliPage::Rails.client`: the SDK's user-facing surface is `PoliPage::Client.new`. The Rails idiom is "one lazy default" (compare `Sentry.init`, `Rails.application`, `ActiveRecord::Base.connection`). `PoliPage.client` reads as "the configured client"; `PoliPage::Rails.client` reads as "the Rails-specific client" which would be confusing since the SDK is framework-agnostic. The constant `PoliPage::Rails` still exists for the engine/configuration/concern but is not where users go to grab the client.

---

## 6. Configuration

Rails packages do not have a Symfony-style declarative config tree or a Laravel publish-to-array pattern. The idiom is `Rails.application.config.poli_page` accessible from the host app's `config/initializers/poli_page.rb`:

```ruby
# config/initializers/poli_page.rb (in host app)
Rails.application.config.poli_page.tap do |c|
  c.api_key       = ENV.fetch("POLI_PAGE_API_KEY")
  c.base_url      = ENV["POLI_PAGE_BASE_URL"]      # optional; SDK default applies
  c.timeout       = ENV.fetch("POLI_PAGE_TIMEOUT", nil)&.to_f
  c.max_retries   = ENV.fetch("POLI_PAGE_MAX_RETRIES", nil)&.to_i
  c.retry_delay   = ENV.fetch("POLI_PAGE_RETRY_DELAY", nil)&.to_f
  c.user_agent    = nil                            # SDK builds default
  c.logger        = Rails.logger                   # default; pass any Logger
  c.on_retry      = nil                            # default: AS::Notifications bridge
  c.on_error      = nil                            # default: AS::Notifications bridge
  c.proxy         = ENV["POLI_PAGE_HTTP_PROXY"]
  c.ca_file       = ENV["POLI_PAGE_CA_FILE"]
  c.ca_path       = ENV["POLI_PAGE_CA_PATH"]
  c.notifications = true                           # default: bridge SDK hooks to AS::Notifications
end
```

### 6.1 The `Configuration` object

`lib/poli_page/rails/configuration.rb`:

```ruby
module PoliPage
  module Rails
    class Configuration
      attr_accessor :api_key, :base_url, :timeout, :user_agent,
                    :max_retries, :retry_delay,
                    :logger, :on_retry, :on_error,
                    :proxy, :ca_file, :ca_path,
                    :notifications

      def initialize
        @api_key       = nil
        @base_url      = nil   # SDK default applies
        @timeout       = nil   # SDK default applies
        @user_agent    = nil   # SDK default applies
        @max_retries   = nil   # SDK default applies
        @retry_delay   = nil   # SDK default applies
        @logger        = nil   # Railtie sets to Rails.logger by default in after_initialize
        @on_retry      = nil   # Railtie installs notifications bridge by default
        @on_error      = nil   # Railtie installs notifications bridge by default
        @proxy         = nil
        @ca_file       = nil
        @ca_path       = nil
        @notifications = true
      end

      def to_client_kwargs
        # Build the kwargs hash for PoliPage::Client.new, dropping nils so the
        # SDK's own defaults apply for unset values. Single source of truth for
        # defaults stays in the SDK (sdk-ruby-plan.md §10).
        {
          api_key:     api_key,
          base_url:    base_url,
          max_retries: max_retries,
          retry_delay: retry_delay,
          timeout:     timeout,
          logger:      logger,
          on_retry:    on_retry,
          on_error:    on_error,
          proxy:       proxy,
          ca_file:     ca_file,
          ca_path:     ca_path
        }.compact
      end
    end
  end
end
```

**One-to-one mapping with the SDK `PoliPage::Client#initialize` keyword arguments** — no Rails-only invented options, no SDK options omitted, **plus** one Rails-only knob (`notifications`) controlling the `ActiveSupport::Notifications` bridge default-on/off (see §10).

**Default-value discipline**: every option except `api_key` defaults to `nil` in the `Configuration` object, and `to_client_kwargs.compact` removes nil entries before splat into `PoliPage::Client.new(...)` — the SDK's own constants (`Internal::Constants::DEFAULT_BASE_URL`, etc.) take over. Single source of truth for defaults stays in the SDK. Never duplicate a default literal across SDK and gem.

### 6.2 Validation rules (enforced on first `PoliPage.client` access, NOT at boot)

Validation happens **lazily**, the first time `PoliPage.client` is invoked. Rationale: Rails apps boot the framework before reading credentials (CI containers, `rails db:create` on a fresh deploy without `POLI_PAGE_API_KEY` set yet, asset precompile in containers). Eager validation at engine boot would make these scenarios crash. Sentry-rails takes the same approach (`Sentry.init` is lazy on first capture).

Raised exception class: `PoliPage::Rails::ConfigurationError < PoliPage::Error` (so existing `rescue PoliPage::Error` clauses catch it).

Rules — these run inside `PoliPage::Rails::Client.build!`:

- `api_key`: required, non-empty String, **must match `/\App_(test|live)_/`**. The regex catches the #1 misconfiguration: pasting a dashboard token instead of an API key. Error message: `"Poli Page api_key must start with pp_test_ or pp_live_. Get one at https://app.poli.page/settings/api-keys."`
- `base_url`: nil OR a String parsing as a URI with `http`/`https` scheme.
- `timeout`: nil OR Numeric > 0, ≤ 600.
- `max_retries`: nil OR Integer ≥ 0, ≤ 10.
- `retry_delay`: nil OR Numeric ≥ 0, ≤ 30.
- `notifications`: must be `true` or `false`.
- `on_retry`, `on_error`: nil OR object responding to `#call` (`respond_to?(:call)`). If a `String` or `Symbol` is passed, raise — we don't do `Object.const_get` indirection (that's a footgun; users pass actual callables).
- `proxy`, `ca_file`, `ca_path`, `logger`, `user_agent`: pass through unchanged to the SDK; the SDK validates.

Error messages word-for-word match the symfony-bundle and laravel package wherever possible so cross-stack docs are interchangeable.

### 6.3 Why lazy validation: boot-without-key scenarios

These scenarios MUST NOT crash at engine boot:

- `bin/rails assets:precompile` in a Docker build stage (no secrets injected).
- `bin/rails db:create db:migrate` in a fresh-database scenario (CI, first deploy).
- `bin/rails routes` / `bin/rails -T` for tooling introspection.
- IDE / LSP integration that boots the app to introspect routes.

They DO crash on first PDF render attempt. That's the right time to surface "your API key is missing" — when the developer is trying to render, not when they're running `rake -T`.

The Engine's `initializer "poli_page.configure"` block sets up the `Configuration` object and the default callable hooks; it does NOT instantiate `PoliPage::Client`. The Railtie's `config.after_initialize do` block sets `c.logger ||= Rails.logger` and installs the default notifications bridge (overridable in the user's initializer). No SDK call happens until `PoliPage.client` is first invoked.

### 6.4 Environment variable convention

`POLI_PAGE_API_KEY` is the documented env var name (same convention as symfony-bundle, laravel, nextjs). The generated `config/initializers/poli_page.rb` template pre-wires it via `ENV.fetch("POLI_PAGE_API_KEY")` (raises `KeyError` at initializer load if missing, which is fine — once the initializer is published into the host app, the developer has explicitly opted in to "fail loud at boot if missing"). Host apps add the line to whichever secrets manager they use:

```
# .env (or Rails credentials, or Kubernetes secret, etc.)
POLI_PAGE_API_KEY=pp_test_your_key_here
```

The gem itself reads no env vars directly — the host app's initializer maps `ENV` → `Rails.application.config.poli_page`. Same idiom as `Sentry.init` and `Stripe.api_key = ENV[...]`.

---

## 7. Engine, Railtie, and `PoliPage.client` accessor

### 7.1 `Engine`

`lib/poli_page/rails/engine.rb`:

```ruby
module PoliPage
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace PoliPage::Rails

      config.poli_page = Configuration.new

      # No routes, no migrations, no assets in v0.1.0. The engine exists so
      # downstream features (job classes, mailer helpers, controllers) can
      # ship as part of v0.2 without re-architecting.
    end
  end
end
```

**Why `isolate_namespace`**: makes any future engine routes / generators self-contained. Costs nothing in v0.1.0.

### 7.2 `Railtie`

`lib/poli_page/rails/railtie.rb` holds the boot-time hooks:

```ruby
module PoliPage
  module Rails
    class Railtie < ::Rails::Railtie
      # 1. Ensure config.poli_page is available the moment the host app's
      #    initializers load.
      initializer "poli_page.configure", before: :load_config_initializers do |app|
        app.config.poli_page ||= Configuration.new
      end

      # 2. After all host-app initializers ran, fill in defaults for logger
      #    and the notifications bridge — but only if the user did not set
      #    them explicitly in their initializer.
      config.after_initialize do |app|
        c = app.config.poli_page

        c.logger ||= ::Rails.logger

        if c.notifications
          c.on_retry ||= PoliPage::Rails::Notifications.retry_bridge
          c.on_error ||= PoliPage::Rails::Notifications.error_bridge
        end
      end
    end
  end
end
```

The Railtie runs early enough that `Rails.application.config.poli_page` is available when the host app's `config/initializers/poli_page.rb` evaluates. The `config.after_initialize` block runs after the user's initializer, so user-set `logger` / `on_retry` / `on_error` are preserved.

### 7.3 `PoliPage.client` lazy memoised accessor

`lib/poli_page/rails/client.rb`:

```ruby
require "monitor"

module PoliPage
  # Re-open the SDK module to add the Rails-friendly accessor. The SDK itself
  # has no top-level `client` method (the SDK is framework-agnostic).
  class << self
    def client
      Rails::Client.instance
    end

    # Test-only: reset the memoised client. Marked private API; do NOT use in
    # application code.
    def reset_client!
      Rails::Client.reset!
    end
  end

  module Rails
    # Holds the lazy memoised PoliPage::Client. Thread-safe via a Monitor
    # (re-entrant Mutex) — the same instance returns across threads, exactly
    # as the SDK documents safe (sdk-ruby/lib/poli_page/client.rb thread-safety
    # note).
    module Client
      class << self
        def instance
          @lock ||= Monitor.new
          @lock.synchronize do
            @instance ||= build!
          end
        end

        def reset!
          @lock&.synchronize do
            @instance = nil
          end
        end

        private

        def build!
          config = ::Rails.application.config.poli_page
          ConfigurationValidator.validate!(config)
          PoliPage::Client.new(**config.to_client_kwargs)
        end
      end
    end
  end
end
```

**Why `Monitor`, not `Mutex`**: same-thread re-entrant. If a future Railtie initialization path calls `PoliPage.client` while already holding the lock (unlikely, but cheap insurance), `Monitor` doesn't deadlock.

**Why not memoise per-thread (`Thread.current[:poli_page_client]`)**: the SDK's `Client` is documented thread-safe. Per-thread memoisation would multiply socket pools, file descriptors for the logger, etc. Puma's threaded mode and Falcon's fiber-per-request both share the singleton correctly. See `/Users/mickael/Projects/sdk-ruby/lib/poli_page/client.rb:23` ("A single Client may be safely shared across threads — build one at boot and reuse it").

### 7.4 The SDK constructor mapping

Reference (from `/Users/mickael/Projects/sdk-ruby/lib/poli_page/client.rb:52-58`):

```ruby
def initialize(api_key:, base_url: Internal::Constants::DEFAULT_BASE_URL,
               max_retries: Internal::Constants::DEFAULT_MAX_RETRIES,
               retry_delay: Internal::Constants::DEFAULT_RETRY_DELAY,
               timeout: Internal::Constants::DEFAULT_TIMEOUT,
               logger: nil, on_retry: nil, on_error: nil,
               proxy: nil, ca_file: nil, ca_path: nil)
```

`Configuration#to_client_kwargs.compact` drops every nil entry, so SDK defaults kick in for every unset config key. The only required field is `api_key` — `ConfigurationValidator.validate!` raises before reaching the SDK if it's missing.

There is no `user_agent` parameter in the SDK's `Client#initialize` — the SDK builds it internally from `PoliPage::VERSION`. The Configuration object retains a `user_agent` attribute for **future** SDK support, but in v0.1.0 it is **passed through to the SDK only if non-nil**, and silently ignored if the SDK does not accept the keyword. Concretely: `to_client_kwargs` drops `user_agent` (it is not in the kwargs Hash above). The attribute remains in Configuration for forward-compat; document in the generator template that it is currently a no-op.

### 7.5 No DI container; explicit memoisation

Rails has no DI container in the Symfony/Laravel sense. The "container" idiom is module-level memoisation behind a class method. `PoliPage.client` is the entire surface. Users who want to swap the client in tests use `PoliPage::Rails::Client.instance_variable_set(:@instance, fake_client)` or — preferred — `allow(PoliPage).to receive(:client).and_return(fake_client)`.

For a stronger seam, users can wrap their controller code:

```ruby
def show
  pdf = PoliPage.client.render.pdf(project: "billing", template: "invoice", data: ...)
  render_pdf(pdf, filename: "invoice.pdf")
end
```

The `render_pdf` helper is provided by the `Renderable` concern (§8).

---

## 8. `PoliPage::Rails::Renderable` controller concern

Single module, `PoliPage::Rails::Renderable`, included in controllers that need PDF / preview / redirect helpers. **No state.** Pure transformation from SDK output → Rails response.

### 8.1 Usage

```ruby
class InvoicesController < ApplicationController
  include PoliPage::Rails::Renderable

  def show
    pdf = PoliPage.client.render.pdf(
      project:  "billing",
      template: "invoice",
      version:  "1.0.0",
      data:     { invoice_number: params[:id] }
    )
    render_pdf(pdf, filename: "invoice-#{params[:id]}.pdf")
  end

  def preview
    result = PoliPage.client.render.preview(
      project:  "billing",
      template: "invoice",
      version:  "draft",
      data:     { invoice_number: params[:id] }
    )
    render_preview(result)
  end

  def descriptor
    doc = PoliPage.client.documents.get(params[:doc_id])
    redirect_to_document(doc)
  end
end
```

### 8.2 Method signatures

```ruby
module PoliPage
  module Rails
    module Renderable
      extend ActiveSupport::Concern

      # Sends raw PDF bytes with PDF headers + RFC 5987 Content-Disposition.
      # Default is `inline: false` (attachment); set `inline: true` to render
      # in the browser's PDF viewer instead of triggering a download.
      def render_pdf(bytes, filename: "document.pdf", inline: false)
        send_data(
          bytes,
          type: "application/pdf",
          filename: filename,
          disposition: inline ? "inline" : "attachment"
        ).tap do
          response.headers["Content-Disposition"] = FilenameEncoder.disposition(
            filename, inline: inline
          )
          response.headers["Cache-Control"] = "private, no-store"
          response.headers["X-Content-Type-Options"] = "nosniff"
        end
      end

      # Renders the HTML body of a PreviewResult or DocumentPreviewResult.
      # Sets Content-Type and cache headers; does not run through layouts or
      # ERB (the HTML is already a complete document).
      def render_preview(result)
        html = result.respond_to?(:html) ? result.html : result.to_s
        response.headers["Cache-Control"] = "private, no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        render html: html.html_safe, layout: false, content_type: "text/html; charset=utf-8"
      end

      # 302 to the descriptor's presigned URL. Adds Cache-Control so the
      # redirect itself never gets intermediary-cached (the URL has its
      # own TTL anyway).
      def redirect_to_document(descriptor, status: :found)
        response.headers["Cache-Control"] = "private, no-store"
        redirect_to descriptor.presigned_pdf_url, status: status, allow_other_host: true
      end
    end
  end
end
```

### 8.3 Headers each method sets

`render_pdf`:
- `Content-Type: application/pdf`
- `Content-Length` — Rack sets this from the body bytesize automatically
- `Content-Disposition: attachment; filename="..."; filename*=UTF-8''...` (or `inline` if `inline: true`) — RFC 5987 encoding for non-ASCII filenames
- `Cache-Control: private, no-store` — PDFs typically contain personalised data; never let intermediaries cache
- `X-Content-Type-Options: nosniff`

`render_preview`:
- `Content-Type: text/html; charset=utf-8`
- `Cache-Control: private, no-store`
- `X-Content-Type-Options: nosniff`

`redirect_to_document`:
- HTTP 302
- `Location: <descriptor.presigned_pdf_url>`
- `Cache-Control: private, no-store`
- Uses `allow_other_host: true` because the presigned URL points at S3 / R2 / equivalent (Rails 7+ blocks cross-host redirects by default).

### 8.4 Streaming (`render.pdf_stream`)

The SDK's `client.render.pdf_stream(...)` yields chunks. A streamed Rails response uses `ActionController::Live`:

```ruby
class InvoicesController < ApplicationController
  include ActionController::Live
  include PoliPage::Rails::Renderable

  def stream
    response.headers["Content-Type"] = "application/pdf"
    response.headers["Content-Disposition"] = PoliPage::Rails::FilenameEncoder.disposition(
      "invoice.pdf", inline: false
    )
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"

    PoliPage.client.render.pdf_stream(project: "billing", template: "invoice",
                                      version: "1.0.0", data: { ... }) do |chunk|
      response.stream.write(chunk)
    end
  ensure
    response.stream.close
  end
end
```

We do **not** ship a `stream_pdf` helper in v0.1.0 — `ActionController::Live` is opt-in (it requires `include ActionController::Live` on the controller, which changes the request lifecycle), and wrapping it would lock users into our specific lifecycle assumption. The example app's controller demonstrates the pattern; the concern stays small. Defer to v0.2 if user feedback signals demand.

### 8.5 Filename encoding

`PoliPage::Rails::FilenameEncoder.disposition(filename, inline:)` returns the full `Content-Disposition` value. ASCII-only filenames emit `attachment; filename="..."`. Non-ASCII filenames emit BOTH `filename="<ascii-fallback>"` and `filename*=UTF-8''<percent-encoded>` per RFC 5987 / RFC 6266.

We reuse `ActionDispatch::Http::ContentDisposition` (Rails ships this for `ActiveStorage` — it does exactly the right encoding). The helper exists primarily for documentation and as a single seam if Rails changes the API.

---

## 9. `rails generate poli_page:install` generator

**Purpose**: write `config/initializers/poli_page.rb` with a commented template. Rails generators are the idiomatic install step for engines (Devise, RSpec-rails, Pundit all ship one). Direct parity with the symfony-bundle's Flex recipe and the laravel package's `vendor:publish --tag=poli-page-config`.

### 9.1 Signature

```
rails generate poli_page:install [PATH]

  PATH                  Optional initializer file path
                        (default: config/initializers/poli_page.rb)

# Inherited Rails global flags (NEVER redefine these — §10.1 in CLAUDE.md):
#   --skip-namespace
#   --skip-collision-check
#   --quiet / -q
#   --pretend / -p
#   --force / -f
#   --skip / -s
#   --help / -h
```

**Zero custom options in v0.1.0**. The single positional argument has a default. We avoid options entirely so we don't accidentally clash with a Thor-reserved name.

### 9.2 Behaviour

- Generates `config/initializers/poli_page.rb` from `lib/generators/poli_page/install/templates/poli_page.rb.tt`.
- Refuses to overwrite an existing file unless `--force` is given (inherited Rails default; we don't redefine).
- Refuses to write to a non-`config/initializers/*` path unless `--force` (sanity check; users who really need a custom path can pass `--force`).
- Emits a "Created `config/initializers/poli_page.rb`. Set `POLI_PAGE_API_KEY` in your env." success message.

### 9.3 Generator class

`lib/generators/poli_page/install/install_generator.rb`:

```ruby
require "rails/generators"

module PoliPage
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Writes config/initializers/poli_page.rb."

      argument :initializer_path, type: :string, required: false,
               default: "config/initializers/poli_page.rb",
               banner: "PATH"

      def copy_initializer
        template "poli_page.rb.tt", initializer_path
      end

      def show_readme
        readme_path = File.expand_path("../../../../README.md", __dir__)
        return unless File.exist?(readme_path)

        say ""
        say "Created #{initializer_path}.", :green
        say "Set POLI_PAGE_API_KEY in your env, then restart the app.", :green
      end
    end
  end
end
```

### 9.4 Template

`lib/generators/poli_page/install/templates/poli_page.rb.tt`:

```ruby
# frozen_string_literal: true

# Configuration for the poli_page-rails gem (https://poli.page).
#
# Set POLI_PAGE_API_KEY in your environment, then customise below as needed.
# Get a key at https://app.poli.page/settings/api-keys.

Rails.application.config.poli_page.tap do |c|
  c.api_key = ENV.fetch("POLI_PAGE_API_KEY")

  # Optional — defaults to https://api.poli.page (the SDK applies its default
  # when this is nil). Use https://api-develop.poli.page for the develop env.
  # c.base_url = ENV["POLI_PAGE_BASE_URL"]

  # Optional — request timeout in seconds (float). SDK default applies when nil.
  # c.timeout = 30.0

  # Optional — retry policy. SDK defaults apply when nil.
  # c.max_retries = 3
  # c.retry_delay = 0.5

  # Optional — pass any Logger-compatible instance. Defaults to Rails.logger.
  # c.logger = Rails.logger

  # Optional — corporate-egress controls. Honoured by Net::HTTP via the SDK.
  # c.proxy   = ENV["POLI_PAGE_HTTP_PROXY"]
  # c.ca_file = ENV["POLI_PAGE_CA_FILE"]
  # c.ca_path = ENV["POLI_PAGE_CA_PATH"]

  # Optional — set to false to disable the ActiveSupport::Notifications bridge.
  # The bridge is default-on; it costs nothing when no subscribers attach.
  # c.notifications = false

  # Optional — custom retry/error callables. Setting these REPLACES the
  # ActiveSupport::Notifications bridge entirely (you opt out of the default
  # bridge by providing your own callable). To preserve the bridge AND add
  # custom behaviour, subscribe to AS::Notifications instead:
  #
  #   ActiveSupport::Notifications.subscribe("poli_page.retry") do |*args|
  #     event = ActiveSupport::Notifications::Event.new(*args)
  #     Rails.logger.warn("PoliPage retry: #{event.payload}")
  #   end
  #
  # c.on_retry = ->(event) { Rails.logger.warn("retry: #{event.attempt}") }
  # c.on_error = ->(err)   { Sentry.capture_exception(err) }
end
```

The template uses the `.tt` extension (Thor's "template" suffix) so we can inject runtime values if we later need to — none in v0.1.0.

---

## 10. `ActiveSupport::Notifications` bridge

The SDK exposes `on_retry: ->(RetryEvent)` and `on_error: ->(PoliPage::Error)` constructor hooks. We surface these as **`ActiveSupport::Notifications`** events so users can subscribe with standard Rails idioms (`ActiveSupport::Notifications.subscribe`, lograge / appsignal / scout instrumentation slot in automatically).

### 10.1 Event names

- `"poli_page.retry"` — fired before each retry attempt. Payload: `{ attempt: Integer, delay: Float, reason: PoliPage::Error }`.
- `"poli_page.error"` — fired when a request terminally fails (after all retries exhausted, or a non-retryable error). Payload: `{ error: PoliPage::Error }`.

Naming convention: `<gem_name>.<event>`, dotted, lowercase — matches Rails core (`sql.active_record`, `process_action.action_controller`, `deliver.action_mailer`), `sentry-rails` (`sentry.event_sent`), `appsignal-ruby`.

### 10.2 Bridge module

`lib/poli_page/rails/notifications.rb`:

```ruby
require "active_support/notifications"

module PoliPage
  module Rails
    module Notifications
      RETRY_EVENT_NAME = "poli_page.retry"
      ERROR_EVENT_NAME = "poli_page.error"

      def self.retry_bridge
        @retry_bridge ||= lambda do |event|
          ::ActiveSupport::Notifications.instrument(
            RETRY_EVENT_NAME,
            attempt: event.attempt,
            delay:   event.delay,
            reason:  event.reason
          )
        end
      end

      def self.error_bridge
        @error_bridge ||= lambda do |error|
          ::ActiveSupport::Notifications.instrument(
            ERROR_EVENT_NAME,
            error: error
          )
        end
      end
    end
  end
end
```

Wrappers, not reimplementations. Carry the SDK's own event/error object verbatim so subscribers have full access to `attempt`, `delay`, `reason`, plus the error's `code`, `status`, `request_id`.

### 10.3 User-defined hooks (config-level)

If the user sets `c.on_retry = ->(event) { ... }` in the initializer, **that callable fires INSTEAD of the notifications bridge** (not in addition). Rationale: keep the SDK's single-callable constraint visible; users who want both can call `ActiveSupport::Notifications.instrument(...)` inside their custom callable. Same trade-off as symfony-bundle / laravel for the same reason.

### 10.4 Subscriber example (user code, for docs)

```ruby
# config/initializers/poli_page_logging.rb
ActiveSupport::Notifications.subscribe("poli_page.retry") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.warn(
    "[poli_page] retry attempt=#{event.payload[:attempt]} " \
    "delay=#{event.payload[:delay]}s " \
    "reason=#{event.payload[:reason].class}: #{event.payload[:reason].message}"
  )
end

ActiveSupport::Notifications.subscribe("poli_page.error") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Sentry.capture_exception(event.payload[:error]) if defined?(Sentry)
end
```

This is the Rails idiom: no need to register listener classes, no need for an EventServiceProvider. `lograge`, `appsignal`, `scout_apm`, `skylight`, custom Datadog subscribers all hook here automatically.

### 10.5 Why default-on (the divergence from nextjs/nestjs)

The Next.js spec §18 decided notifications/instrumentation is opt-in. Rails diverges: default-on, opt-out via `c.notifications = false`.

**Reasoning**:

1. **`ActiveSupport::Notifications` has near-zero overhead when no subscribers attach.** The notifier checks `@listeners.any?` before allocating an event object. The bridge installation cost is one `lambda` per hook, set once at boot.
2. **Rails culture: instrumentation is on by default.** `ActiveRecord` emits `sql.active_record`, `ActionController` emits `process_action.action_controller`, `ActionMailer` emits `deliver.action_mailer` — always. Gem users expect to be able to `subscribe(...)` without touching gem config.
3. **The opt-in cost is worse than the opt-out cost.** A user who doesn't subscribe pays nothing. A user who DOES want to subscribe but didn't know to flip a config flag will silently get no events — a confusing failure mode.
4. **Opt-out is one config line.** `c.notifications = false` for users who really don't want the bridge. The friction is symmetric.

This is the same call `sentry-rails` makes for its breadcrumb instrumentation, `aws-sdk-rails` for its ActiveJob queue events, and `appsignal-ruby` for its `ActionController` hooks. We match the ecosystem norm.

---

## 11. Auto-discovery & one-line install

After `bundle add poli_page-rails`:

1. Run `bin/rails generate poli_page:install` (writes `config/initializers/poli_page.rb`).
2. Add `POLI_PAGE_API_KEY=pp_test_...` to your environment.
3. Use `PoliPage.client.render.pdf(...)` or include `PoliPage::Rails::Renderable` in a controller.

No `config/application.rb` edits required. No manual `require`. Bundler's autoload plus the engine's Railtie registration handle everything.

---

## 12. Unpublished SDK workaround — Bundler `path:` override

**Problem**: `poli-page` (the Ruby SDK gem) is not yet on RubyGems and we don't want to publish it yet. The gem nonetheless needs to `bundle install` against the local SDK source at `/Users/mickael/Projects/sdk-ruby/`.

**Constraint**: when the SDK does publish (any time after we ship v0.1.0), zero changes are required to the gem's source code or its **published gemspec**. Same constraint as symfony-bundle / laravel; cleaner solution because Bundler natively supports `path:` overrides in the `Gemfile` (not the gemspec).

### 12.1 Solution

The `.gemspec` declares the SDK requirement **cleanly**, as if RubyGems already served it:

```ruby
# poli_page-rails.gemspec
Gem::Specification.new do |spec|
  spec.name        = "poli_page-rails"
  spec.version     = PoliPage::Rails::VERSION
  spec.summary     = "Rails engine for the Poli Page PDF rendering API"
  spec.description = "Rails engine + controller concern + ActiveSupport::Notifications " \
                     "bridge over the official poli-page Ruby SDK."
  spec.authors     = ["Poli Page"]
  spec.email       = "support@poli.page"
  spec.homepage    = "https://poli.page"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri"          => "https://poli.page",
    "source_code_uri"       => "https://github.com/poli-page/rails",
    "changelog_uri"         => "https://github.com/poli-page/rails/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.{rb,tt}"] + Dir["sig/**/*.rbs"] +
               %w[LICENSE README.md CHANGELOG.md]
               .select { |f| File.exist?(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "poli-page", "~> 1.0"
  spec.add_dependency "railties",   ">= 7.0", "< 9"
  spec.add_dependency "actionpack", ">= 7.0", "< 9"
  spec.add_dependency "activesupport", ">= 7.0", "< 9"
end
```

The `Gemfile` (NOT the gemspec) supplies the local-path override:

```ruby
# Gemfile
source "https://rubygems.org"

gemspec

# Why: poli-page (the SDK) is not yet on RubyGems. Path override lives in the
# Gemfile so the gemspec stays Packagist-ready. Delete this line once
# poli-page publishes; everything else continues to work unchanged.
gem "poli-page", path: "../sdk-ruby"

group :development, :test do
  gem "rspec-rails", "~> 6.1"
  gem "combustion",  "~> 1.5"
  gem "appraisal",   "~> 2.5"
  gem "rubocop",          require: false
  gem "rubocop-rails",    require: false
  gem "rubocop-rspec",    require: false
  gem "rubocop-performance", require: false
  gem "dotenv-rails", "~> 3.1"
  gem "webmock",     "~> 3.23", require: false  # used only by example-app demo, never to retest SDK transport
end
```

**Why this is cleaner than Composer's merge-plugin dance**: Bundler natively recognises `gem "..." path: "..."` overrides on top of a `gemspec` directive. No second manifest file, no plugin install bootstrap. The gemspec stays as it will look on RubyGems day one; the `Gemfile` carries the dev override.

### 12.2 What changes when the SDK publishes

1. Remove the `gem "poli-page", path: "../sdk-ruby"` line from `Gemfile`.
2. `bundle update poli-page` — resolves from RubyGems this time.
3. Tag and release v0.1.0.

**The gem's source code (everything in `lib/`, `spec/`, `sig/`) does not change.** The only change is the `Gemfile` dev override removal.

### 12.3 CI handling

`.github/workflows/ci.yml` checks out the SDK alongside the gem so the `path:` override resolves correctly inside CI:

```yaml
- uses: actions/checkout@v4
  with: { path: rails }
- uses: actions/checkout@v4
  with:
    repository: poli-page/sdk-ruby
    path: sdk-ruby
    ref: main
- run: bundle install
  working-directory: rails
```

`actions/checkout` requires `path:` to be inside `$GITHUB_WORKSPACE`, so both repos check out as siblings under the workspace root. `Gemfile`'s `path: "../sdk-ruby"` then resolves correctly relative to `rails/`. Identical to the symfony-bundle / laravel pattern.

After v0.1.0 publishes, remove the "Checkout SDK alongside gem" step.

### 12.4 example-app workaround

`example-app/Gemfile` is a **separate** Bundler project. It uses its own `path:` block (no special bootstrap — example-app is not a published artifact, so the path overrides can live here forever):

```ruby
# example-app/Gemfile
source "https://rubygems.org"

gem "rails", "~> 8.0"
gem "puma"
gem "poli_page-rails", path: "../"
gem "poli-page",       path: "../../sdk-ruby"

gem "dotenv-rails", "~> 3.1"

group :development do
  gem "web-console"
end
```

This stays as-is forever — example-app is meant to install from local sources, not RubyGems.

---

## 13. Testing strategy

### 13.1 Tooling

- **RSpec** (`rspec-rails ~> 6.1`) — community-default for Rails engine specs.
- **Combustion** (`~> 1.5`) — boots a minimal Rails app inside `spec/internal/` for engine specs. Pattern documented at <https://github.com/pat/combustion>.
- **RuboCop** + `rubocop-rails` + `rubocop-rspec` + `rubocop-performance`. Pinned in `.rubocop.yml`. `NewCops: enable`.
- **Appraisal** — multi-Rails matrix (`Appraisals` file lists Rails 7.0 / 7.1 / 7.2 / 8.0).

**Why RSpec, not Minitest**: ecosystem density. `rspec-rails`, `combustion`, `webmock-rspec`, `vcr` (if ever needed), `appraisal` all have first-class RSpec support. Minitest works but the integration surface is thinner. Documented as an alternative in CLAUDE.md §13.2; if a contributor proposes a Minitest port we accept it, but the canonical suite is RSpec.

### 13.2 `spec/spec_helper.rb` shape

```ruby
require "dotenv"
Dotenv.load(
  File.expand_path("../../symfony-bundle/.env", __dir__),
  ".env.local",
  ".env"
)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
```

### 13.3 `spec/rails_helper.rb` shape

```ruby
ENV["RAILS_ENV"] ||= "test"
require "combustion"
Combustion.path = "spec/internal"
Combustion.initialize! :action_controller, :action_dispatch do
  config.eager_load = false
end

require "rspec/rails"
require "poli_page-rails"

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

RSpec.configure do |config|
  config.include PoliPage::Rails::Test::RestoresGlobalHandlers
  config.include PoliPage::Rails::Test::NotificationsLeakDetector
end
```

### 13.4 Layers

**Unit specs** (90%+ of the suite, run in milliseconds, no network):

| Spec | What it covers |
|---|---|
| `engine_spec.rb` | Engine class loads, `Rails.application.config.poli_page` returns a `Configuration` post-Railtie. Smoke. |
| `configuration_spec.rb` | All §6.2 validation rules. Invalid `api_key` / `timeout` / `max_retries` / `retry_delay` / `base_url` / `notifications` / `on_retry` / `on_error` raise `PoliPage::Rails::ConfigurationError` with the expected message. |
| `client_spec.rb` | `PoliPage.client` returns same memoised instance across calls; thread-safety via concurrent calls; `PoliPage.reset_client!` clears it; validation runs on first access (not at boot). |
| `renderable_spec.rb` | Each method on the concern sets the correct headers + body. Cover ASCII and non-ASCII filenames (verify RFC 5987 encoding). Verify `inline: true` flips disposition. Verify `redirect_to_document` uses `allow_other_host: true`. |
| `notifications_spec.rb` | Bridge fires `ActiveSupport::Notifications.instrument` with the right payload. `notifications = false` disables it. User-set `on_retry` replaces the bridge entirely. The `NotificationsLeakDetector` asserts subscriber count stays clean. |
| `filename_encoder_spec.rb` | ASCII-only filenames emit `filename="..."`. Non-ASCII (`é`, `中`, `🦀`) filenames emit BOTH `filename="..."` and `filename*=UTF-8''<percent-encoded>`. |
| `install_generator_spec.rb` | Generator writes `config/initializers/poli_page.rb` with the template body. `--force` overwrites; default refuses to clobber. Uses Rails's `Rails::Generators::TestCase` for isolation. |

**Integration spec** (single test, gated):

`spec/integration/render_against_develop_api_spec.rb`:

```ruby
RSpec.describe "Rendering against the develop API", :integration do
  before do
    skip "POLI_PAGE_API_KEY not set" if ENV["POLI_PAGE_API_KEY"].nil?
    skip "Refusing to run integration spec with a pp_live_* key" if ENV["POLI_PAGE_API_KEY"].start_with?("pp_live_")
  end

  it "renders the canonical getting-started/welcome template" do
    ::Rails.application.config.poli_page.tap do |c|
      c.api_key  = ENV.fetch("POLI_PAGE_API_KEY")
      c.base_url = "https://api-develop.poli.page"
    end
    PoliPage.reset_client!

    bytes = PoliPage.client.render.pdf(
      project:  "getting-started",
      template: "welcome",
      version:  "1.0.0",
      data:     { name: "Rails CI" }
    )

    expect(bytes).to be_a(String)
    expect(bytes.bytesize).to be > 1024
    expect(bytes[0, 5]).to eq("%PDF-")
  end
end
```

- Skipped when `POLI_PAGE_API_KEY` is unset (PR contributors without a key get green local runs).
- Refuses to run with a `pp_live_*` key (safety belt against accidental production use).
- One test, idempotent, ~3 seconds when it runs.

### 13.5 What we explicitly do NOT test

Anything tested by the SDK:
- HTTP transport behaviour (Net::HTTP edge cases, proxy / CA chains).
- Retry policy (exponential backoff, max attempts, `Retry-After` parsing, never retrying 4xx).
- 4xx / 5xx → error-class mapping.
- Idempotency-key generation.
- Stream chunking correctness.
- Wire envelope (snake_case ↔ camelCase via `Internal::Wire`).

The gem wraps — it does not re-test. If a bug in those areas appears, fix it in the SDK.

### 13.6 Single-root env loading

`spec/spec_helper.rb` reads env vars from `/Users/mickael/Projects/symfony-bundle/.env` (the de-facto workspace root) via `dotenv`. Real shell exports always win — `Dotenv.load` (not `Dotenv.overload`). Same mechanism as symfony-bundle / laravel / nextjs — see `INTEGRATIONS_PLAN.md` §"Cross-cutting DX patterns" §2.

---

## 14. `example-app/` — interactive UI demo

A minimal Rails 8 application that demonstrates every public method of the SDK through the gem. **Mirrors the SDK's 10-step demo 1:1** through JSON routes, and ships a single-page interactive dashboard at `GET /`.

### 14.1 Layout

```
example-app/
├── Gemfile                                       # path: '../' for the gem + path: '../../sdk-ruby'
├── Gemfile.lock                                  # Committed for the example app (it IS an app)
├── config.ru
├── config/
│   ├── application.rb                            # Loads root .env (CLAUDE.md §10.3)
│   ├── boot.rb
│   ├── environment.rb
│   ├── routes.rb
│   ├── credentials.yml.enc (optional, not used in dev)
│   ├── initializers/
│   │   └── poli_page.rb                          # Generated by `rails generate poli_page:install`
│   └── environments/{development.rb,test.rb,production.rb}
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── demos_controller.rb                   # GET / — renders demo.html.erb
│   │   ├── renders_controller.rb                 # JSON routes for SDK demo steps 1, 2, 4, 5
│   │   └── documents_controller.rb               # JSON routes for steps 6, 7, 8, 9, 10
│   ├── views/
│   │   ├── layouts/
│   │   │   └── application.html.erb
│   │   └── demos/
│   │       └── index.html.erb                    # The single-page interactive dashboard
│   └── jobs/                                     # empty in v0.1.0
├── bin/
│   ├── rails
│   ├── setup
│   └── server
├── lib/
│   └── tasks/
│       └── demo.rake                             # rake demo:render_to_file (SDK step 3)
├── public/
├── log/
├── tmp/
└── README.md                                     # `bundle install && bin/rails server`, then open http://localhost:3000
```

### 14.2 Route-to-demo mapping

| SDK demo step | example-app endpoint | Method called |
|---|---|---|
| (UI) | `GET /` | Renders `demos/index.html.erb` — single-page dashboard, one button per row below. |
| 1. `render.pdf` | `GET /api/render/pdf` | `PoliPage.client.render.pdf(...)` → `render_pdf(bytes, filename:)` |
| 2. `render.pdf_stream` | `GET /api/render/stream` | `PoliPage.client.render.pdf_stream(...) { \|chunk\| response.stream.write(chunk) }` (uses `ActionController::Live`) |
| 3. `render_to_file` | `bin/rake demo:render_to_file` | `PoliPage.client.render_to_file(path, **kwargs)` — example-app's own rake task; NOT a published gem feature |
| 4. `render.preview` | `GET /api/render/preview` | `PoliPage.client.render.preview(...)` → `render_preview(result)` |
| 5. `render.document` | `POST /api/documents` | `PoliPage.client.render.document(...)` returns descriptor as JSON |
| 6. `documents.get(id)` | `GET /api/documents/:id` | `redirect_to_document(descriptor)` (302 to presigned URL) |
| 7. `documents.thumbnails(id)` | `GET /api/documents/:id/thumbnails` | Returns base64 thumbnails as JSON |
| 8. `documents.preview(id)` | `GET /api/documents/:id/preview` | `render_preview(result)` |
| 9. `documents.delete(id)` | `DELETE /api/documents/:id` | Returns 204 |
| 10. Error handling | `GET /api/errors/bad-version` | Deliberately triggers 400 INVALID_VERSION_FORMAT, returns exception as JSON |

### 14.3 The interactive UI at `GET /` (`app/views/demos/index.html.erb`)

**Hard requirement (INTEGRATIONS_PLAN.md §"Cross-cutting DX patterns" §1)**: ship an interactive single-page UI, not a `curl`-recipe README. The aesthetic is copied verbatim from `/Users/mickael/Projects/symfony-bundle/example-app/templates/demo.html`:

- White surface (`--bg: #ffffff`), brand indigo `#4f5d99` (`--brand`)
- Display: `Manrope` (700/800 weights) for headings + wordmark
- Body: `IBM Plex Sans` (400/500, italic for taglines)
- Code: `JetBrains Mono` (400/500)
- Hairline borders (`#e5e7ef`), generous gutters, editorial print-specimen feel
- Status pill at the top with a pulsing brand dot

Each SDK feature gets a row with:
- A title and one-sentence "why this exists" description
- A single button labelled with the SDK verb (e.g. "Render PDF")
- An inline result panel that swaps in:
  - `<iframe src="data:application/pdf;base64,...">` for PDF features (browser viewer handles display)
  - `<iframe srcdoc="..." sandbox>` for HTML preview features
  - `<pre>` with pretty-printed JSON for JSON features (swap to a red border on non-2xx)
  - For document features: capture the returned `document_id` into JS state; gate downstream buttons (preview, thumbnails, delete) on its presence; clear it on Delete
- For the `render_to_file` rake task that can't run in-browser: a copy-button block showing the `bin/rake demo:render_to_file` invocation

Total file size target: ~440 lines (matches the symfony-bundle's `demo.html`).

ERB syntax stays minimal — the file is essentially the symfony demo template with `{% %}` Twig directives swapped for `<%= %>` ERB, and a single `<%= csrf_meta_tags %>` in `<head>`. Inline CSS, inline JS, no Sprockets / Propshaft asset pipeline involvement, no Importmap, no esbuild, no Tailwind.

The Rails layout (`app/views/layouts/application.html.erb`) is stripped to:

```erb
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <%= csrf_meta_tags %>
  <%= yield :head %>
</head>
<body><%= yield %></body>
</html>
```

— no `stylesheet_link_tag`, no `javascript_importmap_tags`. The demo view ships its own `<style>` and `<script>` inline.

### 14.4 What example-app proves

- The gem's autoload + Railtie wiring works in a real Rails app (not just `combustion` engine specs).
- The PDF actually streams to a browser with the right headers (open the demo in Chrome, click "Render PDF", see the PDF render inline in an `<iframe>`).
- Every SDK surface is reachable through `PoliPage.client` AND through the `Renderable` concern — the demo's `RendersController` uses `include PoliPage::Rails::Renderable`, the demo's `DocumentsController` deliberately does NOT include the concern (uses `send_data` directly) to demonstrate both work.
- A reader who knows the SDK can read the controllers and immediately see the wrapping pattern.

### 14.5 Single-root env loading in example-app

`config/application.rb` reads the workspace root `.env` first, falls back to per-app overrides:

```ruby
require "dotenv"
Dotenv.load(
  File.expand_path("../../symfony-bundle/.env", __dir__),
  ".env.local",
  ".env"
)
```

**No `.env.local` instruction in the README.** Reference and parser ported from the symfony-bundle conceptually (different impl — Dotenv handles it natively in Ruby). Real shell exports always win.

---

## 15. CI matrix

`.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        ruby: ['3.1', '3.2', '3.3', '3.4']
        rails: ['7.0', '7.1', '7.2', '8.0']
        exclude:
          - ruby: '3.1'
            rails: '8.0'   # Rails 8 requires Ruby >= 3.2
    steps:
      - uses: actions/checkout@v4
        with: { path: rails }
      - uses: actions/checkout@v4
        with:
          repository: poli-page/sdk-ruby
          path: sdk-ruby
          ref: main
        continue-on-error: true
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
          bundler-cache: true
          working-directory: rails
      - name: Pin Rails via Appraisal
        working-directory: rails
        run: |
          if [ -f Appraisals ]; then
            bundle exec appraisal "rails-${{ matrix.rails }}" install
          fi
      - name: Lint
        working-directory: rails
        run: |
          if [ -f .rubocop.yml ]; then
            bundle exec rubocop
          else
            echo "Skipping lint: no .rubocop.yml yet"
          fi
      - name: Specs
        working-directory: rails
        run: |
          if [ -d spec ] && [ -n "$(ls -A spec/*.rb spec/**/*.rb 2>/dev/null)" ]; then
            bundle exec appraisal "rails-${{ matrix.rails }}" rspec --exclude-pattern "spec/integration/**/*"
          else
            echo "Skipping specs: no spec/ yet"
          fi

  integration:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
        with: { path: rails }
      - uses: actions/checkout@v4
        with:
          repository: poli-page/sdk-ruby
          path: sdk-ruby
          ref: main
      - uses: ruby/setup-ruby@v1
        with: { ruby-version: '3.3', bundler-cache: true, working-directory: rails }
      - name: Integration spec against develop API
        working-directory: rails
        env:
          POLI_PAGE_API_KEY: ${{ secrets.POLI_PAGE_DEVELOP_API_KEY }}
        run: |
          if [ -d spec/integration ] && [ -n "$(ls -A spec/integration/*.rb 2>/dev/null)" ]; then
            bundle exec rspec spec/integration
          else
            echo "Skipping integration spec: no spec/integration yet"
          fi
```

**Appraisals** file (matches `sentry-rails`'s pattern):

```ruby
appraise "rails-7.0" do
  gem "rails", "~> 7.0.0"
end

appraise "rails-7.1" do
  gem "rails", "~> 7.1.0"
end

appraise "rails-7.2" do
  gem "rails", "~> 7.2.0"
end

appraise "rails-8.0" do
  gem "rails", "~> 8.0.0"
end
```

Note: `actions/checkout` requires `path:` to be inside `$GITHUB_WORKSPACE`, so both repos check out as siblings under the workspace root. `Gemfile`'s `path: "../sdk-ruby"` then resolves correctly relative to `rails/`. Identical to the symfony-bundle / laravel pattern.

**Auto-skip behaviour** (inherited from the SDK CI convention): each step short-circuits if the relevant config file is missing. Don't change this — a freshly scaffolded repo must be green from day one.

Once SDK publishes (§12.2), remove the "Checkout SDK alongside gem" step.

---

## 16. Versioning & release

- **SemVer**. v0.x while the API stabilises, mirroring the SDK's `1.0.0.rc.x` early-life.
- **`CHANGELOG.md`** in [Keep a Changelog](https://keepachangelog.com/) format. Updated in the same commit as every version bump.
- **Conventional Commits** for every commit (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).
- **Release process**:
  1. Bump `PoliPage::Rails::VERSION` in `lib/poli_page/rails/version.rb`.
  2. Update `CHANGELOG.md`.
  3. `bundle exec rake build` (writes `pkg/poli_page-rails-x.y.z.gem`).
  4. `bundle exec rake release` (tags, pushes, `gem push` to RubyGems).
- **v0.1.0 launch sequence**:
  1. Land the unpublished-SDK workaround removal (§12.2).
  2. Verify CI green on all matrix cells.
  3. `rake release`.
  4. Optionally write a launch note on poli.page/blog.

---

## 17. Deferred to v0.2+ (do not build in v0.1.0)

Calling these out explicitly so they don't sneak in mid-implementation. Each has a real use case but adds maintenance surface beyond v0.1.0's scope.

| Feature | Why deferred |
|---|---|
| **ActiveJob job wrapper** (`PoliPage::Rails::RenderJob.perform_later(...)`) | Requires schema for retry / dead-letter handling. Substantial spec on its own. |
| **Action Mailer `attach_pdf` helper** (`mail.attach_pdf_from_poli_page(descriptor)`) | Easy DX win but very specific use case; better as a recipe than wiring. |
| **Turbo Frame partials** for inline PDF previews | Niche; depends on the host app's Turbo/Stimulus setup. |
| **ActionCable channel** for streaming render progress | Premature — the SDK is synchronous; no progress signal exists. |
| **Sidekiq middleware** for tagging poli_page requests with `bid` | Niche. Subscribe to `poli_page.error` and tag the Sidekiq job ID from there. |
| **Multi-tenant / multi-client config** (named clients `c.clients[:default]`, `c.clients[:invoices]`) | v0.2 add-on; v0.1 single-client config is purely additive when extended. |
| **`bin/rails poli_page:render` rake task in the gem** | Pollutes the host app's `rake -T` output. Lives in the example app instead. Re-evaluate after user feedback. |
| **`/_health` route** for SDK reachability | Niche; better via a one-line user-written controller calling `PoliPage.client.documents.get('nonexistent')` and catching `NotFoundError`. |
| **YARD docs generation** | Source-level docs are good; YARD's HTML output ships when the gem hits 1.0. |
| **Strong typing via Sorbet** (`# typed: strict`) | RBS in `sig/` covers most of the value. Sorbet is a separate ecosystem; defer. |

**Discipline rule**: when implementing, if a "small addition" feels tempting, check this list first. If it's here, defer. If it's not here, ask before adding.

---

## 18. Resolved decisions

Capturing the "why we chose X" so future agents don't relitigate:

| Decision | Choice | Why |
|---|---|---|
| Gem shape | Standard Rails engine + Railtie | The shape every Rails dev recognises (sentry-rails, devise, pundit). Deviating would cost DX. |
| Gem name | `poli_page-rails` (snake_case + hyphen suffix) | RubyGems convention for sub-gems (`rspec-rails`, `sentry-rails`, `stripe-rails`). The hyphen is what Bundler discovers as a sibling to the SDK. |
| Top-level accessor | `PoliPage.client` (module-level), not `PoliPage::Rails.client` | The SDK's user-facing surface is `PoliPage::Client.new`. `PoliPage.client` reads as "the configured client" — single-default ergonomics like `Sentry.init` / `Stripe.api_key`. The `PoliPage::Rails` namespace stays internal to the engine/concern/notifications module. |
| Configuration object type | Plain Ruby class with `attr_accessor`s | Mutable during the `config.poli_page do \|c\| ... end` block, then effectively frozen at `client.build!` time. `Struct` lacks a clear constructor; `Data.define` is immutable, which conflicts with the block-config idiom. |
| Validation timing | Lazy, on first `PoliPage.client` call (NOT at boot) | Rails apps boot in scenarios where credentials aren't yet available (asset precompile, `db:create`, route introspection). Same trade-off `sentry-rails` makes for `Sentry.init`. |
| Rails version range | `>= 7.0, < 9` (7.0, 7.1, 7.2, 8.0) | Matches sentry-rails's range. 7.0 covers the latest LTS slot; 8.0 is current. |
| Ruby version range | `>= 3.2, < 4` (advertised in gemspec) | Matches SDK floor. CI matrix tests 3.1 best-effort but gemspec advertises 3.2+. |
| Memoisation strategy | Module-level `Monitor`-guarded `@instance`, shared across threads | Mirrors `Stripe.api_key` / `Sentry.init` style. SDK documents thread-safety; per-thread memoisation would multiply resources. |
| Default PSR-18 equivalent | N/A (SDK uses `Net::HTTP` directly) | No PSR ecosystem in Ruby. The SDK's `Internal::Transport` owns the choice. No analogue to symfony-bundle's `http_client` override. |
| Default logger | `Rails.logger` (set in Railtie `after_initialize`) | Idiomatic Rails; users can override with any Logger-compatible instance. |
| Notifications bridge default | Default-on (`c.notifications = true`); opt-out via `c.notifications = false` | Different from nextjs/nestjs (opt-in). Rails culture: instrumentation is default-on. `ActiveSupport::Notifications` has zero overhead when nothing subscribes. See §10.5. |
| Event names | `"poli_page.retry"`, `"poli_page.error"` | Matches Rails conventions (`sql.active_record`, `process_action.action_controller`). |
| `Renderable` concern inclusion | Yes, in v0.1.0 | Users get headers wrong without it; the one genuine Rails-flavoured value beyond DI wiring. Matches symfony-bundle's `PoliPageResponseFactory` / laravel's same. |
| `stream_pdf` helper | Deferred to v0.2 | `ActionController::Live` is opt-in and changes the request lifecycle. Wrapping it would lock users into our assumption. Example app demonstrates the pattern. |
| Install generator | Yes, in v0.1.0 | Devise / RSpec-rails / Pundit all ship one. Direct parity. Zero custom options to avoid Thor-reserved-name traps. |
| Rake / CLI tasks beyond the generator | None in v0.1.0 | Rails has no `bin/rails server`-equivalent slot we should attach to without polluting the host app's `rake -T`. The example app's `bin/rails server` IS the smoke test. The `render_to_file` demo lives in the example app's `lib/tasks/demo.rake`, not in the gem. |
| Test framework | RSpec + combustion | Ecosystem density (rspec-rails, combustion, appraisal all RSpec-first). Minitest documented as alternative but not the canonical suite. |
| Multi-Rails CI runner | Appraisal | Standard for engines (sentry-rails, rspec-rails). One `Appraisals` file generates per-Rails gemfiles. |
| Interactive demo UI | Yes, single-page ERB view at `GET /` (INTEGRATIONS_PLAN.md §"Cross-cutting DX patterns" §1) | Mickael's hard requirement. Aesthetic ported verbatim from symfony-bundle's `demo.html` (Manrope + IBM Plex Sans + JetBrains Mono, white surface, brand indigo). One button per SDK feature, inline previews. |
| `.env` strategy | Single root `.env` via `Dotenv.load` (NOT `Dotenv.overload`); real shell exports win | Mickael's hard requirement. No `cp .env .env.local`. (INTEGRATIONS_PLAN.md §"Cross-cutting DX patterns" §2.) |
| Test runner hygiene | `RestoresGlobalHandlers` + `NotificationsLeakDetector` support files | Signal traps and AS::Notifications subscribers leak between specs if not snapshotted. (INTEGRATIONS_PLAN.md §"Cross-cutting DX patterns" §4.) |
| Integration spec count | One, env-gated (INTEGRATIONS_PLAN.md §"Cross-cutting DX patterns" §5) | The SDK's own spec suite covers transport, retries, 4xx mapping, idempotency, stream chunking. The gem's integration spec is a single happy-path smoke test. |
| Unpublished SDK workaround | `Gemfile` `path:` override (NOT in gemspec) | Bundler natively recognises this; gemspec stays RubyGems-ready. Cleaner than symfony/laravel's two-file dance — Bundler is friendlier here. |
| RuboCop disables | Forbidden | `# rubocop:disable` survives review only with a `# Why:` comment naming the framework constraint. No blanket disables. |

---

## 19. Implementation order

A suggested commit-by-commit sequence — each commit ships green CI, each step is independently reviewable. Strict TDD per the inherited convention (RED → GREEN → refactor).

The detailed task-by-task plan lives at `docs/plan/2026-05-27-implementation.md`. High-level outline:

1. **`chore: bootstrap gemspec, Gemfile, Appraisals, CI`** — manifest, CI stub, rubocop config. CI green (auto-skip on missing specs).
2. **`chore: add Gemfile path: override for local SDK`** — §12.1 mechanism. Verify `bundle install` resolves SDK from `../sdk-ruby/`.
3. **`feat: Engine skeleton + spec/internal Combustion app`** — first passing spec: engine boots in `combustion`.
4. **`feat: Configuration object + validation + ConfigurationError`** — §6.1, §6.2. `configuration_spec.rb` covers all cases.
5. **`feat: PoliPage.client lazy accessor + Railtie wiring`** — §7.1–§7.3. `client_spec.rb` proves memoisation, thread-safety, lazy validation.
6. **`feat: FilenameEncoder helper for RFC 5987 Content-Disposition`** — §8.5. Unit specs for ASCII / non-ASCII.
7. **`feat: Renderable concern with render_pdf / render_preview / redirect_to_document`** — §8. Unit specs for each method's headers.
8. **`feat: ActiveSupport::Notifications bridge + default-on wiring`** — §10. Bridge fires events; `c.notifications = false` disables.
9. **`feat: install generator + template`** — §9. Generator spec proves file written, `--force` semantics.
10. **`test: integration spec against develop API (gated)`** — §13.4.
11. **`feat: example-app skeleton + JSON routes for all 10 SDK demo steps`** — §14.1, §14.2.
12. **`feat: example-app interactive demo UI at GET /`** — §14.3.
13. **`docs: README, CHANGELOG initial entry, LICENSE`** — install snippet, 5-line quick start, link to docs.poli.page.

Estimated effort: **3-5 working days** for a single agent with this spec in hand.

---

## 20. Open questions (none blocking v0.1.0)

- Should the gem's User-Agent augmentation include the gem's own version (`poli-page-rails/0.1.0`) alongside the SDK's default? The SDK does not currently accept a `user_agent:` kwarg (see §7.4). Track as an SDK feature request; defer the gem-side wiring until the SDK exposes the seam.
- Should `Renderable` ship a `stream_pdf(filename:, &block)` convenience helper wrapping `ActionController::Live`? Currently NO (the lifecycle implications are user-controlled). Revisit if 3+ users ask.
- Should the install generator also append a `# POLI_PAGE_API_KEY=` line to `.env` if it detects `dotenv-rails`? Tempting; rejected for v0.1.0 because credential management is out of scope and we don't want to assume `.env` (some apps use Rails encrypted credentials exclusively).

These are noted, not blocking. Implementor can decide at first encounter.
