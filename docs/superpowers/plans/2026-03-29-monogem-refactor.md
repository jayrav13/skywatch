# Monogem Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the multi-gem skywatch project (briefer + radar as separate gems) into a single `skywatch` gem with internal domain modules under `Skywatch::Briefer` and `Skywatch::Radar`, and shared infrastructure under `Skywatch::Shared`.

**Architecture:** Delete the old `briefer/` and `radar/` directories. Create a new top-level gem scaffold (`skywatch.gemspec`, `lib/skywatch.rb`). Move all existing code into the new namespace hierarchy. All existing tests are re-namespaced but test identical behavior.

**Tech Stack:** Ruby 3.2+, Faraday ~> 2.0, faraday-retry ~> 2.0, rgeo ~> 3.0, rgeo-geojson ~> 2.0, Thor ~> 1.3, RSpec, WebMock, RuboCop

---

### Task 1: New Gem Scaffold

**Files:**
- Create: `skywatch.gemspec`
- Create: `Gemfile` (replace existing)
- Create: `lib/skywatch.rb`
- Create: `lib/skywatch/version.rb`
- Create: `exe/skywatch`
- Create: `spec/spec_helper.rb`
- Create: `.rspec`
- Create: `.rubocop.yml`
- Modify: `Rakefile` (replace existing)
- Modify: `.gitignore` (replace existing)
- Create: `CLAUDE.md` (replace briefer/CLAUDE.md)

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p lib/skywatch/{shared,briefer/{sources,models,analysis,formatters},radar/{sources,models,analysis,formatters}}
mkdir -p spec/{shared,briefer/{sources,models,analysis,formatters},radar/{sources,models,analysis},fixtures/{metars,tafs,pireps,winds_aloft,sigmets,airmets,tfrs,afd,opensky}}
mkdir -p exe
```

- [ ] **Step 2: Create version.rb**

Create `lib/skywatch/version.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  VERSION = "0.1.0"
end
```

- [ ] **Step 3: Create lib/skywatch.rb (minimal — just version and errors for now)**

Create `lib/skywatch.rb`:

```ruby
# frozen_string_literal: true

require_relative "skywatch/version"

module Skywatch
  class << self
  end
end
```

- [ ] **Step 4: Create skywatch.gemspec**

Create `skywatch.gemspec`:

```ruby
# frozen_string_literal: true

require_relative "lib/skywatch/version"

Gem::Specification.new do |spec|
  spec.name = "skywatch"
  spec.version = Skywatch::VERSION
  spec.authors = ["Jay Ravaliya"]
  spec.email = ["jayrav13@gmail.com"]

  spec.summary = "Aviation situational awareness toolkit"
  spec.description = "Real-time aviation weather, flight tracking, and situational awareness. " \
                     "Consolidates public FAA/NWS/ADS-B data into a unified CLI and Ruby API."
  spec.homepage = "https://github.com/jayrav13/skywatch"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jayrav13/skywatch"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "exe/*", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["skywatch"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "rgeo", "~> 3.0"
  spec.add_dependency "rgeo-geojson", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"
end
```

- [ ] **Step 5: Create Gemfile**

Create `Gemfile`:

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rspec", "~> 3.0"
  gem "rubocop", "~> 1.0"
  gem "webmock", "~> 3.0"
end
```

- [ ] **Step 6: Create Rakefile**

Create `Rakefile`:

```ruby
# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]
```

- [ ] **Step 7: Create .rubocop.yml**

Create `.rubocop.yml`:

```yaml
AllCops:
  TargetRubyVersion: 3.2
  NewCops: enable
  SuggestExtensions: false

Style/Documentation:
  Enabled: false

Metrics/BlockLength:
  Exclude:
    - "spec/**/*"
```

- [ ] **Step 8: Create .rspec**

Create `.rspec`:

```
--require spec_helper
--format documentation
```

- [ ] **Step 9: Create .gitignore**

Create `.gitignore`:

```
/.bundle/
/tmp/
/pkg/
Gemfile.lock
*.gem
.rspec_status
```

- [ ] **Step 10: Create spec/spec_helper.rb**

Create `spec/spec_helper.rb`:

```ruby
# frozen_string_literal: true

require "skywatch"
require "webmock/rspec"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
```

- [ ] **Step 11: Create exe/skywatch**

Create `exe/skywatch`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "skywatch"

Skywatch::CLI.start(ARGV)
```

```bash
chmod +x exe/skywatch
```

- [ ] **Step 12: Create CLAUDE.md**

Create `CLAUDE.md`:

