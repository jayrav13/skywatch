# Phase 2: Core Weather Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `briefer taf KACK`, `briefer pireps KCDW`, `briefer winds KCDW --altitude 6000`, and `briefer crosswind KCDW --runway 280` work from the CLI with a memory cache.

**Architecture:** Extends Phase 1 patterns — new Source/Model pairs for TAF, PIREP, and Winds Aloft. Memory cache wraps the HTTP client. CrosswindCalculator is a pure analysis module. All new CLI commands follow the existing Thor pattern.

**Tech Stack:** Ruby 3.2+, Thor, Faraday, RSpec + WebMock

---

### Task 1: Memory Cache

**Files:**
- Create: `lib/briefer/client/cache.rb`
- Create: `spec/client/cache_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/client/cache_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Client::Cache do
  let(:http_client) { Briefer::Client::Http.new }
  subject(:cache) { described_class.new(client: http_client) }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json")
      .to_return(status: 200, body: '[{"icaoId":"KCDW"}]', headers: { "Content-Type" => "application/json" })
  end

  describe "#get" do
    it "delegates to the underlying client" do
      result = cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      expect(result).to eq([{ "icaoId" => "KCDW" }])
    end

    it "returns cached response on second call" do
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)

      expect(WebMock).to have_requested(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json").once
    end

    it "fetches again after TTL expires" do
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 0)
      sleep 0.01
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 0)

      expect(WebMock).to have_requested(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json").twice
    end

    it "uses different cache keys for different params" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar?ids=KTEB&format=json")
        .to_return(status: 200, body: '[{"icaoId":"KTEB"}]', headers: { "Content-Type" => "application/json" })

      result1 = cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      result2 = cache.get("/api/data/metar", { ids: "KTEB", format: "json" }, ttl: 300)

      expect(result1.first["icaoId"]).to eq("KCDW")
      expect(result2.first["icaoId"]).to eq("KTEB")
    end
  end

  describe "#clear" do
    it "empties the cache" do
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      cache.clear
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)

      expect(WebMock).to have_requested(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json").twice
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

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/client/cache_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Client::Cache`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/client/cache.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Client
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

- [ ] **Step 4: Wire cache into `lib/briefer.rb`**

Replace the `client` method and add a require. The full `lib/briefer.rb`:

```ruby
# frozen_string_literal: true

require_relative "briefer/version"
require_relative "briefer/errors"
require_relative "briefer/client/http"
require_relative "briefer/client/cache"
require_relative "briefer/models/position"
require_relative "briefer/models/metar"
require_relative "briefer/analysis/flight_category"
require_relative "briefer/sources/metar"
require_relative "briefer/formatters/text"

module Briefer
  class << self
    def client
      @client ||= Client::Cache.new(client: Client::Http.new)
    end

    def reset!
      @client = nil
    end

    def metar(*station_ids)
      Sources::Metar.new.fetch(*station_ids)
    end
  end
end

require_relative "briefer/cli"
```

- [ ] **Step 5: Update `Sources::Metar` to pass TTL**

Modify `lib/briefer/sources/metar.rb` — change the `fetch` method to pass `ttl: 300`:

```ruby
# frozen_string_literal: true

module Briefer
  module Sources
    class Metar
      ENDPOINT = "/api/data/metar"
      TTL = 300

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(*station_ids)
        ids = station_ids.map(&:upcase).join(",")
        data = @client.get(ENDPOINT, { ids: ids, format: "json" }, ttl: TTL)
        data.map { |entry| Models::Metar.from_awc(entry) }
      end
    end
  end
end
```

Note: The cache's `get` method accepts `ttl:` as a keyword arg. The existing `Client::Http#get` only takes `(path, params)`. Since sources now go through the cache, this works. But if a source is given a raw `Http` client (e.g. in tests), we need the `Http#get` to also accept and ignore the `ttl:` keyword. Update `lib/briefer/client/http.rb` — change the `get` signature:

```ruby
def get(path, params = {}, ttl: nil) # rubocop:disable Lint/UnusedMethodArgument
  response = connection.get(path, params)
  raise ApiError.new("HTTP #{response.status}", response: response) unless response.success?

  JSON.parse(response.body)
rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
  raise ConnectionError, e.message
rescue JSON::ParserError => e
  raise ParseError, e.message
end
```

- [ ] **Step 6: Run tests to verify everything passes**

Run: `bundle exec rspec`
Expected: all examples pass (73 existing + 6 new cache = ~79)

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/client/cache.rb lib/briefer/client/http.rb lib/briefer.rb \
  lib/briefer/sources/metar.rb spec/client/cache_spec.rb
