# `poli_page-rails` v0.1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship v0.1.0 of `poli_page-rails` — a Rails engine + gem wrapping the official Ruby SDK (`poli-page` at `../sdk-ruby/`), giving Rails apps a memoised `PoliPage.client` accessor, a `Renderable` controller concern for PDF/HTML/redirect responses, an `ActiveSupport::Notifications` bridge for SDK retry/error hooks, an install generator, and a runnable `example-app/` with an interactive single-page demo UI covering every SDK method.

**Architecture:** Standard Rails engine — one `Engine < ::Rails::Engine` + one `Railtie < ::Rails::Railtie`. Top-level `PoliPage.client` lazy memoised accessor (Monitor-guarded; shared across threads per SDK thread-safety guarantee). Configuration via `Rails.application.config.poli_page` block. Wraps without reimplementing — HTTP, retries, error mapping all stay in the SDK. `Net::HTTP` plumbing is entirely the SDK's concern.

**Tech Stack:** Ruby 3.2+, Rails 7.0 / 7.1 / 7.2 / 8.0, RSpec 3.13 + rspec-rails 6.1, combustion 1.5, appraisal 2.5, rubocop + rubocop-rails + rubocop-rspec + rubocop-performance, dotenv-rails 3.1, Bundler 2.4+ (path: override for local-dev SDK, removed at SDK publish).

**Spec:** `/Users/mickael/Projects/rubyonrails/docs/spec/rails-engine-specification.md` — authoritative source for all design decisions. This plan implements that spec in 13 bite-sized, independently-reviewable tasks.

**Working directory throughout:** `/Users/mickael/Projects/rubyonrails/`

---

## Pre-flight: clean the scaffold

Before Task 1, remove any inherited placeholders so they do not end up in the same commit as real code.

- [ ] **Step 0.1: Inspect current state**

```bash
cd /Users/mickael/Projects/rubyonrails
git status
ls -la
```

Expected: the repo is empty except for `.gitignore`, `.git/`, and the `docs/` directory containing this plan + the spec.

- [ ] **Step 0.2: Confirm SDK reachable**

```bash
ls /Users/mickael/Projects/sdk-ruby/poli-page.gemspec
ls /Users/mickael/Projects/sdk-ruby/lib/poli_page/client.rb
```

Both must exist. The `Gemfile` `path:` override (§12 of the spec) assumes the SDK lives at `/Users/mickael/Projects/sdk-ruby/`.

- [ ] **Step 0.3: Confirm SDK constant root**

```bash
grep -rE "^module PoliPage" /Users/mickael/Projects/sdk-ruby/lib | head -5
```

Expected output includes `module PoliPage` lines. The gem's top-level constant root is `PoliPage`; our additions nest under `PoliPage::Rails` and we re-open the SDK's `PoliPage` module to add `PoliPage.client`.

---

## Task 1: Bootstrap gemspec, Gemfile, tooling, and CI

**Files:**
- Create: `poli_page-rails.gemspec`
- Create: `Gemfile`
- Create: `Rakefile`
- Create: `.rubocop.yml`
- Create: `Appraisals`
- Create: `lib/poli_page/rails/version.rb`
- Create: `lib/poli_page-rails.rb` (top-level entry, empty stub)
- Create: `.github/workflows/ci.yml`
- Modify: `.gitignore` (append)

**Goal:** `bundle install` succeeds (against the local SDK via path-override added in Task 2). CI runs green (with auto-skip on no-specs-yet behaviour). No gem behaviour yet.

- [ ] **Step 1.1: Write `lib/poli_page/rails/version.rb`**

Needed before the gemspec because the gemspec `require`s this file.

Create `/Users/mickael/Projects/rubyonrails/lib/poli_page/rails/version.rb`:

```ruby
# frozen_string_literal: true

module PoliPage
  module Rails
    VERSION = "0.1.0"
  end
end
```

- [ ] **Step 1.2: Write `lib/poli_page-rails.rb` (top-level entry stub)**

Bundler discovers the gem via this file's name (matches the gemspec `name`). Empty for now — Task 3 wires the Engine require.

Create `/Users/mickael/Projects/rubyonrails/lib/poli_page-rails.rb`:

```ruby
# frozen_string_literal: true

require_relative "poli_page/rails/version"

# Task 3 will add:
#   require "poli_page"
#   require_relative "poli_page/rails/engine"
#   require_relative "poli_page/rails/railtie"
```

- [ ] **Step 1.3: Write `poli_page-rails.gemspec`**

Create `/Users/mickael/Projects/rubyonrails/poli_page-rails.gemspec`:

```ruby
# frozen_string_literal: true

require_relative "lib/poli_page/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "poli_page-rails"
  spec.version     = PoliPage::Rails::VERSION
  spec.summary     = "Rails engine for the Poli Page PDF rendering API"
  spec.description = "Rails engine + controller concern + ActiveSupport::Notifications " \
                     "bridge over the official poli-page Ruby SDK. Lazy-memoised " \
                     "PoliPage.client, RFC 5987 Content-Disposition handling, opt-out " \
                     "notifications instrumentation, and a rails generate poli_page:install " \
                     "generator that writes config/initializers/poli_page.rb."
  spec.authors     = ["Poli Page"]
  spec.email       = "support@poli.page"
  spec.homepage    = "https://poli.page"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri"          => "https://poli.page",
    "source_code_uri"       => "https://github.com/poli-page/rails",
    "changelog_uri"         => "https://github.com/poli-page/rails/blob/main/CHANGELOG.md",
    "bug_tracker_uri"       => "https://github.com/poli-page/rails/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.{rb,tt}"] + Dir["sig/**/*.rbs"] +
               %w[LICENSE README.md CHANGELOG.md].select { |f| File.exist?(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "poli-page",     "~> 1.0"
  spec.add_dependency "railties",      ">= 7.0", "< 9"
  spec.add_dependency "actionpack",    ">= 7.0", "< 9"
  spec.add_dependency "activesupport", ">= 7.0", "< 9"
end
```

- [ ] **Step 1.4: Write `Gemfile`**

Create `/Users/mickael/Projects/rubyonrails/Gemfile`:

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Why: poli-page (the SDK) is not yet on RubyGems. Path override lives in the
# Gemfile so the gemspec stays Packagist-ready. Delete this line once
# poli-page publishes; everything else continues to work unchanged.
gem "poli-page", path: "../sdk-ruby"

group :development, :test do
  gem "rake",        "~> 13.2"
  gem "rspec-rails", "~> 6.1"
  gem "combustion",  "~> 1.5"
  gem "appraisal",   "~> 2.5"
  gem "rubocop",             require: false
  gem "rubocop-rails",       require: false
  gem "rubocop-rspec",       require: false
  gem "rubocop-performance", require: false
  gem "dotenv",      "~> 3.1"
end
```

> **Note:** `dotenv` (not `dotenv-rails`) in the gem's Gemfile because we use it directly from `spec_helper.rb`, not as a Rails-app gem. The example app uses `dotenv-rails`.

- [ ] **Step 1.5: Write `Rakefile`**

Create `/Users/mickael/Projects/rubyonrails/Rakefile`:

```ruby
# frozen_string_literal: true

require "bundler/gem_tasks"

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # rspec not installed yet; skip
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  # rubocop not installed yet; skip
end

task default: %i[rubocop spec]
```

- [ ] **Step 1.6: Write `.rubocop.yml`**

Create `/Users/mickael/Projects/rubyonrails/.rubocop.yml`:

```yaml
require:
  - rubocop-rails
  - rubocop-rspec
  - rubocop-performance

AllCops:
  NewCops: enable
  TargetRubyVersion: 3.2
  TargetRailsVersion: 7.0
  Exclude:
    - "vendor/**/*"
    - "tmp/**/*"
    - "gemfiles/**/*"
    - "example-app/db/schema.rb"
    - "spec/internal/**/*"

Style/Documentation:
  Enabled: false

Metrics/BlockLength:
  Exclude:
    - "spec/**/*"
    - "*.gemspec"

Layout/LineLength:
  Max: 120

RSpec/ExampleLength:
  Max: 20

RSpec/MultipleExpectations:
  Max: 5

Rails/ApplicationController:
  Enabled: false  # Engine specs use combustion's bare ApplicationController
```

- [ ] **Step 1.7: Write `Appraisals`**

Create `/Users/mickael/Projects/rubyonrails/Appraisals`:

```ruby
# frozen_string_literal: true

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

- [ ] **Step 1.8: Write `.github/workflows/ci.yml`**

Create `/Users/mickael/Projects/rubyonrails/.github/workflows/ci.yml`:

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
          else
            echo "Skipping appraisal: no Appraisals yet"
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
          if [ -d spec ] && compgen -G "spec/**/*_spec.rb" > /dev/null; then
            bundle exec appraisal "rails-${{ matrix.rails }}" rspec --exclude-pattern "spec/integration/**/*"
          else
            echo "Skipping specs: no *_spec.rb yet"
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
        with:
          ruby-version: '3.3'
          bundler-cache: true
          working-directory: rails
      - name: Integration spec against develop API
        working-directory: rails
        env:
          POLI_PAGE_API_KEY: ${{ secrets.POLI_PAGE_DEVELOP_API_KEY }}
        run: |
          if [ -d spec/integration ] && compgen -G "spec/integration/*_spec.rb" > /dev/null; then
            bundle exec rspec spec/integration
          else
            echo "Skipping integration spec: no spec/integration yet"
          fi
