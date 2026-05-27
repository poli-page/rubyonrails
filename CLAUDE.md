# CLAUDE.md

> Instructions for Claude Code agents working in `poli-page/rails`.

## 1. Repo at a glance

| Field        | Value |
| ------------ | ----- |
| Repository   | `poli-page/rails` |
| Type         | Framework integration (Rails engine + gem) |
| Language     | Ruby 3.1+ |
| Rails        | `>= 7.0, < 9` (matrix: 7.0, 7.1, 7.2, 8.0) |
| Registry     | RubyGems — `poli_page-rails` |
| Depends on   | `poli-page` (RubyGems, the official Ruby SDK at `/Users/mickael/Projects/sdk-ruby/`) |
| Roadmap slot | new — closes the Rails gap that `INTEGRATIONS_PLAN.md` did not originally cover (Ruby SDK landed after the plan was written) |

**Source-of-truth docs (read first):**
- `docs/spec/rails-engine-specification.md` — full design spec for v0.1.0
- `docs/plan/2026-05-27-implementation.md` — implementation plan
- `/Users/mickael/Projects/INTEGRATIONS_PLAN.md` — cross-repo umbrella note, esp. §"Cross-cutting DX patterns"
- `/Users/mickael/Projects/symfony-bundle/` — closest sister integration (DI bundle + config block + response factory + console command + event bridge); decisions copy across with idiom translation
- `/Users/mickael/Projects/laravel/` — second-closest (ServiceProvider parallels Railtie, Facade parallels module accessor)

## 2. The gem's job

This gem is a **thin wrapper** around the official Poli Page Ruby SDK (`poli-page`, source at `/Users/mickael/Projects/sdk-ruby/`). It provides:

- A `PoliPage::Rails::Engine` (subclass of `::Rails::Engine`) auto-loaded by Bundler from a host app's `Gemfile`
- A `Railtie`-backed initializer registering `Rails.application.config.poli_page` (a `PoliPage::Rails::Configuration` object)
- A lazy memoised client accessor: `PoliPage.client` returns the configured SDK `PoliPage::Client` instance
- A `PoliPage::Rails::Renderable` controller concern exposing `render_pdf`, `render_preview`, `redirect_to_document` helpers — Rails-idiomatic mirrors of `send_data` / `send_file` / `redirect_to`
- `ActiveSupport::Notifications` instrumentation: the SDK's `on_retry` / `on_error` hooks bridge into `poli_page.retry` / `poli_page.error` events automatically (default-on; opt-out, not opt-in)
- A generator: `rails generate poli_page:install` writes `config/initializers/poli_page.rb` with a commented template

**This gem does NOT** reimplement HTTP transport, retries, error mapping, idempotency, `Net::HTTP` plumbing, or anything else the SDK already does. Bug in those areas? Fix it in `sdk-ruby`, not here.

## 3. Working language

- **Code, comments, file names, commit messages, PR descriptions, repository documentation**: English.
- **Day-to-day conversation with Xavier/Mickael**: French, tutoiement.
- **Conversation in this Claude Code session**: French is fine for the chat; artifacts stay English.

## 4. TDD is mandatory

RED → GREEN → refactor for every change. Tests live in `spec/` (RSpec, mocked SDK, 90%+ of the suite) and `spec/integration/` (one happy-path test against the develop API, gated on `POLI_PAGE_API_KEY`). The Rails app for engine specs is booted via `combustion` from `spec/internal/`.

### What to test (integration-specific!)

- **Engine boot & autoload**: requiring the gem from a Rails app loads `Engine`, runs the Railtie initializers, and `Rails.application.config.poli_page` returns a frozen-after-boot `Configuration`.
- **Lazy client accessor**: `PoliPage.client` returns the same memoised `PoliPage::Client` across calls; `PoliPage.reset_client!` (private/test-only) clears it; missing `api_key` raises a clear `PoliPage::Rails::ConfigurationError` at first access (NOT at boot — see spec §6.3).
- **Configuration validation**: invalid `api_key` (no `pp_` prefix), `timeout`, `max_retries`, `retry_delay` raise `PoliPage::Rails::ConfigurationError` with the documented messages on first `PoliPage.client` call.
- **`Renderable` concern**: `render_pdf` sets `Content-Type: application/pdf`, RFC 5987 `Content-Disposition`, `Cache-Control: private, no-store`, `X-Content-Type-Options: nosniff`. `render_preview` sets `text/html; charset=utf-8`. `redirect_to_document` issues a 302 to the descriptor's presigned URL with `Cache-Control: private, no-store`. ASCII and non-ASCII filenames both encode correctly.
- **Install generator**: `rails generate poli_page:install` writes `config/initializers/poli_page.rb` with the expected commented-template body. `--force` overwrites; default refuses to clobber. **No reserved Rails-generator flags** (`--skip-namespace`, `--quiet`, `--pretend`, `--force`, etc.) get redefined — only consumed (see §10.1).
- **Notifications bridge**: invoking the SDK retry/error callable fires `ActiveSupport::Notifications.instrument('poli_page.retry', ...)` / `'poli_page.error'`. Setting `config.poli_page.notifications = false` disables it.

