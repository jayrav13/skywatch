# Phase 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `briefer metar KCDW` works from the CLI and returns structured weather data from the AWC API.

**Architecture:** Single Ruby gem with internal modules. HTTP client fetches pre-decoded JSON from the AWC Data API, maps it to typed model objects, and outputs via CLI (Thor) in text or JSON format. No raw METAR string parsing — AWC does the decoding.

**Tech Stack:** Ruby 3.2+, Thor (CLI), Faraday (HTTP), RSpec + WebMock + VCR (testing), RuboCop + rubocop-rspec (linting), Lefthook (git hooks)

---

### Task 1: Gem Scaffold & Linting Setup

**Files:**
- Create: `Gemfile`
- Create: `briefer.gemspec`
- Create: `Rakefile`
- Create: `lib/briefer.rb`
- Create: `lib/briefer/version.rb`
- Create: `.rubocop.yml`
- Create: `lefthook.yml`
- Create: `.rspec`
- Create: `.ruby-version`
- Create: `.gitignore`
- Create: `spec/spec_helper.rb`
- Create: `LICENSE.txt`

- [ ] **Step 1: Create `.ruby-version`**

```
3.2
```

- [ ] **Step 2: Create `.gitignore`**

```
/.bundle/
/.yardoc
/_yardoc/
/coverage/
/doc/
/pkg/
/spec/reports/
/tmp/
*.gem
Gemfile.lock
.rspec_status
```

- [ ] **Step 3: Create `lib/briefer/version.rb`**

```ruby
# frozen_string_literal: true

module Briefer
  VERSION = "1.0.0"
end
```

- [ ] **Step 4: Create `briefer.gemspec`**

```ruby
# frozen_string_literal: true

require_relative "lib/briefer/version"

Gem::Specification.new do |spec|
  spec.name = "briefer"
  spec.version = Briefer::VERSION
  spec.authors = ["Jay Ravaliya"]
  spec.email = ["jayrav13@gmail.com"]

  spec.summary = "FAA-standard preflight weather briefings for pilots and AI agents"
  spec.description = "Consolidates aviation weather data from free, public FAA/NWS sources " \
                     "into structured preflight briefings. Provides METAR, TAF, NOTAMs, " \
                     "TFRs, and go/no-go decisions via CLI and Ruby API."
  spec.homepage = "https://github.com/jayrav13/briefer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jayrav13/briefer"
  spec.metadata["changelog_uri"] = "https://github.com/jayrav13/briefer/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"
end
```

- [ ] **Step 5: Create `Gemfile`**

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

gem "rubocop", "~> 1.86"
gem "rubocop-rspec", "~> 3.0", require: false

gem "lefthook", "~> 2.1", require: false

gem "vcr", "~> 6.0"
gem "webmock", "~> 3.0"
```

- [ ] **Step 6: Create `Rakefile`**

```ruby
# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]
```

- [ ] **Step 7: Create `lib/briefer.rb`**

```ruby
# frozen_string_literal: true

require_relative "briefer/version"

module Briefer
end
```

- [ ] **Step 8: Create `.rubocop.yml`**

```yaml
plugins:
  - rubocop-rspec

AllCops:
  TargetRubyVersion: 3.2
  NewCops: enable
  SuggestExtensions: false

Style/StringLiterals:
  EnforcedStyle: double_quotes

Style/StringLiteralsInInterpolation:
  EnforcedStyle: double_quotes

Style/Documentation:
  Enabled: false

Style/CommentedKeyword:
  Enabled: false

Layout/LineLength:
  Max: 120

Metrics/BlockLength:
  Exclude:
    - "spec/**/*"
    - "*.gemspec"

RSpec/SpecFilePathFormat:
  Enabled: false

RSpec/MultipleExpectations:
  Max: 4

RSpec/ExampleLength:
  Max: 10

RSpec/MultipleDescribes:
  Enabled: false

RSpec/BeforeAfterAll:
  Enabled: false

RSpec/DescribeClass:
  Enabled: false

RSpec/VerifiedDoubles:
  Enabled: false

RSpec/IdenticalEqualityAssertion:
  Enabled: false

RSpec/ScatteredLet:
  Enabled: false
```

- [ ] **Step 9: Create `.rspec`**

```
--format documentation
--color
--require spec_helper
```

- [ ] **Step 10: Create `spec/spec_helper.rb`**

```ruby
# frozen_string_literal: true

require "briefer"
require "webmock/rspec"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
```

- [ ] **Step 11: Create `lefthook.yml`**

```yaml
pre-commit:
  parallel: true
  commands:
    rubocop:
      glob: "*.rb"
      run: bundle exec rubocop --force-exclusion {staged_files}
      stage_fixed: true

pre-push:
  parallel: true
  commands:
    rspec:
      run: bundle exec rspec