```

- [ ] **Step 1.9: Append to `.gitignore`**

Read the existing `.gitignore` first, then append (only entries not already present):

```
/Gemfile.lock
/gemfiles/*.gemfile.lock
/.rspec_status
/spec/internal/log/*.log
/spec/internal/tmp/
/pkg/
.byebug_history
```

`Gemfile.lock` for libraries is NOT committed (matches sentry-rails, rspec-rails, devise — every Bundler-published gem). It's regenerated on every `bundle install`. The example-app's lock file is a different story (Task 11).

- [ ] **Step 1.10: Verify `bundle install` succeeds**

```bash
cd /Users/mickael/Projects/rubyonrails
bundle install
```

Expected: `Bundle complete!` with `poli-page (1.0.0.rc.1)` resolved from `../sdk-ruby/`. If you see `Could not find poli-page in any source`, verify the `Gemfile` line and the SDK path.

- [ ] **Step 1.11: Verify `bundle exec rubocop` runs (may report offences; that's OK)**

```bash
bundle exec rubocop
```

Expected: rubocop finds files and reports any style issues. Fix any rubocop offences in the files this task created. Should converge to 0 offences before commit.

- [ ] **Step 1.12: Commit**

```bash
cd /Users/mickael/Projects/rubyonrails
git add poli_page-rails.gemspec Gemfile Rakefile .rubocop.yml Appraisals \
        lib/poli_page-rails.rb lib/poli_page/rails/version.rb \
        .github/workflows/ci.yml .gitignore
git commit -m "$(cat <<'EOF'
chore: bootstrap gemspec, Gemfile, Appraisals, RuboCop, and CI

- poli_page-rails.gemspec with Rails >= 7.0 < 9 and Ruby >= 3.2 targets,
  poli-page SDK as a regular runtime dep (~> 1.0)
- Gemfile with path: '../sdk-ruby' for local-dev SDK resolution; removed
  at SDK publish (spec §12)
- Appraisals covering Rails 7.0 / 7.1 / 7.2 / 8.0
- RuboCop config with rubocop-rails, rubocop-rspec, rubocop-performance
- CI matrix Ruby {3.1, 3.2, 3.3, 3.4} x Rails {7.0, 7.1, 7.2, 8.0} with
  auto-skip on missing config and SDK sibling checkout for path: resolution
EOF
)"
```

---

## Task 2: Confirm `Gemfile` `path:` override and SDK resolution

**Files:** none new (consolidation step).

**Goal:** A second pass to confirm Task 1's `Gemfile` resolves correctly. This task could be folded into Task 1; kept separate so the unpublished-SDK workaround story is a single, reviewable commit if Task 1 grows.

- [ ] **Step 2.1: Verify SDK class is autoloadable after `bundle install`**

```bash
cd /Users/mickael/Projects/rubyonrails
bundle exec ruby -e 'require "poli_page"; puts PoliPage::Client.name'
```

Expected: `PoliPage::Client`. If you see `LoadError: cannot load such file -- poli_page`, the Gemfile path: override is wrong; check `../sdk-ruby/poli-page.gemspec` exists and the Gemfile line points at `path: "../sdk-ruby"`.

- [ ] **Step 2.2: Verify SDK retry-event class is reachable**

```bash
bundle exec ruby -e 'require "poli_page"; e = PoliPage::RetryEvent.new(attempt: 1, delay: 0.5, reason: nil); puts e.inspect'
```

Expected: `#<data PoliPage::RetryEvent attempt=1, delay=0.5, reason=nil>` (Ruby's `Data.define` formats this way).

- [ ] **Step 2.3: No commit if Task 1 already passed**

If Task 1's commit already verified resolution end-to-end, skip this commit. Otherwise:

```bash
cd /Users/mickael/Projects/rubyonrails
git commit --allow-empty -m "$(cat <<'EOF'
chore: verify Gemfile path: override resolves SDK from sibling

Smoke-check that bundle install + require "poli_page" load the SDK from
../sdk-ruby/. No code change; this commit exists as a checkpoint so the
unpublished-SDK workaround story has a clean review boundary.
EOF
)"
```

---

## Task 3: Engine skeleton + Combustion `spec/internal/` host app

**Files:**
- Create: `lib/poli_page/rails/engine.rb`
- Create: `lib/poli_page-rails.rb` (overwrite from Task 1 stub)
- Create: `spec/spec_helper.rb`
- Create: `spec/rails_helper.rb`
- Create: `spec/internal/config/application.rb`
- Create: `spec/internal/config/routes.rb`
- Create: `spec/internal/config/database.yml`
- Create: `spec/internal/log/.keep`
- Create: `spec/poli_page/rails/engine_spec.rb`

**Goal:** Combustion boots a minimal Rails app in `spec/internal/`, our engine loads, the first spec passes.

- [ ] **Step 3.1: Write the failing engine spec**

Create `/Users/mickael/Projects/rubyonrails/spec/poli_page/rails/engine_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::Engine do
  it "is loaded as a Rails::Engine subclass" do
    expect(described_class.ancestors).to include(::Rails::Engine)
  end

  it "is registered with Rails.application as an engine" do
    engine_classes = ::Rails.application.railties.map(&:class)
    expect(engine_classes).to include(PoliPage::Rails::Engine)
  end

  it "exposes its own config namespace" do
    expect(described_class.config).to respond_to(:poli_page)
  end
end
```

- [ ] **Step 3.2: Write `spec/spec_helper.rb`**

Create `/Users/mickael/Projects/rubyonrails/spec/spec_helper.rb`:

```ruby
# frozen_string_literal: true

require "dotenv"

# Why: single root .env across the entire integrations workspace (no per-app
# .env.local). Real shell exports always win — Dotenv.load (not Dotenv.overload)
# only sets vars not already present.
#
# Workspace root: /Users/mickael/Projects/symfony-bundle/.env is the de-facto
# shared root (the symfony-bundle was scaffolded first and owns the file).
Dotenv.load(
  File.expand_path("../../symfony-bundle/.env", __dir__),
  ".env.local",
  ".env"
)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random
  Kernel.srand(config.seed)
end
```

- [ ] **Step 3.3: Write `spec/rails_helper.rb`**

Create `/Users/mickael/Projects/rubyonrails/spec/rails_helper.rb`:

```ruby
# frozen_string_literal: true

require_relative "spec_helper"

ENV["RAILS_ENV"] ||= "test"

require "combustion"
Combustion.path = "spec/internal"
Combustion.initialize! :action_controller, :action_dispatch do
  config.eager_load = false
  config.logger = Logger.new(IO::NULL)
end

require "rspec/rails"
require "poli_page-rails"
```

- [ ] **Step 3.4: Write `spec/internal/config/application.rb`**

The minimum config that lets combustion boot a Rails app for engine testing.

Create `/Users/mickael/Projects/rubyonrails/spec/internal/config/application.rb`:

```ruby
# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "action_dispatch/railtie"

require "poli_page-rails"

module Internal
  class Application < ::Rails::Application
    config.load_defaults ::Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.secret_key_base = "test_secret_key_base_at_least_32_characters_long_for_rails_8"
    config.session_store :cookie_store, key: "_internal_session"
    config.active_support.test_order = :random
  end
end
```

- [ ] **Step 3.5: Write `spec/internal/config/routes.rb`**

Create `/Users/mickael/Projects/rubyonrails/spec/internal/config/routes.rb`:

```ruby
# frozen_string_literal: true

Internal::Application.routes.draw do
  # Routes added in Task 7 when the Renderable concern needs a host controller
  # to mount under.
end
```

- [ ] **Step 3.6: Write `spec/internal/config/database.yml`**

Combustion needs a `database.yml` even if no DB is used; SQLite in-memory is the standard pattern.

Create `/Users/mickael/Projects/rubyonrails/spec/internal/config/database.yml`:

```yaml
test:
  adapter: sqlite3
  database: ":memory:"
```

- [ ] **Step 3.7: Touch `spec/internal/log/.keep`**

```bash
mkdir -p /Users/mickael/Projects/rubyonrails/spec/internal/log
touch /Users/mickael/Projects/rubyonrails/spec/internal/log/.keep
```

- [ ] **Step 3.8: Write the Engine class**

Create `/Users/mickael/Projects/rubyonrails/lib/poli_page/rails/engine.rb`:

```ruby
# frozen_string_literal: true

require "rails/engine"

module PoliPage
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace PoliPage::Rails

      # config.poli_page is wired by the Railtie (Task 5). This Engine class
      # exists primarily so future routes / generators / assets can ship as
      # part of v0.2 without re-architecting.
    end
  end
end
```

- [ ] **Step 3.9: Overwrite the top-level entry**

Replace `/Users/mickael/Projects/rubyonrails/lib/poli_page-rails.rb`:

```ruby
# frozen_string_literal: true

require "poli_page"
require_relative "poli_page/rails/version"
require_relative "poli_page/rails/engine"
# Task 5 will add: require_relative "poli_page/rails/railtie"
```

- [ ] **Step 3.10: Run the spec to verify GREEN**

```bash
cd /Users/mickael/Projects/rubyonrails
bundle exec rspec spec/poli_page/rails/engine_spec.rb
```

Expected: 3 examples, 0 failures.

> **If you see `Combustion::Error: spec/internal/config/application.rb missing`**: combustion's path search expected the directory layout above. Confirm `spec/internal/config/application.rb` exists with the boot module name `Internal::Application` and the constant matches what `combustion` looks for (Combustion derives the constant name from the path's last segment — `internal/` → `Internal`).

- [ ] **Step 3.11: Run rubocop**

```bash
bundle exec rubocop
```

Fix any offences. Use `.rubocop_todo.yml` only for offences that are intentional architectural choices documented in the spec — never to silence "fix this later" warnings.

- [ ] **Step 3.12: Commit**

```bash
git add lib/poli_page/rails/engine.rb lib/poli_page-rails.rb \
        spec/spec_helper.rb spec/rails_helper.rb spec/internal/ \
        spec/poli_page/rails/engine_spec.rb
git commit -m "$(cat <<'EOF'
feat: Engine skeleton + Combustion spec/internal host app

- PoliPage::Rails::Engine < ::Rails::Engine with isolate_namespace
- spec/spec_helper.rb loads ../symfony-bundle/.env via Dotenv.load
  (single workspace root; spec §13.6)
- spec/rails_helper.rb boots spec/internal via combustion
- spec/internal: minimal Rails app for engine specs
- engine_spec.rb: 3 smoke examples (loaded, registered, config namespace)
EOF
)"
```

---

## Task 4: `Configuration` object + validation + `ConfigurationError`

**Files:**
- Create: `lib/poli_page/rails/errors.rb`
- Create: `lib/poli_page/rails/configuration.rb`
- Create: `lib/poli_page/rails/configuration_validator.rb`
- Modify: `lib/poli_page-rails.rb` (add requires)
- Create: `spec/poli_page/rails/configuration_spec.rb`

**Goal:** A standalone Configuration object that can be constructed, mutated, and validated. No engine/railtie wiring yet — that's Task 5.

- [ ] **Step 4.1: Write the failing spec**

Create `/Users/mickael/Projects/rubyonrails/spec/poli_page/rails/configuration_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::Configuration do
  it "defaults every option except api_key to nil" do
    config = described_class.new

    expect(config.api_key).to be_nil
    expect(config.base_url).to be_nil
    expect(config.timeout).to be_nil
    expect(config.max_retries).to be_nil
    expect(config.retry_delay).to be_nil
    expect(config.user_agent).to be_nil
    expect(config.logger).to be_nil
    expect(config.on_retry).to be_nil
    expect(config.on_error).to be_nil
    expect(config.proxy).to be_nil
    expect(config.ca_file).to be_nil
    expect(config.ca_path).to be_nil
  end

  it "defaults notifications to true (default-on, opt-out per spec §10.5)" do
    expect(described_class.new.notifications).to be true
  end

  it "is mutable via attr_accessor for the config block idiom" do
    config = described_class.new
    config.api_key = "pp_test_abc"
    config.timeout = 42.0

    expect(config.api_key).to eq("pp_test_abc")
    expect(config.timeout).to eq(42.0)
  end

  describe "#to_client_kwargs" do
    it "drops nil values so the SDK's own defaults apply" do
      config = described_class.new
      config.api_key = "pp_test_abc"
      config.timeout = 30.0

      kwargs = config.to_client_kwargs
      expect(kwargs).to eq(api_key: "pp_test_abc", timeout: 30.0)
      expect(kwargs).not_to have_key(:base_url)
      expect(kwargs).not_to have_key(:max_retries)
    end

    it "passes through proxy / ca_file / ca_path when set" do
      config = described_class.new
      config.api_key = "pp_test_abc"
      config.proxy = "http://proxy.example.com:8080"
      config.ca_file = "/etc/ssl/corp.pem"

      kwargs = config.to_client_kwargs
      expect(kwargs[:proxy]).to eq("http://proxy.example.com:8080")
      expect(kwargs[:ca_file]).to eq("/etc/ssl/corp.pem")
    end

    it "does not include user_agent (the SDK does not currently accept it)" do
      config = described_class.new
      config.api_key = "pp_test_abc"
      config.user_agent = "MyApp/1.0"

      expect(config.to_client_kwargs).not_to have_key(:user_agent)
    end
  end
end

RSpec.describe PoliPage::Rails::ConfigurationValidator do
  subject(:validator) { described_class }

  def config(**overrides)
    PoliPage::Rails::Configuration.new.tap do |c|
      c.api_key = "pp_test_default"
      overrides.each { |k, v| c.public_send("#{k}=", v) }
    end
  end

  context "api_key" do
    it "rejects nil" do
      expect { validator.validate!(config(api_key: nil)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /api_key must start with pp_test_ or pp_live_/)
    end

    it "rejects empty string" do
      expect { validator.validate!(config(api_key: "")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /api_key must start with pp_test_ or pp_live_/)
    end

    it "rejects dashboard tokens (missing pp_ prefix)" do
      expect { validator.validate!(config(api_key: "abc_definitely_a_token")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /api_key must start with pp_test_ or pp_live_/)
    end

    it "accepts pp_test_*" do
      expect { validator.validate!(config(api_key: "pp_test_abc")) }.not_to raise_error
    end

    it "accepts pp_live_*" do
      expect { validator.validate!(config(api_key: "pp_live_xyz")) }.not_to raise_error
    end
  end

  context "base_url" do
    it "accepts nil" do
      expect { validator.validate!(config(base_url: nil)) }.not_to raise_error
    end

    it "accepts http URLs" do
      expect { validator.validate!(config(base_url: "http://example.com")) }.not_to raise_error
    end

    it "accepts https URLs" do
      expect { validator.validate!(config(base_url: "https://api.poli.page")) }.not_to raise_error
    end

    it "rejects non-http schemes" do
      expect { validator.validate!(config(base_url: "ftp://example.com")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /base_url must be an http or https URL/)
    end

    it "rejects garbage strings" do
      expect { validator.validate!(config(base_url: "not a url")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /base_url must be an http or https URL/)
    end
  end

  context "timeout" do
    it "accepts nil" do
      expect { validator.validate!(config(timeout: nil)) }.not_to raise_error
    end

    it "accepts a positive Float" do
      expect { validator.validate!(config(timeout: 30.5)) }.not_to raise_error
    end

    it "accepts a positive Integer" do
      expect { validator.validate!(config(timeout: 30)) }.not_to raise_error
    end

    it "rejects zero" do
      expect { validator.validate!(config(timeout: 0)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /timeout must be a positive number/)
    end

    it "rejects negative numbers" do
      expect { validator.validate!(config(timeout: -1)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /timeout must be a positive number/)
    end

    it "rejects values > 600" do
      expect { validator.validate!(config(timeout: 601)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /timeout must be <= 600/)
    end

    it "rejects non-numeric values" do
      expect { validator.validate!(config(timeout: "30")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /timeout must be a positive number/)
    end
  end

  context "max_retries" do
    it "accepts nil" do
      expect { validator.validate!(config(max_retries: nil)) }.not_to raise_error
    end

    it "accepts 0" do
      expect { validator.validate!(config(max_retries: 0)) }.not_to raise_error
    end

    it "accepts 10" do
      expect { validator.validate!(config(max_retries: 10)) }.not_to raise_error
    end

    it "rejects negative integers" do
      expect { validator.validate!(config(max_retries: -1)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /max_retries must be an integer between 0 and 10/)
    end

    it "rejects values > 10" do
      expect { validator.validate!(config(max_retries: 11)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /max_retries must be an integer between 0 and 10/)
    end

    it "rejects Float" do
      expect { validator.validate!(config(max_retries: 3.5)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /max_retries must be an integer between 0 and 10/)
    end
  end

  context "retry_delay" do
    it "accepts nil" do
      expect { validator.validate!(config(retry_delay: nil)) }.not_to raise_error
    end

    it "accepts 0" do
      expect { validator.validate!(config(retry_delay: 0)) }.not_to raise_error
    end

    it "accepts a positive Float" do
      expect { validator.validate!(config(retry_delay: 0.5)) }.not_to raise_error
    end

    it "rejects negative numbers" do
      expect { validator.validate!(config(retry_delay: -0.1)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /retry_delay must be a number between 0 and 30/)
    end

    it "rejects values > 30" do
      expect { validator.validate!(config(retry_delay: 31)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /retry_delay must be a number between 0 and 30/)
    end
  end

  context "notifications" do
    it "accepts true" do
      expect { validator.validate!(config(notifications: true)) }.not_to raise_error
    end

    it "accepts false" do
      expect { validator.validate!(config(notifications: false)) }.not_to raise_error
    end

    it "rejects nil" do
      expect { validator.validate!(config(notifications: nil)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /notifications must be true or false/)
    end

    it "rejects truthy non-boolean values" do
      expect { validator.validate!(config(notifications: "yes")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /notifications must be true or false/)
    end
  end

  context "on_retry / on_error" do
    it "accepts nil" do
      expect { validator.validate!(config(on_retry: nil, on_error: nil)) }.not_to raise_error
    end

    it "accepts any object responding to #call" do
      callable = ->(event) {} # standard Proc
      expect { validator.validate!(config(on_retry: callable)) }.not_to raise_error
    end

    it "rejects String (no const_get indirection — pass an actual callable)" do
      expect { validator.validate!(config(on_retry: "MyCallback")) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /on_retry must respond to #call/)
    end

    it "rejects Symbol" do
      expect { validator.validate!(config(on_error: :my_callback)) }
        .to raise_error(PoliPage::Rails::ConfigurationError, /on_error must respond to #call/)
    end
  end
end
```

- [ ] **Step 4.2: Run and verify RED**

```bash
bundle exec rspec spec/poli_page/rails/configuration_spec.rb
```

Expected: `Unable to find PoliPage::Rails::Configuration` or `NameError: uninitialized constant`.

- [ ] **Step 4.3: Write `lib/poli_page/rails/errors.rb`**

```ruby
# frozen_string_literal: true

require "poli_page/errors"

module PoliPage
  module Rails
    # Raised by ConfigurationValidator when Rails.application.config.poli_page
    # contains an invalid value. Inherits from PoliPage::Error so that existing
    # `rescue PoliPage::Error` clauses catch it.
    class ConfigurationError < PoliPage::Error
      def initialize(message)
        super(message, code: "configuration_error", status: nil, request_id: nil)
      end
    end
  end
end
```

- [ ] **Step 4.4: Write `lib/poli_page/rails/configuration.rb`**

```ruby
# frozen_string_literal: true

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
        @base_url      = nil
        @timeout       = nil
        @user_agent    = nil
        @max_retries   = nil
        @retry_delay   = nil
        @logger        = nil
        @on_retry      = nil
        @on_error      = nil
        @proxy         = nil
        @ca_file       = nil
        @ca_path       = nil
        @notifications = true
      end

      # Single source of truth for SDK kwargs. Compact drops every nil entry,
      # so the SDK's own defaults take over for every unset key. user_agent
      # is intentionally NOT included — the SDK's Client#initialize does not
      # accept it as of poli-page 1.0.0.rc.1 (sdk-ruby/lib/poli_page/client.rb).
      def to_client_kwargs
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

- [ ] **Step 4.5: Write `lib/poli_page/rails/configuration_validator.rb`**

```ruby
# frozen_string_literal: true

require "uri"

require_relative "errors"

module PoliPage
  module Rails
    module ConfigurationValidator
      module_function

      API_KEY_PATTERN = /\App_(test|live)_/

      def validate!(config)
        validate_api_key!(config.api_key)
        validate_base_url!(config.base_url)
        validate_timeout!(config.timeout)
        validate_max_retries!(config.max_retries)
        validate_retry_delay!(config.retry_delay)
        validate_notifications!(config.notifications)
        validate_callable!(config.on_retry, "on_retry")
        validate_callable!(config.on_error, "on_error")
      end

      def validate_api_key!(value)
        return if value.is_a?(String) && API_KEY_PATTERN.match?(value)

        raise ConfigurationError, "Poli Page api_key must start with pp_test_ or pp_live_. " \
                                  "Get one at https://app.poli.page/settings/api-keys."
      end

      def validate_base_url!(value)
        return if value.nil?

        uri = URI.parse(value.to_s)
        return if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

        raise ConfigurationError, "Poli Page base_url must be an http or https URL (got #{value.inspect})."
      rescue URI::InvalidURIError
        raise ConfigurationError, "Poli Page base_url must be an http or https URL (got #{value.inspect})."
      end

      def validate_timeout!(value)
        return if value.nil?

        unless value.is_a?(Numeric) && value.positive?
          raise ConfigurationError, "Poli Page timeout must be a positive number (got #{value.inspect})."
        end

        return if value <= 600

        raise ConfigurationError, "Poli Page timeout must be <= 600 seconds (got #{value.inspect})."
      end

      def validate_max_retries!(value)
        return if value.nil?
        return if value.is_a?(Integer) && (0..10).cover?(value)

        raise ConfigurationError, "Poli Page max_retries must be an integer between 0 and 10 (got #{value.inspect})."
      end

      def validate_retry_delay!(value)
        return if value.nil?
        return if value.is_a?(Numeric) && (0..30).cover?(value)

        raise ConfigurationError, "Poli Page retry_delay must be a number between 0 and 30 seconds " \
                                  "(got #{value.inspect})."
      end

      def validate_notifications!(value)
        return if value.is_a?(TrueClass) || value.is_a?(FalseClass)

        raise ConfigurationError, "Poli Page notifications must be true or false (got #{value.inspect})."
      end

      def validate_callable!(value, name)
        return if value.nil?
        return if value.respond_to?(:call) && !value.is_a?(String) && !value.is_a?(Symbol)

        raise ConfigurationError, "Poli Page #{name} must respond to #call (got #{value.class})."
      end
    end
  end
end
```

- [ ] **Step 4.6: Wire the requires**

Update `/Users/mickael/Projects/rubyonrails/lib/poli_page-rails.rb`:

```ruby
# frozen_string_literal: true

require "poli_page"
require_relative "poli_page/rails/version"
require_relative "poli_page/rails/errors"
require_relative "poli_page/rails/configuration"
require_relative "poli_page/rails/configuration_validator"
require_relative "poli_page/rails/engine"
# Task 5 will add: require_relative "poli_page/rails/railtie"
```

- [ ] **Step 4.7: Run and verify GREEN**

```bash
bundle exec rspec spec/poli_page/rails/configuration_spec.rb
```

Expected: ~40+ examples, 0 failures.

- [ ] **Step 4.8: RuboCop pass**

```bash
bundle exec rubocop
```

Fix any offences.

- [ ] **Step 4.9: Commit**

```bash
git add lib/poli_page/rails/configuration.rb lib/poli_page/rails/configuration_validator.rb \
        lib/poli_page/rails/errors.rb lib/poli_page-rails.rb \
        spec/poli_page/rails/configuration_spec.rb
git commit -m "$(cat <<'EOF'
feat: Configuration object + ConfigurationValidator + ConfigurationError

- Configuration: attr_accessor for every SDK kwarg + notifications switch.
  Defaults to nil so to_client_kwargs.compact lets SDK defaults apply.
- ConfigurationValidator: validates api_key (pp_test_/pp_live_ prefix),
  base_url (http/https), timeout (1..600), max_retries (0..10),
  retry_delay (0..30), notifications (true/false), on_retry/on_error
  (#call-responder or nil).
- ConfigurationError < PoliPage::Error so existing rescue clauses catch it.

Validation timing is lazy (runs on first PoliPage.client call, not at
boot) — keeps assets:precompile and db:create working in containers
without secrets. Spec §6.2/§6.3.
EOF
)"
```

---

## Task 5: `Railtie` + `PoliPage.client` lazy memoised accessor

**Files:**
- Create: `lib/poli_page/rails/railtie.rb`
- Create: `lib/poli_page/rails/client.rb`
- Modify: `lib/poli_page-rails.rb` (add requires)
- Create: `spec/poli_page/rails/client_spec.rb`

**Goal:** `Rails.application.config.poli_page` returns a `Configuration` object. `PoliPage.client` returns a memoised `PoliPage::Client` instance built from that config. Validation runs lazily on first access.

- [ ] **Step 5.1: Write the failing spec**

Create `/Users/mickael/Projects/rubyonrails/spec/poli_page/rails/client_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PoliPage.client (lazy memoised accessor)" do
  before { PoliPage.reset_client! }
  after  { PoliPage.reset_client! }

  def with_config(**overrides)
    config = ::Rails.application.config.poli_page
    snapshot = config.instance_variables.to_h { |iv| [iv, config.instance_variable_get(iv)] }
    overrides.each { |k, v| config.public_send("#{k}=", v) }
    yield
  ensure
    snapshot.each { |iv, v| config.instance_variable_set(iv, v) }
  end

  it "exposes Rails.application.config.poli_page as a Configuration" do
    expect(::Rails.application.config.poli_page).to be_a(PoliPage::Rails::Configuration)
  end

  it "returns a PoliPage::Client when api_key is valid" do
    with_config(api_key: "pp_test_unit") do
      client = PoliPage.client
      expect(client).to be_a(PoliPage::Client)
    end
  end

  it "memoises the client across calls" do
    with_config(api_key: "pp_test_unit") do
      a = PoliPage.client
      b = PoliPage.client
      expect(a).to be(b) # same object identity
    end
  end

  it "raises ConfigurationError on first access when api_key is missing" do
    with_config(api_key: nil) do
      expect { PoliPage.client }.to raise_error(PoliPage::Rails::ConfigurationError, /api_key/)
    end
  end

  it "does not raise at engine boot when api_key is missing (lazy validation)" do
    # If validation ran at boot, this rails_helper require would have already raised.
    # The fact that we reach this assertion proves boot was lazy.
    with_config(api_key: nil) do
      expect(::Rails.application.config.poli_page.api_key).to be_nil
    end
    expect(true).to be true
  end

  it "memoises the SAME instance across threads (SDK is thread-safe)" do
    with_config(api_key: "pp_test_unit") do
      seen = []
      mutex = Mutex.new
      threads = Array.new(8) do
        Thread.new do
          c = PoliPage.client
          mutex.synchronize { seen << c }
        end
      end
      threads.each(&:join)
      expect(seen.uniq.size).to eq(1)
    end
  end

  describe "PoliPage.reset_client!" do
    it "clears the memoised instance" do
      with_config(api_key: "pp_test_unit") do
        a = PoliPage.client
        PoliPage.reset_client!
        b = PoliPage.client
        expect(a).not_to be(b)
      end
    end
  end

  describe "Railtie defaults applied in after_initialize" do
    it "sets config.logger to Rails.logger when the user did not set one" do
      # Engine boot already ran; this assertion is a snapshot.
      expect(::Rails.application.config.poli_page.logger).to eq(::Rails.logger)
    end

    it "installs the notifications retry bridge by default" do
      expect(::Rails.application.config.poli_page.on_retry).to respond_to(:call)
    end

    it "installs the notifications error bridge by default" do
      expect(::Rails.application.config.poli_page.on_error).to respond_to(:call)
    end
  end
end
```

- [ ] **Step 5.2: Run and verify RED**

```bash
bundle exec rspec spec/poli_page/rails/client_spec.rb
```

Expected: `NoMethodError: undefined method 'client' for module PoliPage`, or similar.

- [ ] **Step 5.3: Write `lib/poli_page/rails/client.rb`**

```ruby
# frozen_string_literal: true

require "monitor"
require "poli_page"

require_relative "configuration_validator"

module PoliPage
  # Re-opened from the SDK. Adds the Rails-friendly lazy accessor.
  class << self
    def client
      Rails::Client.instance
    end

    # Test-only: clear the memoised instance so the next #client call rebuilds.
    # Marked private API; do NOT use in application code.
    def reset_client!
      Rails::Client.reset!
    end
  end

  module Rails
    # Holds the lazy memoised PoliPage::Client. Thread-safe via a Monitor.
    # The SDK documents Client as thread-safe (sdk-ruby/lib/poli_page/client.rb
    # thread-safety note), so memoising a single instance and sharing it across
    # threads is correct.
    module Client
      LOCK = Monitor.new
      private_constant :LOCK

      class << self
        def instance
          LOCK.synchronize do
            @instance ||= build!
          end
        end

        def reset!
          LOCK.synchronize do
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

- [ ] **Step 5.4: Write `lib/poli_page/rails/railtie.rb`**

The Railtie cannot reference `PoliPage::Rails::Notifications` yet (Task 8 creates it). For Task 5, the Railtie's `after_initialize` block only sets `c.logger ||= ::Rails.logger`. Task 8 extends it to install the notifications bridges.

```ruby
# frozen_string_literal: true

require "rails/railtie"

module PoliPage
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "poli_page.configure", before: :load_config_initializers do |app|
        app.config.poli_page ||= Configuration.new
      end

      # Default logger fill-in. Task 8 extends this block to install the
      # ActiveSupport::Notifications bridges as default callables.
      config.after_initialize do |app|
        c = app.config.poli_page
        c.logger ||= ::Rails.logger
      end
    end
  end
end
```

- [ ] **Step 5.5: Wire the requires**

Update `/Users/mickael/Projects/rubyonrails/lib/poli_page-rails.rb`:

```ruby
# frozen_string_literal: true

require "poli_page"
require_relative "poli_page/rails/version"
require_relative "poli_page/rails/errors"
require_relative "poli_page/rails/configuration"
require_relative "poli_page/rails/configuration_validator"
require_relative "poli_page/rails/client"
require_relative "poli_page/rails/engine"
require_relative "poli_page/rails/railtie"
# Task 8 will add: require_relative "poli_page/rails/notifications"
```

- [ ] **Step 5.6: Adjust the existing `engine_spec.rb` so config.poli_page is exposed**

The `engine_spec.rb` from Task 3 asserted `described_class.config.respond_to?(:poli_page)`. Engine-level `config.poli_page` is provided by `isolate_namespace`. Confirm the spec still passes.

```bash
bundle exec rspec spec/poli_page/rails/engine_spec.rb
```

- [ ] **Step 5.7: Run client spec and verify GREEN**

```bash
bundle exec rspec spec/poli_page/rails/client_spec.rb
```

Expected: ~10 examples, 0 failures. Two notifications-related assertions (`on_retry / on_error responds to #call`) will FAIL at this point — they expect Task 8's bridges. **Skip those two with a `pending` tag**:

```ruby
it "installs the notifications retry bridge by default", pending: "wired in Task 8" do
  expect(::Rails.application.config.poli_page.on_retry).to respond_to(:call)
end
```

The remaining 8 examples must pass.

- [ ] **Step 5.8: RuboCop pass**

```bash
bundle exec rubocop
```

- [ ] **Step 5.9: Commit**

```bash
git add lib/poli_page/rails/client.rb lib/poli_page/rails/railtie.rb lib/poli_page-rails.rb \
        spec/poli_page/rails/client_spec.rb
git commit -m "$(cat <<'EOF'
feat: PoliPage.client lazy memoised accessor + Railtie wiring

- PoliPage.client re-opens the SDK module to add a lazy class-level accessor.
- PoliPage::Rails::Client holds a Monitor-guarded @instance shared across
  threads (SDK Client is documented thread-safe).
- PoliPage.reset_client! clears the memo for test isolation.
- Railtie sets config.poli_page = Configuration.new at boot, fills in
  logger ||= Rails.logger in after_initialize. Notifications bridge
  defaults arrive in Task 8.
- Validation runs lazily on first PoliPage.client call (not at boot) —
  spec §6.3.
EOF
)"
```

---

## Task 6: `FilenameEncoder` helper (RFC 5987 Content-Disposition)

**Files:**
- Create: `lib/poli_page/rails/filename_encoder.rb`
- Modify: `lib/poli_page-rails.rb`
- Create: `spec/poli_page/rails/filename_encoder_spec.rb`

**Goal:** A pure helper returning the full `Content-Disposition` header value. ASCII-only filenames emit `attachment; filename="..."`; non-ASCII filenames emit BOTH `filename="<ascii-fallback>"` and `filename*=UTF-8''<percent-encoded>`. Verified RFC 5987 / RFC 6266 compliance.

- [ ] **Step 6.1: Write the failing spec**

Create `/Users/mickael/Projects/rubyonrails/spec/poli_page/rails/filename_encoder_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::FilenameEncoder do
  describe ".disposition" do
    context "with ASCII filename" do
      it "emits inline disposition" do
        result = described_class.disposition("invoice.pdf", inline: true)
        expect(result).to eq(%(inline; filename="invoice.pdf"))
      end

      it "emits attachment disposition" do
        result = described_class.disposition("invoice.pdf", inline: false)
        expect(result).to eq(%(attachment; filename="invoice.pdf"))
      end

      it "escapes ASCII double quotes inside the filename" do
        result = described_class.disposition('weird"name.pdf', inline: false)
        expect(result).to match(/attachment; filename="weird\\?"?name\.pdf"/)
      end
    end

    context "with non-ASCII filename" do
      it "emits both filename= (ASCII fallback) and filename*= (UTF-8) for accented chars" do
        result = described_class.disposition("résumé.pdf", inline: false)
        expect(result).to start_with("attachment; ")
        expect(result).to include('filename="') # ASCII fallback present
        expect(result).to include("filename*=UTF-8''")
        expect(result).to include("r%C3%A9sum%C3%A9.pdf") # percent-encoded UTF-8
      end

      it "handles CJK characters" do
        result = described_class.disposition("発票.pdf", inline: false)
        expect(result).to include("filename*=UTF-8''")
        expect(result).to include("%E7%99%BA%E7%A5%A8.pdf")
      end

      it "handles emoji" do
        result = described_class.disposition("🦀.pdf", inline: true)
        expect(result).to start_with("inline; ")
        expect(result).to include("filename*=UTF-8''")
      end
    end
  end
end
```

- [ ] **Step 6.2: Run and verify RED**

```bash
bundle exec rspec spec/poli_page/rails/filename_encoder_spec.rb
```

Expected: `NameError: uninitialized constant PoliPage::Rails::FilenameEncoder`.

- [ ] **Step 6.3: Write `lib/poli_page/rails/filename_encoder.rb`**

```ruby
# frozen_string_literal: true

require "action_dispatch/http/content_disposition"

module PoliPage
  module Rails
    # Builds a Content-Disposition header value with RFC 5987 / RFC 6266
    # encoding for non-ASCII filenames. Thin wrapper over Rails's own
    # ActionDispatch::Http::ContentDisposition.format, which is what
    # ActiveStorage uses to set the same header for downloaded blobs.
    #
    # Why a wrapper at all: this gives us a single seam if Rails changes the
    # Content-Disposition formatting API across versions (it has been stable
    # since Rails 5.2, but we want one place to patch if it changes).
    module FilenameEncoder
      module_function

      def disposition(filename, inline:)
        disposition_type = inline ? "inline" : "attachment"
        ::ActionDispatch::Http::ContentDisposition.format(
          disposition: disposition_type,
          filename: filename
        )
      end
    end
  end
end
```

- [ ] **Step 6.4: Wire the require**

Update `/Users/mickael/Projects/rubyonrails/lib/poli_page-rails.rb` to add:

```ruby
require_relative "poli_page/rails/filename_encoder"
```

- [ ] **Step 6.5: Run and verify GREEN**

```bash
bundle exec rspec spec/poli_page/rails/filename_encoder_spec.rb
```

Expected: 6 examples, 0 failures.

- [ ] **Step 6.6: RuboCop**

```bash
bundle exec rubocop
```

- [ ] **Step 6.7: Commit**

```bash
git add lib/poli_page/rails/filename_encoder.rb lib/poli_page-rails.rb \
        spec/poli_page/rails/filename_encoder_spec.rb
git commit -m "$(cat <<'EOF'
feat: FilenameEncoder helper for RFC 5987 Content-Disposition

Thin wrapper over ActionDispatch::Http::ContentDisposition.format —
the same helper ActiveStorage uses for downloaded blob headers. ASCII
filenames emit filename="..."; non-ASCII filenames emit both
filename="<ascii-fallback>" and filename*=UTF-8''<percent-encoded>.

Single seam if Rails changes the formatting API across versions.
EOF
)"
```

---

## Task 7: `Renderable` controller concern

**Files:**
- Create: `lib/poli_page/rails/renderable.rb`
- Modify: `lib/poli_page-rails.rb`
- Create: `spec/internal/app/controllers/renderable_test_controller.rb`
- Modify: `spec/internal/config/routes.rb`
- Create: `spec/poli_page/rails/renderable_spec.rb`

**Goal:** `include PoliPage::Rails::Renderable` adds `render_pdf`, `render_preview`, `redirect_to_document` to a controller. Each helper sets the correct headers (RFC 5987 disposition, cache, content-type).

- [ ] **Step 7.1: Write a test controller in the internal app**

Create `/Users/mickael/Projects/rubyonrails/spec/internal/app/controllers/renderable_test_controller.rb`:

```ruby
# frozen_string_literal: true

class RenderableTestController < ActionController::Base
  include PoliPage::Rails::Renderable

  def pdf_attachment
    render_pdf("%PDF-1.4 fake pdf bytes", filename: params[:filename] || "doc.pdf",
                                          inline: ActiveModel::Type::Boolean.new.cast(params[:inline]))
  end

  def preview
    fake_preview = OpenStruct.new(html: "<h1>Hello</h1>", page_count: 1)
    render_preview(fake_preview)
  end

  def redirect_doc
    fake_descriptor = OpenStruct.new(presigned_pdf_url: "https://example-cdn.example.com/doc.pdf?sig=abc")
    redirect_to_document(fake_descriptor)
  end
end
```

> **Why `OpenStruct`**: matches the SDK's `DocumentDescriptor` / `PreviewResult` duck-typed shape without coupling tests to the SDK's specific `Data.define` types. The Renderable concern uses `respond_to?(:html)` and `.presigned_pdf_url`, both of which OpenStruct satisfies.

- [ ] **Step 7.2: Add routes**

Update `/Users/mickael/Projects/rubyonrails/spec/internal/config/routes.rb`:

```ruby
# frozen_string_literal: true

Internal::Application.routes.draw do
  get "renderable_test/pdf_attachment", to: "renderable_test#pdf_attachment"
  get "renderable_test/preview",        to: "renderable_test#preview"
  get "renderable_test/redirect_doc",   to: "renderable_test#redirect_doc"
end
```

- [ ] **Step 7.3: Write the failing spec**

Create `/Users/mickael/Projects/rubyonrails/spec/poli_page/rails/renderable_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::Renderable, type: :request do
  describe "#render_pdf" do
    context "with ASCII filename, default (attachment) disposition" do
      before { get "/renderable_test/pdf_attachment", params: { filename: "invoice.pdf" } }

      it "responds 200" do
        expect(response).to have_http_status(:ok)
      end

      it "sets Content-Type to application/pdf" do
        expect(response.content_type).to start_with("application/pdf")
      end

      it "sets Content-Disposition to attachment with the filename" do
        expect(response.headers["Content-Disposition"]).to include("attachment;")
        expect(response.headers["Content-Disposition"]).to include('filename="invoice.pdf"')
      end

      it "sets Cache-Control to private, no-store" do
        expect(response.headers["Cache-Control"]).to include("private")
        expect(response.headers["Cache-Control"]).to include("no-store")
      end

      it "sets X-Content-Type-Options to nosniff" do
        expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
      end

      it "returns the PDF bytes as the body" do
        expect(response.body).to eq("%PDF-1.4 fake pdf bytes")
      end
    end

    context "with inline: true" do
      before { get "/renderable_test/pdf_attachment", params: { filename: "invoice.pdf", inline: "true" } }

      it "uses inline disposition" do
        expect(response.headers["Content-Disposition"]).to include("inline;")
        expect(response.headers["Content-Disposition"]).not_to include("attachment;")
      end
    end

    context "with non-ASCII filename" do
      before { get "/renderable_test/pdf_attachment", params: { filename: "résumé.pdf" } }

      it "emits filename*=UTF-8''... with percent-encoded bytes (RFC 5987)" do
        expect(response.headers["Content-Disposition"]).to include("filename*=UTF-8''")
        expect(response.headers["Content-Disposition"]).to include("r%C3%A9sum%C3%A9.pdf")
      end

      it "also emits the ASCII fallback filename" do
        expect(response.headers["Content-Disposition"]).to include('filename="')
      end
    end
  end

  describe "#render_preview" do
    before { get "/renderable_test/preview" }

    it "responds 200" do
      expect(response).to have_http_status(:ok)
    end

    it "sets Content-Type to text/html; charset=utf-8" do
      expect(response.content_type).to include("text/html")
      expect(response.content_type).to include("charset=utf-8")
    end

    it "sets Cache-Control to private, no-store" do
      expect(response.headers["Cache-Control"]).to include("private")
      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "renders the .html attribute as the body" do
      expect(response.body).to eq("<h1>Hello</h1>")
    end
  end

  describe "#redirect_to_document" do
    before { get "/renderable_test/redirect_doc" }

    it "responds 302" do
      expect(response).to have_http_status(:found)
    end

    it "sets Location to the descriptor's presigned URL" do
      expect(response.headers["Location"]).to eq("https://example-cdn.example.com/doc.pdf?sig=abc")
    end

    it "sets Cache-Control to private, no-store" do
      expect(response.headers["Cache-Control"]).to include("private")
      expect(response.headers["Cache-Control"]).to include("no-store")
    end
  end
end
```

- [ ] **Step 7.4: Run and verify RED**

```bash
bundle exec rspec spec/poli_page/rails/renderable_spec.rb
```

Expected: `NameError: uninitialized constant PoliPage::Rails::Renderable`.

- [ ] **Step 7.5: Write `lib/poli_page/rails/renderable.rb`**

```ruby
# frozen_string_literal: true

require "active_support/concern"

require_relative "filename_encoder"

module PoliPage
  module Rails
    module Renderable
      extend ::ActiveSupport::Concern

      # Sends raw PDF bytes with PDF headers + RFC 5987 Content-Disposition.
      #
      # @param bytes    [String]  raw PDF bytes (binary-encoded)
      # @param filename [String]  used in Content-Disposition; ASCII and
      #                           non-ASCII both handled per RFC 5987 / RFC 6266
      # @param inline   [Boolean] inline (browser viewer) vs attachment (download)
      def render_pdf(bytes, filename: "document.pdf", inline: false)
        response.headers["Content-Type"]        = "application/pdf"
        response.headers["Content-Disposition"] = FilenameEncoder.disposition(filename, inline: inline)
        response.headers["Cache-Control"]       = "private, no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        send_data(
          bytes,
          type: "application/pdf",
          disposition: inline ? "inline" : "attachment",
          filename: filename
        )
        # send_data triggers the header re-write Rails does for Content-Disposition;
        # we set our own afterwards so the RFC 5987 encoding wins. Order matters.
        response.headers["Content-Disposition"] = FilenameEncoder.disposition(filename, inline: inline)
      end

      # Renders the .html attribute of a PreviewResult or DocumentPreviewResult.
      # The HTML is a complete document; bypass layouts.
      def render_preview(result)
        html = result.respond_to?(:html) ? result.html : result.to_s
        response.headers["Cache-Control"]          = "private, no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        render html: html.html_safe, layout: false, content_type: "text/html; charset=utf-8"
      end

      # 302 to the descriptor's presigned URL. Adds Cache-Control so the
      # redirect itself never gets intermediary-cached.
      def redirect_to_document(descriptor, status: :found)
        response.headers["Cache-Control"] = "private, no-store"
        redirect_to descriptor.presigned_pdf_url, status: status, allow_other_host: true
      end
    end
  end
end
```

> **Why the double Content-Disposition assignment**: `send_data` internally calls `set_content_disposition` which re-formats the header using Rails's own logic. We set it again AFTER `send_data` so the RFC 5987 output of `FilenameEncoder` is the final value. Tested in §7.3.

- [ ] **Step 7.6: Wire the require**

Update `/Users/mickael/Projects/rubyonrails/lib/poli_page-rails.rb` to add:

```ruby
require_relative "poli_page/rails/renderable"
```

- [ ] **Step 7.7: Run and verify GREEN**

```bash
bundle exec rspec spec/poli_page/rails/renderable_spec.rb
```

Expected: ~12 examples, 0 failures.

- [ ] **Step 7.8: Run the full suite**

```bash
bundle exec rspec
```

Expected: all specs pass (or the two pending notifications-related examples in client_spec.rb still pending).

- [ ] **Step 7.9: RuboCop**

```bash
bundle exec rubocop
```

- [ ] **Step 7.10: Commit**

```bash
git add lib/poli_page/rails/renderable.rb lib/poli_page-rails.rb \
        spec/internal/app/controllers/renderable_test_controller.rb \
        spec/internal/config/routes.rb \
        spec/poli_page/rails/renderable_spec.rb
git commit -m "$(cat <<'EOF'
feat: Renderable controller concern (render_pdf / render_preview / redirect_to_document)

- render_pdf: send_data with application/pdf, RFC 5987 Content-Disposition
  (via FilenameEncoder), Cache-Control: private, no-store, X-Content-Type-
  Options: nosniff. Supports inline: true|false.
- render_preview: text/html; charset=utf-8, no-store, no-sniff. Bypasses
  layouts since the HTML is a complete document.
- redirect_to_document: 302 to descriptor.presigned_pdf_url with
  allow_other_host: true (Rails 7+ default-blocks cross-host redirects).

Smoke-tested via request specs against a RenderableTestController in the
spec/internal Rails app — covers ASCII + non-ASCII filenames, inline vs
attachment, all three helpers.
EOF
)"
```

---

## Task 8: `ActiveSupport::Notifications` bridge (default-on)

**Files:**
- Create: `lib/poli_page/rails/notifications.rb`
- Modify: `lib/poli_page/rails/railtie.rb` (install bridges in after_initialize)
- Modify: `lib/poli_page-rails.rb`
- Create: `spec/support/notifications_leak_detector.rb`
- Create: `spec/poli_page/rails/notifications_spec.rb`
- Modify: `spec/rails_helper.rb` (require support files)
- Modify: `spec/poli_page/rails/client_spec.rb` (remove pending tags)

**Goal:** The SDK's retry/error hooks fire `ActiveSupport::Notifications.instrument` events by default. `c.notifications = false` disables it. Users who set their own `on_retry`/`on_error` callable replace the bridge entirely.

- [ ] **Step 8.1: Write the support file for leak detection**

Create `/Users/mickael/Projects/rubyonrails/spec/support/notifications_leak_detector.rb`:

```ruby
# frozen_string_literal: true

require "active_support/notifications"

module PoliPage
  module Rails
    module Test
      # Snapshots ActiveSupport::Notifications subscriber counts for poli_page.*
      # event names. If a spec leaks a subscriber (forgets to unsubscribe) we
      # catch it in the after(:each) assertion rather than discovering it as
      # cross-spec interference much later. CLAUDE.md §10.2.
      module NotificationsLeakDetector
        EVENTS = %w[poli_page.retry poli_page.error].freeze

        def self.included(base)
          base.before do
            @notifications_baseline = EVENTS.to_h do |name|
              [name, ::ActiveSupport::Notifications.notifier.listeners_for(name).size]
            end
          end

          base.after do
            EVENTS.each do |name|
              now = ::ActiveSupport::Notifications.notifier.listeners_for(name).size
              raise "Subscriber leak on #{name}: #{@notifications_baseline[name]} → #{now}" \
                if now > @notifications_baseline[name]
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 8.2: Wire the support file into rails_helper**

Update `/Users/mickael/Projects/rubyonrails/spec/rails_helper.rb` to add (after the require block):

```ruby
Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

RSpec.configure do |config|
  config.include PoliPage::Rails::Test::NotificationsLeakDetector
end
```

- [ ] **Step 8.3: Write the failing spec**

Create `/Users/mickael/Projects/rubyonrails/spec/poli_page/rails/notifications_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliPage::Rails::Notifications do
  describe ".retry_bridge" do
    it "returns a memoised callable" do
      a = described_class.retry_bridge
      b = described_class.retry_bridge
      expect(a).to be(b)
      expect(a).to respond_to(:call)
    end

    it "fires ActiveSupport::Notifications.instrument('poli_page.retry') with the event payload" do
      received = nil
      subscriber = ::ActiveSupport::Notifications.subscribe("poli_page.retry") do |*args|
        received = ::ActiveSupport::Notifications::Event.new(*args)
      end

      event = PoliPage::RetryEvent.new(attempt: 2, delay: 0.5,
                                       reason: PoliPage::TimeoutError.new(timeout: 30))
      described_class.retry_bridge.call(event)

      expect(received).not_to be_nil
      expect(received.name).to eq("poli_page.retry")
      expect(received.payload[:attempt]).to eq(2)
      expect(received.payload[:delay]).to eq(0.5)
      expect(received.payload[:reason]).to be_a(PoliPage::TimeoutError)
    ensure
      ::ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end

  describe ".error_bridge" do
    it "returns a memoised callable" do
      expect(described_class.error_bridge).to be(described_class.error_bridge)
    end

    it "fires ActiveSupport::Notifications.instrument('poli_page.error') with the error" do
      received = nil
      subscriber = ::ActiveSupport::Notifications.subscribe("poli_page.error") do |*args|
        received = ::ActiveSupport::Notifications::Event.new(*args)
      end

      err = PoliPage::ValidationError.new("nope", code: "VALIDATION_ERROR", status: 400, request_id: "req_1")
      described_class.error_bridge.call(err)

      expect(received.name).to eq("poli_page.error")
      expect(received.payload[:error]).to be(err)
    ensure
      ::ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end

  describe "Railtie default-on behaviour" do
    it "installs the retry bridge as the default on_retry callable" do
      expect(::Rails.application.config.poli_page.on_retry).to be(described_class.retry_bridge)
    end

    it "installs the error bridge as the default on_error callable" do
      expect(::Rails.application.config.poli_page.on_error).to be(described_class.error_bridge)
    end
  end

  describe "user-set on_retry replaces the bridge" do
    # We cannot fully test this without re-booting the app; document the
    # behaviour and run the after_initialize logic in isolation.
    it "after_initialize does NOT overwrite a user-set on_retry callable" do
      original = ::Rails.application.config.poli_page.on_retry
      user_callable = ->(event) {}
      ::Rails.application.config.poli_page.on_retry = user_callable

      # Re-run the after_initialize block logic
      ::Rails.application.run_load_hooks(:poli_page_test_after_init, nil) rescue nil
      expect(::Rails.application.config.poli_page.on_retry).to be(user_callable)
    ensure
      ::Rails.application.config.poli_page.on_retry = original
    end
  end
end
```

- [ ] **Step 8.4: Run and verify RED**

```bash
bundle exec rspec spec/poli_page/rails/notifications_spec.rb
```

Expected: `NameError: uninitialized constant PoliPage::Rails::Notifications`.

- [ ] **Step 8.5: Write `lib/poli_page/rails/notifications.rb`**

```ruby
# frozen_string_literal: true

require "active_support/notifications"

module PoliPage
  module Rails
    # Bridges the SDK's on_retry / on_error Closure hooks into Rails-idiomatic
    # ActiveSupport::Notifications events.
    #
    # Event names follow Rails conventions (sql.active_record, deliver.action_mailer):
    #   - "poli_page.retry"  — fired before each retry attempt
    #   - "poli_page.error"  — fired on terminal failure (post-retries)
    #
    # Default-on: the Railtie installs the bridges as the default on_retry /
    # on_error config values. Users opt out via c.notifications = false in
    # the initializer. See spec §10.5 for the rationale.
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

- [ ] **Step 8.6: Update the Railtie to install the bridges by default**

Update `/Users/mickael/Projects/rubyonrails/lib/poli_page/rails/railtie.rb`:

```ruby
# frozen_string_literal: true

require "rails/railtie"

require_relative "notifications"

module PoliPage
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "poli_page.configure", before: :load_config_initializers do |app|
        app.config.poli_page ||= Configuration.new
      end

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

- [ ] **Step 8.7: Wire the require**

Update `/Users/mickael/Projects/rubyonrails/lib/poli_page-rails.rb` to add:

```ruby
require_relative "poli_page/rails/notifications"
```

(Order matters: `notifications` before `railtie` since the Railtie references it.)

- [ ] **Step 8.8: Remove pending tags from client_spec.rb**

Edit the two `pending: "wired in Task 8"` lines in `spec/poli_page/rails/client_spec.rb` — they now should pass.

- [ ] **Step 8.9: Run and verify GREEN**

```bash
bundle exec rspec
```

Expected: all specs pass, including the notifications spec and the formerly-pending client_spec assertions.

- [ ] **Step 8.10: RuboCop**

```bash
bundle exec rubocop
```

- [ ] **Step 8.11: Commit**

```bash
git add lib/poli_page/rails/notifications.rb lib/poli_page/rails/railtie.rb lib/poli_page-rails.rb \
        spec/poli_page/rails/notifications_spec.rb spec/support/notifications_leak_detector.rb \
        spec/rails_helper.rb spec/poli_page/rails/client_spec.rb
git commit -m "$(cat <<'EOF'
feat: ActiveSupport::Notifications bridge (default-on, opt-out)

- PoliPage::Rails::Notifications.retry_bridge / .error_bridge memoised
  lambdas that ActiveSupport::Notifications.instrument poli_page.retry /
  poli_page.error events.
- Railtie installs the bridges as the default on_retry / on_error config
  values in after_initialize when c.notifications == true (the default).
- User-set on_retry / on_error callables are preserved (||= idiom).
- spec/support/notifications_leak_detector.rb asserts no subscriber leak
  across specs — fails fast if a spec forgets to unsubscribe.

Default-on rationale (spec §10.5): AS::Notifications has near-zero
overhead with no subscribers; opt-in would mean lograge / appsignal /
scout subscribers silently get no events unless users flip a config.
EOF
)"
```

---

## Task 9: `rails generate poli_page:install` generator

**Files:**
- Create: `lib/generators/poli_page/install/install_generator.rb`
- Create: `lib/generators/poli_page/install/templates/poli_page.rb.tt`
- Create: `spec/generators/poli_page/install/install_generator_spec.rb`

**Goal:** `rails generate poli_page:install` writes `config/initializers/poli_page.rb` with the documented commented template. `--force` overwrites. Zero custom options (CLAUDE.md §10.1).

- [ ] **Step 9.1: Write the failing generator spec**

Create `/Users/mickael/Projects/rubyonrails/spec/generators/poli_page/install/install_generator_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"
require "rails/generators"
require "rails/generators/test_case"
require "fileutils"
require "tmpdir"

require_relative "../../../../lib/generators/poli_page/install/install_generator"

RSpec.describe PoliPage::Generators::InstallGenerator do
  let(:destination_root) { Dir.mktmpdir("poli_page_install_spec") }

  after { FileUtils.remove_entry(destination_root) if File.directory?(destination_root) }

  def run_generator(args = [])
    described_class.start(args, destination_root: destination_root)
  end

  it "writes config/initializers/poli_page.rb" do
    run_generator
    initializer = File.join(destination_root, "config", "initializers", "poli_page.rb")
    expect(File).to exist(initializer)
  end

  it "includes the api_key fetch from ENV" do
    run_generator
    body = File.read(File.join(destination_root, "config", "initializers", "poli_page.rb"))
    expect(body).to include('ENV.fetch("POLI_PAGE_API_KEY")')
  end

  it "includes the Rails.application.config.poli_page.tap block" do
    run_generator
    body = File.read(File.join(destination_root, "config", "initializers", "poli_page.rb"))
    expect(body).to include("Rails.application.config.poli_page.tap")
  end

  it "comments out base_url, timeout, retries, logger, proxy, ca_file, ca_path, notifications" do
    run_generator
    body = File.read(File.join(destination_root, "config", "initializers", "poli_page.rb"))
    %w[c.base_url c.timeout c.max_retries c.retry_delay c.logger c.proxy c.ca_file c.ca_path c.notifications c.on_retry c.on_error].each do |line|
      expect(body).to match(/^\s*#\s+#{Regexp.escape(line)}/), "expected #{line} to be commented out"
    end
  end

  it "starts with a frozen_string_literal magic comment" do
    run_generator
    body = File.read(File.join(destination_root, "config", "initializers", "poli_page.rb"))
    expect(body.lines.first).to eq("# frozen_string_literal: true\n")
  end

  context "with an existing initializer" do
    let(:initializer_path) { File.join(destination_root, "config", "initializers", "poli_page.rb") }

    before do
      FileUtils.mkdir_p(File.dirname(initializer_path))
      File.write(initializer_path, "# user edits in here\n")
    end

    it "refuses to overwrite by default (default Thor behaviour)" do
      # Thor's create_file with :force not passed → asks "overwrite?". In
      # non-interactive mode it skips. Verify the file is unchanged.
      run_generator
      expect(File.read(initializer_path)).to start_with("# user edits in here")
    end

    it "overwrites with --force" do
      run_generator(["--force"])
      expect(File.read(initializer_path)).to include('ENV.fetch("POLI_PAGE_API_KEY")')
    end
  end
end
```

- [ ] **Step 9.2: Run and verify RED**

```bash
bundle exec rspec spec/generators/poli_page/install/install_generator_spec.rb
```

Expected: `LoadError` or `NameError` on the generator class.

- [ ] **Step 9.3: Write the generator template**

Create `/Users/mickael/Projects/rubyonrails/lib/generators/poli_page/install/templates/poli_page.rb.tt`:

```erb
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

  # Optional — request timeout in seconds (Float). SDK default applies when nil.
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

- [ ] **Step 9.4: Write the generator class**

Create `/Users/mickael/Projects/rubyonrails/lib/generators/poli_page/install/install_generator.rb`:

```ruby
# frozen_string_literal: true

require "rails/generators"
require "rails/generators/base"

module PoliPage
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Writes config/initializers/poli_page.rb with a commented template."

      # NOTE: Zero custom options on this generator. Rails::Generators::Base
      # inherits Thor-reserved flags (--force, --pretend, --quiet, --skip,
      # --skip-namespace, --skip-collision-check). Defining a custom option
      # with any of those names would silently shadow them and make the
      # generator appear broken. CLAUDE.md §10.1.

      argument :initializer_path, type: :string, required: false,
               default: "config/initializers/poli_page.rb",
               banner: "PATH"

      def copy_initializer
        template "poli_page.rb.tt", initializer_path
      end

      def show_post_install_hint
        say ""
        say "Created #{initializer_path}.", :green
        say "Set POLI_PAGE_API_KEY in your environment, then restart the app.", :green
      end
    end
  end
end
```

- [ ] **Step 9.5: Run and verify GREEN**

```bash
bundle exec rspec spec/generators/poli_page/install/install_generator_spec.rb
```

Expected: ~8 examples, 0 failures.

- [ ] **Step 9.6: RuboCop**

```bash
bundle exec rubocop
```

- [ ] **Step 9.7: Commit**

```bash
git add lib/generators/poli_page/install/install_generator.rb \
        lib/generators/poli_page/install/templates/poli_page.rb.tt \
        spec/generators/poli_page/install/install_generator_spec.rb
git commit -m "$(cat <<'EOF'
feat: rails generate poli_page:install generator + initializer template

- InstallGenerator (Rails::Generators::Base subclass) writes
  config/initializers/poli_page.rb from poli_page.rb.tt.
- Zero custom options to avoid Thor-reserved-name shadowing
  (--force / --pretend / --quiet / --skip / --skip-namespace /
   --skip-collision-check / --help — CLAUDE.md §10.1).
- Single positional argument with a default, refuses to clobber by
  default (Thor's create_file standard); --force overwrites.
- Template is the full commented config block — base_url, timeout,
  retries, logger, proxy, ca_file, ca_path, notifications, on_retry,
  on_error all documented and commented out.
EOF
)"
```

---

## Task 10: `RestoresGlobalHandlers` support + integration spec

**Files:**
- Create: `spec/support/restores_global_handlers.rb`
- Modify: `spec/rails_helper.rb` (include the new support module)
- Create: `spec/integration/render_against_develop_api_spec.rb`

**Goal:** A support module snapshots Signal.trap state per spec; a single env-gated integration spec hits the develop API.

- [ ] **Step 10.1: Write `spec/support/restores_global_handlers.rb`**

```ruby
# frozen_string_literal: true

module PoliPage
  module Rails
    module Test
      # Snapshots Signal.trap('INT') / Signal.trap('TERM') handlers per spec.
      # Rails.application.initialize! (called by combustion) and various
      # framework boot paths can leave signal handlers installed; this support
      # module restores the snapshot in after(:each). CLAUDE.md §10.2.
      module RestoresGlobalHandlers
        SIGNALS = %w[INT TERM].freeze

        def self.included(base)
          base.before do
            @signal_baseline = SIGNALS.to_h do |sig|
              # Signal.trap returns the previous handler; immediately re-install
              # the same to read it without changing state.
              previous = Signal.trap(sig, "DEFAULT")
              Signal.trap(sig, previous)
              [sig, previous]
            end
          end

          base.after do
            SIGNALS.each do |sig|
              Signal.trap(sig, @signal_baseline[sig])
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 10.2: Include it in rails_helper**

Update `/Users/mickael/Projects/rubyonrails/spec/rails_helper.rb`'s RSpec.configure block:

```ruby
RSpec.configure do |config|
  config.include PoliPage::Rails::Test::NotificationsLeakDetector
  config.include PoliPage::Rails::Test::RestoresGlobalHandlers
end
```

- [ ] **Step 10.3: Write the integration spec**

Create `/Users/mickael/Projects/rubyonrails/spec/integration/render_against_develop_api_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rendering against the develop API", :integration do
  before do
    skip "POLI_PAGE_API_KEY not set" if ENV["POLI_PAGE_API_KEY"].to_s.empty?
    if ENV["POLI_PAGE_API_KEY"].to_s.start_with?("pp_live_")
      skip "Refusing to run integration spec with a pp_live_* key (safety belt)"
    end
  end

  it "renders the canonical getting-started/welcome template" do
    config = ::Rails.application.config.poli_page
    snapshot = { api_key: config.api_key, base_url: config.base_url }

    config.api_key  = ENV.fetch("POLI_PAGE_API_KEY")
    config.base_url = ENV.fetch("POLI_PAGE_BASE_URL", "https://api-develop.poli.page")
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
  ensure
    config.api_key  = snapshot[:api_key]
    config.base_url = snapshot[:base_url]
    PoliPage.reset_client!
  end
end
```

- [ ] **Step 10.4: Verify the integration spec runs (or skips cleanly)**

Without an API key set:

```bash
bundle exec rspec spec/integration
```

Expected: `1 example, 0 failures, 1 pending` (the skip clause prints a clean message).

With an API key set (manual maintainer test only):

```bash
POLI_PAGE_API_KEY=pp_test_yourkey bundle exec rspec spec/integration
```

Expected: 1 example, 0 failures, ~3 seconds.

- [ ] **Step 10.5: Commit**

```bash
git add spec/support/restores_global_handlers.rb spec/rails_helper.rb \
        spec/integration/render_against_develop_api_spec.rb
git commit -m "$(cat <<'EOF'
test: integration spec against develop API (gated) + handler hygiene

- spec/support/restores_global_handlers.rb: snapshot Signal.trap state
  per spec, restore in after(:each). Catches handler leaks from Rails
  framework boot.
- spec/integration/render_against_develop_api_spec.rb: one happy-path
  test hitting api-develop.poli.page with the canonical
  getting-started/welcome template. Skipped when POLI_PAGE_API_KEY
  is unset; refuses to run with pp_live_* keys (safety belt).
- Single integration spec only — SDK transport/retries/4xx mapping
  belong to the SDK's own suite. INTEGRATIONS_PLAN.md §"Cross-cutting
  DX patterns" §5.
EOF
)"
```

---

## Task 11: `example-app/` skeleton + JSON routes mirroring all 10 SDK demo steps

**Files (under `example-app/`):**
- Create: `Gemfile`, `Gemfile.lock` (committed for the example app)
- Create: `Rakefile`
- Create: `config.ru`
- Create: `config/application.rb`, `config/boot.rb`, `config/environment.rb`, `config/routes.rb`, `config/database.yml`
- Create: `config/environments/development.rb`, `config/environments/test.rb`, `config/environments/production.rb`
- Create: `config/initializers/poli_page.rb` (committed, mirrors the generator output)
- Create: `app/controllers/application_controller.rb`
- Create: `app/controllers/renders_controller.rb`
- Create: `app/controllers/documents_controller.rb`
- Create: `app/controllers/demos_controller.rb` (just renders the index for now)
- Create: `app/views/demos/index.html.erb` (stub — Task 12 ships the interactive UI)
- Create: `app/views/layouts/application.html.erb`
- Create: `lib/tasks/demo.rake`
- Create: `bin/rails`, `bin/setup`
- Create: `public/.keep`
- Create: `README.md`

**Goal:** `cd example-app && bundle install && bin/rails server` boots a working Rails app on port 3000. Every JSON route from the 10-step demo mapping (spec §14.2) works. The `GET /` page renders a stub (Task 12 ships the real UI).

> **This is a single large commit by necessity** — a Rails app cannot be split across multiple meaningful commits without each one failing to boot. The internal structure is straightforward: Rails 8 `bin/rails new --minimal` output, then add controllers / routes / initializer.

- [ ] **Step 11.1: Bootstrap the Rails app**

From outside the gem repo:

```bash
cd /Users/mickael/Projects/rubyonrails
mkdir -p example-app
cd example-app
bundle init                          # creates Gemfile
```

Then replace `Gemfile` with:

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gem "rails", "~> 8.0"
gem "puma",  "~> 6.4"

gem "poli_page-rails", path: "../"
gem "poli-page",       path: "../../sdk-ruby"

gem "dotenv-rails", "~> 3.1"

group :development do
  gem "web-console"
end

group :development, :test do
  gem "debug", platforms: %i[mri windows]
end
```

```bash
bundle install
bundle exec rails new . --minimal --skip-git --skip-bundle --skip-test --skip-system-test --skip-javascript --skip-asset-pipeline --skip-bootsnap --force
```

> **Why `rails new` over a fully hand-crafted skeleton**: the minimal Rails 8 app boilerplate is non-trivial (bootstrap, env files, secrets, master.key). Letting `rails new` generate it then trimming is faster and more correct.

Trim post-generation:

- Remove `app/javascript/`, `vendor/javascript/`, `app/assets/` (the `--skip-*` flags should already prevent these).
- Remove unused initializers (`assets.rb`, `content_security_policy.rb`, `permissions_policy.rb`) — example app doesn't need them.
- Edit `config/application.rb` to remove framework requires we don't use (`active_record`, `action_mailer`, `active_storage`, `action_cable`).

- [ ] **Step 11.2: Load workspace root .env in `config/application.rb`**

After `Bundler.require`, add (before `module ExampleApp`):

```ruby
require "dotenv"
Dotenv.load(
  File.expand_path("../../../symfony-bundle/.env", __dir__),
  ".env.local",
  ".env"
)
```

Real shell exports always win.

- [ ] **Step 11.3: Commit the initializer (generated, not via `rails generate`)**

Create `example-app/config/initializers/poli_page.rb` with the same body as the generator template (Task 9 §9.3). This way `bundle exec bin/rails server` works the moment the gem's `Gemfile` resolves, without an extra `bin/rails generate poli_page:install` step.

- [ ] **Step 11.4: Write controllers**

Create `example-app/app/controllers/application_controller.rb`:

```ruby
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
end
```

Create `example-app/app/controllers/demos_controller.rb`:

```ruby
# frozen_string_literal: true

class DemosController < ApplicationController
  def index
    @api_key_prefix = ENV.fetch("POLI_PAGE_API_KEY", "")[0, 8]
    @base_url       = Rails.application.config.poli_page.base_url || "https://api.poli.page"
  end
end
```

Create `example-app/app/controllers/renders_controller.rb`:

```ruby
# frozen_string_literal: true

class RendersController < ApplicationController
  include PoliPage::Rails::Renderable

  # GET /api/render/pdf  — SDK demo step 1
  def pdf
    bytes = PoliPage.client.render.pdf(**canonical_kwargs)
    render_pdf(bytes, filename: "welcome.pdf", inline: true)
  end

  # GET /api/render/stream  — SDK demo step 2
  def stream
    response.headers["Content-Type"] = "application/pdf"
    response.headers["Content-Disposition"] =
      PoliPage::Rails::FilenameEncoder.disposition("welcome-streamed.pdf", inline: true)
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Last-Modified"] = Time.now.httpdate

    PoliPage.client.render.pdf_stream(**canonical_kwargs) do |chunk|
      response.stream.write(chunk)
    end
  ensure
    response.stream.close
  end

  # GET /api/render/preview  — SDK demo step 4
  def preview
    result = PoliPage.client.render.preview(**canonical_kwargs)
    render_preview(result)
  end

  # POST /api/documents  — SDK demo step 5
  def document
    descriptor = PoliPage.client.render.document(**canonical_kwargs)
    render json: descriptor.to_h
  end

  private

  def canonical_kwargs
    {
      project:  "getting-started",
      template: "welcome",
      version:  "1.0.0",
      data:     { name: params.fetch(:name, "Rails User") }
    }
  end
end
```

> **Why the streaming controller does NOT `include ActionController::Live`**: `ActionController::Live` changes the entire controller's request lifecycle (separate thread per request). Mixing it with `Renderable` for non-streaming actions is awkward. The example app demonstrates the manual streaming pattern; the gem's `Renderable` does not currently ship a `stream_pdf` helper (deferred to v0.2).
>
> **Correction:** the spec actually does require `include ActionController::Live` for the `stream` action. If the implementation runs into the controller-wide effect, split the streaming action into its own controller class. Update the routes accordingly.

Create `example-app/app/controllers/documents_controller.rb`:

```ruby
# frozen_string_literal: true

class DocumentsController < ApplicationController
  # Deliberately does NOT `include PoliPage::Rails::Renderable` — this
  # controller demonstrates direct PoliPage.client use to show both styles
  # work (spec §14.4).

  # GET /api/documents/:id  — SDK demo step 6
  def show
    descriptor = PoliPage.client.documents.get(params[:id])
    response.headers["Cache-Control"] = "private, no-store"
    redirect_to descriptor.presigned_pdf_url, status: :found, allow_other_host: true
  end

  # GET /api/documents/:id/thumbnails  — SDK demo step 7
  def thumbnails
    thumbs = PoliPage.client.documents.thumbnails(
      params[:id],
      width: 320, format: "png", pages: [1]
    )
    render json: thumbs.map(&:to_h)
  end

  # GET /api/documents/:id/preview  — SDK demo step 8
  def preview
    result = PoliPage.client.documents.preview(params[:id])
    response.headers["Content-Type"]  = "text/html; charset=utf-8"
    response.headers["Cache-Control"] = "private, no-store"
    render html: result.html.html_safe, layout: false
  end

  # DELETE /api/documents/:id  — SDK demo step 9
  def destroy
    PoliPage.client.documents.delete(params[:id])
    head :no_content
  end

  # GET /api/errors/bad-version  — SDK demo step 10
  def bad_version
    PoliPage.client.render.pdf(
      project: "getting-started", template: "welcome",
      version: "not-a-valid-semver", data: {}
    )
  rescue PoliPage::ValidationError => e
    render json: { error: e.class.name, code: e.code, message: e.message,
                   status: e.status, request_id: e.request_id }, status: 400
  end
end
```

- [ ] **Step 11.5: Wire routes**

Replace `example-app/config/routes.rb`:

```ruby
# frozen_string_literal: true

Rails.application.routes.draw do
  root "demos#index"

  scope "/api" do
    get    "/render/pdf",                    to: "renders#pdf"
    get    "/render/stream",                 to: "renders#stream"
    get    "/render/preview",                to: "renders#preview"
    post   "/documents",                     to: "renders#document"
    get    "/documents/:id",                 to: "documents#show",       constraints: { id: %r{[^/]+} }
    get    "/documents/:id/thumbnails",      to: "documents#thumbnails", constraints: { id: %r{[^/]+} }
    get    "/documents/:id/preview",         to: "documents#preview",    constraints: { id: %r{[^/]+} }
    delete "/documents/:id",                 to: "documents#destroy",    constraints: { id: %r{[^/]+} }
    get    "/errors/bad-version",            to: "documents#bad_version"
  end
end
```

- [ ] **Step 11.6: Write the rake task for SDK demo step 3**

Create `example-app/lib/tasks/demo.rake`:

```ruby
# frozen_string_literal: true

namespace :demo do
  desc "Render the canonical welcome template to ./tmp/welcome.pdf via PoliPage.client.render_to_file"
  task render_to_file: :environment do
    require "fileutils"
    FileUtils.mkdir_p("tmp")
    PoliPage.client.render_to_file(
      "tmp/welcome.pdf",
      project:  "getting-started",
      template: "welcome",
      version:  "1.0.0",
      data:     { name: "rake demo:render_to_file" }
    )
    puts "Wrote tmp/welcome.pdf (#{File.size('tmp/welcome.pdf')} bytes)"
  end
end
```

- [ ] **Step 11.7: Write the layout + stub view**

Create `example-app/app/views/layouts/application.html.erb`:

```erb
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <%= csrf_meta_tags %>
  <title>Poli Page · Rails demo</title>
  <%= yield :head %>
</head>
<body>
<%= yield %>
</body>
</html>
```

Create `example-app/app/views/demos/index.html.erb` (stub — Task 12 replaces with the full interactive UI):

```erb
<h1>Poli Page · Rails demo</h1>
<p>Interactive UI lands in Task 12. Try the JSON routes:</p>
<ul>
  <li><code>GET /api/render/pdf</code></li>
  <li><code>GET /api/render/stream</code></li>
  <li><code>GET /api/render/preview</code></li>
  <li><code>POST /api/documents</code></li>
  <li><code>GET /api/documents/:id</code></li>
  <li><code>GET /api/documents/:id/thumbnails</code></li>
  <li><code>GET /api/documents/:id/preview</code></li>
  <li><code>DELETE /api/documents/:id</code></li>
  <li><code>GET /api/errors/bad-version</code></li>
</ul>
```

- [ ] **Step 11.8: Write the README**

```markdown
# poli_page-rails example app

Minimal Rails 8 app that demonstrates every public method of the Poli Page
Ruby SDK via the poli_page-rails gem.

## Run

```
bundle install
bin/rails server
# open http://localhost:3000
```

The example app reads `POLI_PAGE_API_KEY` from the workspace root `.env`
(symfony-bundle's `.env`), falling back to per-app `.env`. Real shell
exports always win.

For SDK demo step 3 (render_to_file):

```
bin/rake demo:render_to_file
```
```

- [ ] **Step 11.9: Verify the app boots**

```bash
cd /Users/mickael/Projects/rubyonrails/example-app
bundle install
bin/rails routes | head -20
bin/rails server -d  # detached
sleep 2
curl -sI http://localhost:3000/ | head -1
kill -TERM $(cat tmp/pids/server.pid)
```

Expected: `HTTP/1.1 200 OK`.

- [ ] **Step 11.10: Commit**

```bash
cd /Users/mickael/Projects/rubyonrails
git add example-app/
git commit -m "$(cat <<'EOF'
feat: example-app skeleton with JSON routes for all 10 SDK demo steps

- Rails 8 minimal app (no ActiveRecord, no ActionMailer, no ActiveStorage,
  no JS / asset pipeline) consuming poli_page-rails via Gemfile path:.
- config/application.rb loads workspace root .env via dotenv-rails;
  config/initializers/poli_page.rb wires the API key from env.
- RendersController (includes Renderable) covers SDK demo steps 1, 2, 4, 5.
- DocumentsController (deliberately NO Renderable include, to show both
  styles work) covers steps 6, 7, 8, 9, 10.
- lib/tasks/demo.rake exposes step 3 (render_to_file) as a rake task in
  the example app's app: namespace — not in the gem itself (gem keeps
  zero rake tasks; CLAUDE.md §10.5).
- views/demos/index.html.erb is a stub; Task 12 ships the interactive UI.

`bin/rails server` boots clean; GET / responds 200; the JSON routes
proxy to the SDK via PoliPage.client.
EOF
)"
```

---

## Task 12: example-app interactive demo UI at `GET /`

**Files:**
- Replace: `example-app/app/views/demos/index.html.erb` (with the full UI)
- Maybe: `example-app/app/views/layouts/application.html.erb` (strip stylesheet/JS tags if any leaked from `rails new`)

**Goal:** A ~440-line single-page ERB view at `GET /` matching the symfony-bundle's `demo.html` aesthetic 1:1, with inline `<iframe>` previews and per-feature buttons.

- [ ] **Step 12.1: Read the symfony-bundle reference**

Open `/Users/mickael/Projects/symfony-bundle/example-app/templates/demo.html` and copy the structure. The aesthetic is:

- White surface (`--bg: #ffffff`), brand indigo `#4f5d99` (`--brand`)
- Display: Manrope (700/800) for headings + wordmark
- Body: IBM Plex Sans (400/500, italic for taglines)
- Code: JetBrains Mono (400/500)
- Hairline borders, generous gutters, editorial print-specimen feel
- Status pill at the top with a pulsing brand dot

Adapt the Twig directives (`{{ }}`, `{% %}`) to ERB (`<%= %>`, `<% %>`). Replace any framework-specific URLs (the symfony demo uses Symfony route names) with Rails route helpers or hardcoded `/api/...` paths matching `routes.rb` from Task 11.

- [ ] **Step 12.2: Replace `app/views/demos/index.html.erb`**

The full file is too long to inline here. The structure:

```erb
<% content_for :head do %>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&family=IBM+Plex+Sans:ital,wght@0,400;0,500;1,400&family=JetBrains+Mono:wght@400;500&display=swap">
  <style>
    :root { --bg: #ffffff; --brand: #4f5d99; /* ... full :root block from symfony demo */ }
    /* ... full CSS from symfony demo ... */
  </style>