```markdown
# Skywatch

Aviation situational awareness toolkit — real-time weather, flight tracking, and more from public FAA/NWS/ADS-B data.

## Project Overview

- **Type**: Ruby gem (single gem, internal domain modules)
- **CLI framework**: Thor (subcommands per domain)
- **HTTP client**: Faraday (with faraday-retry)
- **Geospatial**: rgeo + rgeo-geojson
- **Testing**: RSpec with WebMock fixtures
- **Style**: RuboCop

## Commands

```bash
bundle exec rspec              # Run tests
bundle exec rubocop            # Lint
bundle exec rake               # Default task (spec + rubocop)
exe/skywatch                   # CLI entry point
```

## Architecture

```
Skywatch (top-level module + convenience API)
├── Shared    # HTTP client, cache, geometry, errors, Position
├── Briefer   # aviation weather briefings
├── Radar     # flight tracking via OpenSky
└── CLI       # Thor with subcommands
```

## CLI Usage

```bash
skywatch weather metar KCDW
skywatch weather taf KACK
skywatch weather pireps KCDW --radius 100
skywatch radar track UAL1234
skywatch radar flights 37.62 -122.38
```

## Conventions

- All data sources under `Skywatch::<Domain>::Sources`
- All models under `Skywatch::<Domain>::Models`
- Shared infrastructure under `Skywatch::Shared`
- No API keys required for core functionality
- Cache TTLs: METARs 5min, TAFs 30min, state vectors 15s
- Test against saved fixtures, never live APIs
- All CLI commands support --format json|text (auto-detect TTY)
```

- [ ] **Step 13: Install dependencies**

```bash
bundle install
```

- [ ] **Step 14: Verify gem loads**

Run: `bundle exec ruby -e "require 'skywatch'; puts Skywatch::VERSION"`
Expected: `0.1.0`

- [ ] **Step 15: Commit**

```bash
git add skywatch.gemspec Gemfile Rakefile .rubocop.yml .rspec .gitignore \
  lib/skywatch.rb lib/skywatch/version.rb exe/skywatch \
  spec/spec_helper.rb CLAUDE.md
git commit -m "Scaffold skywatch gem with single-gem structure"
```

---

### Task 2: Shared Infrastructure

**Files:**
- Create: `lib/skywatch/shared/errors.rb`
- Create: `lib/skywatch/shared/http.rb`
- Create: `lib/skywatch/shared/cache.rb`
- Create: `lib/skywatch/shared/geometry.rb`
- Create: `lib/skywatch/shared/position.rb`
- Create: `spec/shared/errors_spec.rb`
- Create: `spec/shared/http_spec.rb`
- Create: `spec/shared/cache_spec.rb`
- Create: `spec/shared/geometry_spec.rb`
- Modify: `lib/skywatch.rb`

- [ ] **Step 1: Create errors.rb**

Create `lib/skywatch/shared/errors.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  class Error < StandardError
    attr_reader :response

    def initialize(message = nil, response: nil)
      @response = response
      super(message)
    end
  end

  class ConnectionError < Error; end
  class ApiError < Error; end
  class ParseError < Error; end
end
```

- [ ] **Step 2: Create position.rb**

Create `lib/skywatch/shared/position.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Shared
    Position = Data.define(:lat, :lon)
  end
end
```

- [ ] **Step 3: Create http.rb**

Create `lib/skywatch/shared/http.rb`:

```ruby
# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Skywatch
  module Shared
    class Http
      DEFAULT_BASE_URL = "https://aviationweather.gov"

      attr_reader :connection

      def initialize(base_url: DEFAULT_BASE_URL)
        @connection = build_connection(base_url)
      end

      def get(path, params = {}, ttl: nil) # rubocop:disable Lint/UnusedMethodArgument
        response = connection.get(path, params)
        raise ApiError.new("HTTP #{response.status}", response: response) unless response.success?

        JSON.parse(response.body)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise ConnectionError, e.message
      rescue JSON::ParserError => e
        raise ParseError, e.message
      end

      def get_raw(path, params = {}, ttl: nil) # rubocop:disable Lint/UnusedMethodArgument
        response = connection.get(path, params)
        raise ApiError.new("HTTP #{response.status}", response: response) unless response.success?

        response.body
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise ConnectionError, e.message
      end

      private

      def build_connection(base_url)
        Faraday.new(url: base_url) do |f|
          f.request :retry, max: 3, interval: 0.5, backoff_factor: 2
          f.headers["User-Agent"] = "Skywatch/#{Skywatch::VERSION} (ruby; github.com/jayrav13/skywatch)"
          f.options.open_timeout = 10
          f.options.timeout = 30
        end
      end
    end
  end
end
```