### What NOT to test (the SDK already does)

- HTTP transport behaviour (`Net::HTTP` edge cases, proxy/CA chains)
- Retry policy (backoff, max attempts, `Retry-After`, never-retry-4xx)
- 4xx / 5xx → exception class mapping (`ValidationError`, `AuthenticationError`, etc.)
- Idempotency-Key generation
- Stream chunking correctness
- Wire envelope (`Internal::Wire.from_wire` / `to_wire`)
- API contract drift — the SDK's contract specs own that

Re-testing these here wastes time and creates double-maintenance burden. The SDK's `spec/` suite owns transport behaviour. **If you find yourself writing a stubbed HTTP server with `WebMock` for retry semantics, stop — you're doing the SDK's job.**

## 5. Robustness over shortcuts

Mickael's hard rule (validated across symfony-bundle, laravel, nextjs sessions): **no hacks to make a spec pass or a corner case go away**. Fix root causes. If a workaround is genuinely required (framework bug, SDK quirk), document it inline with a `# Why:` comment naming the constraint.

Concretely: do not sprinkle `# rubocop:disable` to silence warnings, do not `RSpec.describe ..., :skip` to dodge a flaky test, do not catch-and-swallow `PoliPage::Error` in production code paths, do not stub `PoliPage::Client` at the top level to avoid wiring the test container properly.

## 6. Code conventions

- **RuboCop** with `rubocop`, `rubocop-rails`, `rubocop-rspec`, `rubocop-performance`. Pinned in `.rubocop.yml`. `NewCops: enable`.
- **RBS signatures** in `sig/` mirror the SDK's discipline (the SDK ships `sig/`, this gem mirrors it for `lib/`).
- No commented-out code, no `# TODO` without a linked issue, no `puts`/`pp` debug prints in committed code.
- Default to no comments. Add one only when the *why* is non-obvious. Comments restating *what* the code does are noise.
- **Frozen string literals** (`# frozen_string_literal: true`) at the top of every Ruby file. Matches SDK convention.
- **No `Rails.logger` writes from `lib/poli_page/rails/`** outside the Railtie's `initializer` blocks. The SDK accepts an injected `logger:` — pass `Rails.logger` to it once, at engine boot, and let the SDK do the logging.

## 7. Commits and PRs

- **Conventional Commits**: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- **One concern per PR**, reviewable in under 30 minutes.
- PR description: what changed, why, how it was tested.
- CI must be green before merge.

## 8. CI

Workflow: `.github/workflows/ci.yml`. Matrix: Ruby `{3.1, 3.2, 3.3, 3.4}` × Rails `{7.0, 7.1, 7.2, 8.0}` with `appraisal`. Excludes the impossible combinations (Rails 8.0 needs Ruby ≥ 3.2; Rails 7.0 specs against Ruby 3.4 are allowed but tagged). Each step auto-skips if the relevant config is missing (so a freshly scaffolded repo is green from day one). Don't change that behaviour.

When working in this repo:
- After adding `poli_page-rails.gemspec` + `Gemfile`, the install step lights up.
- After adding `.rubocop.yml`, the lint step lights up.
- After adding specs in `spec/`, the test step lights up.

## 9. Unpublished SDK note

The Ruby SDK is **not yet on RubyGems** (`poli-page` is reserved; `1.0.0.rc.1` lives in `/Users/mickael/Projects/sdk-ruby/`). We use a `Gemfile` `path:` block for local dev — the gemspec stays clean (`spec.add_dependency "poli-page", "~> 1.0"`). See `docs/spec/rails-engine-specification.md` §12 for the full workaround.

When the SDK publishes:
1. Remove the `gem "poli-page", path: "../sdk-ruby"` line from the `Gemfile`.
2. `bundle update poli-page` (resolves from RubyGems).
3. Tag v0.1.0.

**Gem source code is untouched** by this transition — only the dev environment is.

## 10. Known gotchas (battle-tested — don't relearn the hard way)

These surfaced in `symfony-bundle` / `laravel` / `nextjs` or are Rails-specific. Recorded so future agents don't burn a session rediscovering them.

### 10.1 Rails reserves several generator and rake-task option names

Rails generators silently accept these global flags via `Thor` / `Rails::Generators::Base`: `--skip-namespace`, `--skip-collision-check`, `--quiet`/`-q`, `--pretend`/`-p`, `--force`/`-f`, `--skip`/`-s`, `--help`/`-h`. Rake tasks reserve `--trace`, `--quiet`, `--describe`, `--tasks`, `--silent`. **Never define a generator option with any of these names** — the option will be shadowed and the generator will appear broken with no error.

The `poli_page:install` generator therefore has **zero custom options** in v0.1.0 (it has one positional path argument with a default). If we add options later, prefix them with the noun they describe (`--initializer-path`, not `--path`). Symfony Console's `--version` shadowing on the symfony-bundle's `poli-page:render` command is the cautionary tale; same shape applies here.

