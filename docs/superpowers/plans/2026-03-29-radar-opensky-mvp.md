# Radar — OpenSky MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `radar` Ruby gem that tracks flights using the OpenSky Network API, with CLI commands for flights near airports, callsign tracking, and aircraft lookup.

**Architecture:** Single gem following the skywatch gem contract. OpenSky REST API as sole data source, Faraday HTTP client, Thor CLI, RSpec + WebMock tests. Same patterns as briefer gem (sources/, models/, analysis/, formatters/).

**Tech Stack:** Ruby 3.2+, Faraday ~> 2.0, faraday-retry ~> 2.0, Thor ~> 1.3, RSpec, WebMock, RuboCop

---

### Task 1: Gem Scaffold

**Files:**
- Create: `radar/radar.gemspec`
- Create: `radar/Gemfile`
- Create: `radar/Rakefile`
- Create: `radar/.rubocop.yml`
- Create: `radar/.rspec`
- Create: `radar/.gitignore`
- Create: `radar/LICENSE.txt`
- Create: `radar/lib/radar.rb`
- Create: `radar/lib/radar/version.rb`
- Create: `radar/lib/radar/errors.rb`
- Create: `radar/exe/radar`
- Create: `radar/spec/spec_helper.rb`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p radar/lib/radar/{client,sources,models,analysis,formatters}
mkdir -p radar/spec/{fixtures/opensky,sources,models,analysis}
mkdir -p radar/exe
```

- [ ] **Step 2: Create version.rb**

Create `radar/lib/radar/version.rb`:

```ruby
# frozen_string_literal: true

module Radar
  VERSION = "0.1.0"
end
```

- [ ] **Step 3: Create errors.rb**

Create `radar/lib/radar/errors.rb`:

```ruby
# frozen_string_literal: true

module Radar
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

- [ ] **Step 4: Create lib/radar.rb**

Create `radar/lib/radar.rb`:

```ruby
# frozen_string_literal: true

require_relative "radar/version"
require_relative "radar/errors"

module Radar
  class << self
  end
end
```

- [ ] **Step 5: Create gemspec**

Create `radar/radar.gemspec`:

```ruby
# frozen_string_literal: true

require_relative "lib/radar/version"

Gem::Specification.new do |spec|
  spec.name = "radar"
  spec.version = Radar::VERSION
  spec.authors = ["Jay Ravaliya"]
  spec.summary = "Flight tracking via OpenSky Network"
  spec.description = "Real-time flight tracking using the OpenSky Network API. Part of the skywatch aviation awareness system."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "exe/*", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["radar"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
```

- [ ] **Step 6: Create Gemfile**

Create `radar/Gemfile`:

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec
```

- [ ] **Step 7: Create Rakefile**

Create `radar/Rakefile`:

```ruby
# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]
```

- [ ] **Step 8: Create .rubocop.yml**

Create `radar/.rubocop.yml`:

```yaml
AllCops:
  TargetRubyVersion: 3.2
  NewCops: enable

Style/Documentation:
  Enabled: false

Metrics/BlockLength:
  Exclude:
    - "spec/**/*"
```

- [ ] **Step 9: Create .rspec**

Create `radar/.rspec`:

```
--require spec_helper
--format documentation
```

- [ ] **Step 10: Create .gitignore**

Create `radar/.gitignore`:

```
/.bundle/
/tmp/
/pkg/
Gemfile.lock
*.gem
```

- [ ] **Step 11: Create LICENSE.txt**

Create `radar/LICENSE.txt`:

```
MIT License

Copyright (c) 2026 Jay Ravaliya

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 12: Create spec_helper.rb**

Create `radar/spec/spec_helper.rb`:

```ruby
# frozen_string_literal: true

require "radar"
require "webmock/rspec"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
```

- [ ] **Step 13: Create exe/radar**

Create `radar/exe/radar`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "radar"

Radar::CLI.start(ARGV)
```

- [ ] **Step 14: Make exe executable and install deps**

```bash
chmod +x radar/exe/radar
cd radar && bundle install
```

- [ ] **Step 15: Create CLAUDE.md**

Create `radar/CLAUDE.md`:

```markdown
# Radar

A Ruby gem for real-time flight tracking via the OpenSky Network API. Part of the skywatch aviation awareness system.

## Project Overview

- **Type**: Ruby gem (single gem, internal modules)
- **CLI framework**: Thor
- **HTTP client**: Faraday (with faraday-retry)
- **Testing**: RSpec with WebMock fixtures
- **Style**: RuboCop

## Commands

\`\`\`bash
bundle exec rspec              # Run tests
bundle exec rubocop            # Lint
bundle exec rake               # Default task
bin/radar                      # CLI entry point
\`\`\`

## Architecture

\`\`\`
Radar (top-level convenience methods)
  -> CLI (Thor)
  -> Data Layer (Sources module)
  -> HTTP Client (Faraday wrapper with caching)
\`\`\`

Key modules: `Sources::Opensky` (data fetching), `Models::StateVector` (aircraft state), `Analysis::Proximity` (bounding box, distance), `Formatters::Text` (human-readable output).

## Conventions

- Data source is OpenSky Network (free, no key)
- Cache TTL: 15 seconds for state vectors
- Custom User-Agent header on all requests
- Test against saved fixtures, never live APIs in tests
- All CLI commands support --format json|text (auto-detect TTY)
```