- [ ] **Step 4: Create cache.rb**

Create `lib/skywatch/shared/cache.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Shared
    class Cache
      def initialize(client:)
        @client = client
        @store = {}
        @mutex = Mutex.new
      end

      def get(path, params = {}, ttl: 300)
        key = cache_key(path, params)

        @mutex.synchronize do
          entry = @store[key]
          return entry[:data] if entry && !expired?(entry, ttl)
        end

        data = @client.get(path, params)

        @mutex.synchronize do
          @store[key] = { data: data, cached_at: Time.now }
        end

        data
      end

      def get_raw(path, params = {}, ttl: 300)
        key = cache_key(path, params)

        @mutex.synchronize do
          entry = @store[key]
          return entry[:data] if entry && !expired?(entry, ttl)
        end

        data = @client.get_raw(path, params)

        @mutex.synchronize do
          @store[key] = { data: data, cached_at: Time.now }
        end

        data
      end

      def clear
        @mutex.synchronize { @store.clear }
      end

      def size
        @mutex.synchronize { @store.size }
      end

      private

      def cache_key(path, params)
        [path, params.sort_by { |k, _| k.to_s }].to_s
      end

      def expired?(entry, ttl)
        Time.now - entry[:cached_at] > ttl
      end
    end
  end
end
```

- [ ] **Step 5: Create geometry.rb**

Create `lib/skywatch/shared/geometry.rb`:

```ruby
# frozen_string_literal: true

require "rgeo"

module Skywatch
  module Shared
    module Geometry
      FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

      def self.polygon_from_coords(coords)
        return nil if coords.nil? || coords.size < 3

        points = coords.map { |c| FACTORY.point(c.lon, c.lat) }
        ring = FACTORY.linear_ring(points)
        FACTORY.polygon(ring)
      end

      def self.point(lat, lon)
        FACTORY.point(lon, lat)
      end
    end
  end
end
```

- [ ] **Step 6: Update lib/skywatch.rb with requires and client accessor**

Replace `lib/skywatch.rb` with:

```ruby
# frozen_string_literal: true

require_relative "skywatch/version"
require_relative "skywatch/shared/errors"
require_relative "skywatch/shared/position"
require_relative "skywatch/shared/http"
require_relative "skywatch/shared/cache"
require_relative "skywatch/shared/geometry"

module Skywatch
  class << self
    def client
      @client ||= Shared::Cache.new(client: Shared::Http.new)
    end

    def reset!
      @client = nil
    end
  end
end
```

- [ ] **Step 7: Write shared specs**

Create `spec/shared/errors_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Error do
  it "is a StandardError" do
    expect(described_class.new).to be_a(StandardError)
  end
end

RSpec.describe Skywatch::ConnectionError do
  it "is a Skywatch::Error" do
    expect(described_class.new).to be_a(Skywatch::Error)
  end
end

RSpec.describe Skywatch::ApiError do
  it "is a Skywatch::Error" do
    expect(described_class.new).to be_a(Skywatch::Error)
  end

  it "stores the response" do
    error = described_class.new("bad", response: { status: 500 })
    expect(error.response).to eq({ status: 500 })
  end
end

RSpec.describe Skywatch::ParseError do
  it "is a Skywatch::Error" do
    expect(described_class.new).to be_a(Skywatch::Error)
  end
end
```

Create `spec/shared/http_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Shared::Http do
  subject(:client) { described_class.new }

  describe "#connection" do
    it "sets the base URL to aviationweather.gov by default" do
      expect(client.connection.url_prefix.to_s).to eq("https://aviationweather.gov/")
    end

    it "accepts a custom base URL" do
      custom = described_class.new(base_url: "https://opensky-network.org")
      expect(custom.connection.url_prefix.to_s).to eq("https://opensky-network.org/")
    end

    it "sets a custom User-Agent header" do
      user_agent = client.connection.headers["User-Agent"]
      expect(user_agent).to match(%r{Skywatch/\d+\.\d+\.\d+ \(ruby; github\.com/jayrav13/skywatch\)})
    end
  end

  describe "#get" do
    it "makes a GET request and returns parsed JSON" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW", format: "json" })
        .to_return(status: 200, body: '[{"icaoId":"KCDW"}]',
                   headers: { "Content-Type" => "application/json" })

      response = client.get("/api/data/metar", { ids: "KCDW", format: "json" })
      expect(response).to eq([{ "icaoId" => "KCDW" }])
    end

    it "raises ConnectionError on network failure" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { client.get("/api/data/metar") }.to raise_error(Skywatch::ConnectionError)
    end

    it "raises ApiError on non-200 response" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .to_return(status: 500, body: "Internal Server Error")

      expect { client.get("/api/data/metar") }.to raise_error(Skywatch::ApiError)
    end
  end

  describe "#get_raw" do
    it "returns response body as string" do
      stub_request(:get, "https://aviationweather.gov/api/data/fcstdisc")
        .with(query: { cwa: "KBOX" })
        .to_return(status: 200, body: "Raw text", headers: { "Content-Type" => "text/plain" })

      result = client.get_raw("/api/data/fcstdisc", { cwa: "KBOX" })
      expect(result).to eq("Raw text")
    end
  end
end
```