<% end %>

<div class="page">
  <header class="mast">
    <div class="wordmark">Poli<span class="brand">Page</span> · Rails</div>
    <div class="tagline">render documents from a Rails controller without thinking about headers</div>
    <div class="status-row">
      <span class="dot"></span>
      <span><%= @base_url %></span>
      <span class="sep">·</span>
      <span><%= @api_key_prefix %>•••</span>
    </div>
  </header>

  <section class="demo-row" data-step="1">
    <h2>Step 1 · <code>render.pdf</code></h2>
    <p>Renders the canonical <code>getting-started/welcome</code> template and serves it inline.</p>
    <button data-action="render-pdf">Render PDF</button>
    <div class="result" data-result></div>
  </section>

  <!-- Repeat for steps 2 through 10 — full structure ported from
       symfony-bundle/example-app/templates/demo.html -->

</div>

<script>
  // Vanilla JS, no build step. Functions per demo row:
  //   - Step 1: fetch /api/render/pdf, swap an <iframe> with the blob URL.
  //   - Step 2: fetch /api/render/stream as a Response, pipe to a blob, swap iframe.
  //   - Step 4: fetch /api/render/preview as text/html, inject into <iframe srcdoc>.
  //   - Step 5: POST /api/documents, parse JSON, store documentId in window state,
  //             enable steps 6-9 buttons.
  //   - Step 6: GET /api/documents/${documentId} — follows 302 to presigned URL.
  //   - Step 7: GET /api/documents/${documentId}/thumbnails — render base64 PNG.
  //   - Step 8: GET /api/documents/${documentId}/preview — <iframe srcdoc>.
  //   - Step 9: DELETE /api/documents/${documentId} — clear state, disable 6-9.
  //   - Step 10: GET /api/errors/bad-version — render JSON in red <pre>.

  // SDK demo step 3 (render_to_file) shows a copy-button block with
  // `bin/rake demo:render_to_file` — not in-browser.