git commit -m "Add memory cache with per-request TTL"
```

---

### Task 2: TafGroup Model

**Files:**
- Create: `lib/briefer/models/taf_group.rb`
- Create: `spec/models/taf_group_spec.rb`
- Create: `spec/fixtures/tafs/kack.json`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Create TAF fixture**

Create `spec/fixtures/tafs/kack.json`:

```json
{
  "icaoId": "KACK",
  "dbPopTime": "2026-03-28T05:20:19.463Z",
  "bulletinTime": "2026-03-28T05:20:00.000Z",
  "issueTime": "2026-03-28T05:20:00.000Z",
  "validTimeFrom": 1774677600,
  "validTimeTo": 1774764000,
  "rawTAF": "TAF KACK 280520Z 2806/2906 02014KT P6SM BKN070 FM281600 36014G23KT P6SM OVC050 FM290100 25005KT P6SM FEW140",
  "mostRecent": 1,
  "remarks": "",
  "lat": 41.25407,
  "lon": -70.05892,
  "elev": 12,
  "prior": 3,
  "name": "Nantucket Mem Arpt",
  "fcsts": [
    {
      "timeFrom": 1774677600,
      "timeTo": 1774713600,
      "timeBec": null,
      "fcstChange": null,
      "probability": null,
      "wdir": 20,
      "wspd": 14,
      "wgst": null,
      "wshearHgt": null,
      "wshearDir": null,
      "wshearSpd": null,
      "visib": "6+",
      "altim": null,
      "vertVis": null,
      "wxString": null,
      "notDecoded": null,
      "clouds": [{"cover": "BKN", "base": 7000, "type": null}],
      "icgTurb": [],
      "temp": []
    },
    {
      "timeFrom": 1774713600,
      "timeTo": 1774746000,
      "timeBec": null,
      "fcstChange": "FM",
      "probability": null,
      "wdir": 360,
      "wspd": 14,
      "wgst": 23,
      "wshearHgt": null,
      "wshearDir": null,
      "wshearSpd": null,
      "visib": "6+",
      "altim": null,
      "vertVis": null,
      "wxString": null,
      "notDecoded": null,
      "clouds": [{"cover": "OVC", "base": 5000, "type": null}],
      "icgTurb": [],
      "temp": []
    },
    {
      "timeFrom": 1774746000,
      "timeTo": 1774764000,
      "timeBec": null,
      "fcstChange": "FM",
      "probability": null,
      "wdir": 250,
      "wspd": 5,
      "wgst": null,
      "wshearHgt": null,
      "wshearDir": null,
      "wshearSpd": null,
      "visib": "6+",
      "altim": null,
      "vertVis": null,
      "wxString": null,
      "notDecoded": null,
      "clouds": [{"cover": "FEW", "base": 14000, "type": null}],
      "icgTurb": [],
      "temp": []
    }
  ]
}
```

- [ ] **Step 2: Write the failing test**

Create `spec/models/taf_group_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::TafGroup do
  let(:taf_data) { JSON.parse(File.read("spec/fixtures/tafs/kack.json")) }

  describe ".from_awc" do
    context "with initial forecast group" do
      subject(:group) { described_class.from_awc(taf_data["fcsts"][0]) }

      it "parses time_from as UTC" do
        expect(group.time_from).to be_a(Time)
        expect(group.time_from.utc?).to be(true)
      end

      it "parses time_to" do
        expect(group.time_to).to be_a(Time)
      end

      it "sets change_type to :initial for nil fcstChange" do
        expect(group.change_type).to eq(:initial)
      end

      it "parses wind" do
        expect(group.wind_direction_deg).to eq(20)
        expect(group.wind_speed_kt).to eq(14)
        expect(group.wind_gust_kt).to be_nil
      end

      it "parses visibility" do
        expect(group.visibility_sm).to eq(6.0)
      end

      it "parses sky condition" do
        expect(group.sky_condition).to eq([{ cover: :bkn, base_ft: 7000 }])
      end

      it "computes ceiling" do
        expect(group.ceiling_ft).to eq(7000)
      end

      it "computes flight category" do
        expect(group.flight_category).to eq(:vfr)
      end
    end

    context "with FM group (gusty, OVC)" do
      subject(:group) { described_class.from_awc(taf_data["fcsts"][1]) }

      it "sets change_type to :fm" do
        expect(group.change_type).to eq(:fm)
      end

      it "parses gusts" do
        expect(group.wind_gust_kt).to eq(23)
      end

      it "computes ceiling from OVC" do
        expect(group.ceiling_ft).to eq(5000)
      end
    end

    context "with FEW-only group (no ceiling)" do
      subject(:group) { described_class.from_awc(taf_data["fcsts"][2]) }

      it "returns nil ceiling for FEW" do
        expect(group.ceiling_ft).to be_nil
      end

      it "classifies as VFR" do
        expect(group.flight_category).to eq(:vfr)
      end
    end
  end

  describe "#to_h" do
    subject(:group) { described_class.from_awc(taf_data["fcsts"][0]) }

    it "returns a hash with all fields" do
      hash = group.to_h
      expect(hash[:change_type]).to eq(:initial)
      expect(hash[:wind_speed_kt]).to eq(14)
      expect(hash[:flight_category]).to eq(:vfr)
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/models/taf_group_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models::TafGroup`

- [ ] **Step 4: Write the implementation**

Create `lib/briefer/models/taf_group.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Models
    class TafGroup
      CEILING_COVERS = %i[bkn ovc].freeze
      CHANGE_TYPES = { nil => :initial, "FM" => :fm, "BECMG" => :becmg, "TEMPO" => :tempo, "PROB" => :prob }.freeze

      attr_reader :time_from, :time_to, :change_type, :probability,
                  :wind_direction_deg, :wind_speed_kt, :wind_gust_kt,
                  :visibility_sm, :weather, :sky_condition

      def self.from_awc(data) # rubocop:disable Metrics/MethodLength
        new(
          time_from: Time.at(data["timeFrom"]).utc,
          time_to: Time.at(data["timeTo"]).utc,
          change_type: CHANGE_TYPES.fetch(data["fcstChange"], :initial),
          probability: data["probability"],
          wind_direction_deg: data["wdir"],
          wind_speed_kt: data["wspd"],
          wind_gust_kt: data["wgst"],
          visibility_sm: Metar.send(:parse_visibility, data["visib"]),
          weather: Metar.send(:parse_weather, data["wxString"]),
          sky_condition: Metar.send(:parse_clouds, data["clouds"])
        )
      end

      def initialize(**attrs) # rubocop:disable Metrics/MethodLength
        @time_from = attrs[:time_from]
        @time_to = attrs[:time_to]
        @change_type = attrs[:change_type]
        @probability = attrs[:probability]
        @wind_direction_deg = attrs[:wind_direction_deg]
        @wind_speed_kt = attrs[:wind_speed_kt]
        @wind_gust_kt = attrs[:wind_gust_kt]
        @visibility_sm = attrs[:visibility_sm]
        @weather = attrs[:weather]
        @sky_condition = attrs[:sky_condition]
      end

      def ceiling_ft
        ceiling_layer = sky_condition&.find { |layer| CEILING_COVERS.include?(layer[:cover]) }
        ceiling_layer&.dig(:base_ft)
      end

      def flight_category
        Analysis::FlightCategory.classify(ceiling_ft: ceiling_ft, visibility_sm: visibility_sm)
      end

      def to_h
        {
          time_from: time_from&.iso8601, time_to: time_to&.iso8601,
          change_type: change_type, probability: probability,
          wind_direction_deg: wind_direction_deg, wind_speed_kt: wind_speed_kt, wind_gust_kt: wind_gust_kt,
          visibility_sm: visibility_sm, weather: weather, sky_condition: sky_condition,
          ceiling_ft: ceiling_ft, flight_category: flight_category
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end
    end
  end
end
```

- [ ] **Step 5: Add require to `lib/briefer.rb`**

Add after the metar model require:

```ruby
require_relative "briefer/models/taf_group"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/taf_group_spec.rb`
Expected: 12 examples, 0 failures

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/taf_group.rb spec/models/taf_group_spec.rb`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/models/taf_group.rb lib/briefer.rb \
  spec/models/taf_group_spec.rb spec/fixtures/tafs/
git commit -m "Add TafGroup model for forecast period parsing"
```

---

### Task 3: Taf Model

**Files:**
- Create: `lib/briefer/models/taf.rb`
- Create: `spec/models/taf_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/models/taf_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::Taf do
  let(:taf_data) { JSON.parse(File.read("spec/fixtures/tafs/kack.json")) }

  describe ".from_awc" do
    subject(:taf) { described_class.from_awc(taf_data) }

    it "parses station_id" do
      expect(taf.station_id).to eq("KACK")
    end

    it "parses raw TAF" do
      expect(taf.raw).to start_with("TAF KACK")
    end

    it "parses issued_at" do
      expect(taf.issued_at).to be_a(Time)
    end

    it "parses valid_from and valid_to" do
      expect(taf.valid_from).to be_a(Time)
      expect(taf.valid_to).to be_a(Time)
      expect(taf.valid_to).to be > taf.valid_from
    end

    it "parses station info" do
      expect(taf.station_name).to eq("Nantucket Mem Arpt")
      expect(taf.latitude).to eq(41.25407)
    end

    it "builds position" do
      expect(taf.position).to eq(Briefer::Models::Position.new(lat: 41.25407, lon: -70.05892))
    end

    it "parses forecast groups" do
      expect(taf.forecast_groups.size).to eq(3)
      expect(taf.forecast_groups).to all(be_a(Briefer::Models::TafGroup))
    end

    it "has correct change types in order" do
      types = taf.forecast_groups.map(&:change_type)
      expect(types).to eq(%i[initial fm fm])
    end
  end

  describe "#group_at" do
    subject(:taf) { described_class.from_awc(taf_data) }

    it "returns the initial group for a time in the first period" do
      time = taf.valid_from + 60
      group = taf.group_at(time)
      expect(group.change_type).to eq(:initial)
    end

    it "returns the FM group for a time in the second period" do
      time = Time.at(1774713600).utc + 60
      group = taf.group_at(time)
      expect(group.change_type).to eq(:fm)
      expect(group.wind_gust_kt).to eq(23)
    end

    it "returns nil for a time outside the valid period" do
      group = taf.group_at(Time.at(0).utc)
      expect(group).to be_nil
    end
  end

  describe "#to_h" do
    subject(:taf) { described_class.from_awc(taf_data) }

    it "includes station_id and forecast_groups" do
      hash = taf.to_h
      expect(hash[:station_id]).to eq("KACK")
      expect(hash[:forecast_groups]).to be_an(Array)
      expect(hash[:forecast_groups].size).to eq(3)
    end
  end

  describe "#to_json" do
    subject(:taf) { described_class.from_awc(taf_data) }

    it "returns valid JSON" do
      parsed = JSON.parse(taf.to_json)
      expect(parsed["station_id"]).to eq("KACK")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/taf_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models::Taf`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/models/taf.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Models
    class Taf
      attr_reader :station_id, :raw, :issued_at, :valid_from, :valid_to,
                  :station_name, :latitude, :longitude, :elevation_ft,
                  :forecast_groups

      def self.from_awc(data) # rubocop:disable Metrics/MethodLength
        new(
          station_id: data["icaoId"],
          raw: data["rawTAF"],
          issued_at: Time.parse(data["issueTime"]).utc,
          valid_from: Time.at(data["validTimeFrom"]).utc,
          valid_to: Time.at(data["validTimeTo"]).utc,
          station_name: data["name"],
          latitude: data["lat"],
          longitude: data["lon"],
          elevation_ft: data["elev"] ? (data["elev"] * 3.28084).round : nil,
          forecast_groups: data["fcsts"]&.map { |f| TafGroup.from_awc(f) } || []
        )
      end

      def initialize(**attrs) # rubocop:disable Metrics/MethodLength
        @station_id = attrs[:station_id]
        @raw = attrs[:raw]
        @issued_at = attrs[:issued_at]
        @valid_from = attrs[:valid_from]
        @valid_to = attrs[:valid_to]
        @station_name = attrs[:station_name]
        @latitude = attrs[:latitude]
        @longitude = attrs[:longitude]
        @elevation_ft = attrs[:elevation_ft]
        @forecast_groups = attrs[:forecast_groups]
      end

      def position
        Position.new(lat: latitude, lon: longitude)
      end

      def group_at(time)
        forecast_groups.reverse.find { |g| time >= g.time_from && time < g.time_to }
      end

      def to_h
        {
          station_id: station_id, raw: raw, issued_at: issued_at&.iso8601,
          valid_from: valid_from&.iso8601, valid_to: valid_to&.iso8601,
          station_name: station_name, latitude: latitude, longitude: longitude,
          elevation_ft: elevation_ft,
          forecast_groups: forecast_groups.map(&:to_h)
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end
    end
  end
end
```

- [ ] **Step 4: Add require to `lib/briefer.rb`**

Add after taf_group require:

```ruby
require_relative "briefer/models/taf"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/models/taf_spec.rb`
Expected: 11 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/taf.rb spec/models/taf_spec.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/models/taf.rb lib/briefer.rb spec/models/taf_spec.rb
git commit -m "Add Taf model with forecast group lookup"
```

---

### Task 4: TAF Source + CLI Command

**Files:**
- Create: `lib/briefer/sources/taf.rb`
- Create: `spec/sources/taf_spec.rb`
- Modify: `lib/briefer.rb`
- Modify: `lib/briefer/formatters/text.rb`
- Modify: `lib/briefer/cli.rb`
- Modify: `spec/cli_spec.rb`

- [ ] **Step 1: Write the source test**

Create `spec/sources/taf_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Sources::Taf do
  subject(:source) { described_class.new(client: Briefer.client) }

  let(:kack_response) { [JSON.parse(File.read("spec/fixtures/tafs/kack.json"))] }

  describe "#fetch" do
    it "fetches and returns Taf models" do
      stub_request(:get, "https://aviationweather.gov/api/data/taf")
        .with(query: { ids: "KACK", format: "json" })
        .to_return(status: 200, body: kack_response.to_json, headers: { "Content-Type" => "application/json" })

      tafs = source.fetch("KACK")
      expect(tafs.size).to eq(1)
      expect(tafs.first).to be_a(Briefer::Models::Taf)
      expect(tafs.first.station_id).to eq("KACK")
      expect(tafs.first.forecast_groups.size).to eq(3)
    end

    it "upcases station IDs" do
      stub_request(:get, "https://aviationweather.gov/api/data/taf")
        .with(query: { ids: "KACK", format: "json" })
        .to_return(status: 200, body: kack_response.to_json, headers: { "Content-Type" => "application/json" })

      tafs = source.fetch("kack")
      expect(tafs.first.station_id).to eq("KACK")
    end
  end
end
```

- [ ] **Step 2: Write the source implementation**

Create `lib/briefer/sources/taf.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Sources
    class Taf
      ENDPOINT = "/api/data/taf"
      TTL = 1800

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(*station_ids)
        ids = station_ids.map(&:upcase).join(",")
        data = @client.get(ENDPOINT, { ids: ids, format: "json" }, ttl: TTL)
        data.map { |entry| Models::Taf.from_awc(entry) }
      end
    end
  end
end
```

- [ ] **Step 3: Add text formatter for TAF**

Add to `lib/briefer/formatters/text.rb` — add these methods before the `private_class_method` line:

```ruby
def self.format_taf(taf)
  lines = ["#{taf.station_id} (#{taf.station_name}) — TAF issued #{taf.issued_at.strftime('%d %b %Y %H%MZ')}\n"]
  lines << "  #{taf.raw}\n"
  taf.forecast_groups.each do |group|
    prefix = group.change_type == :initial ? "  " : "  #{group.change_type.upcase} "
    from = group.time_from.strftime("%H%MZ")
    to = group.time_to.strftime("%H%MZ")
    wind = "#{group.wind_direction_deg}°@#{group.wind_speed_kt}kt"
    wind += "G#{group.wind_gust_kt}" if group.wind_gust_kt
    vis = group.visibility_sm && group.visibility_sm >= 6 ? "P6SM" : "#{group.visibility_sm}SM"
    clouds = group.sky_condition.map { |c| "#{c[:cover].upcase}#{c[:base_ft] ? format('%03d', c[:base_ft] / 100) : ''}" }.join(" ")
    lines << "#{prefix}#{from}-#{to}: #{wind} #{vis} #{clouds} [#{group.flight_category.upcase}]\n"
  end
  lines.join
end
```

Update the `private_class_method` line to keep existing methods private (don't make `format_taf` private).

- [ ] **Step 4: Add CLI command and convenience method**

Add to `lib/briefer.rb` in the `class << self` block:

```ruby
def taf(*station_ids)
  Sources::Taf.new.fetch(*station_ids)
end
```

Add require after sources/metar:

```ruby
require_relative "briefer/sources/taf"
```

Add to `lib/briefer/cli.rb` — add this command after the `categories` command:

```ruby
desc "taf STATION [STATION...]", "Fetch current TAF(s)"
def taf(*stations)
  tafs = Briefer.taf(*stations)

  if output_format == "json"
    puts JSON.pretty_generate(tafs.map(&:to_h))
  else
    tafs.each { |t| print Formatters::Text.format_taf(t) }
  end
rescue Briefer::Error => e
  warn "Error: #{e.message}"
  exit 1
end
```

- [ ] **Step 5: Add CLI test**

Add to `spec/cli_spec.rb` — add a new describe block:

```ruby
describe "taf command" do
  let(:kack_taf_response) { [JSON.parse(File.read("spec/fixtures/tafs/kack.json"))] }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/taf")
      .with(query: { ids: "KACK", format: "json" })
      .to_return(status: 200, body: kack_taf_response.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "outputs TAF in text format" do
    output = capture_stdout { described_class.start(["taf", "KACK", "--format", "text"]) }
    expect(output).to include("KACK")
    expect(output).to include("TAF")
  end

  it "outputs TAF in JSON format" do
    output = capture_stdout { described_class.start(["taf", "KACK", "--format", "json"]) }
    parsed = JSON.parse(output)
    expect(parsed.first["station_id"]).to eq("KACK")
  end
end
```

- [ ] **Step 6: Run all tests**

Run: `bundle exec rspec`
Expected: all pass

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/sources/taf.rb lib/briefer.rb lib/briefer/formatters/text.rb \
  lib/briefer/cli.rb spec/sources/taf_spec.rb spec/cli_spec.rb
git commit -m "Add TAF source, formatter, and CLI command"
```

---

### Task 5: Pirep Model

**Files:**
- Create: `lib/briefer/models/pirep.rb`
- Create: `spec/models/pirep_spec.rb`
- Create: `spec/fixtures/pireps/icing.json`
- Create: `spec/fixtures/pireps/turbulence.json`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Create PIREP fixtures**

Create `spec/fixtures/pireps/icing.json`:

```json
{
  "receiptTime": "2026-03-28T04:40:07.395Z",
  "obsTime": 1774672320,
  "qcField": 0,
  "icaoId": "KWBC",
  "acType": "C17",
  "lat": 40.0143,
  "lon": -73.7172,
  "fltLvl": 70,
  "fltLvlType": "OTHER",
  "clouds": null,
  "visib": null,
  "wxString": "",
  "temp": -10,
  "wdir": null,
  "wspd": null,
  "icgBas1": 50,
  "icgTop1": 80,
  "icgInt1": "LGT",
  "icgType1": "RIME",
  "icgBas2": null,
  "icgTop2": null,
  "icgInt2": "",
  "icgType2": "",
  "tbBas1": null,
  "tbTop1": null,
  "tbInt1": "",
  "tbType1": "",
  "tbFreq1": "",
  "tbBas2": null,
  "tbTop2": null,
  "tbInt2": "",
  "tbType2": "",
  "tbFreq2": "",
  "vertGust": null,
  "brkAction": "",
  "pirepType": "PIREP",
  "rawOb": "MJX UA /OV CYN080035/TM 0432/FL070/TP C17/TA M10/IC LGT RIME 050-080"
}
```

Create `spec/fixtures/pireps/turbulence.json`:

```json
{
  "receiptTime": "2026-03-28T04:45:05.153Z",
  "obsTime": 1774672200,
  "qcField": 0,
  "icaoId": "KWBC",
  "acType": "BCS3",
  "lat": 41.7243,
  "lon": -71.4296,
  "fltLvl": 140,
  "fltLvlType": "OTHER",
  "clouds": null,
  "visib": null,
  "wxString": "",
  "temp": null,
  "wdir": null,
  "wspd": null,
  "icgBas1": null,
  "icgTop1": null,
  "icgInt1": "",
  "icgType1": "",
  "icgBas2": null,
  "icgTop2": null,
  "icgInt2": "",
  "icgType2": "",
  "tbBas1": 120,
  "tbTop1": 150,
  "tbInt1": "MOD",
  "tbType1": "",
  "tbFreq1": "",
  "tbBas2": null,
  "tbTop2": null,
  "tbInt2": "",
  "tbType2": "",
  "tbFreq2": "",
  "vertGust": null,
  "brkAction": "",
  "pirepType": "PIREP",
  "rawOb": "PVD UA /OV PVD/TM 0430/FL140/TP BCS3/TB MOD 120-150"
}
```

- [ ] **Step 2: Write the failing test**

Create `spec/models/pirep_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::Pirep do
  def load_fixture(name)
    JSON.parse(File.read("spec/fixtures/pireps/#{name}.json"))
  end

  describe ".from_awc" do
    context "with icing PIREP" do
      subject(:pirep) { described_class.from_awc(load_fixture("icing")) }

      it "parses basic fields" do
        expect(pirep.aircraft_type).to eq("C17")
        expect(pirep.flight_level).to eq(70)
        expect(pirep.altitude_ft).to eq(7000)
        expect(pirep.temperature_c).to eq(-10)
        expect(pirep.pirep_type).to eq(:pirep)
      end

      it "parses position" do
        expect(pirep.latitude).to eq(40.0143)
        expect(pirep.longitude).to eq(-73.7172)
        expect(pirep.position).to eq(Briefer::Models::Position.new(lat: 40.0143, lon: -73.7172))
      end

      it "parses observed_at" do
        expect(pirep.observed_at).to be_a(Time)
        expect(pirep.observed_at.utc?).to be(true)
      end

      it "parses icing" do
        expect(pirep.icing_intensity).to eq("LGT")
        expect(pirep.icing_type).to eq("RIME")
        expect(pirep.icing_base_ft).to eq(5000)
        expect(pirep.icing_top_ft).to eq(8000)
      end

      it "reports icing present" do
        expect(pirep).to be_icing
        expect(pirep).not_to be_turbulence
      end

      it "parses raw observation" do
        expect(pirep.raw).to include("IC LGT RIME")
      end
    end

    context "with turbulence PIREP" do
      subject(:pirep) { described_class.from_awc(load_fixture("turbulence")) }

      it "parses turbulence" do
        expect(pirep.turbulence_intensity).to eq("MOD")
        expect(pirep.turbulence_base_ft).to eq(12_000)
        expect(pirep.turbulence_top_ft).to eq(15_000)
      end

      it "reports turbulence present" do
        expect(pirep).to be_turbulence
        expect(pirep).not_to be_icing
      end

      it "has no temperature" do
        expect(pirep.temperature_c).to be_nil
      end
    end
  end

  describe "#to_h" do
    subject(:pirep) { described_class.from_awc(load_fixture("icing")) }

    it "returns hash with key fields" do
      hash = pirep.to_h
      expect(hash[:aircraft_type]).to eq("C17")
      expect(hash[:icing_intensity]).to eq("LGT")
      expect(hash[:altitude_ft]).to eq(7000)
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/models/pirep_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models::Pirep`

- [ ] **Step 4: Write the implementation**

Create `lib/briefer/models/pirep.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Models
    class Pirep
      attr_reader :raw, :observed_at, :pirep_type, :aircraft_type,
                  :latitude, :longitude, :flight_level,
                  :temperature_c, :wind_direction_deg, :wind_speed_kt,
                  :icing_intensity, :icing_type, :icing_base_ft, :icing_top_ft,
                  :turbulence_intensity, :turbulence_type, :turbulence_base_ft, :turbulence_top_ft

      def self.from_awc(data) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        new(
          raw: data["rawOb"],
          observed_at: Time.at(data["obsTime"]).utc,
          pirep_type: data["pirepType"]&.downcase&.to_sym || :pirep,
          aircraft_type: data["acType"],
          latitude: data["lat"],
          longitude: data["lon"],
          flight_level: data["fltLvl"],
          temperature_c: data["temp"],
          wind_direction_deg: data["wdir"],
          wind_speed_kt: data["wspd"],
          icing_intensity: blank_to_nil(data["icgInt1"]),
          icing_type: blank_to_nil(data["icgType1"]),
          icing_base_ft: data["icgBas1"] ? data["icgBas1"] * 100 : nil,
          icing_top_ft: data["icgTop1"] ? data["icgTop1"] * 100 : nil,
          turbulence_intensity: blank_to_nil(data["tbInt1"]),
          turbulence_type: blank_to_nil(data["tbType1"]),
          turbulence_base_ft: data["tbBas1"] ? data["tbBas1"] * 100 : nil,
          turbulence_top_ft: data["tbTop1"] ? data["tbTop1"] * 100 : nil
        )
      end

      def initialize(**attrs) # rubocop:disable Metrics/MethodLength
        @raw = attrs[:raw]
        @observed_at = attrs[:observed_at]
        @pirep_type = attrs[:pirep_type]
        @aircraft_type = attrs[:aircraft_type]
        @latitude = attrs[:latitude]
        @longitude = attrs[:longitude]
        @flight_level = attrs[:flight_level]
        @temperature_c = attrs[:temperature_c]
        @wind_direction_deg = attrs[:wind_direction_deg]
        @wind_speed_kt = attrs[:wind_speed_kt]
        @icing_intensity = attrs[:icing_intensity]
        @icing_type = attrs[:icing_type]
        @icing_base_ft = attrs[:icing_base_ft]
        @icing_top_ft = attrs[:icing_top_ft]
        @turbulence_intensity = attrs[:turbulence_intensity]
        @turbulence_type = attrs[:turbulence_type]
        @turbulence_base_ft = attrs[:turbulence_base_ft]
        @turbulence_top_ft = attrs[:turbulence_top_ft]
      end

      def position
        Position.new(lat: latitude, lon: longitude)
      end

      def altitude_ft
        flight_level ? flight_level * 100 : nil
      end

      def icing?
        !icing_intensity.nil?
      end

      def turbulence?
        !turbulence_intensity.nil?
      end

      def to_h # rubocop:disable Metrics/MethodLength
        {
          raw: raw, observed_at: observed_at&.iso8601, pirep_type: pirep_type,
          aircraft_type: aircraft_type, latitude: latitude, longitude: longitude,
          flight_level: flight_level, altitude_ft: altitude_ft,
          temperature_c: temperature_c,
          icing_intensity: icing_intensity, icing_type: icing_type,
          icing_base_ft: icing_base_ft, icing_top_ft: icing_top_ft,
          turbulence_intensity: turbulence_intensity, turbulence_type: turbulence_type,
          turbulence_base_ft: turbulence_base_ft, turbulence_top_ft: turbulence_top_ft
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end

      def self.blank_to_nil(value)
        return nil if value.nil? || (value.is_a?(String) && value.strip.empty?)

        value
      end

      private_class_method :blank_to_nil
    end
  end
end
```

- [ ] **Step 5: Add require to `lib/briefer.rb`**

Add after taf require:

```ruby
require_relative "briefer/models/pirep"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/pirep_spec.rb`
Expected: 10 examples, 0 failures

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/pirep.rb spec/models/pirep_spec.rb`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/models/pirep.rb lib/briefer.rb \
  spec/models/pirep_spec.rb spec/fixtures/pireps/
git commit -m "Add Pirep model with icing and turbulence parsing"
```

---

### Task 6: PIREP Source + CLI Command

**Files:**
- Create: `lib/briefer/sources/pirep.rb`
- Create: `spec/sources/pirep_spec.rb`
- Modify: `lib/briefer.rb`
- Modify: `lib/briefer/formatters/text.rb`
- Modify: `lib/briefer/cli.rb`
- Modify: `spec/cli_spec.rb`

- [ ] **Step 1: Write the source test**

Create `spec/sources/pirep_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Sources::Pirep do
  subject(:source) { described_class.new(client: Briefer.client) }

  let(:pirep_response) do
    [
      JSON.parse(File.read("spec/fixtures/pireps/icing.json")),
      JSON.parse(File.read("spec/fixtures/pireps/turbulence.json"))
    ]
  end

  describe "#fetch" do
    it "fetches PIREPs near a station" do
      stub_request(:get, "https://aviationweather.gov/api/data/pirep")
        .with(query: { id: "KCDW", dist: "100", format: "json" })
        .to_return(status: 200, body: pirep_response.to_json, headers: { "Content-Type" => "application/json" })

      pireps = source.fetch("KCDW", radius_nm: 100)
      expect(pireps.size).to eq(2)
      expect(pireps).to all(be_a(Briefer::Models::Pirep))
    end

    it "defaults to 100nm radius" do
      stub_request(:get, "https://aviationweather.gov/api/data/pirep")
        .with(query: { id: "KCDW", dist: "100", format: "json" })
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      pireps = source.fetch("KCDW")
      expect(pireps).to eq([])
    end
  end
end
```

- [ ] **Step 2: Write the source implementation**

Create `lib/briefer/sources/pirep.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Sources
    class Pirep
      ENDPOINT = "/api/data/pirep"
      TTL = 600

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(station_id, radius_nm: 100)
        data = @client.get(ENDPOINT, { id: station_id.upcase, dist: radius_nm.to_s, format: "json" }, ttl: TTL)
        data.map { |entry| Models::Pirep.from_awc(entry) }
      end
    end
  end
end
```

- [ ] **Step 3: Add text formatter for PIREP**

Add to `lib/briefer/formatters/text.rb` (before `private_class_method`):

```ruby
def self.format_pirep(pirep)
  parts = ["#{pirep.aircraft_type} FL#{format('%03d', pirep.flight_level || 0)}"]
  parts << "IC:#{pirep.icing_intensity} #{pirep.icing_type}" if pirep.icing?
  parts << "TB:#{pirep.turbulence_intensity}" if pirep.turbulence?
  parts << "Temp:#{pirep.temperature_c}°C" if pirep.temperature_c
  "  #{parts.join('  ')}  (#{pirep.observed_at.strftime('%H%MZ')})\n"
end
```

- [ ] **Step 4: Add CLI command and convenience method**

Add to `lib/briefer.rb` in the `class << self` block:

```ruby
def pireps(station_id, radius_nm: 100)
  Sources::Pirep.new.fetch(station_id, radius_nm: radius_nm)
end
```

Add require after sources/taf:

```ruby
require_relative "briefer/sources/pirep"
```

Add to `lib/briefer/cli.rb`:

```ruby
desc "pireps STATION", "Fetch recent PIREPs near station"
option :radius, type: :numeric, default: 100, desc: "Search radius in NM"
def pireps(station)
  pireps = Briefer.pireps(station, radius_nm: options[:radius])

  if output_format == "json"
    puts JSON.pretty_generate(pireps.map(&:to_h))
  else
    if pireps.empty?
      puts "No PIREPs within #{options[:radius]}nm of #{station.upcase}"
    else
      puts "PIREPs within #{options[:radius]}nm of #{station.upcase}:"
      pireps.each { |p| print Formatters::Text.format_pirep(p) }
    end
  end
rescue Briefer::Error => e
  warn "Error: #{e.message}"
  exit 1
end
```

- [ ] **Step 5: Run all tests**

Run: `bundle exec rspec`
Expected: all pass

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/sources/pirep.rb lib/briefer.rb lib/briefer/formatters/text.rb \
  lib/briefer/cli.rb spec/sources/pirep_spec.rb
git commit -m "Add PIREP source, formatter, and CLI command"
```

---

### Task 7: WindsAloft Model

**Files:**
- Create: `lib/briefer/models/winds_aloft.rb`
- Create: `spec/models/winds_aloft_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/models/winds_aloft_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::WindsAloft do
  describe ".decode" do
    it "decodes standard wind: 2835+06 at 6000" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 6000, encoded: "2835+06")
      expect(wa.wind_direction_deg).to eq(280)
      expect(wa.wind_speed_kt).to eq(35)
      expect(wa.temperature_c).to eq(6)
      expect(wa).not_to be_light_and_variable
    end

    it "decodes negative temp: 2510-09 at 9000" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 9000, encoded: "2510-09")
      expect(wa.wind_direction_deg).to eq(250)
      expect(wa.wind_speed_kt).to eq(10)
      expect(wa.temperature_c).to eq(-9)
    end

    it "decodes light and variable: 9900+05" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 3000, encoded: "9900+05")
      expect(wa).to be_light_and_variable
      expect(wa.wind_direction_deg).to be_nil
      expect(wa.wind_speed_kt).to be_nil
      expect(wa.temperature_c).to eq(5)
    end

    it "decodes high speed (>100kt): 7545 at 30000" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 30_000, encoded: "262849")
      expect(wa.wind_direction_deg).to eq(260)
      expect(wa.wind_speed_kt).to eq(128)
      expect(wa.temperature_c).to eq(-49)
    end

    it "decodes wind-only (no temp): 2124 at 3000" do
      wa = described_class.decode(station_id: "ABR", altitude_ft: 3000, encoded: "2124")
      expect(wa.wind_direction_deg).to eq(210)
      expect(wa.wind_speed_kt).to eq(24)
      expect(wa.temperature_c).to be_nil
    end

    it "returns nil for nil encoded string" do
      wa = described_class.decode(station_id: "ABQ", altitude_ft: 3000, encoded: nil)
      expect(wa).to be_nil
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 6000, encoded: "2835+06")
      hash = wa.to_h
      expect(hash[:station_id]).to eq("JFK")
      expect(hash[:altitude_ft]).to eq(6000)
      expect(hash[:wind_direction_deg]).to eq(280)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/winds_aloft_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models::WindsAloft`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/models/winds_aloft.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Models
    class WindsAloft
      attr_reader :station_id, :altitude_ft, :wind_direction_deg, :wind_speed_kt,
                  :temperature_c, :light_and_variable

      def self.decode(station_id:, altitude_ft:, encoded:) # rubocop:disable Metrics/MethodLength
        return nil if encoded.nil? || encoded.strip.empty?

        direction, speed, temp = parse_encoded(encoded, altitude_ft)

        new(
          station_id: station_id,
          altitude_ft: altitude_ft,
          wind_direction_deg: direction,
          wind_speed_kt: speed,
          temperature_c: temp,
          light_and_variable: direction.nil? && speed.nil? && encoded.start_with?("99")
        )
      end

      def initialize(**attrs)
        @station_id = attrs[:station_id]
        @altitude_ft = attrs[:altitude_ft]
        @wind_direction_deg = attrs[:wind_direction_deg]
        @wind_speed_kt = attrs[:wind_speed_kt]
        @temperature_c = attrs[:temperature_c]
        @light_and_variable = attrs[:light_and_variable] || false
      end

      def light_and_variable?
        @light_and_variable
      end

      def to_h
        {
          station_id: station_id, altitude_ft: altitude_ft,
          wind_direction_deg: wind_direction_deg, wind_speed_kt: wind_speed_kt,
          temperature_c: temperature_c, light_and_variable: light_and_variable?
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end

      def self.parse_encoded(encoded, altitude_ft) # rubocop:disable Metrics/MethodLength
        wind_part = encoded[0, 4]
        temp_part = encoded[4..]

        dir_code = wind_part[0, 2].to_i
        speed = wind_part[2, 2].to_i

        # Light and variable
        if dir_code == 99 && speed == 0
          temp = parse_temp(temp_part, altitude_ft)
          return [nil, nil, temp]
        end

        # High speed encoding: direction > 36 means subtract 50, add 100 to speed
        if dir_code > 36
          dir_code -= 50
          speed += 100
        end

        direction = dir_code * 10
        temp = parse_temp(temp_part, altitude_ft)

        [direction, speed, temp]
      end

      def self.parse_temp(temp_part, altitude_ft)
        return nil if temp_part.nil? || temp_part.strip.empty?

        if temp_part.match?(/^[+-]/)
          temp_part.to_i
        else
          temp = temp_part.to_i
          altitude_ft >= 24_000 ? -temp : temp
        end
      end

      private_class_method :parse_encoded, :parse_temp
    end
  end
end
```