Create `spec/shared/cache_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Shared::Cache do
  subject(:cache) { described_class.new(client: http_client) }

  let(:http_client) { Skywatch::Shared::Http.new }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json")
      .to_return(status: 200, body: '[{"icaoId":"KCDW"}]',
                 headers: { "Content-Type" => "application/json" })
  end

  describe "#get" do
    it "delegates to the underlying client" do
      result = cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      expect(result).to eq([{ "icaoId" => "KCDW" }])
    end

    it "returns cached response on second call" do
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      expect(WebMock).to have_requested(:get,
        "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json").once
    end

    it "fetches again after TTL expires" do
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 0)
      sleep 0.01
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 0)
      expect(WebMock).to have_requested(:get,
        "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json").twice
    end
  end

  describe "#clear" do
    it "empties the cache" do
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      cache.clear
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      expect(WebMock).to have_requested(:get,
        "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json").twice
    end
  end

  describe "#size" do
    it "returns the number of cached entries" do
      expect(cache.size).to eq(0)
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      expect(cache.size).to eq(1)
    end
  end
end
```

Create `spec/shared/geometry_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Shared::Geometry do
  describe ".polygon_from_coords" do
    it "builds an RGeo polygon from Position array" do
      coords = [
        Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -73.0),
        Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0)
      ]
      polygon = described_class.polygon_from_coords(coords)
      expect(polygon).to be_a(RGeo::Geographic::SphericalPolygonImpl)
    end

    it "returns nil for fewer than 3 points" do
      coords = [
        Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -74.0)
      ]
      expect(described_class.polygon_from_coords(coords)).to be_nil
    end

    it "returns nil for nil input" do
      expect(described_class.polygon_from_coords(nil)).to be_nil
    end
  end

  describe ".point" do
    it "builds an RGeo point from lat/lon" do
      point = described_class.point(40.87, -74.28)
      expect(point).to be_a(RGeo::Geographic::SphericalPointImpl)
      expect(point.latitude).to be_within(0.001).of(40.87)
    end
  end

  describe "FACTORY" do
    it "is a spherical factory with SRID 4326" do
      expect(described_class::FACTORY.srid).to eq(4326)
    end
  end
end
```

- [ ] **Step 8: Run tests**

Run: `bundle exec rspec spec/shared/`
Expected: all pass

- [ ] **Step 9: Run rubocop**

Run: `bundle exec rubocop lib/skywatch/shared/ spec/shared/`
Expected: no offenses

- [ ] **Step 10: Commit**

```bash
git add lib/skywatch/ spec/shared/
git commit -m "Add shared infrastructure: errors, HTTP client, cache, geometry, position"
```

---

### Task 3: Briefer Models

Move all briefer models to `Skywatch::Briefer::Models`. Internal references to `Geometry`, `Position`, and error classes change to `Skywatch::Shared::*`.

**Files:**
- Create: `lib/skywatch/briefer/models/metar.rb`
- Create: `lib/skywatch/briefer/models/taf_group.rb`
- Create: `lib/skywatch/briefer/models/taf.rb`
- Create: `lib/skywatch/briefer/models/pirep.rb`
- Create: `lib/skywatch/briefer/models/winds_aloft.rb`
- Create: `lib/skywatch/briefer/models/sigmet.rb`
- Create: `lib/skywatch/briefer/models/airmet.rb`
- Create: `lib/skywatch/briefer/models/tfr.rb`
- Copy: `spec/fixtures/` from `briefer/spec/fixtures/`
- Create: all model specs under `spec/briefer/models/`
- Modify: `lib/skywatch.rb`

- [ ] **Step 1: Copy all fixture files**