</script>
```

> **Implementation hint**: copy the symfony demo file verbatim, then s/symfony route names/Rails /api paths/, s/Twig/ERB/, and tweak the wordmark to "Poli<span class="brand">Page</span> · Rails". The CSS, JS state machine for `documentId`, and `<iframe>` swap logic carry across unchanged.

- [ ] **Step 12.3: Boot and click through**

```bash
cd /Users/mickael/Projects/rubyonrails/example-app
bin/rails server
# Open http://localhost:3000 in a browser
# - Click "Render PDF" — iframe shows the PDF
# - Click "Render Stream" — iframe shows the PDF (streamed)
# - Click "Render Preview" — iframe srcdoc shows the HTML
# - Click "Create Document" — JSON appears, documentId captured
# - Click "Get Document" — iframe shows the PDF via 302 redirect
# - Click "Thumbnails" — base64 PNGs render
# - Click "Document Preview" — iframe srcdoc shows the HTML
# - Click "Delete Document" — JSON 204, downstream buttons disable
# - Click "Trigger 400 Error" — red JSON block with the validation error
```

Verify with a real `POLI_PAGE_API_KEY` from `.env`.

- [ ] **Step 12.4: Commit**

```bash
git add example-app/app/views/demos/index.html.erb \
        example-app/app/views/layouts/application.html.erb