- [ ] **Step 4: Add require to `lib/briefer.rb`**

Add after pirep require:

```ruby
require_relative "briefer/models/winds_aloft"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/models/winds_aloft_spec.rb`
Expected: 7 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/winds_aloft.rb spec/models/winds_aloft_spec.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/models/winds_aloft.rb lib/briefer.rb spec/models/winds_aloft_spec.rb
git commit -m "Add WindsAloft model with encoded string decoder"
```

---

### Task 8: WindsAloft Source + CLI Command

**Files:**
- Create: `lib/briefer/sources/winds_aloft.rb`
- Create: `spec/sources/winds_aloft_spec.rb`
- Create: `spec/fixtures/winds_aloft/low_level.json`
- Modify: `lib/briefer.rb`
- Modify: `lib/briefer/formatters/text.rb`
- Modify: `lib/briefer/cli.rb`

- [ ] **Step 1: Create winds aloft fixture**

Create `spec/fixtures/winds_aloft/low_level.json`:

```json
[
  {
    "station_id": "JFK",
    "ft_3000": "0823+05",
    "ft_6000": "2835+06",
    "ft_9000": "2510-09",
    "ft_12000": "3020-15",
    "ft_18000": "2920-22",
    "ft_24000": "272539",
    "ft_30000": "262849",
    "ft_34000": "262159",
    "ft_39000": null
  },
  {
    "station_id": "ACK",
    "ft_3000": "9900+08",
    "ft_6000": "2020+04",
    "ft_9000": "2515-05",
    "ft_12000": "2825-12",
    "ft_18000": "2935-20",
    "ft_24000": null,
    "ft_30000": null,
    "ft_34000": null,
    "ft_39000": null
  }
]
```

- [ ] **Step 2: Write the source test**

Create `spec/sources/winds_aloft_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Sources::WindsAloft do
  subject(:source) { described_class.new(client: Briefer.client) }

  let(:winds_response) { JSON.parse(File.read("spec/fixtures/winds_aloft/low_level.json")) }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/windtemp")
      .with(query: { region: "all", level: "low", fcst: "06", format: "json" })
      .to_return(status: 200, body: winds_response.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe "#fetch" do
    it "fetches winds for a station at all altitudes" do
      winds = source.fetch("JFK")
      expect(winds).to all(be_a(Briefer::Models::WindsAloft))
      expect(winds.first.station_id).to eq("JFK")
    end

    it "filters to a specific altitude" do
      winds = source.fetch("JFK", altitude_ft: 6000)
      expect(winds.size).to eq(1)
      expect(winds.first.altitude_ft).to eq(6000)
      expect(winds.first.wind_speed_kt).to eq(35)
    end

    it "returns empty for unknown station" do
      winds = source.fetch("XXXX")
      expect(winds).to eq([])
    end

    it "skips nil altitude entries" do
      winds = source.fetch("ACK")
      altitudes = winds.map(&:altitude_ft)
      expect(altitudes).not_to include(24_000)
    end
  end
end
```

- [ ] **Step 3: Write the source implementation**

Create `lib/briefer/sources/winds_aloft.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Sources
    class WindsAloft
      ENDPOINT = "/api/data/windtemp"
      TTL = 3600
      ALTITUDE_COLUMNS = {
        3000 => "ft_3000", 6000 => "ft_6000", 9000 => "ft_9000",
        12_000 => "ft_12000", 18_000 => "ft_18000", 24_000 => "ft_24000",
        30_000 => "ft_30000", 34_000 => "ft_34000", 39_000 => "ft_39000"
      }.freeze

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(station_id, altitude_ft: nil) # rubocop:disable Metrics/MethodLength
        data = @client.get(ENDPOINT, { region: "all", level: "low", fcst: "06", format: "json" }, ttl: TTL)
        station_data = data.find { |entry| entry["station_id"]&.upcase == station_id.upcase }
        return [] unless station_data

        columns = altitude_ft ? { altitude_ft => ALTITUDE_COLUMNS[altitude_ft] } : ALTITUDE_COLUMNS

        columns.filter_map do |alt, col|
          encoded = station_data[col]
          Models::WindsAloft.decode(station_id: station_data["station_id"], altitude_ft: alt, encoded: encoded)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Add text formatter for winds aloft**

Add to `lib/briefer/formatters/text.rb` (before `private_class_method`):

```ruby
def self.format_winds_aloft(winds)
  return "No winds aloft data available\n" if winds.empty?

  lines = [format("  %-8s %-10s %-8s %-8s\n", "Alt", "Dir", "Speed", "Temp")]
  winds.each do |w|
    if w.light_and_variable?
      lines << format("  %-8s %-10s %-8s %-8s\n", "#{number_with_commas(w.altitude_ft)}'", "VRB", "LGT", w.temperature_c ? "#{w.temperature_c}°C" : "-")
    else
      lines << format("  %-8s %-10s %-8s %-8s\n", "#{number_with_commas(w.altitude_ft)}'", "#{w.wind_direction_deg}°", "#{w.wind_speed_kt}kt", w.temperature_c ? "#{w.temperature_c}°C" : "-")
    end
  end
  lines.join
end
```

- [ ] **Step 5: Add CLI command and convenience method**

Add to `lib/briefer.rb` in `class << self`:

```ruby
def winds_aloft(station_id, altitude_ft: nil)
  Sources::WindsAloft.new.fetch(station_id, altitude_ft: altitude_ft)
end
```

Add require after sources/pirep:

```ruby
require_relative "briefer/sources/winds_aloft"
```

Add to `lib/briefer/cli.rb`:

```ruby
desc "winds STATION", "Fetch winds aloft forecast"
option :altitude, type: :numeric, desc: "Filter to specific altitude (feet)"
def winds(station)
  winds = Briefer.winds_aloft(station, altitude_ft: options[:altitude])

  if output_format == "json"
    puts JSON.pretty_generate(winds.map(&:to_h))
  else
    puts "Winds aloft for #{station.upcase}:"
    print Formatters::Text.format_winds_aloft(winds)
  end
rescue Briefer::Error => e
  warn "Error: #{e.message}"
  exit 1
end
```

- [ ] **Step 6: Run all tests**

Run: `bundle exec rspec`
Expected: all pass

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/sources/winds_aloft.rb lib/briefer.rb lib/briefer/formatters/text.rb \
  lib/briefer/cli.rb spec/sources/winds_aloft_spec.rb spec/fixtures/winds_aloft/
git commit -m "Add winds aloft source, formatter, and CLI command"
```

---

### Task 9: Crosswind Calculator + CLI Command

**Files:**
- Create: `lib/briefer/analysis/crosswind_calculator.rb`
- Create: `spec/analysis/crosswind_calculator_spec.rb`
- Modify: `lib/briefer.rb`
- Modify: `lib/briefer/formatters/text.rb`
- Modify: `lib/briefer/cli.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/analysis/crosswind_calculator_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Analysis::CrosswindCalculator do
  describe ".calculate" do
    it "calculates crosswind for 90-degree cross" do
      result = described_class.calculate(wind_direction_deg: 280, wind_speed_kt: 15, runway_heading: 190)
      expect(result[:crosswind_kt]).to be_within(0.1).of(15.0)
      expect(result[:headwind_kt]).to be_within(0.1).of(0.0)
    end

    it "calculates headwind for direct headwind" do
      result = described_class.calculate(wind_direction_deg: 280, wind_speed_kt: 15, runway_heading: 280)
      expect(result[:crosswind_kt]).to be_within(0.1).of(0.0)
      expect(result[:headwind_kt]).to be_within(0.1).of(15.0)
    end

    it "calculates for angled wind" do
      result = described_class.calculate(wind_direction_deg: 330, wind_speed_kt: 15, runway_heading: 280)
      # 50 degree angle: crosswind = 15 * sin(50) = 11.5, headwind = 15 * cos(50) = 9.6
      expect(result[:crosswind_kt]).to be_within(0.5).of(11.5)
      expect(result[:headwind_kt]).to be_within(0.5).of(9.6)
    end

    it "returns zeros for calm winds" do
      result = described_class.calculate(wind_direction_deg: 0, wind_speed_kt: 0, runway_heading: 280)
      expect(result[:crosswind_kt]).to eq(0.0)
      expect(result[:headwind_kt]).to eq(0.0)
    end

    it "handles tailwind (negative headwind)" do
      result = described_class.calculate(wind_direction_deg: 100, wind_speed_kt: 10, runway_heading: 280)
      expect(result[:headwind_kt]).to be < 0
    end

    it "handles wind direction wrapping around 360" do
      result = described_class.calculate(wind_direction_deg: 350, wind_speed_kt: 10, runway_heading: 10)
      # 20 degree angle
      expect(result[:crosswind_kt]).to be_within(0.5).of(3.4)
      expect(result[:headwind_kt]).to be_within(0.5).of(9.4)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/analysis/crosswind_calculator_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Analysis::CrosswindCalculator`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/analysis/crosswind_calculator.rb`:

```ruby
# frozen_string_literal: true

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
```

- [ ] **Step 4: Add text formatter for crosswind**

Add to `lib/briefer/formatters/text.rb` (before `private_class_method`):

```ruby
def self.format_crosswind(result, station_id, runway_heading)
  tailwind = result[:headwind_kt] < 0
  hw_label = tailwind ? "Tailwind" : "Headwind"
  "#{station_id} Runway #{runway_heading}°: Crosswind #{result[:crosswind_kt]}kt, #{hw_label} #{result[:headwind_kt].abs}kt\n"
end
```

- [ ] **Step 5: Add CLI command and convenience method**

Add require to `lib/briefer.rb` after flight_category:

```ruby
require_relative "briefer/analysis/crosswind_calculator"
```

Add to `lib/briefer.rb` in `class << self`:

```ruby
def crosswind(station_id, runway_heading:)
  metars = metar(station_id)
  raise Error, "No METAR available for #{station_id}" if metars.empty?

  m = metars.first
  Analysis::CrosswindCalculator.calculate(
    wind_direction_deg: m.wind_direction_deg || 0,
    wind_speed_kt: m.wind_speed_kt || 0,
    runway_heading: runway_heading
  )
end
```

Add to `lib/briefer/cli.rb`:

```ruby
desc "crosswind STATION", "Calculate crosswind component"
option :runway, type: :numeric, required: true, desc: "Runway heading (degrees)"
def crosswind(station)
  result = Briefer.crosswind(station, runway_heading: options[:runway])

  if output_format == "json"
    puts JSON.pretty_generate(result)
  else
    print Formatters::Text.format_crosswind(result, station.upcase, options[:runway])
  end
rescue Briefer::Error => e
  warn "Error: #{e.message}"
  exit 1
end
```

- [ ] **Step 6: Run all tests**

Run: `bundle exec rspec`
Expected: all pass

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/analysis/crosswind_calculator.rb lib/briefer.rb \
  lib/briefer/formatters/text.rb lib/briefer/cli.rb \
  spec/analysis/crosswind_calculator_spec.rb
git commit -m "Add crosswind calculator, formatter, and CLI command"
```

---

### Task 10: Integration Test & Full Suite Verification

**Files:**
- Modify: `spec/briefer_spec.rb`

- [ ] **Step 1: Add integration tests for new convenience methods**

Add to `spec/briefer_spec.rb`:

```ruby
describe ".taf" do
  let(:kack_taf) { [JSON.parse(File.read("spec/fixtures/tafs/kack.json"))] }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/taf")
      .with(query: { ids: "KACK", format: "json" })
      .to_return(status: 200, body: kack_taf.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "returns an array of Taf models" do
    tafs = described_class.taf("KACK")
    expect(tafs.first).to be_a(Briefer::Models::Taf)
    expect(tafs.first.station_id).to eq("KACK")
    expect(tafs.first.forecast_groups).not_to be_empty
  end
end

describe ".pireps" do
  let(:pirep_data) { [JSON.parse(File.read("spec/fixtures/pireps/icing.json"))] }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/pirep")
      .with(query: { id: "KCDW", dist: "100", format: "json" })
      .to_return(status: 200, body: pirep_data.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "returns an array of Pirep models" do
    pireps = described_class.pireps("KCDW")
    expect(pireps.first).to be_a(Briefer::Models::Pirep)
  end
end

describe ".crosswind" do
  let(:kcdw_data) { [JSON.parse(File.read("spec/fixtures/metars/kcdw.json"))] }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/metar")
      .with(query: { ids: "KCDW", format: "json" })
      .to_return(status: 200, body: kcdw_data.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "returns crosswind and headwind components" do
    result = described_class.crosswind("KCDW", runway_heading: 280)
    expect(result).to have_key(:crosswind_kt)
    expect(result).to have_key(:headwind_kt)
  end
end
```

- [ ] **Step 2: Run the full test suite**

Run: `bundle exec rspec`
Expected: all pass (roughly 100+ examples, 0 failures)

- [ ] **Step 3: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 4: Run default rake task**

Run: `bundle exec rake`
Expected: all pass

- [ ] **Step 5: Smoke test all new CLI commands**

Run: `bundle exec exe/briefer taf KACK --format text`
Expected: TAF for Nantucket with forecast groups

Run: `bundle exec exe/briefer pireps KCDW --format text`
Expected: PIREPs near Caldwell (may be empty if none reported)

Run: `bundle exec exe/briefer winds JFK --altitude 6000 --format text`
Expected: winds aloft for JFK at 6000'

Run: `bundle exec exe/briefer crosswind KCDW --runway 280 --format text`
Expected: crosswind and headwind components for runway 28

- [ ] **Step 6: Commit and push**

```bash
git add spec/briefer_spec.rb
git commit -m "Add Phase 2 integration tests and verify full suite"
git push
```