```

- [ ] **Step 12: Create `LICENSE.txt`**

Standard MIT license with `Copyright (c) 2026 Jay Ravaliya`.

- [ ] **Step 13: Run `bundle install`**

Run: `bundle install`
Expected: all gems install successfully, `Gemfile.lock` created.

- [ ] **Step 14: Install lefthook**

Run: `bundle exec lefthook install`
Expected: git hooks installed.

- [ ] **Step 15: Run rubocop to verify config**

Run: `bundle exec rubocop`
Expected: no offenses detected on the scaffold files.

- [ ] **Step 16: Run rspec to verify setup**

Run: `bundle exec rspec`
Expected: 0 examples, 0 failures (no specs yet).

- [ ] **Step 17: Commit**

```bash
git add .ruby-version .gitignore .rubocop.yml .rspec lefthook.yml LICENSE.txt \
  briefer.gemspec Gemfile Gemfile.lock Rakefile \
  lib/briefer.rb lib/briefer/version.rb spec/spec_helper.rb
git commit -m "Scaffold briefer gem with linting, lefthook, and test setup"
```

---

### Task 2: Error Classes

**Files:**
- Create: `lib/briefer/errors.rb`
- Create: `spec/errors_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/errors_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Error do
  it "is a StandardError" do
    expect(described_class.new).to be_a(StandardError)
  end
end

RSpec.describe Briefer::ConnectionError do
  it "is a Briefer::Error" do
    expect(described_class.new).to be_a(Briefer::Error)
  end
end

RSpec.describe Briefer::ApiError do
  it "is a Briefer::Error" do
    expect(described_class.new).to be_a(Briefer::Error)
  end

  it "stores the response" do
    error = described_class.new("bad", response: { status: 500 })
    expect(error.response).to eq({ status: 500 })
  end
end

RSpec.describe Briefer::ParseError do
  it "is a Briefer::Error" do
    expect(described_class.new).to be_a(Briefer::Error)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/errors_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Error`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/errors.rb`:

```ruby
# frozen_string_literal: true

module Briefer
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

- [ ] **Step 4: Require errors in `lib/briefer.rb`**

Update `lib/briefer.rb`:

```ruby
# frozen_string_literal: true

require_relative "briefer/version"
require_relative "briefer/errors"

module Briefer
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/errors_spec.rb`
Expected: 4 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/errors.rb spec/errors_spec.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/errors.rb lib/briefer.rb spec/errors_spec.rb
git commit -m "Add error class hierarchy"
```

---

### Task 3: HTTP Client

**Files:**
- Create: `lib/briefer/client/http.rb`
- Create: `spec/client/http_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/client/http_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Client::Http do
  subject(:client) { described_class.new }

  describe "#connection" do
    it "sets the base URL to aviationweather.gov" do
      expect(client.connection.url_prefix.to_s).to eq("https://aviationweather.gov/")
    end

    it "sets a custom User-Agent header" do
      user_agent = client.connection.headers["User-Agent"]
      expect(user_agent).to match(%r{Briefer/\d+\.\d+\.\d+ \(ruby; github\.com/jay/briefer\)})
    end

    it "configures open timeout" do
      expect(client.connection.options.open_timeout).to eq(10)
    end

    it "configures read timeout" do
      expect(client.connection.options.timeout).to eq(10)
    end
  end

  describe "#get" do
    it "makes a GET request and returns parsed JSON" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json")
        .to_return(status: 200, body: '[{"icaoId":"KCDW"}]', headers: { "Content-Type" => "application/json" })

      response = client.get("/api/data/metar", ids: "KCDW", format: "json")
      expect(response).to eq([{ "icaoId" => "KCDW" }])
    end

    it "raises ConnectionError on network failure" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { client.get("/api/data/metar") }.to raise_error(Briefer::ConnectionError)
    end

    it "raises ApiError on non-200 response" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .to_return(status: 500, body: "Internal Server Error")

      expect { client.get("/api/data/metar") }.to raise_error(Briefer::ApiError)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/client/http_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Client`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/client/http.rb`:

```ruby
# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Briefer
  module Client
    class Http
      BASE_URL = "https://aviationweather.gov"

      attr_reader :connection

      def initialize
        @connection = build_connection
      end

      def get(path, params = {})
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
          f.request :retry, max: 3, interval: 0.5, backoff_factor: 2
          f.headers["User-Agent"] = "Briefer/#{Briefer::VERSION} (ruby; github.com/jay/briefer)"
          f.options.open_timeout = 10
          f.options.timeout = 10
        end
      end
    end
  end
end
```

- [ ] **Step 4: Require client in `lib/briefer.rb` and add `.client` accessor**

Update `lib/briefer.rb`:

```ruby
# frozen_string_literal: true

require_relative "briefer/version"
require_relative "briefer/errors"
require_relative "briefer/client/http"

module Briefer
  class << self
    def client
      @client ||= Client::Http.new
    end

    def reset!
      @client = nil
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/client/http_spec.rb`
Expected: 5 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/client/http.rb spec/client/http_spec.rb lib/briefer.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/client/http.rb lib/briefer.rb spec/client/http_spec.rb
git commit -m "Add HTTP client with retry, timeouts, and error handling"
```

---

### Task 4: Position Model

**Files:**
- Create: `lib/briefer/models/position.rb`
- Create: `spec/models/position_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/models/position_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::Position do
  subject(:position) { described_class.new(lat: 40.8764, lon: -74.2828) }

  it "stores latitude" do
    expect(position.lat).to eq(40.8764)
  end

  it "stores longitude" do
    expect(position.lon).to eq(-74.2828)
  end

  it "is immutable" do
    expect(position).to be_frozen
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/position_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/models/position.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Models
    Position = Data.define(:lat, :lon)
  end
end
```