```bash
cp briefer/spec/fixtures/metars/*.json spec/fixtures/metars/
cp briefer/spec/fixtures/tafs/*.json spec/fixtures/tafs/
cp briefer/spec/fixtures/pireps/*.json spec/fixtures/pireps/
cp briefer/spec/fixtures/winds_aloft/*.json spec/fixtures/winds_aloft/
cp briefer/spec/fixtures/sigmets/*.json spec/fixtures/sigmets/
cp briefer/spec/fixtures/airmets/*.json spec/fixtures/airmets/
cp briefer/spec/fixtures/tfrs/*.json spec/fixtures/tfrs/
```

- [ ] **Step 2: Create each model file**

For every model file, the changes are mechanical: replace `module Briefer` with `module Skywatch; module Briefer`, replace `Position` references with `Skywatch::Shared::Position`, replace `Geometry` references with `Skywatch::Shared::Geometry`.

Create each file by copying the corresponding `briefer/lib/briefer/models/<name>.rb` and applying the namespace change. The pattern for every model:

**Example — `lib/skywatch/briefer/models/metar.rb`:**
- Open `briefer/lib/briefer/models/metar.rb`
- Replace `module Briefer` → `module Skywatch; module Briefer` (add closing `end`)
- Replace `Analysis::FlightCategory` → `Skywatch::Briefer::Analysis::FlightCategory`
- Replace `Models::Position` → `Skywatch::Shared::Position`
- Save to `lib/skywatch/briefer/models/metar.rb`

Apply this same transformation to: `taf_group.rb`, `taf.rb`, `pirep.rb`, `winds_aloft.rb`, `sigmet.rb`, `airmet.rb`, `tfr.rb`.

For models that reference `Geometry` (sigmet, airmet, tfr): replace `Geometry.polygon_from_coords` → `Skywatch::Shared::Geometry.polygon_from_coords`.

For models that reference `Position` in `parse_coords`: replace `Position.new` → `Skywatch::Shared::Position.new`.

- [ ] **Step 3: Create each model spec file**

For every spec file, copy from `briefer/spec/models/<name>_spec.rb` and apply:
- Replace `Briefer::Models::` → `Skywatch::Briefer::Models::`
- Replace `Briefer::Models::Position` → `Skywatch::Shared::Position`
- Save to `spec/briefer/models/<name>_spec.rb`

- [ ] **Step 4: Add requires to lib/skywatch.rb**

Add after the shared requires:

```ruby
require_relative "skywatch/briefer/models/metar"
require_relative "skywatch/briefer/models/taf_group"
require_relative "skywatch/briefer/models/taf"
require_relative "skywatch/briefer/models/pirep"
require_relative "skywatch/briefer/models/winds_aloft"
require_relative "skywatch/briefer/models/sigmet"
require_relative "skywatch/briefer/models/airmet"
require_relative "skywatch/briefer/models/tfr"
```

- [ ] **Step 5: Run tests**

Run: `bundle exec rspec spec/briefer/models/`
Expected: all pass (same count as before)

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/briefer/models/ spec/briefer/models/ spec/fixtures/
git commit -m "Move briefer models to Skywatch::Briefer::Models namespace"
```

---

### Task 4: Briefer Analysis

**Files:**
- Create: `lib/skywatch/briefer/analysis/flight_category.rb`
- Create: `lib/skywatch/briefer/analysis/crosswind_calculator.rb`
- Create: `spec/briefer/analysis/flight_category_spec.rb`
- Create: `spec/briefer/analysis/crosswind_calculator_spec.rb`
- Modify: `lib/skywatch.rb`

- [ ] **Step 1: Create flight_category.rb**

Create `lib/skywatch/briefer/analysis/flight_category.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Briefer
    module Analysis
      module FlightCategory
        CATEGORIES = %i[lifr ifr mvfr vfr].freeze

        def self.classify(ceiling_ft:, visibility_sm:)
          ceiling_cat = classify_ceiling(ceiling_ft)
          visibility_cat = classify_visibility(visibility_sm)

          worse_index = [CATEGORIES.index(ceiling_cat), CATEGORIES.index(visibility_cat)].min
          CATEGORIES[worse_index]
        end

        def self.classify_ceiling(ceiling_ft)
          return :vfr if ceiling_ft.nil?

          if ceiling_ft < 500 then :lifr
          elsif ceiling_ft < 1000 then :ifr
          elsif ceiling_ft <= 3000 then :mvfr
          else :vfr
          end
        end

        def self.classify_visibility(visibility_sm)
          if visibility_sm < 1 then :lifr
          elsif visibility_sm < 3 then :ifr
          elsif visibility_sm <= 5 then :mvfr
          else :vfr
          end
        end

        private_class_method :classify_ceiling, :classify_visibility
      end
    end
  end