- [ ] **Step 16: Verify setup**

Run: `cd radar && bundle exec ruby -e "require 'radar'; puts Radar::VERSION"`
Expected: `0.1.0`

- [ ] **Step 17: Commit**

```bash
cd radar && git init && git add -A
git commit -m "Scaffold radar gem with dependencies and test setup"
```

---

### Task 2: HTTP Client + Cache

**Files:**
- Create: `radar/lib/radar/client/http.rb`
- Create: `radar/lib/radar/client/cache.rb`
- Create: `radar/spec/client/http_spec.rb`
- Create: `radar/spec/client/cache_spec.rb`
- Modify: `radar/lib/radar.rb`

- [ ] **Step 1: Write the HTTP client test**

Create `radar/spec/client/http_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Radar::Client::Http do
  subject(:client) { described_class.new }

  describe "#get" do
    it "returns parsed JSON" do
      stub_request(:get, "https://opensky-network.org/api/states/all")
        .with(query: { lamin: "37.0", lamax: "38.0", lomin: "-123.0", lomax: "-122.0" })
        .to_return(status: 200, body: '{"time":1234,"states":[]}',
                   headers: { "Content-Type" => "application/json" })

      result = client.get("/api/states/all", { lamin: "37.0", lamax: "38.0", lomin: "-123.0", lomax: "-122.0" })
      expect(result).to eq({ "time" => 1234, "states" => [] })
    end

    it "raises ApiError on HTTP failure" do
      stub_request(:get, "https://opensky-network.org/api/states/all")
        .to_return(status: 500, body: "Server Error")

      expect { client.get("/api/states/all") }.to raise_error(Radar::ApiError)
    end

    it "raises ConnectionError on network failure" do
      stub_request(:get, "https://opensky-network.org/api/states/all")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { client.get("/api/states/all") }.to raise_error(Radar::ConnectionError)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd radar && bundle exec rspec spec/client/http_spec.rb`
Expected: FAIL — `uninitialized constant Radar::Client`

- [ ] **Step 3: Write the HTTP client implementation**

Create `radar/lib/radar/client/http.rb`:

```ruby
# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Radar
  module Client
    class Http
      BASE_URL = "https://opensky-network.org"

      attr_reader :connection

      def initialize
        @connection = build_connection
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

      private

      def build_connection
        Faraday.new(url: BASE_URL) do |f|
          f.request :retry, max: 3, interval: 1.0, backoff_factor: 2
          f.headers["User-Agent"] = "Radar/#{Radar::VERSION} (ruby; skywatch)"
          f.options.open_timeout = 10
          f.options.timeout = 30
        end
      end
    end
  end
end
```

- [ ] **Step 4: Add require and client accessor to lib/radar.rb**

Replace `radar/lib/radar.rb` contents with:

```ruby
# frozen_string_literal: true

require_relative "radar/version"
require_relative "radar/errors"
require_relative "radar/client/http"
require_relative "radar/client/cache"

module Radar
  class << self
    def client
      @client ||= Client::Cache.new(client: Client::Http.new)
    end

    def reset!
      @client = nil
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd radar && bundle exec rspec spec/client/http_spec.rb`
Expected: 3 examples, 0 failures

- [ ] **Step 6: Write the cache test**

Create `radar/spec/client/cache_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Radar::Client::Cache do
  let(:inner_client) { instance_double(Radar::Client::Http) }
  subject(:cache) { described_class.new(client: inner_client) }

  describe "#get" do
    it "delegates to inner client on cache miss" do
      allow(inner_client).to receive(:get)
        .with("/api/states/all", {})
        .and_return({ "time" => 1234, "states" => [] })

      result = cache.get("/api/states/all", {}, ttl: 15)
      expect(result).to eq({ "time" => 1234, "states" => [] })
    end

    it "returns cached value on subsequent calls" do
      allow(inner_client).to receive(:get)
        .with("/api/states/all", {})
        .and_return({ "time" => 1234, "states" => [] })

      cache.get("/api/states/all", {}, ttl: 15)
      cache.get("/api/states/all", {}, ttl: 15)

      expect(inner_client).to have_received(:get).once
    end

    it "re-fetches after TTL expires" do
      allow(inner_client).to receive(:get)
        .with("/api/states/all", {})
        .and_return({ "time" => 1234, "states" => [] })

      cache.get("/api/states/all", {}, ttl: 0)
      sleep 0.01
      cache.get("/api/states/all", {}, ttl: 0)

      expect(inner_client).to have_received(:get).twice
    end
  end

  describe "#clear" do
    it "empties the cache" do
      allow(inner_client).to receive(:get).and_return({})

      cache.get("/test", {}, ttl: 300)
      expect(cache.size).to eq(1)
      cache.clear
      expect(cache.size).to eq(0)
    end
  end
end
```

- [ ] **Step 7: Write the cache implementation**

Create `radar/lib/radar/client/cache.rb`:

```ruby
# frozen_string_literal: true

module Radar
  module Client
    class Cache
      def initialize(client:)
        @client = client
        @store = {}
        @mutex = Mutex.new
      end

      def get(path, params = {}, ttl: 15)
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

- [ ] **Step 8: Run all tests**

Run: `cd radar && bundle exec rspec`
Expected: all pass

- [ ] **Step 9: Run rubocop**

Run: `cd radar && bundle exec rubocop`
Expected: no offenses

- [ ] **Step 10: Commit**

```bash
git add lib/radar/client/ spec/client/ lib/radar.rb
git commit -m "Add HTTP client and cache layer for OpenSky API"
```

---

### Task 3: StateVector Model

**Files:**
- Create: `radar/spec/fixtures/opensky/states_bbox.json`
- Create: `radar/lib/radar/models/state_vector.rb`
- Create: `radar/spec/models/state_vector_spec.rb`
- Modify: `radar/lib/radar.rb`

- [ ] **Step 1: Create fixture**

Create `radar/spec/fixtures/opensky/states_bbox.json`:

```json
{
  "time": 1711670400,
  "states": [
    ["a12345", "UAL1234 ", "United States", 1711670398, 1711670400, -122.379, 37.621, 5486.4, false, 128.5, 280.0, -6.5, null, 5562.6, "1200", false, 0],
    ["a67890", "AAL567  ", "United States", 1711670395, 1711670399, -122.100, 37.800, 10668.0, false, 231.5, 90.0, 0.0, null, 10700.0, "4521", false, 0],
    ["ab0000", null, "Canada", 1711670390, 1711670398, -122.500, 37.500, null, true, 5.1, 180.0, null, null, null, null, false, 0]
  ]
}
```

- [ ] **Step 2: Write the failing test**

Create `radar/spec/models/state_vector_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Radar::Models::StateVector do
  let(:fixture) { JSON.parse(File.read("spec/fixtures/opensky/states_bbox.json")) }
  let(:row) { fixture["states"][0] }

  describe ".from_api" do
    subject(:sv) { described_class.from_api(row) }

    it "parses identification fields" do
      expect(sv.icao24).to eq("a12345")
      expect(sv.callsign).to eq("UAL1234")
      expect(sv.origin_country).to eq("United States")
    end

    it "parses position fields" do
      expect(sv.longitude).to be_within(0.001).of(-122.379)
      expect(sv.latitude).to be_within(0.001).of(37.621)
      expect(sv.baro_altitude_m).to be_within(0.1).of(5486.4)
      expect(sv.on_ground).to be(false)
    end

    it "parses velocity fields" do
      expect(sv.velocity_ms).to be_within(0.1).of(128.5)
      expect(sv.true_track_deg).to be_within(0.1).of(280.0)
      expect(sv.vertical_rate_ms).to be_within(0.1).of(-6.5)
    end

    it "parses squawk" do
      expect(sv.squawk).to eq("1200")
    end

    it "strips whitespace from callsign" do
      expect(sv.callsign).to eq("UAL1234")
    end
  end

  describe ".from_api with nil callsign" do
    subject(:sv) { described_class.from_api(fixture["states"][2]) }

    it "handles nil callsign" do
      expect(sv.callsign).to be_nil
    end

    it "handles ground aircraft" do
      expect(sv.on_ground).to be(true)
    end
  end

  describe "#altitude_ft" do
    subject(:sv) { described_class.from_api(row) }

    it "converts meters to feet" do
      expect(sv.altitude_ft).to be_within(1).of(18_001)
    end

    it "returns nil when baro_altitude_m is nil" do
      ground = described_class.from_api(fixture["states"][2])
      expect(ground.altitude_ft).to be_nil
    end
  end

  describe "#velocity_kt" do
    subject(:sv) { described_class.from_api(row) }

    it "converts m/s to knots" do
      expect(sv.velocity_kt).to be_within(1).of(250)
    end
  end

  describe "#vertical_rate_fpm" do
    subject(:sv) { described_class.from_api(row) }

    it "converts m/s to ft/min" do
      expect(sv.vertical_rate_fpm).to be_within(10).of(-1280)
    end
  end

  describe "#emergency?" do
    it "returns false for normal squawk" do
      sv = described_class.from_api(row)
      expect(sv.emergency?).to be(false)
    end

    it "returns true for 7700" do
      emergency_row = row.dup
      emergency_row[14] = "7700"
      sv = described_class.from_api(emergency_row)
      expect(sv.emergency?).to be(true)
    end

    it "returns true for 7600" do
      row_dup = row.dup
      row_dup[14] = "7600"
      sv = described_class.from_api(row_dup)
      expect(sv.emergency?).to be(true)
    end

    it "returns true for 7500" do
      row_dup = row.dup
      row_dup[14] = "7500"
      sv = described_class.from_api(row_dup)
      expect(sv.emergency?).to be(true)
    end
  end

  describe "#to_h" do
    subject(:sv) { described_class.from_api(row) }

    it "returns a hash with key fields" do
      hash = sv.to_h
      expect(hash[:icao24]).to eq("a12345")
      expect(hash[:callsign]).to eq("UAL1234")
      expect(hash[:altitude_ft]).to be_within(1).of(18_001)
      expect(hash[:velocity_kt]).to be_within(1).of(250)
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd radar && bundle exec rspec spec/models/state_vector_spec.rb`
Expected: FAIL — `uninitialized constant Radar::Models`

- [ ] **Step 4: Write the implementation**

Create `radar/lib/radar/models/state_vector.rb`:

```ruby
# frozen_string_literal: true