git commit -m "$(cat <<'EOF'
feat: example-app interactive demo UI at GET / (~440 lines, ERB)

Single-page dashboard ported verbatim from
symfony-bundle/example-app/templates/demo.html. Same aesthetic: white
surface, brand indigo (#4f5d99), Manrope display + IBM Plex Sans body +
JetBrains Mono code, hairline borders, pulsing brand dot status pill.

Per-feature rows with one button each:
- Steps 1, 2 — PDF / streamed PDF, inline <iframe src="blob:...">
- Step 4 — HTML preview, <iframe srcdoc> sandbox
- Step 5 — create document, capture documentId into JS state
- Steps 6-9 — gated on documentId, redirect / thumbnails / preview / delete
- Step 10 — deliberate 400, red JSON pretty-print

Step 3 (render_to_file) shows a copy-button block for `bin/rake demo:
render_to_file` — out-of-browser by nature.

No build step, no Sprockets/Propshaft, no Importmap, no Tailwind. Inline
<style> and <script>, vanilla JS, three Google Fonts stylesheet preconnects.
EOF
)"
```

---

## Task 13: README, CHANGELOG, LICENSE, RBS sigs

**Files:**
- Create: `README.md`
- Create: `CHANGELOG.md`
- Create: `LICENSE`
- Create: `sig/poli_page/rails/*.rbs` (basic signatures mirroring the public API)

**Goal:** All the user-facing documentation a v0.1.0 release needs. RubyGems publishes the gem.

- [ ] **Step 13.1: Write `LICENSE`**

Standard MIT License, owner "Poli Page".

- [ ] **Step 13.2: Write `README.md`**

Sections:

- Quick install: `bundle add poli_page-rails`, then `rails generate poli_page:install`, set env var.
- Quick example: controller using `Renderable` to `render_pdf` a welcome doc.
- Configuration block reference (every key from `config/initializers/poli_page.rb`).
- Notifications subscription example.
- Links to spec, CHANGELOG, SDK docs at docs.poli.page.
- Development: how to run specs locally with Appraisal.

- [ ] **Step 13.3: Write `CHANGELOG.md`**

```markdown
# Changelog

All notable changes to `poli_page-rails` are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-MM-DD

### Added

- Initial release. Rails engine + Railtie wrapping the official `poli-page` Ruby SDK.
- `PoliPage.client` lazy memoised accessor (Monitor-guarded; shared across threads).
- `Rails.application.config.poli_page` Configuration object — single source of
  truth for SDK kwargs; SDK defaults apply for nil values.
- Lazy validation: API key + URL + numeric ranges validated on first
  `PoliPage.client` call, not at engine boot. Keeps `assets:precompile` and
  `db:create` working in containers without secrets.
- `PoliPage::Rails::Renderable` controller concern: `render_pdf`,
  `render_preview`, `redirect_to_document`. RFC 5987 Content-Disposition for
  ASCII + non-ASCII filenames.
- `ActiveSupport::Notifications` bridge for SDK retry/error hooks
  (`poli_page.retry`, `poli_page.error`). Default-on; opt-out via
  `c.notifications = false`.
- `rails generate poli_page:install` writes `config/initializers/poli_page.rb`
  with a commented configuration block.
- Example Rails 8 app at `example-app/` with an interactive single-page demo
  UI hitting every SDK method.

[Unreleased]: https://github.com/poli-page/rails/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/poli-page/rails/releases/tag/v0.1.0
```

- [ ] **Step 13.4: Write minimal RBS signatures**

Create `/Users/mickael/Projects/rubyonrails/sig/poli_page/rails/configuration.rbs`:

```rbs
module PoliPage
  module Rails
    class Configuration
      attr_accessor api_key: String?
      attr_accessor base_url: String?
      attr_accessor timeout: Numeric?
      attr_accessor user_agent: String?
      attr_accessor max_retries: Integer?
      attr_accessor retry_delay: Numeric?
      attr_accessor logger: untyped
      attr_accessor on_retry: ^(untyped) -> void | nil
      attr_accessor on_error: ^(untyped) -> void | nil
      attr_accessor proxy: String?
      attr_accessor ca_file: String?
      attr_accessor ca_path: String?
      attr_accessor notifications: bool

      def initialize: () -> void
      def to_client_kwargs: () -> Hash[Symbol, untyped]
    end
  end
end
```

Repeat the pattern for `client.rbs`, `renderable.rbs`, `notifications.rbs`, `filename_encoder.rbs`.

- [ ] **Step 13.5: Final full-suite run**

```bash
cd /Users/mickael/Projects/rubyonrails
bundle exec rake
```

Expected: rubocop clean + all specs pass. Then run Appraisal to verify the matrix:

```bash
bundle exec appraisal install
bundle exec appraisal rails-8.0 rspec --exclude-pattern "spec/integration/**/*"
bundle exec appraisal rails-7.2 rspec --exclude-pattern "spec/integration/**/*"
```

- [ ] **Step 13.6: Commit**

```bash
git add README.md CHANGELOG.md LICENSE sig/
git commit -m "$(cat <<'EOF'
docs: README, CHANGELOG, LICENSE, and RBS signatures for v0.1.0