### 10.2 RSpec runner & `ActiveSupport::Notifications` subscriber leaks

`Rails.application.initialize!` (called by `combustion` for engine specs) registers `Signal.trap('INT')` / `Signal.trap('TERM')` handlers, plus framework-level `ActiveSupport::Notifications` subscribers. Repeated boot/teardown across specs leaks them. RSpec doesn't fail on this by default, but we want clean handler state for deterministic notification specs.

Fix at the fixture layer with `spec/support/restores_global_handlers.rb` (port from `symfony-bundle/tests/RestoresGlobalHandlers.php`, idiom-translated to Ruby):

- Snapshot `Signal.trap('INT') { ... }` and `Signal.trap('TERM') { ... }` (returns the previous handler symbol) in a `before(:suite)` block.
- In `after(:each)` of any spec that boots a Rails app or registers notification listeners: `ActiveSupport::Notifications.unsubscribe(subscriber)` for every subscriber the spec registered. Track via a small `NotificationsLeakDetector` helper that snapshots `ActiveSupport::Notifications.notifier.listeners_for('poli_page.retry').size` in `before` and asserts equality in `after`.

**Do NOT** disable RSpec's `--warnings` or wrap specs in `:skip` to avoid the noise. Same rule as symfony-bundle §10.1.

### 10.3 Single root `.env`, no per-app `.env.local`

Both the engine specs (via `spec/spec_helper.rb`) and the example app (via `config/application.rb`) load env vars from the workspace's root `.env` at `/Users/mickael/Projects/symfony-bundle/.env` (the de-facto root shared with the other integrations). We use `dotenv-rails` with an explicit absolute path:

```ruby
# spec/spec_helper.rb (or example-app/config/application.rb)
require "dotenv"
Dotenv.load(
  File.expand_path("../../symfony-bundle/.env", __dir__),  # workspace root
  ".env.local",                                            # per-app override (optional)
  ".env"                                                   # per-app default (optional)
)
```

Real shell exports always win — `Dotenv.load` (not `Dotenv.overload`) is the right verb.

**Do NOT** instruct users to `cp .env .env.local` or introduce a per-app `.env.local`. This was an explicit hard requirement from Mickael during the symfony-bundle session. See `INTEGRATIONS_PLAN.md` §"Cross-cutting DX patterns" §2.

### 10.4 Notifications bridge is default-on (opt-out, not opt-in)

Unlike the symfony-bundle (where the EventDispatcher bridge is wired but does nothing until a listener registers) and the laravel package (where the event bridge is default-on but invisible until a listener subscribes), the Rails engine **always** subscribes the SDK's retry/error hooks to `ActiveSupport::Notifications` at boot. Users opt OUT by setting `config.poli_page.notifications = false`.

Why default-on: `ActiveSupport::Notifications` already has zero overhead when nothing is subscribed (notifier checks `@listeners.any?` first). The bridge installation cost is one `lambda` per hook. Default-on means `bullet`, `lograge`, `appsignal`, `scout_apm`, and any custom subscriber Just Work without further config — the standard Rails idiom.

Justified in spec §10.5.

### 10.5 No CLI beyond the generator

Rails has no per-app `bin/rails poli_page:render` slot we should attach to without polluting the Rake namespace. The example app's `bin/rails server` IS the smoke test. The `render_to_file` SDK demo (step 3) is a standalone `bin/rake demo:render_to_file` task **inside the example app**, in the example app's `app:` namespace (defined under `example-app/lib/tasks/demo.rake`), NOT in the gem's `lib/tasks/`. Do not invent additional rake tasks in the gem itself.

### 10.6 `PoliPage::Client` is shared across threads; do not memoise per-thread

The SDK's `Client` is documented thread-safe (configuration is immutable post-`#initialize`; each request opens its own `Net::HTTP` connection). The lazy memoisation in `PoliPage.client` uses a `Mutex` around `@client ||= ...`, NOT `Thread.current[:poli_page_client]`. Puma's threaded worker mode (and Falcon's fiber-per-request) both share the memoised instance correctly. Don't try to "fix" perceived thread issues — the SDK owns thread safety.

## 11. When stuck

- Re-read `docs/spec/rails-engine-specification.md` first; most "open questions" are answered there or in §18 "Resolved decisions".
- Compare with the SDK reference at `/Users/mickael/Projects/sdk-ruby/` — read `lib/poli_page/client.rb` constructor and `lib/poli_page/errors.rb` before inventing API shape.
- Compare with `/Users/mickael/Projects/symfony-bundle/` and `/Users/mickael/Projects/laravel/` — same product, sister frameworks; decisions you can copy directly with idiom translation.
- Compare patterns with `sentry-rails`, `stripe-ruby` (gem) + `stripe-rails` (community), `aws-sdk-rails`, `appsignal-ruby`, `pundit`, `devise` (engine shape). The bar.
- Ask Mickael early. A two-line message is faster than a half-day rebuilding the wrong thing.
- If a CI failure looks unrelated to your change, check `main` first before assuming you caused it.