- [ ] **Step 4: Require in `lib/briefer.rb`**

Add after the errors require:

```ruby
require_relative "briefer/models/position"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/models/position_spec.rb`
Expected: 3 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/position.rb spec/models/position_spec.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/models/position.rb lib/briefer.rb spec/models/position_spec.rb
git commit -m "Add Position data model"
```

---

### Task 5: FlightCategory Analysis

**Files:**
- Create: `lib/briefer/analysis/flight_category.rb`
- Create: `spec/analysis/flight_category_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/analysis/flight_category_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Analysis::FlightCategory do
  describe ".classify" do
    # VFR: ceiling > 3000 AND visibility > 5
    it "returns :vfr for clear skies and good visibility" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 10)).to eq(:vfr)
    end

    it "returns :vfr for nil ceiling (unlimited) and good visibility" do
      expect(described_class.classify(ceiling_ft: nil, visibility_sm: 10)).to eq(:vfr)
    end

    # MVFR: ceiling 1000-3000 OR visibility 3-5
    it "returns :mvfr for ceiling at exactly 3000" do
      expect(described_class.classify(ceiling_ft: 3000, visibility_sm: 10)).to eq(:mvfr)
    end

    it "returns :mvfr for visibility at exactly 5" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 5)).to eq(:mvfr)
    end

    it "returns :mvfr for ceiling 1000 and good visibility" do
      expect(described_class.classify(ceiling_ft: 1000, visibility_sm: 10)).to eq(:mvfr)
    end

    it "returns :mvfr for visibility 3 and high ceiling" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 3)).to eq(:mvfr)
    end

    # IFR: ceiling 500-999 OR visibility 1-<3
    it "returns :ifr for ceiling at exactly 999" do
      expect(described_class.classify(ceiling_ft: 999, visibility_sm: 10)).to eq(:ifr)
    end

    it "returns :ifr for ceiling at exactly 500" do
      expect(described_class.classify(ceiling_ft: 500, visibility_sm: 10)).to eq(:ifr)
    end

    it "returns :ifr for visibility at 2" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 2)).to eq(:ifr)
    end

    it "returns :ifr for visibility at 1" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 1)).to eq(:ifr)
    end

    # LIFR: ceiling < 500 OR visibility < 1
    it "returns :lifr for ceiling at 499" do
      expect(described_class.classify(ceiling_ft: 499, visibility_sm: 10)).to eq(:lifr)
    end

    it "returns :lifr for ceiling at 0" do
      expect(described_class.classify(ceiling_ft: 0, visibility_sm: 10)).to eq(:lifr)
    end

    it "returns :lifr for visibility at 0.5" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 0.5)).to eq(:lifr)
    end

    it "returns :lifr for visibility at 0" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 0)).to eq(:lifr)
    end

    # Lowest condition wins
    it "uses the lower category when ceiling and visibility differ" do
      # VFR ceiling but IFR visibility
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 2)).to eq(:ifr)
    end

    it "uses the lower category when visibility is worse" do
      # MVFR ceiling but LIFR visibility
      expect(described_class.classify(ceiling_ft: 2000, visibility_sm: 0.5)).to eq(:lifr)
    end

    # Nil ceiling + low vis
    it "returns :lifr for nil ceiling and very low visibility" do
      expect(described_class.classify(ceiling_ft: nil, visibility_sm: 0.25)).to eq(:lifr)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/analysis/flight_category_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Analysis`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/analysis/flight_category.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Analysis
    module FlightCategory
      CATEGORIES = %i[lifr ifr mvfr vfr].freeze

      def self.classify(ceiling_ft:, visibility_sm:)
        ceiling_cat = classify_ceiling(ceiling_ft)
        visibility_cat = classify_visibility(visibility_sm)

        # Return the worse (lower index) category
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
```

- [ ] **Step 4: Require in `lib/briefer.rb`**

Add after models require:

```ruby
require_relative "briefer/analysis/flight_category"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/analysis/flight_category_spec.rb`
Expected: 17 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/analysis/flight_category.rb spec/analysis/flight_category_spec.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/analysis/flight_category.rb lib/briefer.rb spec/analysis/flight_category_spec.rb
git commit -m "Add flight category classification (VFR/MVFR/IFR/LIFR)"
```

---

### Task 6: Metar Model

**Files:**
- Create: `lib/briefer/models/metar.rb`
- Create: `spec/models/metar_spec.rb`
- Create: `spec/fixtures/metars/kcdw.json`
- Create: `spec/fixtures/metars/kewr_gusty.json`
- Create: `spec/fixtures/metars/calm_winds.json`
- Create: `spec/fixtures/metars/clear_sky.json`
- Modify: `lib/briefer.rb`

The AWC API returns JSON with these fields:
- `icaoId`, `rawOb`, `temp`, `dewp`, `wdir`, `wspd`, `wgst` (optional)
- `visib` (string: "10+", "6", "1/2"), `altim` (hPa), `slp`
- `clouds` (array: `[{cover: "BKN", base: 7000}]`), `fltCat`
- `lat`, `lon`, `elev` (meters), `name`, `metarType`
- `obsTime` (unix epoch), `wxString` (optional, e.g. "+RA BR")

- [ ] **Step 1: Create test fixtures**

Create `spec/fixtures/metars/kcdw.json`:

```json
{
  "icaoId": "KCDW",
  "receiptTime": "2026-03-28T04:55:55.357Z",
  "obsTime": 1774673580,
  "reportTime": "2026-03-28T05:00:00.000Z",
  "temp": 3.9,
  "dewp": -8.9,
  "wdir": 330,
  "wspd": 3,
  "visib": "10+",
  "altim": 1023.5,
  "slp": 1023.9,
  "qcField": 4,
  "metarType": "METAR",
  "rawOb": "METAR KCDW 280453Z 33003KT 10SM BKN070 04/M09 A3022 RMK AO2 SLP239 T00391089 401670039",
  "lat": 40.8764,
  "lon": -74.2828,
  "elev": 52,
  "name": "Caldwell/Essex Cnty, NJ, US",
  "cover": "BKN",
  "clouds": [
    { "cover": "BKN", "base": 7000 }
  ],
  "fltCat": "VFR"
}
```

Create `spec/fixtures/metars/kewr_gusty.json`:

```json
{
  "icaoId": "KEWR",
  "receiptTime": "2026-03-28T04:54:08.727Z",
  "obsTime": 1774673460,
  "reportTime": "2026-03-28T05:00:00.000Z",
  "temp": 5.0,
  "dewp": -10.0,
  "wdir": 340,
  "wspd": 13,
  "wgst": 21,
  "visib": "10+",
  "altim": 1023.1,
  "slp": 1022.8,
  "qcField": 4,
  "metarType": "METAR",
  "rawOb": "METAR KEWR 280451Z 34013G21KT 10SM FEW050 BKN065 BKN130 05/M10 A3021 RMK AO2 SLP228 T00501100 401830050",
  "lat": 40.6828,
  "lon": -74.1692,
  "elev": 2,
  "name": "Newark Intl, NJ, US",
  "cover": "BKN",
  "clouds": [
    { "cover": "FEW", "base": 5000 },
    { "cover": "BKN", "base": 6500 },
    { "cover": "BKN", "base": 13000 }
  ],
  "fltCat": "VFR"
}
```

Create `spec/fixtures/metars/calm_winds.json`:

```json
{
  "icaoId": "KACK",
  "receiptTime": "2026-03-28T04:56:18.002Z",
  "obsTime": 1774673580,
  "reportTime": "2026-03-28T05:00:00.000Z",
  "temp": -1.1,
  "dewp": -6.7,
  "wdir": 0,
  "wspd": 0,
  "visib": "10+",
  "altim": 1021.1,
  "slp": 1021.1,
  "qcField": 198,
  "metarType": "METAR",
  "rawOb": "METAR KACK 280453Z AUTO 00000KT 10SM CLR M01/M07 A3015 RMK AO2 SLP211",
  "lat": 41.2541,
  "lon": -70.0589,
  "elev": 12,
  "name": "Nantucket Mem Arpt, MA, US",
  "cover": "CLR",
  "clouds": [],
  "fltCat": "VFR"
}
```

Create `spec/fixtures/metars/clear_sky.json`:

```json
{
  "icaoId": "KACK",
  "receiptTime": "2026-03-28T04:56:18.002Z",
  "obsTime": 1774673580,
  "reportTime": "2026-03-28T05:00:00.000Z",
  "temp": 15.0,
  "dewp": 5.0,
  "wdir": 180,
  "wspd": 8,
  "visib": "10+",
  "altim": 1015.0,
  "slp": 1015.0,
  "qcField": 4,
  "metarType": "METAR",
  "rawOb": "METAR KACK 280453Z 18008KT 10SM CLR 15/05 A2997 RMK AO2",
  "lat": 41.2541,
  "lon": -70.0589,
  "elev": 12,
  "name": "Nantucket Mem Arpt, MA, US",
  "cover": "CLR",
  "clouds": [],
  "fltCat": "VFR"
}
```

- [ ] **Step 2: Write the failing test**

Create `spec/models/metar_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::Metar do
  def load_fixture(name)
    JSON.parse(File.read("spec/fixtures/metars/#{name}.json"))
  end

  describe ".from_awc" do
    context "with a standard METAR (KCDW)" do
      subject(:metar) { described_class.from_awc(load_fixture("kcdw")) }

      it "parses station_id" do
        expect(metar.station_id).to eq("KCDW")
      end

      it "parses the raw observation" do
        expect(metar.raw).to start_with("METAR KCDW")
      end

      it "parses observed_at as UTC Time" do
        expect(metar.observed_at).to be_a(Time)
        expect(metar.observed_at.utc?).to be(true)
      end

      it "parses temperature" do
        expect(metar.temperature_c).to eq(3.9)
      end

      it "parses dewpoint" do
        expect(metar.dewpoint_c).to eq(-8.9)
      end

      it "parses wind" do
        expect(metar.wind_direction_deg).to eq(330)
        expect(metar.wind_speed_kt).to eq(3)
        expect(metar.wind_gust_kt).to be_nil
      end

      it "parses visibility as float" do
        expect(metar.visibility_sm).to eq(10.0)
      end

      it "parses altimeter from hPa to inHg" do
        expect(metar.altimeter_inhg).to be_within(0.01).of(30.22)
      end

      it "parses sky condition" do
        expect(metar.sky_condition).to eq([{ cover: :bkn, base_ft: 7000 }])
      end

      it "computes ceiling from BKN layer" do
        expect(metar.ceiling_ft).to eq(7000)
      end

      it "parses station info" do
        expect(metar.station_name).to eq("Caldwell/Essex Cnty, NJ, US")
        expect(metar.elevation_ft).to be_within(1).of(170)
      end

      it "builds a position" do
        expect(metar.position).to eq(Briefer::Models::Position.new(lat: 40.8764, lon: -74.2828))
      end

      it "classifies as VFR" do
        expect(metar.flight_category).to eq(:vfr)
        expect(metar).to be_vfr
      end

      it "computes spread" do
        expect(metar.spread_c).to be_within(0.1).of(12.8)
      end
    end

    context "with gusty winds (KEWR)" do
      subject(:metar) { described_class.from_awc(load_fixture("kewr_gusty")) }

      it "parses gust speed" do
        expect(metar.wind_gust_kt).to eq(21)
      end

      it "finds ceiling from first BKN/OVC layer" do
        expect(metar.ceiling_ft).to eq(6500)
      end
    end

    context "with calm winds" do
      subject(:metar) { described_class.from_awc(load_fixture("calm_winds")) }

      it "parses calm winds as zero" do
        expect(metar.wind_direction_deg).to eq(0)
        expect(metar.wind_speed_kt).to eq(0)
      end
    end

    context "with clear sky" do
      subject(:metar) { described_class.from_awc(load_fixture("clear_sky")) }

      it "returns nil ceiling" do
        expect(metar.ceiling_ft).to be_nil
      end

      it "classifies as VFR" do
        expect(metar.flight_category).to eq(:vfr)
      end
    end
  end

  describe "#to_h" do
    subject(:metar) { described_class.from_awc(load_fixture("kcdw")) }

    it "returns a hash with all fields" do
      hash = metar.to_h
      expect(hash[:station_id]).to eq("KCDW")
      expect(hash[:flight_category]).to eq(:vfr)
      expect(hash[:temperature_c]).to eq(3.9)
    end
  end

  describe "#to_json" do
    subject(:metar) { described_class.from_awc(load_fixture("kcdw")) }

    it "returns valid JSON" do
      parsed = JSON.parse(metar.to_json)
      expect(parsed["station_id"]).to eq("KCDW")
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/models/metar_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models::Metar`

- [ ] **Step 4: Write the implementation**

Create `lib/briefer/models/metar.rb`:

```ruby
# frozen_string_literal: true