module Radar
  module Models
    class StateVector
      METERS_TO_FEET = 3.28084
      MS_TO_KNOTS = 1.94384
      MS_TO_FPM = 196.85

      EMERGENCY_SQUAWKS = %w[7500 7600 7700].freeze

      attr_reader :icao24, :callsign, :origin_country,
                  :time_position, :last_contact,
                  :longitude, :latitude, :baro_altitude_m,
                  :on_ground, :velocity_ms, :true_track_deg,
                  :vertical_rate_ms, :geo_altitude_m,
                  :squawk, :spi

      def self.from_api(row) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        new(
          icao24: row[0],
          callsign: row[1]&.strip&.then { |s| s.empty? ? nil : s },
          origin_country: row[2],
          time_position: row[3],
          last_contact: row[4],
          longitude: row[5]&.to_f,
          latitude: row[6]&.to_f,
          baro_altitude_m: row[7]&.to_f,
          on_ground: row[8],
          velocity_ms: row[9]&.to_f,
          true_track_deg: row[10]&.to_f,
          vertical_rate_ms: row[11]&.to_f,
          geo_altitude_m: row[13]&.to_f,
          squawk: row[14],
          spi: row[15] || false
        )
      end

      def initialize(**attrs) # rubocop:disable Metrics/MethodLength
        @icao24 = attrs[:icao24]
        @callsign = attrs[:callsign]
        @origin_country = attrs[:origin_country]
        @time_position = attrs[:time_position]
        @last_contact = attrs[:last_contact]
        @longitude = attrs[:longitude]
        @latitude = attrs[:latitude]
        @baro_altitude_m = attrs[:baro_altitude_m]
        @on_ground = attrs[:on_ground]
        @velocity_ms = attrs[:velocity_ms]
        @true_track_deg = attrs[:true_track_deg]
        @vertical_rate_ms = attrs[:vertical_rate_ms]
        @geo_altitude_m = attrs[:geo_altitude_m]
        @squawk = attrs[:squawk]
        @spi = attrs[:spi]
      end

      def altitude_ft
        return nil if baro_altitude_m.nil?

        (baro_altitude_m * METERS_TO_FEET).round
      end

      def velocity_kt
        return nil if velocity_ms.nil?

        (velocity_ms * MS_TO_KNOTS).round
      end

      def vertical_rate_fpm
        return nil if vertical_rate_ms.nil?

        (vertical_rate_ms * MS_TO_FPM).round
      end

      def emergency?
        EMERGENCY_SQUAWKS.include?(squawk)
      end

      def to_h # rubocop:disable Metrics/MethodLength
        {
          icao24: icao24, callsign: callsign, origin_country: origin_country,
          latitude: latitude, longitude: longitude,
          altitude_ft: altitude_ft, on_ground: on_ground,
          velocity_kt: velocity_kt, true_track_deg: true_track_deg,
          vertical_rate_fpm: vertical_rate_fpm,
          squawk: squawk, emergency: emergency?
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end
    end
  end
end
```

- [ ] **Step 5: Add require to lib/radar.rb**

Add after `require_relative "radar/client/cache"`:

```ruby
require_relative "radar/models/state_vector"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd radar && bundle exec rspec spec/models/state_vector_spec.rb`
Expected: 14 examples, 0 failures

- [ ] **Step 7: Run rubocop**

Run: `cd radar && bundle exec rubocop lib/radar/models/state_vector.rb spec/models/state_vector_spec.rb`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/radar/models/state_vector.rb spec/models/state_vector_spec.rb \
  spec/fixtures/opensky/states_bbox.json lib/radar.rb
git commit -m "Add StateVector model with OpenSky array parsing and unit conversions"
```

---

### Task 4: Proximity Analysis

**Files:**
- Create: `radar/lib/radar/analysis/proximity.rb`
- Create: `radar/spec/analysis/proximity_spec.rb`
- Modify: `radar/lib/radar.rb`

- [ ] **Step 1: Write the failing test**

Create `radar/spec/analysis/proximity_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Radar::Analysis::Proximity do
  describe ".bbox" do
    it "returns a bounding box hash around a lat/lon" do
      # KSFO: 37.6213, -122.379
      box = described_class.bbox(37.6213, -122.379, radius_nm: 50)

      expect(box).to have_key(:lamin)
      expect(box).to have_key(:lamax)
      expect(box).to have_key(:lomin)
      expect(box).to have_key(:lomax)
      expect(box[:lamin]).to be < 37.6213
      expect(box[:lamax]).to be > 37.6213
      expect(box[:lomin]).to be < -122.379
      expect(box[:lomax]).to be > -122.379
    end

    it "produces a larger box for larger radius" do
      small = described_class.bbox(37.6213, -122.379, radius_nm: 10)
      large = described_class.bbox(37.6213, -122.379, radius_nm: 100)

      expect(large[:lamax] - large[:lamin]).to be > (small[:lamax] - small[:lamin])
    end
  end

  describe ".distance_nm" do
    it "calculates distance between two points" do
      # KSFO to KOAK is approximately 11nm
      dist = described_class.distance_nm(37.6213, -122.379, 37.7213, -122.221)
      expect(dist).to be_within(3).of(10)
    end

    it "returns 0 for same point" do
      dist = described_class.distance_nm(37.6213, -122.379, 37.6213, -122.379)
      expect(dist).to eq(0)
    end
  end

  describe ".within_radius" do
    let(:close_sv) do
      Radar::Models::StateVector.new(
        icao24: "a12345", callsign: "UAL1", latitude: 37.65, longitude: -122.40,
        baro_altitude_m: 5000.0, on_ground: false, velocity_ms: 100.0,
        true_track_deg: 280.0, vertical_rate_ms: 0.0, squawk: "1200", spi: false
      )
    end

    let(:far_sv) do
      Radar::Models::StateVector.new(
        icao24: "b67890", callsign: "DAL2", latitude: 40.0, longitude: -120.0,
        baro_altitude_m: 10000.0, on_ground: false, velocity_ms: 200.0,
        true_track_deg: 90.0, vertical_rate_ms: 0.0, squawk: "1200", spi: false
      )
    end

    it "filters state vectors to those within radius" do
      result = described_class.within_radius([close_sv, far_sv], lat: 37.6213, lon: -122.379, radius_nm: 50)
      expect(result.size).to eq(1)
      expect(result.first.callsign).to eq("UAL1")
    end

    it "excludes vectors with nil position" do
      nil_sv = Radar::Models::StateVector.new(
        icao24: "c00000", callsign: "TST", latitude: nil, longitude: nil,
        on_ground: false, squawk: nil, spi: false
      )
      result = described_class.within_radius([nil_sv, close_sv], lat: 37.6213, lon: -122.379, radius_nm: 50)
      expect(result.size).to eq(1)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd radar && bundle exec rspec spec/analysis/proximity_spec.rb`
Expected: FAIL — `uninitialized constant Radar::Analysis`

- [ ] **Step 3: Write the implementation**

Create `radar/lib/radar/analysis/proximity.rb`:

```ruby
# frozen_string_literal: true

module Radar
  module Analysis
    module Proximity
      NM_PER_DEG_LAT = 60.0

      def self.bbox(lat, lon, radius_nm: 50)
        lat_offset = radius_nm / NM_PER_DEG_LAT
        lon_offset = radius_nm / (NM_PER_DEG_LAT * Math.cos(lat * Math::PI / 180))

        {
          lamin: (lat - lat_offset).round(4),
          lamax: (lat + lat_offset).round(4),
          lomin: (lon - lon_offset).round(4),
          lomax: (lon + lon_offset).round(4)
        }
      end

      def self.distance_nm(lat1, lon1, lat2, lon2)
        return 0 if lat1 == lat2 && lon1 == lon2

        rlat1 = lat1 * Math::PI / 180
        rlat2 = lat2 * Math::PI / 180
        dlat = (lat2 - lat1) * Math::PI / 180
        dlon = (lon2 - lon1) * Math::PI / 180

        a = Math.sin(dlat / 2)**2 + Math.cos(rlat1) * Math.cos(rlat2) * Math.sin(dlon / 2)**2
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

        (3440.065 * c).round(1)
      end

      def self.within_radius(state_vectors, lat:, lon:, radius_nm:)
        state_vectors.select do |sv|
          next false if sv.latitude.nil? || sv.longitude.nil?

          distance_nm(lat, lon, sv.latitude, sv.longitude) <= radius_nm
        end
      end
    end
  end
end
```

- [ ] **Step 4: Add require to lib/radar.rb**

Add after `require_relative "radar/models/state_vector"`:

```ruby
require_relative "radar/analysis/proximity"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd radar && bundle exec rspec spec/analysis/proximity_spec.rb`
Expected: 6 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `cd radar && bundle exec rubocop lib/radar/analysis/proximity.rb spec/analysis/proximity_spec.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/radar/analysis/proximity.rb spec/analysis/proximity_spec.rb lib/radar.rb
git commit -m "Add Proximity analysis with bbox, haversine distance, and radius filter"
```

---

### Task 5: OpenSky Source

**Files:**
- Create: `radar/spec/fixtures/opensky/states_callsign.json`
- Create: `radar/spec/fixtures/opensky/states_icao24.json`
- Create: `radar/lib/radar/sources/opensky.rb`
- Create: `radar/spec/sources/opensky_spec.rb`
- Modify: `radar/lib/radar.rb`

- [ ] **Step 1: Create callsign fixture**

Create `radar/spec/fixtures/opensky/states_callsign.json`:

```json
{
  "time": 1711670400,
  "states": [
    ["a12345", "UAL1234 ", "United States", 1711670398, 1711670400, -122.379, 37.621, 5486.4, false, 128.5, 280.0, -6.5, null, 5562.6, "1200", false, 0]
  ]
}
```

- [ ] **Step 2: Create icao24 fixture**

Create `radar/spec/fixtures/opensky/states_icao24.json`:

```json
{
  "time": 1711670400,
  "states": [
    ["a12345", "UAL1234 ", "United States", 1711670398, 1711670400, -122.379, 37.621, 5486.4, false, 128.5, 280.0, -6.5, null, 5562.6, "1200", false, 0]
  ]
}
```

- [ ] **Step 3: Write the failing test**

Create `radar/spec/sources/opensky_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Radar::Sources::Opensky do
  subject(:source) { described_class.new(client: Radar::Client::Http.new) }

  let(:bbox_response) { File.read("spec/fixtures/opensky/states_bbox.json") }
  let(:callsign_response) { File.read("spec/fixtures/opensky/states_callsign.json") }
  let(:icao24_response) { File.read("spec/fixtures/opensky/states_icao24.json") }

  describe "#states_bbox" do
    before do
      stub_request(:get, "https://opensky-network.org/api/states/all")
        .with(query: hash_including("lamin" => "37.0", "lamax" => "38.0"))
        .to_return(status: 200, body: bbox_response,
                   headers: { "Content-Type" => "application/json" })
    end

    it "returns StateVector models" do
      vectors = source.states_bbox(lamin: 37.0, lamax: 38.0, lomin: -123.0, lomax: -122.0)
      expect(vectors).to all(be_a(Radar::Models::StateVector))
      expect(vectors.size).to eq(3)
    end

    it "parses callsigns correctly" do
      vectors = source.states_bbox(lamin: 37.0, lamax: 38.0, lomin: -123.0, lomax: -122.0)
      expect(vectors.first.callsign).to eq("UAL1234")
    end
  end

  describe "#states_by_callsign" do
    before do
      stub_request(:get, "https://opensky-network.org/api/states/all")
        .to_return(status: 200, body: bbox_response,
                   headers: { "Content-Type" => "application/json" })
    end

    it "filters by callsign (case-insensitive)" do
      vectors = source.states_by_callsign("UAL1234")
      expect(vectors.size).to eq(1)
      expect(vectors.first.callsign).to eq("UAL1234")
    end

    it "returns empty array for no match" do
      vectors = source.states_by_callsign("NONEXISTENT")
      expect(vectors).to eq([])
    end
  end

  describe "#states_by_icao24" do
    before do
      stub_request(:get, "https://opensky-network.org/api/states/all")
        .with(query: hash_including("icao24" => "a12345"))
        .to_return(status: 200, body: icao24_response,
                   headers: { "Content-Type" => "application/json" })
    end

    it "returns StateVector for icao24" do
      vectors = source.states_by_icao24("a12345")
      expect(vectors.size).to eq(1)
      expect(vectors.first.icao24).to eq("a12345")
    end
  end

  describe "empty states response" do
    before do
      stub_request(:get, "https://opensky-network.org/api/states/all")
        .to_return(status: 200, body: '{"time":1234,"states":null}',
                   headers: { "Content-Type" => "application/json" })
    end

    it "returns empty array when states is null" do
      vectors = source.states_by_callsign("UAL1234")
      expect(vectors).to eq([])
    end
  end
end
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd radar && bundle exec rspec spec/sources/opensky_spec.rb`
Expected: FAIL — `uninitialized constant Radar::Sources`

- [ ] **Step 5: Write the implementation**

Create `radar/lib/radar/sources/opensky.rb`:

```ruby
# frozen_string_literal: true

module Radar
  module Sources
    class Opensky
      ENDPOINT = "/api/states/all"
      TTL = 15

      def initialize(client: Radar.client)
        @client = client
      end

      def states_bbox(lamin:, lamax:, lomin:, lomax:)
        data = @client.get(ENDPOINT, {
          lamin: lamin.to_s, lamax: lamax.to_s,
          lomin: lomin.to_s, lomax: lomax.to_s
        }, ttl: TTL)
        parse_states(data)
      end

      def states_by_callsign(callsign)
        data = @client.get(ENDPOINT, {}, ttl: TTL)
        parse_states(data).select { |sv| sv.callsign&.upcase == callsign.upcase }
      end

      def states_by_icao24(icao24)
        data = @client.get(ENDPOINT, { icao24: icao24.downcase }, ttl: TTL)
        parse_states(data)
      end

      private

      def parse_states(data)
        return [] if data["states"].nil?

        data["states"].map { |row| Models::StateVector.from_api(row) }
      end
    end
  end
end
```

- [ ] **Step 6: Add require to lib/radar.rb**

Add after `require_relative "radar/analysis/proximity"`:

```ruby
require_relative "radar/sources/opensky"
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd radar && bundle exec rspec spec/sources/opensky_spec.rb`
Expected: 5 examples, 0 failures

- [ ] **Step 8: Run full suite and rubocop**

Run: `cd radar && bundle exec rspec && bundle exec rubocop`
Expected: all pass, no offenses

- [ ] **Step 9: Commit**

```bash
git add lib/radar/sources/opensky.rb spec/sources/opensky_spec.rb \
  spec/fixtures/opensky/states_callsign.json spec/fixtures/opensky/states_icao24.json \
  lib/radar.rb
git commit -m "Add OpenSky source with bbox, callsign, and icao24 queries"
```

---

### Task 6: Text Formatter + CLI

**Files:**
- Create: `radar/lib/radar/formatters/text.rb`
- Create: `radar/lib/radar/cli.rb`
- Create: `radar/spec/formatters/text_spec.rb`
- Modify: `radar/lib/radar.rb`
- Modify: `radar/exe/radar`

- [ ] **Step 1: Write the formatter test**

Create `radar/spec/formatters/text_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Radar::Formatters::Text do
  let(:sv) do
    Radar::Models::StateVector.new(
      icao24: "a12345", callsign: "UAL1234", origin_country: "United States",
      time_position: 1711670398, last_contact: 1711670400,
      latitude: 37.621, longitude: -122.379,
      baro_altitude_m: 5486.4, on_ground: false,
      velocity_ms: 128.5, true_track_deg: 280.0, vertical_rate_ms: -6.5,
      geo_altitude_m: 5562.6, squawk: "1200", spi: false
    )
  end

  describe ".format_flight_row" do
    it "returns a formatted row" do
      row = described_class.format_flight_row(sv)
      expect(row).to include("UAL1234")
      expect(row).to include("1200")
    end
  end

  describe ".format_track" do
    it "returns a detailed track display" do
      output = described_class.format_track(sv)
      expect(output).to include("UAL1234")
      expect(output).to include("United States")
      expect(output).to include("280")
    end
  end

  describe ".format_flights_table" do
    it "returns a header and rows" do
      output = described_class.format_flights_table([sv], label: "KSFO (50nm)")
      expect(output).to include("KSFO")
      expect(output).to include("UAL1234")
      expect(output).to include("CALL")
    end

    it "handles empty array" do
      output = described_class.format_flights_table([], label: "KSFO (50nm)")
      expect(output).to include("No flights")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd radar && bundle exec rspec spec/formatters/text_spec.rb`
Expected: FAIL — `uninitialized constant Radar::Formatters`

- [ ] **Step 3: Write the formatter implementation**

Create `radar/lib/radar/formatters/text.rb`:

```ruby
# frozen_string_literal: true

module Radar
  module Formatters
    module Text
      HEADER = "  %-10s %7s %6s %5s %7s" # rubocop:disable Style/FormatStringToken
      ROW    = "  %-10s %7s %6s %5s %7s" # rubocop:disable Style/FormatStringToken

      def self.format_flights_table(state_vectors, label:)
        return "No flights found near #{label}\n" if state_vectors.empty?

        lines = ["Flights near #{label} — #{state_vectors.size} aircraft\n"]
        lines << format(HEADER, "CALL", "ALT", "SPD", "HDG", "SQUAWK") + "\n"
        state_vectors.each { |sv| lines << format_flight_row(sv) }
        lines.join
      end

      def self.format_flight_row(sv)
        call = sv.callsign || sv.icao24
        alt = sv.altitude_ft ? "#{number_with_commas(sv.altitude_ft)}'" : "GND"
        spd = sv.velocity_kt ? "#{sv.velocity_kt}kt" : "-"
        hdg = sv.true_track_deg ? "#{sv.true_track_deg.round}°" : "-"
        sqk = sv.squawk || "-"
        format(ROW, call, alt, spd, hdg, sqk) + "\n"
      end

      def self.format_track(sv) # rubocop:disable Metrics/AbcSize
        call = sv.callsign || sv.icao24
        alt = sv.altitude_ft ? "#{number_with_commas(sv.altitude_ft)} ft" : "On ground"
        spd = sv.velocity_kt ? "#{sv.velocity_kt} kt" : "-"
        hdg = sv.true_track_deg ? "#{sv.true_track_deg.round}°" : "-"
        vr = sv.vertical_rate_fpm ? "#{sv.vertical_rate_fpm} fpm" : "-"
        desc = sv.vertical_rate_fpm &.negative? ? " (descending)" : sv.vertical_rate_fpm&.positive? ? " (climbing)" : ""

        <<~TEXT
          #{call} — #{sv.origin_country}
            Position:  #{sv.latitude}°N, #{sv.longitude}°W
            Altitude:  #{alt}
            Speed:     #{spd}, heading #{hdg}
            Vertical:  #{vr}#{desc}
            Squawk:    #{sv.squawk || "-"}
            On ground: #{sv.on_ground ? "Yes" : "No"}
        TEXT
      end

      def self.number_with_commas(number)
        number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      end

      private_class_method :number_with_commas
    end
  end
end
```

- [ ] **Step 4: Write the CLI**

Create `radar/lib/radar/cli.rb`:

```ruby
# frozen_string_literal: true

require "thor"
require "json"

module Radar
  class CLI < Thor
    class_option :format, type: :string, enum: %w[text json],
                          desc: "Output format (default: text on TTY, json when piped)"

    desc "flights LAT LON", "Active flights near coordinates"
    option :radius, type: :numeric, default: 50, desc: "Search radius in NM"
    def flights(lat, lon)
      box = Analysis::Proximity.bbox(lat.to_f, lon.to_f, radius_nm: options[:radius])
      vectors = Sources::Opensky.new.states_bbox(**box)
      nearby = Analysis::Proximity.within_radius(vectors, lat: lat.to_f, lon: lon.to_f, radius_nm: options[:radius])

      if output_format == "json"
        puts JSON.pretty_generate(nearby.map(&:to_h))
      else
        label = "#{lat}, #{lon} (#{options[:radius]}nm)"
        print Formatters::Text.format_flights_table(nearby, label: label)
      end
    rescue Radar::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "track CALLSIGN", "Track flight by callsign"
    def track(callsign)
      vectors = Sources::Opensky.new.states_by_callsign(callsign)

      if vectors.empty?
        if output_format == "json"
          puts "[]"
        else
          puts "No aircraft found with callsign #{callsign.upcase}"
        end
        return
      end

      if output_format == "json"
        puts JSON.pretty_generate(vectors.map(&:to_h))
      else
        vectors.each { |sv| print Formatters::Text.format_track(sv) }
      end
    rescue Radar::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "aircraft ICAO24", "Lookup by ICAO24 hex address"
    def aircraft(icao24)
      vectors = Sources::Opensky.new.states_by_icao24(icao24)

      if vectors.empty?
        if output_format == "json"
          puts "[]"
        else
          puts "No aircraft found with ICAO24 #{icao24}"
        end
        return
      end

      if output_format == "json"
        puts JSON.pretty_generate(vectors.map(&:to_h))
      else
        vectors.each { |sv| print Formatters::Text.format_track(sv) }
      end
    rescue Radar::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "version", "Print version"
    def version
      puts "radar #{Radar::VERSION}"
    end

    private

    def output_format
      options[:format] || ($stdout.tty? ? "text" : "json")
    end
  end
end
```

- [ ] **Step 5: Add requires to lib/radar.rb**

Add after the last require_relative:

```ruby
require_relative "radar/formatters/text"
```

Add at the bottom of the file, after the module block:

```ruby
require_relative "radar/cli"
```

- [ ] **Step 6: Add convenience methods to lib/radar.rb**

Add inside the `class << self` block:

```ruby
def flights(lat:, lon:, radius_nm: 50)
  box = Analysis::Proximity.bbox(lat, lon, radius_nm: radius_nm)
  vectors = Sources::Opensky.new.states_bbox(**box)
  Analysis::Proximity.within_radius(vectors, lat: lat, lon: lon, radius_nm: radius_nm)
end

def track(callsign)
  Sources::Opensky.new.states_by_callsign(callsign)
end

def aircraft(icao24)
  Sources::Opensky.new.states_by_icao24(icao24)
end
```

- [ ] **Step 7: Run all tests**

Run: `cd radar && bundle exec rspec`
Expected: all pass

- [ ] **Step 8: Run rubocop**

Run: `cd radar && bundle exec rubocop`
Expected: no offenses

- [ ] **Step 9: Commit**

```bash
git add lib/radar/formatters/text.rb lib/radar/cli.rb \
  spec/formatters/text_spec.rb lib/radar.rb exe/radar
git commit -m "Add text formatter, CLI commands, and convenience API"
```

---

### Task 7: Integration Tests & Full Verification

**Files:**
- Create: `radar/spec/radar_spec.rb`
- Create: `radar/spec/cli_spec.rb`

- [ ] **Step 1: Write integration tests**

Create `radar/spec/radar_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Radar do
  let(:bbox_response) { File.read("spec/fixtures/opensky/states_bbox.json") }

  before do
    described_class.reset!
    stub_request(:get, "https://opensky-network.org/api/states/all")
      .with(query: hash_including({}))
      .to_return(status: 200, body: bbox_response,
                 headers: { "Content-Type" => "application/json" })
  end

  describe ".flights" do
    it "returns StateVector array filtered by radius" do
      flights = described_class.flights(lat: 37.6213, lon: -122.379, radius_nm: 50)
      expect(flights).to all(be_a(Radar::Models::StateVector))
    end
  end

  describe ".track" do
    it "returns matching flights by callsign" do
      flights = described_class.track("UAL1234")
      expect(flights.size).to eq(1)
      expect(flights.first.callsign).to eq("UAL1234")
    end

    it "returns empty array for unknown callsign" do
      flights = described_class.track("NOPE999")
      expect(flights).to eq([])
    end
  end

  describe ".aircraft" do
    it "returns matching flights by icao24" do
      flights = described_class.aircraft("a12345")
      expect(flights.size).to eq(1)
      expect(flights.first.icao24).to eq("a12345")
    end
  end
end
```

- [ ] **Step 2: Write CLI spec**

Create `radar/spec/cli_spec.rb`:

```ruby
# frozen_string_literal: true

require "open3"

RSpec.describe "CLI" do
  let(:bbox_response) { File.read("spec/fixtures/opensky/states_bbox.json") }

  before do
    Radar.reset!
    stub_request(:get, "https://opensky-network.org/api/states/all")
      .with(query: hash_including({}))
      .to_return(status: 200, body: bbox_response,
                 headers: { "Content-Type" => "application/json" })
  end

  describe "version" do
    it "prints version" do
      expect { Radar::CLI.start(["version"]) }.to output(/radar \d+\.\d+\.\d+/).to_stdout
    end
  end

  describe "track" do
    it "outputs track info for known callsign" do
      expect { Radar::CLI.start(["track", "UAL1234"]) }.to output(/UAL1234/).to_stdout
    end
  end
end
```

- [ ] **Step 3: Run the full test suite**

Run: `cd radar && bundle exec rspec`
Expected: all pass

- [ ] **Step 4: Run rubocop**

Run: `cd radar && bundle exec rubocop`
Expected: no offenses

- [ ] **Step 5: Run default rake task**

Run: `cd radar && bundle exec rake`
Expected: all pass

- [ ] **Step 6: Commit**

```bash
git add spec/radar_spec.rb spec/cli_spec.rb
git commit -m "Add integration tests and verify full radar suite"
```