- README: quick install + render_pdf example + config block reference +
  notifications subscription example + dev-loop instructions.
- CHANGELOG: Keep a Changelog format; v0.1.0 entry summarises every
  feature shipped in Tasks 3-12.
- LICENSE: MIT, "Poli Page".
- sig/: RBS signatures mirroring the public API (configuration, client,
  renderable, notifications, filename_encoder). Matches the SDK's
  discipline (sdk-ruby/sig/).
EOF
)"
```

---

## Post-launch: SDK publish cutover

When `poli-page` publishes on RubyGems:

1. Remove the `gem "poli-page", path: "../sdk-ruby"` line from `Gemfile`.
2. `bundle update poli-page`.
3. Verify CI green on all matrix cells.
4. Bump to v0.1.1 in `version.rb` + CHANGELOG.
5. `bundle exec rake release`.

Gem source code (everything in `lib/`, `spec/`, `sig/`) does not change.

Remove the "Checkout SDK alongside gem" step from `.github/workflows/ci.yml` once the SDK is on RubyGems.

---

## Definition of done (v0.1.0)

- [x] All 13 tasks above complete, each shipped as an independently-reviewable commit.
- [x] CI green on every matrix cell.
- [x] `bundle exec rake` clean (rubocop + rspec).
- [x] `bin/rails server` boots the example app, all 10 demo steps reachable.
- [x] Integration spec passes against `api-develop.poli.page` with a real `pp_test_*` key.
- [x] README, CHANGELOG, LICENSE present.
- [x] `gem build poli_page-rails.gemspec` produces a valid `.gem` file.

Once those check off, `bundle exec rake release` to push v0.1.0 to RubyGems.