end
```

- [ ] **Step 2: Create crosswind_calculator.rb**

Create `lib/skywatch/briefer/analysis/crosswind_calculator.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Briefer
    module Analysis
      module CrosswindCalculator
        def self.calculate(wind_direction_deg:, wind_speed_kt:, runway_heading:)
          return { crosswind_kt: 0.0, headwind_kt: 0.0 } if wind_speed_kt.zero?

          angle_rad = (wind_direction_deg - runway_heading) * Math::PI / 180.0

          {
            crosswind_kt: (wind_speed_kt * Math.sin(angle_rad)).abs.round(1),
            headwind_kt: (wind_speed_kt * Math.cos(angle_rad)).round(1)
          }
        end
      end
    end
  end
end
```

- [ ] **Step 3: Create analysis specs**

Create `spec/briefer/analysis/flight_category_spec.rb` — copy from `briefer/spec/analysis/flight_category_spec.rb`, replace `Briefer::Analysis::FlightCategory` → `Skywatch::Briefer::Analysis::FlightCategory`.

Create `spec/briefer/analysis/crosswind_calculator_spec.rb` — copy from `briefer/spec/analysis/crosswind_calculator_spec.rb`, replace `Briefer::Analysis::CrosswindCalculator` → `Skywatch::Briefer::Analysis::CrosswindCalculator`.

- [ ] **Step 4: Add requires to lib/skywatch.rb**

```ruby
require_relative "skywatch/briefer/analysis/flight_category"
require_relative "skywatch/briefer/analysis/crosswind_calculator"
```

- [ ] **Step 5: Run tests**

Run: `bundle exec rspec spec/briefer/analysis/`
Expected: all pass

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/briefer/analysis/ spec/briefer/analysis/
git commit -m "Move briefer analysis modules to Skywatch::Briefer::Analysis"
```

---

### Task 5: Briefer Sources + Formatter

**Files:**
- Create: `lib/skywatch/briefer/sources/{metar,taf,pirep,winds_aloft}.rb`
- Create: `lib/skywatch/briefer/formatters/text.rb`
- Create: `spec/briefer/sources/{metar,taf,pirep,winds_aloft}_spec.rb`
- Create: `spec/briefer/formatters/text_spec.rb`
- Modify: `lib/skywatch.rb`

- [ ] **Step 1: Create each source file**

For every source file, copy from `briefer/lib/briefer/sources/<name>.rb` and apply:
- Replace `module Briefer` → `module Skywatch; module Briefer` (add closing `end`)
- Replace `Briefer.client` → `Skywatch.client`
- Replace `Models::Metar` → `Skywatch::Briefer::Models::Metar` (etc. for each model reference)

- [ ] **Step 2: Create text formatter**

Copy from `briefer/lib/briefer/formatters/text.rb` and apply:
- Replace `module Briefer` → `module Skywatch; module Briefer` (add closing `end`)

- [ ] **Step 3: Create each source spec**

Copy each from `briefer/spec/sources/<name>_spec.rb` and apply:
- Replace all `Briefer::` → `Skywatch::Briefer::`
- Replace `Briefer.client` → `Skywatch.client`

- [ ] **Step 4: Create formatter spec**

Copy from `briefer/spec/formatters/text_spec.rb` and apply:
- Replace all `Briefer::` → `Skywatch::Briefer::`

- [ ] **Step 5: Add requires to lib/skywatch.rb**

```ruby
require_relative "skywatch/briefer/sources/metar"
require_relative "skywatch/briefer/sources/taf"
require_relative "skywatch/briefer/sources/pirep"
require_relative "skywatch/briefer/sources/winds_aloft"
require_relative "skywatch/briefer/formatters/text"
```

- [ ] **Step 6: Run tests**

Run: `bundle exec rspec spec/briefer/`
Expected: all briefer specs pass

- [ ] **Step 7: Commit**

```bash
git add lib/skywatch/briefer/sources/ lib/skywatch/briefer/formatters/ \
  spec/briefer/sources/ spec/briefer/formatters/
git commit -m "Move briefer sources and formatter to Skywatch::Briefer"
```

---

### Task 6: Briefer CLI + Convenience API + Integration Tests

**Files:**
- Create: `lib/skywatch/briefer/cli.rb`
- Create: `lib/skywatch/cli.rb`
- Create: `spec/briefer_spec.rb`
- Create: `spec/cli_spec.rb`
- Modify: `lib/skywatch.rb`