require "json"
require "time"

module Briefer
  module Models
    class Metar
      CEILING_COVERS = %i[bkn ovc].freeze
      HPA_TO_INHG = 0.02953

      attr_reader :raw, :station_id, :observed_at, :metar_type,
                  :wind_direction_deg, :wind_speed_kt, :wind_gust_kt,
                  :visibility_sm, :weather, :sky_condition,
                  :temperature_c, :dewpoint_c, :altimeter_inhg,
                  :station_name, :latitude, :longitude, :elevation_ft,
                  :sea_level_pressure_mb

      def self.from_awc(data)
        new(
          raw: data["rawOb"],
          station_id: data["icaoId"],
          observed_at: Time.at(data["obsTime"]).utc,
          metar_type: data["metarType"],
          wind_direction_deg: data["wdir"],
          wind_speed_kt: data["wspd"],
          wind_gust_kt: data["wgst"],
          visibility_sm: parse_visibility(data["visib"]),
          weather: parse_weather(data["wxString"]),
          sky_condition: parse_clouds(data["clouds"]),
          temperature_c: data["temp"]&.to_f,
          dewpoint_c: data["dewp"]&.to_f,
          altimeter_inhg: data["altim"] ? (data["altim"] * HPA_TO_INHG).round(2) : nil,
          station_name: data["name"],
          latitude: data["lat"],
          longitude: data["lon"],
          elevation_ft: data["elev"] ? (data["elev"] * 3.28084).round : nil,
          sea_level_pressure_mb: data["slp"]
        )
      end

      def initialize(**attrs) # rubocop:disable Metrics/MethodLength
        @raw = attrs[:raw]
        @station_id = attrs[:station_id]
        @observed_at = attrs[:observed_at]
        @metar_type = attrs[:metar_type]
        @wind_direction_deg = attrs[:wind_direction_deg]
        @wind_speed_kt = attrs[:wind_speed_kt]
        @wind_gust_kt = attrs[:wind_gust_kt]
        @visibility_sm = attrs[:visibility_sm]
        @weather = attrs[:weather]
        @sky_condition = attrs[:sky_condition]
        @temperature_c = attrs[:temperature_c]
        @dewpoint_c = attrs[:dewpoint_c]
        @altimeter_inhg = attrs[:altimeter_inhg]
        @station_name = attrs[:station_name]
        @latitude = attrs[:latitude]
        @longitude = attrs[:longitude]
        @elevation_ft = attrs[:elevation_ft]
        @sea_level_pressure_mb = attrs[:sea_level_pressure_mb]
      end

      def position
        Position.new(lat: latitude, lon: longitude)
      end

      def ceiling_ft
        ceiling_layer = sky_condition&.find { |layer| CEILING_COVERS.include?(layer[:cover]) }
        ceiling_layer&.dig(:base_ft)
      end

      def flight_category
        Analysis::FlightCategory.classify(ceiling_ft: ceiling_ft, visibility_sm: visibility_sm)
      end

      def spread_c
        return nil unless temperature_c && dewpoint_c

        (temperature_c - dewpoint_c).round(1)
      end

      def density_altitude_ft
        return nil unless temperature_c && altimeter_inhg && elevation_ft

        pressure_alt = elevation_ft + ((29.92 - altimeter_inhg) * 1000)
        isa_temp = 15.0 - (elevation_ft * 0.002)
        (pressure_alt + (120 * (temperature_c - isa_temp))).round
      end

      def vfr? = flight_category == :vfr
      def mvfr? = flight_category == :mvfr
      def ifr? = flight_category == :ifr
      def lifr? = flight_category == :lifr

      def to_h # rubocop:disable Metrics/MethodLength
        {
          station_id: station_id, raw: raw, observed_at: observed_at&.iso8601, metar_type: metar_type,
          wind_direction_deg: wind_direction_deg, wind_speed_kt: wind_speed_kt, wind_gust_kt: wind_gust_kt,
          visibility_sm: visibility_sm, weather: weather, sky_condition: sky_condition,
          temperature_c: temperature_c, dewpoint_c: dewpoint_c, altimeter_inhg: altimeter_inhg,
          station_name: station_name, latitude: latitude, longitude: longitude, elevation_ft: elevation_ft,
          ceiling_ft: ceiling_ft, flight_category: flight_category, spread_c: spread_c,
          density_altitude_ft: density_altitude_ft
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def self.parse_visibility(visib)
        return nil if visib.nil?

        visib = visib.to_s.gsub("+", "")
        if visib.include?("/")
          parts = visib.split("/")
          parts[0].to_f / parts[1].to_f
        else
          visib.to_f
        end
      end

      def self.parse_weather(wx_string)
        return [] if wx_string.nil? || wx_string.strip.empty?

        wx_string.strip.split
      end

      def self.parse_clouds(clouds)
        return [] if clouds.nil?

        clouds.map do |cloud|
          { cover: cloud["cover"]&.downcase&.to_sym, base_ft: cloud["base"] }
        end
      end

      private_class_method :parse_visibility, :parse_weather, :parse_clouds
    end
  end
end
```

- [ ] **Step 5: Require in `lib/briefer.rb`**

Add after position require:

```ruby
require_relative "briefer/models/metar"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/metar_spec.rb`
Expected: 18 examples, 0 failures

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/metar.rb spec/models/metar_spec.rb`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/models/metar.rb lib/briefer.rb \
  spec/models/metar_spec.rb spec/fixtures/metars/
git commit -m "Add Metar model with AWC JSON parsing and computed fields"
```

---

### Task 7: Metar Source

**Files:**
- Create: `lib/briefer/sources/metar.rb`
- Create: `spec/sources/metar_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/sources/metar_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Sources::Metar do
  subject(:source) { described_class.new(client: Briefer.client) }

  let(:kcdw_response) { [JSON.parse(File.read("spec/fixtures/metars/kcdw.json"))] }
  let(:multi_response) do
    [
      JSON.parse(File.read("spec/fixtures/metars/kcdw.json")),
      JSON.parse(File.read("spec/fixtures/metars/kewr_gusty.json"))
    ]
  end

  describe "#fetch" do
    it "fetches a single station METAR" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW", format: "json" })
        .to_return(status: 200, body: kcdw_response.to_json, headers: { "Content-Type" => "application/json" })

      metars = source.fetch("KCDW")
      expect(metars.size).to eq(1)
      expect(metars.first).to be_a(Briefer::Models::Metar)
      expect(metars.first.station_id).to eq("KCDW")
    end

    it "fetches multiple stations in a single request" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW,KEWR", format: "json" })
        .to_return(status: 200, body: multi_response.to_json, headers: { "Content-Type" => "application/json" })

      metars = source.fetch("KCDW", "KEWR")
      expect(metars.size).to eq(2)
      expect(metars.map(&:station_id)).to contain_exactly("KCDW", "KEWR")
    end

    it "returns empty array when API returns empty array" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KXYZ", format: "json" })
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      metars = source.fetch("KXYZ")
      expect(metars).to eq([])
    end

    it "raises ApiError on HTTP failure" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW", format: "json" })
        .to_return(status: 500, body: "Server Error")

      expect { source.fetch("KCDW") }.to raise_error(Briefer::ApiError)
    end

    it "upcases station IDs" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW", format: "json" })
        .to_return(status: 200, body: kcdw_response.to_json, headers: { "Content-Type" => "application/json" })

      metars = source.fetch("kcdw")
      expect(metars.first.station_id).to eq("KCDW")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/sources/metar_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Sources`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/sources/metar.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Sources
    class Metar
      ENDPOINT = "/api/data/metar"

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(*station_ids)
        ids = station_ids.map(&:upcase).join(",")
        data = @client.get(ENDPOINT, ids: ids, format: "json")
        data.map { |entry| Models::Metar.from_awc(entry) }
      end
    end
  end
end
```

- [ ] **Step 4: Require in `lib/briefer.rb` and add convenience method**

Add the require:

```ruby
require_relative "briefer/sources/metar"
```

Add to the `class << self` block:

```ruby
def metar(*station_ids)
  Sources::Metar.new.fetch(*station_ids)
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/sources/metar_spec.rb`
Expected: 5 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/sources/metar.rb spec/sources/metar_spec.rb lib/briefer.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/sources/metar.rb lib/briefer.rb spec/sources/metar_spec.rb
git commit -m "Add METAR source for AWC API fetching"
```

---

### Task 8: Text Formatter

**Files:**
- Create: `lib/briefer/formatters/text.rb`
- Create: `spec/formatters/text_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/formatters/text_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Formatters::Text do
  def metar_from_fixture(name)
    data = JSON.parse(File.read("spec/fixtures/metars/#{name}.json"))
    Briefer::Models::Metar.from_awc(data)
  end

  describe ".format_metar" do
    it "formats a standard METAR with station name and category" do
      metar = metar_from_fixture("kcdw")
      output = described_class.format_metar(metar)

      expect(output).to include("KCDW")
      expect(output).to include("Caldwell/Essex Cnty")
      expect(output).to include("VFR")
      expect(output).to include("METAR KCDW")
      expect(output).to include("Ceiling: 7,000'")
      expect(output).to include("Wind: 330")
    end

    it "formats gusty winds" do
      metar = metar_from_fixture("kewr_gusty")
      output = described_class.format_metar(metar)

      expect(output).to include("G21")
    end

    it "shows no ceiling for clear skies" do
      metar = metar_from_fixture("clear_sky")
      output = described_class.format_metar(metar)

      expect(output).to include("Ceiling: -")
    end
  end

  describe ".format_category" do
    it "formats station with its flight category" do
      metar = metar_from_fixture("kcdw")
      output = described_class.format_category(metar)

      expect(output).to include("KCDW")
      expect(output).to include("VFR")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/formatters/text_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Formatters`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/formatters/text.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Formatters
    module Text
      def self.format_metar(metar)
        wind = format_wind(metar)
        ceiling = metar.ceiling_ft ? "#{number_with_commas(metar.ceiling_ft)}'" : "-"
        ceiling_cover = metar.sky_condition&.find { |l| %i[bkn ovc].include?(l[:cover]) }
        ceiling_label = ceiling_cover ? " (#{ceiling_cover[:cover].upcase})" : ""

        <<~TEXT
          #{metar.station_id} (#{metar.station_name}) — #{metar.flight_category.upcase}
            #{metar.raw}
            Ceiling: #{ceiling}#{ceiling_label}  Vis: #{format_visibility(metar.visibility_sm)}  Wind: #{wind}
            Temp: #{metar.temperature_c}°C  Dew: #{metar.dewpoint_c}°C  Spread: #{metar.spread_c}°C  Altimeter: #{metar.altimeter_inhg}
        TEXT
      end

      def self.format_category(metar)
        "#{metar.station_id} — #{metar.flight_category.upcase}\n"
      end

      def self.format_wind(metar)
        wind = "#{metar.wind_direction_deg}° @ #{metar.wind_speed_kt}kt"
        wind += "G#{metar.wind_gust_kt}kt" if metar.wind_gust_kt
        wind
      end

      def self.format_visibility(vis)
        return "-" if vis.nil?

        vis >= 10 ? "10+SM" : "#{vis}SM"
      end

      def self.number_with_commas(number)
        number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      end

      private_class_method :format_wind, :format_visibility, :number_with_commas
    end
  end
end
```

- [ ] **Step 4: Require in `lib/briefer.rb`**

Add:

```ruby
require_relative "briefer/formatters/text"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/formatters/text_spec.rb`
Expected: 4 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/formatters/text.rb spec/formatters/text_spec.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/formatters/text.rb lib/briefer.rb spec/formatters/text_spec.rb
git commit -m "Add text formatter for METAR display"
```

---

### Task 9: CLI

**Files:**
- Create: `lib/briefer/cli.rb`
- Create: `exe/briefer`
- Create: `spec/cli_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/cli_spec.rb`:

```ruby
# frozen_string_literal: true

require "open3"

RSpec.describe Briefer::CLI do
  let(:kcdw_response) { [JSON.parse(File.read("spec/fixtures/metars/kcdw.json"))] }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/metar")
      .with(query: { ids: "KCDW", format: "json" })
      .to_return(status: 200, body: kcdw_response.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe "metar command" do
    it "outputs text format by default" do
      output = capture_stdout { described_class.start(["metar", "KCDW", "--format", "text"]) }
      expect(output).to include("KCDW")
      expect(output).to include("VFR")
      expect(output).to include("METAR KCDW")
    end

    it "outputs JSON format" do
      output = capture_stdout { described_class.start(["metar", "KCDW", "--format", "json"]) }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.first["station_id"]).to eq("KCDW")
    end

    it "outputs raw METAR only with --raw" do
      output = capture_stdout { described_class.start(["metar", "KCDW", "--raw"]) }
      expect(output.strip).to eq("METAR KCDW 280453Z 33003KT 10SM BKN070 04/M09 A3022 RMK AO2 SLP239 T00391089 401670039")
    end
  end

  describe "categories command" do
    it "outputs flight categories in text format" do
      output = capture_stdout { described_class.start(["categories", "KCDW", "--format", "text"]) }
      expect(output).to include("KCDW")
      expect(output).to include("VFR")
    end

    it "outputs flight categories in JSON format" do
      output = capture_stdout { described_class.start(["categories", "KCDW", "--format", "json"]) }
      parsed = JSON.parse(output)
      expect(parsed).to eq({ "KCDW" => "vfr" })
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/cli_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::CLI`

- [ ] **Step 3: Write the CLI implementation**

Create `lib/briefer/cli.rb`:

```ruby
# frozen_string_literal: true

require "thor"
require "json"

module Briefer
  class CLI < Thor
    class_option :format, type: :string, enum: %w[text json], desc: "Output format (default: text on TTY, json when piped)"

    desc "metar STATION [STATION...]", "Fetch current METAR(s)"
    option :raw, type: :boolean, desc: "Show raw METAR string only"
    def metar(*stations)
      metars = Briefer.metar(*stations)

      if options[:raw]
        metars.each { |m| puts m.raw }
      elsif output_format == "json"
        puts JSON.pretty_generate(metars.map(&:to_h))
      else
        metars.each { |m| print Formatters::Text.format_metar(m) }
      end
    rescue Briefer::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "categories STATION [STATION...]", "Check flight categories"
    def categories(*stations)
      metars = Briefer.metar(*stations)

      if output_format == "json"
        result = metars.to_h { |m| [m.station_id, m.flight_category.to_s] }
        puts JSON.pretty_generate(result)
      else
        metars.each { |m| print Formatters::Text.format_category(m) }
      end
    rescue Briefer::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    private

    def output_format
      options[:format] || ($stdout.tty? ? "text" : "json")
    end
  end
end
```

- [ ] **Step 4: Create the executable**

Create `exe/briefer`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "briefer"
require "briefer/cli"

Briefer::CLI.start(ARGV)
```

- [ ] **Step 5: Make executable**

Run: `chmod +x exe/briefer`

- [ ] **Step 6: Require CLI in `lib/briefer.rb`**

Add at the end of `lib/briefer.rb`:

```ruby
require_relative "briefer/cli"
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bundle exec rspec spec/cli_spec.rb`
Expected: 5 examples, 0 failures

- [ ] **Step 8: Run rubocop**

Run: `bundle exec rubocop lib/briefer/cli.rb exe/briefer spec/cli_spec.rb`
Expected: no offenses

- [ ] **Step 9: Commit**

```bash
git add lib/briefer/cli.rb exe/briefer lib/briefer.rb spec/cli_spec.rb
git commit -m "Add CLI with metar and categories commands"
```

---

### Task 10: Integration Test & Full Suite Verification

**Files:**
- Create: `spec/briefer_spec.rb`

- [ ] **Step 1: Write integration spec**

Create `spec/briefer_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer do
  it "has a version number" do
    expect(Briefer::VERSION).not_to be_nil
  end

  describe ".metar" do
    let(:kcdw_data) { [JSON.parse(File.read("spec/fixtures/metars/kcdw.json"))] }

    before do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW", format: "json" })
        .to_return(status: 200, body: kcdw_data.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns an array of Metar models" do
      metars = described_class.metar("KCDW")
      expect(metars).to be_an(Array)
      expect(metars.first).to be_a(Briefer::Models::Metar)
      expect(metars.first.station_id).to eq("KCDW")
      expect(metars.first.flight_category).to eq(:vfr)
    end
  end

  describe ".client" do
    it "returns a lazy-initialized HTTP client" do
      expect(described_class.client).to be_a(Briefer::Client::Http)
    end

    it "returns the same instance on repeated calls" do
      expect(described_class.client).to be(described_class.client)
    end
  end

  describe ".reset!" do
    it "clears the cached client" do
      first_client = described_class.client
      described_class.reset!
      expect(described_class.client).not_to be(first_client)
    end
  end
end
```

- [ ] **Step 2: Run the full test suite**

Run: `bundle exec rspec`
Expected: all examples pass (roughly 35-40 examples, 0 failures)

- [ ] **Step 3: Run the full lint check**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 4: Run the default rake task**

Run: `bundle exec rake`
Expected: all tests pass and rubocop reports no offenses

- [ ] **Step 5: Smoke test the CLI**

Run: `bundle exec exe/briefer metar KCDW`
Expected: live METAR output for Caldwell showing station name, raw METAR, weather data, and flight category

Run: `bundle exec exe/briefer categories KCDW KTEB KEWR`
Expected: flight category for each station

Run: `bundle exec exe/briefer metar KCDW --format json`
Expected: JSON array with METAR data

Run: `bundle exec exe/briefer metar KCDW --raw`
Expected: raw METAR string only

- [ ] **Step 6: Commit**

```bash
git add spec/briefer_spec.rb
git commit -m "Add integration tests and verify full suite"
```

- [ ] **Step 7: Push**

```bash
git push
```