- [ ] **Step 1: Create briefer CLI**

Create `lib/skywatch/briefer/cli.rb` — copy from `briefer/lib/briefer/cli.rb` and apply:
- Replace `module Briefer` → `module Skywatch; module Briefer` (add closing `end`)
- Replace `Briefer.metar` → `Skywatch.metar` (etc. for all convenience methods)
- Replace `Briefer::Error` → `Skywatch::Error`
- Replace `Formatters::Text` → `Skywatch::Briefer::Formatters::Text`

- [ ] **Step 2: Create top-level CLI**

Create `lib/skywatch/cli.rb`:

```ruby
# frozen_string_literal: true

require "thor"

module Skywatch
  class CLI < Thor
    desc "weather SUBCOMMAND", "Aviation weather briefings"
    subcommand "weather", Skywatch::Briefer::CLI

    desc "version", "Print version"
    def version
      puts "skywatch #{Skywatch::VERSION}"
    end
  end
end
```

- [ ] **Step 3: Add convenience methods to lib/skywatch.rb**

Add inside the `class << self` block:

```ruby
def metar(*station_ids)
  Briefer::Sources::Metar.new.fetch(*station_ids)
end

def taf(*station_ids)
  Briefer::Sources::Taf.new.fetch(*station_ids)
end

def pireps(station_id, radius_nm: 100)
  Briefer::Sources::Pirep.new.fetch(station_id, radius_nm: radius_nm)
end

def winds_aloft(station_id, altitude_ft: nil)
  Briefer::Sources::WindsAloft.new.fetch(station_id, altitude_ft: altitude_ft)
end

def crosswind(station_id, runway_heading:)
  metars = metar(station_id)
  raise Error, "No METAR available for #{station_id}" if metars.empty?

  m = metars.first
  Briefer::Analysis::CrosswindCalculator.calculate(
    wind_direction_deg: m.wind_direction_deg || 0,
    wind_speed_kt: m.wind_speed_kt || 0,
    runway_heading: runway_heading
  )
end
```

Add requires at the bottom of the file:

```ruby
require_relative "skywatch/briefer/cli"
require_relative "skywatch/cli"
```

- [ ] **Step 4: Create integration spec**

Create `spec/briefer_spec.rb` — copy from `briefer/spec/briefer_spec.rb` and apply:
- Replace `Briefer` (the described class) → `Skywatch`
- Replace all `Briefer::` → `Skywatch::Briefer::` (for model references)
- Replace `Briefer::Client::Cache` → `Skywatch::Shared::Cache`

- [ ] **Step 5: Create CLI spec**

Create `spec/cli_spec.rb` — copy from `briefer/spec/cli_spec.rb` and apply:
- Replace `Briefer::CLI` → `Skywatch::Briefer::CLI`
- Replace all `Briefer::` → `Skywatch::Briefer::` (for model references)

- [ ] **Step 6: Run full test suite**

Run: `bundle exec rspec`
Expected: all pass — should match the 169 original tests (re-namespaced)

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses (fix any that appear)

- [ ] **Step 8: Commit**

```bash
git add lib/skywatch/briefer/cli.rb lib/skywatch/cli.rb lib/skywatch.rb \
  spec/briefer_spec.rb spec/cli_spec.rb
git commit -m "Add briefer CLI, top-level CLI, convenience API, and integration tests"
```

---

### Task 7: Radar Domain

**Files:**
- Create: `lib/skywatch/radar/models/state_vector.rb`
- Create: `lib/skywatch/radar/sources/opensky.rb`
- Create: `lib/skywatch/radar/analysis/proximity.rb`
- Create: `lib/skywatch/radar/formatters/text.rb`
- Create: `lib/skywatch/radar/cli.rb`
- Create: `spec/fixtures/opensky/states_bbox.json`
- Create: `spec/fixtures/opensky/states_callsign.json`
- Create: `spec/fixtures/opensky/states_icao24.json`
- Create: `spec/radar/models/state_vector_spec.rb`
- Create: `spec/radar/sources/opensky_spec.rb`
- Create: `spec/radar/analysis/proximity_spec.rb`
- Create: `spec/radar/formatters/text_spec.rb`
- Modify: `lib/skywatch.rb`
- Modify: `lib/skywatch/cli.rb`

This is **new code** — build per the radar design spec (`docs/superpowers/specs/2026-03-29-radar-design.md`), but under the `Skywatch::Radar` namespace instead of a standalone `Radar` gem. Follow the exact same code from the radar plan (`docs/superpowers/plans/2026-03-29-radar-opensky-mvp.md`) Tasks 3-6, but:

- Replace all `Radar::` → `Skywatch::Radar::`
- Replace `Radar.client` → `Skywatch::Shared::Http.new(base_url: "https://opensky-network.org")`
- Use `Skywatch::Shared::Position` instead of any radar-specific position type

- [ ] **Step 1: Create fixtures**

Copy the three OpenSky fixture files from the radar plan (Task 3 Step 1, Task 5 Steps 1-2) into `spec/fixtures/opensky/`.

- [ ] **Step 2: Create StateVector model**

Create `lib/skywatch/radar/models/state_vector.rb` — the code from radar plan Task 3, but wrapped in `module Skywatch; module Radar`.

- [ ] **Step 3: Create Proximity analysis**

Create `lib/skywatch/radar/analysis/proximity.rb` — the code from radar plan Task 4, but wrapped in `module Skywatch; module Radar`.

- [ ] **Step 4: Create Opensky source**

Create `lib/skywatch/radar/sources/opensky.rb` — the code from radar plan Task 5, but:
- Wrapped in `module Skywatch; module Radar`
- Constructor creates its own HTTP client: `Skywatch::Shared::Http.new(base_url: "https://opensky-network.org")`
- Cache wraps it: `Skywatch::Shared::Cache.new(client: http)`
- References `Skywatch::Radar::Models::StateVector`

- [ ] **Step 5: Create text formatter**

Create `lib/skywatch/radar/formatters/text.rb` — the code from radar plan Task 6, but wrapped in `module Skywatch; module Radar`.

- [ ] **Step 6: Create radar CLI**

Create `lib/skywatch/radar/cli.rb` — the code from radar plan Task 6, but:
- Wrapped in `module Skywatch; module Radar`
- References `Skywatch::Radar::*` namespaces
- References `Skywatch::Error`

- [ ] **Step 7: Create all radar specs**

Create each spec file under `spec/radar/` using the code from the radar plan, with `Skywatch::Radar::` namespace.

- [ ] **Step 8: Add requires and convenience methods to lib/skywatch.rb**

Add requires:
```ruby
require_relative "skywatch/radar/models/state_vector"
require_relative "skywatch/radar/sources/opensky"
require_relative "skywatch/radar/analysis/proximity"
require_relative "skywatch/radar/formatters/text"
require_relative "skywatch/radar/cli"
```

Add convenience methods:
```ruby
def flights(lat:, lon:, radius_nm: 50)
  box = Radar::Analysis::Proximity.bbox(lat, lon, radius_nm: radius_nm)
  vectors = Radar::Sources::Opensky.new.states_bbox(**box)
  Radar::Analysis::Proximity.within_radius(vectors, lat: lat, lon: lon, radius_nm: radius_nm)
end

def track(callsign)
  Radar::Sources::Opensky.new.states_by_callsign(callsign)
end

def aircraft(icao24)
  Radar::Sources::Opensky.new.states_by_icao24(icao24)
end
```

- [ ] **Step 9: Register radar subcommand in top-level CLI**

Add to `lib/skywatch/cli.rb`:

```ruby
desc "radar SUBCOMMAND", "Flight tracking"
subcommand "radar", Skywatch::Radar::CLI
```

- [ ] **Step 10: Run full test suite**

Run: `bundle exec rspec`
Expected: all pass (169 briefer + new radar tests)

- [ ] **Step 11: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 12: Commit**

```bash
git add lib/skywatch/radar/ spec/radar/ spec/fixtures/opensky/ \
  lib/skywatch.rb lib/skywatch/cli.rb
git commit -m "Add radar domain: StateVector, OpenSky source, proximity, CLI"
```

---

### Task 8: Delete Old Code + Final Verification

**Files:**
- Delete: `briefer/` (entire directory)
- Delete: `radar/` (entire directory)

- [ ] **Step 1: Delete old directories**

```bash
git rm -rf briefer/ radar/
```

- [ ] **Step 2: Run full test suite**

Run: `bundle exec rspec`
Expected: all pass

- [ ] **Step 3: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 4: Run default rake task**

Run: `bundle exec rake`
Expected: all pass

- [ ] **Step 5: Verify CLI**

Run: `bundle exec ruby -e "require 'skywatch'; puts Skywatch::VERSION"`
Expected: `0.1.0`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Remove old briefer/ and radar/ directories — monogem refactor complete"
```

- [ ] **Step 7: Push**

```bash
git push
```
