# Skywatch.brief Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `Skywatch.brief(airport:)` and `skywatch brief AIRPORT` — a single composition layer that produces an [AIM 7-1-5](https://www.faa.gov/air_traffic/publications/atpubs/aim_html/chap7_section_1.html)-shaped weather brief at one airport, composed from existing Briefer + Nimbus primitives. The MVP shipping bar is **validation success** — confirming the LLM-briefer thesis works on what's already built before expanding (route input, coord input, ETD, NOTAMs).

**Architecture:** Pure composition layer over existing primitives — no new data sources. `Skywatch::Brief::Analysis::Composer` orchestrates Briefer + Nimbus fetches sequentially, wraps each in per-slot try/rescue, and assembles `Skywatch::Brief::Models::Brief` whose `#to_h` produces an AIM-9-aligned envelope with uniform `{ available: bool, ... }` slot contracts. Single-airport input. METAR is the only hard-fail; everything else degrades to `available: false` with a reason string.

**Tech Stack:** Ruby gem · Thor (CLI) · Faraday + faraday-retry (HTTP) · `Shared::Http`/`Shared::Cache` (existing) · WebMock (test stubs) · RSpec · RGeo (geometry) · `Briefer::Sources::*` + `Nimbus::Sources::*` (existing primitives, unchanged).

**Reference:** Spec at `docs/superpowers/specs/2026-04-27-skywatch-brief-design.md`. Read it once before starting. The branch `skywatch-brief` already exists with the spec commit (`17acc3a`).

---

## File Structure

**Create:**

| Path | Responsibility |
|---|---|
| `lib/skywatch/brief/models/brief.rb` | The envelope model — holds all slot data, `#to_h` produces AIM-9 hash with uniform `{ available: bool, ... }` per slot |
| `lib/skywatch/brief/analysis/airport_locator.rb` | `coordinates_from_metar(metar) → [lat, lon]` and `wfo_for(lat, lon) → "OKX"` (via `api.weather.gov/points/{lat,lon}`, cached) |
| `lib/skywatch/brief/analysis/adverse_filter.rb` | SIGMET/AIRMET polygon-intersect, PIREP/storm-report distance filtering, PIREP urgent-vs-informational partition |
| `lib/skywatch/brief/analysis/composer.rb` | Orchestrates fetches, derives slots, wraps each in try/rescue, assembles `Brief` |
| `lib/skywatch/brief/cli.rb` | Thor subcommand: `skywatch brief AIRPORT` (JSON-only for MVP) |
| `spec/brief/models/brief_spec.rb` | Brief shape contract tests |
| `spec/brief/analysis/airport_locator_spec.rb` | Locator + WFO lookup + cache behavior |
| `spec/brief/analysis/adverse_filter_spec.rb` | Filter + partition behavior |
| `spec/brief/analysis/composer_spec.rb` | Per-slot success/failure paths, METAR-hard-fail, partial_failures aggregation |
| `spec/brief/cli_spec.rb` | CLI command shape (JSON output, error path) |
| `spec/brief_spec.rb` | Integration: full `Skywatch.brief("KCDW")` against fixtures, snapshot the AIM-9 envelope |
| `spec/fixtures/nws_points/kcdw.json` | NWS `/points/{lat,lon}` response for KCDW (yields `properties.cwa = "OKX"`) |

**Modify:**

| Path | Change |
|---|---|
| `lib/skywatch.rb` | Add `Skywatch.brief(airport:)`; require_relative the new files |
| `lib/skywatch/cli.rb` | Add `brief AIRPORT` direct command (not a subcommand — single command, single arg) |
| `CLAUDE.md` | Add `skywatch brief KCDW` to CLI usage block |

**Validation deliverable (filled at Task 12, not implementation):**

| Path | Purpose |
|---|---|
| `docs/superpowers/specs/2026-04-27-skywatch-brief-validation-results.md` | Captured JSON briefs + LLM responses to canonical 7-question prompt for 3 scenarios + pass/fail call |

---

## Pre-flight

Before Task 1, the implementer should:

1. `cd /Users/jravaliya/Code/skywatch`
2. Confirm we're on the right branch:
   ```bash
   git rev-parse --abbrev-ref HEAD
   # expected: skywatch-brief
   ```
3. Confirm baseline:
   ```bash
   bundle exec rspec
   # expected: 371 examples, 0 failures
   bundle exec rubocop
   # expected: clean
   ```
4. Each task ends with `git add <files> && git commit`. Do not push between tasks; the final task pushes the branch and opens the PR.

---

## Task 1: Capture NWS `/points/{lat,lon}` fixture

**Files:**
- Create: `spec/fixtures/nws_points/kcdw.json`

The composer's WFO lookup hits `api.weather.gov/points/{lat,lon}` and reads `properties.cwa`. We need one canonical fixture. KCDW is at approximately `40.875, -74.282` and falls under WFO OKX (NWS New York).

- [ ] **Step 1: Make the fixture directory**

```bash
mkdir -p spec/fixtures/nws_points
```

- [ ] **Step 2: Write the fixture**

Save as `spec/fixtures/nws_points/kcdw.json`:

```json
{
  "@context": ["https://geojson.org/geojson-ld/geojson-context.jsonld"],
  "id": "https://api.weather.gov/points/40.8751,-74.2814",
  "type": "Feature",
  "geometry": {
    "type": "Point",
    "coordinates": [-74.2814, 40.8751]
  },
  "properties": {
    "@id": "https://api.weather.gov/points/40.8751,-74.2814",
    "@type": "wx:Point",
    "cwa": "OKX",
    "forecastOffice": "https://api.weather.gov/offices/OKX",
    "gridId": "OKX",
    "gridX": 33,
    "gridY": 38,
    "forecast": "https://api.weather.gov/gridpoints/OKX/33,38/forecast",
    "forecastHourly": "https://api.weather.gov/gridpoints/OKX/33,38/forecast/hourly",
    "forecastGridData": "https://api.weather.gov/gridpoints/OKX/33,38",
    "observationStations": "https://api.weather.gov/gridpoints/OKX/33,38/stations",
    "relativeLocation": {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [-74.262, 40.847]},
      "properties": {
        "city": "Caldwell",
        "state": "NJ",
        "distance": {"unitCode": "wmoUnit:m", "value": 3500}
      }
    },
    "forecastZone": "https://api.weather.gov/zones/forecast/NJZ103",
    "county": "https://api.weather.gov/zones/county/NJC013",
    "fireWeatherZone": "https://api.weather.gov/zones/fire/NJZ103",
    "timeZone": "America/New_York",
    "radarStation": "KDIX"
  }
}
```

- [ ] **Step 3: Validate JSON parses**

```bash
ruby -rjson -e 'JSON.parse(File.read("spec/fixtures/nws_points/kcdw.json")); puts "OK"'
```

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add spec/fixtures/nws_points/
git commit -m "test(brief): add NWS /points fixture for KCDW"
```

---

## Task 2: AirportLocator — lat/lon from METAR + WFO from NWS points

**Files:**
- Create: `spec/brief/analysis/airport_locator_spec.rb`
- Create: `lib/skywatch/brief/analysis/airport_locator.rb`

`AirportLocator` is a stateless module. Two methods: `coordinates_from_metar(metar)` is pure (no I/O — just reads the METAR's lat/lon attributes), and `wfo_for(lat, lon)` calls `api.weather.gov/points/{lat,lon}` with a 1-day cache and returns the `properties.cwa` string.

- [ ] **Step 1: Write the spec**

Save as `spec/brief/analysis/airport_locator_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Brief::Analysis::AirportLocator do
  describe '.coordinates_from_metar' do
    it 'returns [lat, lon] from a METAR' do
      metar = Skywatch::Briefer::Models::Metar.new(
        station_id: 'KCDW', latitude: 40.875, longitude: -74.282
      )
      expect(described_class.coordinates_from_metar(metar)).to eq([40.875, -74.282])
    end

    it 'raises when METAR has no coordinates' do
      metar = Skywatch::Briefer::Models::Metar.new(station_id: 'KCDW')
      expect { described_class.coordinates_from_metar(metar) }
        .to raise_error(Skywatch::Error, /no coordinates on METAR/)
    end
  end

  describe '.wfo_for' do
    let(:fixture) { File.read(File.expand_path('../../fixtures/nws_points/kcdw.json', __dir__)) }

    before do
      stub_request(:get, %r{https://api\.weather\.gov/points/40\.875,-74\.282})
        .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })
    end

    it 'returns the WFO id for a coordinate' do
      expect(described_class.wfo_for(40.875, -74.282)).to eq('OKX')
    end

    it 'caches subsequent calls within TTL' do
      described_class.wfo_for(40.875, -74.282)
      described_class.wfo_for(40.875, -74.282)
      expect(WebMock).to have_requested(:get, %r{points/40\.875,-74\.282}).once
    end

    it 'raises Skywatch::Error when the points endpoint fails' do
      stub_request(:get, %r{https://api\.weather\.gov/points/0,0})
        .to_return(status: 500, body: 'boom')
      expect { described_class.wfo_for(0.0, 0.0) }.to raise_error(Skywatch::Error)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/brief/analysis/airport_locator_spec.rb
```

Expected: failure with `uninitialized constant Skywatch::Brief`.

- [ ] **Step 3: Write the implementation**

Save as `lib/skywatch/brief/analysis/airport_locator.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Brief
    module Analysis
      module AirportLocator
        WFO_TTL = 86_400

        def self.coordinates_from_metar(metar)
          raise Skywatch::Error, "no coordinates on METAR for #{metar.station_id}" if
            metar.latitude.nil? || metar.longitude.nil?

          [metar.latitude, metar.longitude]
        end

        def self.wfo_for(lat, lon)
          data = points_client.get("/points/#{lat},#{lon}", {}, ttl: WFO_TTL)
          cwa = data.dig('properties', 'cwa')
          raise Skywatch::Error, "no WFO on /points response for #{lat},#{lon}" if cwa.nil? || cwa.empty?

          cwa
        rescue Skywatch::ApiError => e
          raise Skywatch::Error, "WFO lookup failed for #{lat},#{lon}: #{e.message}"
        end

        def self.points_client
          @points_client ||= Skywatch::Shared::Cache.new(
            client: Skywatch::Shared::Http.new(base_url: 'https://api.weather.gov')
          )
        end

        def self.reset!
          @points_client = nil
        end
      end
    end
  end
end
```

Note: the locator owns its own cached client to keep the WFO TTL (1 day) separate from the shared `Skywatch.client` TTLs. `reset!` is for tests if they need to clear it.

- [ ] **Step 4: Wire it into `lib/skywatch.rb`**

Edit `lib/skywatch.rb`. Find the existing `require_relative 'skywatch/nimbus/formatters/text'` line. Add immediately after it:

```ruby
require_relative 'skywatch/brief/analysis/airport_locator'
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bundle exec rspec spec/brief/analysis/airport_locator_spec.rb
```

Expected: all tests pass.

- [ ] **Step 6: Run rubocop**

```bash
bundle exec rubocop lib/skywatch/brief/ spec/brief/
```

Expected: no offenses.

- [ ] **Step 7: Commit**

```bash
git add lib/skywatch/brief/analysis/airport_locator.rb lib/skywatch.rb spec/brief/analysis/airport_locator_spec.rb
git commit -m "feat(brief): add AirportLocator (METAR coords + NWS WFO lookup)"
```

---

## Task 3: AdverseFilter — polygon-intersect, distance, urgency partition

**Files:**
- Create: `spec/brief/analysis/adverse_filter_spec.rb`
- Create: `lib/skywatch/brief/analysis/adverse_filter.rb`

Three pure functions: `covers?(product, lat, lon)` for SIGMET/AIRMET polygon-intersect; `within(items, lat:, lon:, radius_nm:)` for PIREP/storm-report distance filtering (reuses `Radar::Analysis::Proximity`); `partition_pireps(pireps)` returns `{urgent:, informational:}`.

- [ ] **Step 1: Write the spec**

Save as `spec/brief/analysis/adverse_filter_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Brief::Analysis::AdverseFilter do
  describe '.covers?' do
    let(:square_around_kcdw) do
      coords = [
        Skywatch::Shared::Position.new(lat: 41.0, lon: -75.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 40.0, lon: -75.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -75.0)
      ]
      Skywatch::Briefer::Models::Sigmet.new(coords: coords)
    end

    it 'returns true when the airport is inside the polygon' do
      expect(described_class.covers?(square_around_kcdw, 40.875, -74.282)).to be true
    end

    it 'returns false when the airport is outside the polygon' do
      expect(described_class.covers?(square_around_kcdw, 35.0, -100.0)).to be false
    end

    it 'returns false when the product has no polygon' do
      degenerate = Skywatch::Briefer::Models::Sigmet.new(coords: [])
      expect(described_class.covers?(degenerate, 40.875, -74.282)).to be false
    end
  end

  describe '.within' do
    let(:near_pirep) do
      Skywatch::Briefer::Models::Pirep.new(latitude: 40.9, longitude: -74.3)
    end
    let(:far_pirep) do
      Skywatch::Briefer::Models::Pirep.new(latitude: 30.0, longitude: -90.0)
    end

    it 'keeps items within radius' do
      result = described_class.within([near_pirep, far_pirep], lat: 40.875, lon: -74.282, radius_nm: 100)
      expect(result).to eq([near_pirep])
    end

    it 'returns empty when nothing is in range' do
      expect(described_class.within([far_pirep], lat: 40.875, lon: -74.282, radius_nm: 100)).to eq([])
    end

    it 'skips items missing latitude or longitude' do
      headless = Skywatch::Briefer::Models::Pirep.new(latitude: nil, longitude: nil)
      expect(described_class.within([headless], lat: 40.0, lon: -74.0, radius_nm: 100)).to eq([])
    end
  end

  describe '.partition_pireps' do
    let(:routine) { Skywatch::Briefer::Models::Pirep.new(pirep_type: :pirep) }
    let(:urgent) { Skywatch::Briefer::Models::Pirep.new(pirep_type: :"urgent pirep") }

    it 'splits urgent (any pirep_type containing "urgent") from informational' do
      result = described_class.partition_pireps([routine, urgent])
      expect(result[:urgent]).to eq([urgent])
      expect(result[:informational]).to eq([routine])
    end

    it 'treats nil pirep_type as informational' do
      blank = Skywatch::Briefer::Models::Pirep.new(pirep_type: nil)
      result = described_class.partition_pireps([blank])
      expect(result[:urgent]).to eq([])
      expect(result[:informational]).to eq([blank])
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/brief/analysis/adverse_filter_spec.rb
```

Expected: `uninitialized constant Skywatch::Brief::Analysis::AdverseFilter`.

- [ ] **Step 3: Write the implementation**

Save as `lib/skywatch/brief/analysis/adverse_filter.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Brief
    module Analysis
      module AdverseFilter
        def self.covers?(product, lat, lon)
          polygon = product.polygon
          return false if polygon.nil?

          polygon.contains?(Skywatch::Shared::Geometry.point(lat, lon))
        end

        def self.within(items, lat:, lon:, radius_nm:)
          items.select do |item|
            next false if item.latitude.nil? || item.longitude.nil?

            Skywatch::Radar::Analysis::Proximity.distance_nm(lat, lon, item.latitude, item.longitude) <= radius_nm
          end
        end

        def self.partition_pireps(pireps)
          urgent, informational = pireps.partition do |p|
            p.pirep_type.to_s.include?('urgent')
          end
          { urgent: urgent, informational: informational }
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire it into `lib/skywatch.rb`**

In `lib/skywatch.rb`, immediately after the `require_relative 'skywatch/brief/analysis/airport_locator'` line added in Task 2, add:

```ruby
require_relative 'skywatch/brief/analysis/adverse_filter'
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bundle exec rspec spec/brief/analysis/adverse_filter_spec.rb
```

Expected: all tests pass.

- [ ] **Step 6: Run rubocop**

```bash
bundle exec rubocop lib/skywatch/brief/ spec/brief/
```

Expected: no offenses.

- [ ] **Step 7: Commit**

```bash
git add lib/skywatch/brief/analysis/adverse_filter.rb lib/skywatch.rb spec/brief/analysis/adverse_filter_spec.rb
git commit -m "feat(brief): add AdverseFilter (polygon, distance, urgency partition)"
```

---

## Task 4: Brief model — slot contracts

**Files:**
- Create: `spec/brief/models/brief_spec.rb`
- Create: `lib/skywatch/brief/models/brief.rb`

The model is a value object holding all slot data plus envelope metadata. Each slot is set on construction; `#to_h` produces the AIM-9 envelope. The four hardcoded-unavailable slots (synopsis, enroute_forecast, notams, atc_delays) and the `aim_section` constant are baked in.

- [ ] **Step 1: Write the spec**

Save as `spec/brief/models/brief_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Brief::Models::Brief do
  let(:slot_available) { { available: true, payload: 'ok' } }
  let(:slot_unavailable) { { available: false, reason: 'fetch failed: ...' } }

  let(:brief) do
    described_class.new(
      airport: 'KCDW',
      coordinates: [40.875, -74.282],
      wfo: 'OKX',
      fetched_at: Time.utc(2026, 4, 27, 18, 32, 14),
      adverse_conditions: { available: true, items: [], partial_failures: [] },
      vfr_not_recommended: { available: true, vfr_not_recommended: false, category: 'VFR', explanation: 'VFR conditions' },
      current_conditions: { available: true, metar: { station_id: 'KCDW' }, pireps: [] },
      destination_forecast: slot_available,
      winds_aloft: slot_available,
      afd: slot_available
    )
  end

  it 'serializes the AIM-9 envelope in canonical order' do
    hash = brief.to_h
    expect(hash[:airport]).to eq('KCDW')
    expect(hash[:coordinates]).to eq([40.875, -74.282])
    expect(hash[:wfo]).to eq('OKX')
    expect(hash[:fetched_at]).to eq('2026-04-27T18:32:14Z')
    expect(hash[:aim_section]).to eq('7-1-5')
  end

  it 'includes every AIM 7-1-5 slot' do
    hash = brief.to_h
    %i[adverse_conditions vfr_not_recommended synopsis current_conditions
       enroute_forecast destination_forecast winds_aloft notams atc_delays].each do |slot|
      expect(hash).to include(slot), "missing slot: #{slot}"
    end
  end

  it 'includes the supplementary afd slot' do
    expect(brief.to_h).to include(:afd)
  end

  it 'hardcodes synopsis as unavailable with afd-pointer reason' do
    expect(brief.to_h[:synopsis]).to eq(
      available: false,
      reason: 'no synopsis source in skywatch — see afd slot'
    )
  end

  it 'hardcodes enroute_forecast as unavailable with route-deferred reason' do
    expect(brief.to_h[:enroute_forecast]).to eq(
      available: false,
      reason: 'single-point brief; route input deferred from MVP'
    )
  end

  it 'hardcodes notams as unavailable with sectional-domain reason' do
    expect(brief.to_h[:notams]).to eq(
      available: false,
      reason: 'NOTAMs not in skywatch yet — Sectional domain not yet built'
    )
  end

  it 'hardcodes atc_delays as unavailable' do
    expect(brief.to_h[:atc_delays]).to eq(
      available: false,
      reason: 'ATC delays not in skywatch yet — no source'
    )
  end

  it 'preserves the AIM-9 slots in canonical order' do
    keys = brief.to_h.keys
    aim9 = %i[adverse_conditions vfr_not_recommended synopsis current_conditions
              enroute_forecast destination_forecast winds_aloft notams atc_delays]
    expect(keys & aim9).to eq(aim9)
  end

  it 'serializes to JSON' do
    expect { JSON.parse(brief.to_json) }.not_to raise_error
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/brief/models/brief_spec.rb
```

Expected: `uninitialized constant Skywatch::Brief::Models::Brief`.

- [ ] **Step 3: Write the implementation**

Save as `lib/skywatch/brief/models/brief.rb`:

```ruby
# frozen_string_literal: true

require 'time'
require 'json'

module Skywatch
  module Brief
    module Models
      class Brief
        AIM_SECTION = '7-1-5'

        SYNOPSIS_UNAVAILABLE = {
          available: false,
          reason: 'no synopsis source in skywatch — see afd slot'
        }.freeze

        ENROUTE_UNAVAILABLE = {
          available: false,
          reason: 'single-point brief; route input deferred from MVP'
        }.freeze

        NOTAMS_UNAVAILABLE = {
          available: false,
          reason: 'NOTAMs not in skywatch yet — Sectional domain not yet built'
        }.freeze

        ATC_DELAYS_UNAVAILABLE = {
          available: false,
          reason: 'ATC delays not in skywatch yet — no source'
        }.freeze

        attr_reader :airport, :coordinates, :wfo, :fetched_at,
                    :adverse_conditions, :vfr_not_recommended,
                    :current_conditions, :destination_forecast, :winds_aloft, :afd

        # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
        def initialize(airport:, coordinates:, wfo:, fetched_at:,
                       adverse_conditions:, vfr_not_recommended:,
                       current_conditions:, destination_forecast:, winds_aloft:, afd:)
          @airport = airport
          @coordinates = coordinates
          @wfo = wfo
          @fetched_at = fetched_at
          @adverse_conditions = adverse_conditions
          @vfr_not_recommended = vfr_not_recommended
          @current_conditions = current_conditions
          @destination_forecast = destination_forecast
          @winds_aloft = winds_aloft
          @afd = afd
        end
        # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists

        # rubocop:disable Metrics/MethodLength
        def to_h
          {
            airport: airport,
            coordinates: coordinates,
            wfo: wfo,
            fetched_at: fetched_at&.iso8601,
            aim_section: AIM_SECTION,
            adverse_conditions: adverse_conditions,
            vfr_not_recommended: vfr_not_recommended,
            synopsis: SYNOPSIS_UNAVAILABLE,
            current_conditions: current_conditions,
            enroute_forecast: ENROUTE_UNAVAILABLE,
            destination_forecast: destination_forecast,
            winds_aloft: winds_aloft,
            notams: NOTAMS_UNAVAILABLE,
            atc_delays: ATC_DELAYS_UNAVAILABLE,
            afd: afd
          }
        end
        # rubocop:enable Metrics/MethodLength

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire it into `lib/skywatch.rb`**

In `lib/skywatch.rb`, immediately after the `require_relative 'skywatch/brief/analysis/adverse_filter'` line added in Task 3, add:

```ruby
require_relative 'skywatch/brief/models/brief'
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bundle exec rspec spec/brief/models/brief_spec.rb
```

Expected: all tests pass.

- [ ] **Step 6: Run rubocop**

```bash
bundle exec rubocop lib/skywatch/brief/ spec/brief/
```

Expected: no offenses.

- [ ] **Step 7: Commit**

```bash
git add lib/skywatch/brief/models/brief.rb lib/skywatch.rb spec/brief/models/brief_spec.rb
git commit -m "feat(brief): add Brief model with AIM 7-1-5 envelope"
```

---

## Task 5: Composer happy-path — wires every slot when fetches succeed

**Files:**
- Create: `spec/brief/analysis/composer_spec.rb`
- Create: `lib/skywatch/brief/analysis/composer.rb`

The composer takes an airport identifier, fetches METAR (hard-fail if missing), derives lat/lon and WFO, fetches everything else, and assembles a `Brief`. This task covers the happy path only — error wrapping is added in Task 6.

- [ ] **Step 1: Write the spec**

Save as `spec/brief/analysis/composer_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Brief::Analysis::Composer do
  let(:metar) do
    Skywatch::Briefer::Models::Metar.new(
      station_id: 'KCDW', latitude: 40.875, longitude: -74.282,
      visibility_sm: 10, sky_condition: [{ cover: :few, base_ft: 5000 }]
    )
  end

  let(:metar_source) { instance_double(Skywatch::Briefer::Sources::Metar, fetch: [metar]) }
  let(:taf_source) { instance_double(Skywatch::Briefer::Sources::Taf, fetch: []) }
  let(:pirep_source) { instance_double(Skywatch::Briefer::Sources::Pirep, fetch: []) }
  let(:winds_source) { instance_double(Skywatch::Briefer::Sources::WindsAloft, fetch: []) }
  let(:sigmet_source) { instance_double(Skywatch::Briefer::Sources::Sigmet, fetch: []) }
  let(:airmet_source) { instance_double(Skywatch::Briefer::Sources::Airmet, fetch: []) }
  let(:afd_model) do
    Skywatch::Briefer::Models::Afd.new(
      wfo: 'OKX', product_name: 'Area Forecast Discussion',
      issued_at: Time.utc(2026, 4, 27, 14), text: 'SYNOPSIS...'
    )
  end
  let(:afd_source) { instance_double(Skywatch::Briefer::Sources::Afd, fetch: afd_model) }
  let(:alerts_source) { instance_double(Skywatch::Nimbus::Sources::Alerts, fetch: []) }
  let(:storm_source) { instance_double(Skywatch::Nimbus::Sources::StormReport, fetch: []) }

  before do
    allow(Skywatch::Brief::Analysis::AirportLocator).to receive(:wfo_for).and_return('OKX')
  end

  let(:composer) do
    described_class.new(
      metar_source: metar_source, taf_source: taf_source, pirep_source: pirep_source,
      winds_source: winds_source, sigmet_source: sigmet_source, airmet_source: airmet_source,
      afd_source: afd_source, alerts_source: alerts_source, storm_source: storm_source
    )
  end

  it 'returns a Brief with metadata populated' do
    brief = composer.compose(airport: 'KCDW')
    expect(brief).to be_a(Skywatch::Brief::Models::Brief)
    expect(brief.airport).to eq('KCDW')
    expect(brief.coordinates).to eq([40.875, -74.282])
    expect(brief.wfo).to eq('OKX')
    expect(brief.fetched_at).to be_a(Time)
  end

  it 'sets adverse_conditions available with empty items when nothing is adverse' do
    expect(composer.compose(airport: 'KCDW').adverse_conditions).to eq(
      available: true, items: [], partial_failures: []
    )
  end

  it 'sets vfr_not_recommended from FlightCategory' do
    slot = composer.compose(airport: 'KCDW').vfr_not_recommended
    expect(slot[:available]).to be true
    expect(slot[:vfr_not_recommended]).to be false
    expect(slot[:category]).to eq('VFR')
    expect(slot[:explanation]).to include('VFR')
  end

  it 'sets current_conditions with metar and empty pireps' do
    slot = composer.compose(airport: 'KCDW').current_conditions
    expect(slot[:available]).to be true
    expect(slot[:metar][:station_id]).to eq('KCDW')
    expect(slot[:pireps]).to eq([])
  end

  it 'sets destination_forecast unavailable when no TAF' do
    slot = composer.compose(airport: 'KCDW').destination_forecast
    expect(slot[:available]).to be false
    expect(slot[:reason]).to include('no TAF')
  end

  it 'sets winds_aloft unavailable when no winds-aloft data' do
    slot = composer.compose(airport: 'KCDW').winds_aloft
    expect(slot[:available]).to be false
    expect(slot[:reason]).to include('no winds aloft')
  end

  it 'sets afd available when AFD fetch succeeds' do
    slot = composer.compose(airport: 'KCDW').afd
    expect(slot[:available]).to be true
    expect(slot[:wfo]).to eq('OKX')
    expect(slot[:text]).to eq('SYNOPSIS...')
  end

  it 'classifies LIFR as VFR not recommended' do
    metar_lifr = Skywatch::Briefer::Models::Metar.new(
      station_id: 'KCDW', latitude: 40.875, longitude: -74.282,
      visibility_sm: 0.5, sky_condition: [{ cover: :ovc, base_ft: 200 }]
    )
    allow(metar_source).to receive(:fetch).and_return([metar_lifr])
    slot = composer.compose(airport: 'KCDW').vfr_not_recommended
    expect(slot[:vfr_not_recommended]).to be true
    expect(slot[:category]).to eq('LIFR')
  end

  it 'raises when METAR is missing' do
    allow(metar_source).to receive(:fetch).and_return([])
    expect { composer.compose(airport: 'KZZZ') }
      .to raise_error(Skywatch::Error, /no METAR for KZZZ/)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/brief/analysis/composer_spec.rb
```

Expected: `uninitialized constant Skywatch::Brief::Analysis::Composer`.

- [ ] **Step 3: Write the implementation**

Save as `lib/skywatch/brief/analysis/composer.rb`:

```ruby
# frozen_string_literal: true

require 'time'

module Skywatch
  module Brief
    module Analysis
      class Composer # rubocop:disable Metrics/ClassLength
        ADVERSE_RADIUS_NM = 100
        STORM_REPORT_LOOKBACK_HOURS = 6

        # rubocop:disable Metrics/ParameterLists
        def initialize(metar_source: Skywatch::Briefer::Sources::Metar.new,
                       taf_source: Skywatch::Briefer::Sources::Taf.new,
                       pirep_source: Skywatch::Briefer::Sources::Pirep.new,
                       winds_source: Skywatch::Briefer::Sources::WindsAloft.new,
                       sigmet_source: Skywatch::Briefer::Sources::Sigmet.new,
                       airmet_source: Skywatch::Briefer::Sources::Airmet.new,
                       afd_source: Skywatch::Briefer::Sources::Afd.new,
                       alerts_source: Skywatch::Nimbus::Sources::Alerts.new,
                       storm_source: Skywatch::Nimbus::Sources::StormReport.new)
          @metar_source = metar_source
          @taf_source = taf_source
          @pirep_source = pirep_source
          @winds_source = winds_source
          @sigmet_source = sigmet_source
          @airmet_source = airmet_source
          @afd_source = afd_source
          @alerts_source = alerts_source
          @storm_source = storm_source
        end
        # rubocop:enable Metrics/ParameterLists

        def compose(airport:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          metar = fetch_metar_or_raise(airport)
          lat, lon = AirportLocator.coordinates_from_metar(metar)
          wfo = AirportLocator.wfo_for(lat, lon)

          pireps = @pirep_source.fetch(airport, radius_nm: ADVERSE_RADIUS_NM)
          partitioned = AdverseFilter.partition_pireps(pireps)

          Models::Brief.new(
            airport: airport.upcase,
            coordinates: [lat, lon],
            wfo: wfo,
            fetched_at: Time.now.utc,
            adverse_conditions: build_adverse(lat: lat, lon: lon, urgent_pireps: partitioned[:urgent]),
            vfr_not_recommended: build_vfr(metar),
            current_conditions: build_current(metar: metar, pireps: partitioned[:informational]),
            destination_forecast: build_destination(airport),
            winds_aloft: build_winds(airport),
            afd: build_afd(wfo)
          )
        end

        private

        def fetch_metar_or_raise(airport)
          metars = @metar_source.fetch(airport)
          raise Skywatch::Error, "no METAR for #{airport.upcase}" if metars.empty?

          metars.first
        end

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def build_adverse(lat:, lon:, urgent_pireps:)
          sigmets = @sigmet_source.fetch.select { |s| AdverseFilter.covers?(s, lat, lon) }
          airmets = @airmet_source.fetch.select { |a| AdverseFilter.covers?(a, lat, lon) }
          alerts = @alerts_source.fetch(at: [lat, lon])
          all_storms = @storm_source.fetch
          recent = recent_storms(all_storms)
          near_storms = AdverseFilter.within(recent, lat: lat, lon: lon, radius_nm: ADVERSE_RADIUS_NM)

          items = []
          sigmets.each { |s| items << { kind: 'sigmet' }.merge(s.to_h) }
          airmets.each { |a| items << { kind: 'airmet' }.merge(a.to_h) }
          urgent_pireps.each { |p| items << { kind: 'pirep' }.merge(p.to_h) }
          alerts.each { |a| items << { kind: 'convective_alert' }.merge(a.to_h) }
          near_storms.each { |s| items << { kind: 'storm_report' }.merge(s.to_h) }

          { available: true, items: items, partial_failures: [] }
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        def recent_storms(storms)
          cutoff = Time.now.utc - (STORM_REPORT_LOOKBACK_HOURS * 3600)
          storms.select { |s| s.time && s.time >= cutoff }
        end

        def build_vfr(metar) # rubocop:disable Metrics/MethodLength
          category = metar.flight_category
          case category
          when :lifr, :ifr
            { available: true, vfr_not_recommended: true, category: category.to_s.upcase,
              explanation: explanation_for(metar) }
          when :mvfr
            { available: true, vfr_not_recommended: false, category: 'MVFR',
              explanation: "marginal — #{explanation_for(metar)}" }
          else
            { available: true, vfr_not_recommended: false, category: 'VFR',
              explanation: 'VFR conditions' }
          end
        end

        def explanation_for(metar)
          parts = []
          parts << "ceiling #{metar.ceiling_ft} ft" if metar.ceiling_ft
          parts << "vis #{metar.visibility_sm} SM" if metar.visibility_sm
          parts.empty? ? 'see METAR' : parts.join(', ')
        end

        def build_current(metar:, pireps:)
          { available: true, metar: metar.to_h, pireps: pireps.map(&:to_h) }
        end

        def build_destination(airport)
          tafs = @taf_source.fetch(airport)
          if tafs.empty?
            { available: false, reason: "no TAF for #{airport.upcase}" }
          else
            { available: true, taf: tafs.first.to_h }
          end
        end

        def build_winds(airport)
          forecasts = @winds_source.fetch(airport)
          if forecasts.empty?
            { available: false, reason: "no winds aloft for #{airport.upcase}" }
          else
            { available: true, station: airport.upcase, forecasts: forecasts.map(&:to_h) }
          end
        end

        def build_afd(wfo)
          afd = @afd_source.fetch(wfo)
          { available: true, wfo: afd.wfo, text: afd.text, issued_at: afd.issued_at&.iso8601 }
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire it into `lib/skywatch.rb`**

In `lib/skywatch.rb`, immediately after the `require_relative 'skywatch/brief/models/brief'` line added in Task 4, add:

```ruby
require_relative 'skywatch/brief/analysis/composer'
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bundle exec rspec spec/brief/analysis/composer_spec.rb
```

Expected: all tests pass.

- [ ] **Step 6: Run rubocop**

```bash
bundle exec rubocop lib/skywatch/brief/ spec/brief/
```

Expected: no offenses.

- [ ] **Step 7: Commit**

```bash
git add lib/skywatch/brief/analysis/composer.rb lib/skywatch.rb spec/brief/analysis/composer_spec.rb
git commit -m "feat(brief): add Composer happy-path"
```

---

## Task 6: Composer error wrapping — per-slot try/rescue + adverse partial_failures

**Files:**
- Modify: `spec/brief/analysis/composer_spec.rb`
- Modify: `lib/skywatch/brief/analysis/composer.rb`

This task adds the per-slot resilience: any non-METAR fetch failure renders the slot as `{ available: false, reason: ... }`. For adverse_conditions, individual sub-source failures are recorded in `partial_failures` and the slot stays available unless every sub-source fails.

- [ ] **Step 1: Add the failing tests**

Append to `spec/brief/analysis/composer_spec.rb` (just before the final `end` that closes the `describe`):

```ruby
  context 'error wrapping' do
    it 'sets destination_forecast unavailable when TAF source raises' do
      allow(taf_source).to receive(:fetch).and_raise(Skywatch::ApiError, 'HTTP 500')
      slot = composer.compose(airport: 'KCDW').destination_forecast
      expect(slot[:available]).to be false
      expect(slot[:reason]).to include('fetch failed')
      expect(slot[:reason]).to include('HTTP 500')
    end

    it 'sets winds_aloft unavailable when winds source raises' do
      allow(winds_source).to receive(:fetch).and_raise(StandardError, 'boom')
      slot = composer.compose(airport: 'KCDW').winds_aloft
      expect(slot[:available]).to be false
      expect(slot[:reason]).to include('fetch failed')
    end

    it 'sets afd unavailable when WFO lookup raises' do
      allow(Skywatch::Brief::Analysis::AirportLocator)
        .to receive(:wfo_for).and_raise(Skywatch::Error, 'lookup boom')
      brief = composer.compose(airport: 'KCDW')
      expect(brief.afd[:available]).to be false
      expect(brief.afd[:reason]).to include('fetch failed')
      expect(brief.wfo).to be_nil
    end

    it 'sets afd unavailable when AFD fetch raises' do
      allow(afd_source).to receive(:fetch).and_raise(Skywatch::Error, 'no AFD')
      slot = composer.compose(airport: 'KCDW').afd
      expect(slot[:available]).to be false
      expect(slot[:reason]).to include('fetch failed')
    end

    it 'records partial_failures on adverse_conditions when one sub-source raises' do
      allow(sigmet_source).to receive(:fetch).and_raise(StandardError, 'sigmet boom')
      slot = composer.compose(airport: 'KCDW').adverse_conditions
      expect(slot[:available]).to be true
      expect(slot[:partial_failures]).to contain_exactly(
        hash_including(source: 'sigmet', reason: a_string_including('sigmet boom'))
      )
    end

    it 'sets adverse_conditions unavailable when every sub-source raises' do
      allow(sigmet_source).to receive(:fetch).and_raise(StandardError, 'a')
      allow(airmet_source).to receive(:fetch).and_raise(StandardError, 'b')
      allow(pirep_source).to receive(:fetch).and_raise(StandardError, 'c')
      allow(alerts_source).to receive(:fetch).and_raise(StandardError, 'd')
      allow(storm_source).to receive(:fetch).and_raise(StandardError, 'e')
      slot = composer.compose(airport: 'KCDW').adverse_conditions
      expect(slot[:available]).to be false
      expect(slot[:reason]).to include('all adverse sources failed')
    end

    it 'still raises hard when METAR fails (no wrapping)' do
      allow(metar_source).to receive(:fetch).and_raise(Skywatch::ApiError, 'HTTP 404')
      expect { composer.compose(airport: 'KZZZ') }.to raise_error(Skywatch::ApiError)
    end
  end
```

Note: the partial-failures test for adverse PIREPs is implicit — the pirep_source is shared between the current_conditions slot (informational PIREPs) and adverse (urgent PIREPs). When pirep_source raises, both slots degrade. We test this composite behavior in the integration spec (Task 9).

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/brief/analysis/composer_spec.rb -e "error wrapping"
```

Expected: failures around `slot[:available]` being true when it should be false.

- [ ] **Step 3: Refactor the composer with `wrap` and adverse aggregation**

Replace the contents of `lib/skywatch/brief/analysis/composer.rb` with:

```ruby
# frozen_string_literal: true

require 'time'

module Skywatch
  module Brief
    module Analysis
      class Composer # rubocop:disable Metrics/ClassLength
        ADVERSE_RADIUS_NM = 100
        STORM_REPORT_LOOKBACK_HOURS = 6

        # rubocop:disable Metrics/ParameterLists
        def initialize(metar_source: Skywatch::Briefer::Sources::Metar.new,
                       taf_source: Skywatch::Briefer::Sources::Taf.new,
                       pirep_source: Skywatch::Briefer::Sources::Pirep.new,
                       winds_source: Skywatch::Briefer::Sources::WindsAloft.new,
                       sigmet_source: Skywatch::Briefer::Sources::Sigmet.new,
                       airmet_source: Skywatch::Briefer::Sources::Airmet.new,
                       afd_source: Skywatch::Briefer::Sources::Afd.new,
                       alerts_source: Skywatch::Nimbus::Sources::Alerts.new,
                       storm_source: Skywatch::Nimbus::Sources::StormReport.new)
          @metar_source = metar_source
          @taf_source = taf_source
          @pirep_source = pirep_source
          @winds_source = winds_source
          @sigmet_source = sigmet_source
          @airmet_source = airmet_source
          @afd_source = afd_source
          @alerts_source = alerts_source
          @storm_source = storm_source
        end
        # rubocop:enable Metrics/ParameterLists

        def compose(airport:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          metar = fetch_metar_or_raise(airport)
          lat, lon = AirportLocator.coordinates_from_metar(metar)
          wfo = wrap_wfo(lat, lon)

          pirep_attempt = attempt { @pirep_source.fetch(airport, radius_nm: ADVERSE_RADIUS_NM) }
          partitioned = AdverseFilter.partition_pireps(pirep_attempt[:value] || [])

          Models::Brief.new(
            airport: airport.upcase,
            coordinates: [lat, lon],
            wfo: wfo,
            fetched_at: Time.now.utc,
            adverse_conditions: build_adverse(
              lat: lat, lon: lon, urgent_pireps: partitioned[:urgent], pirep_attempt: pirep_attempt
            ),
            vfr_not_recommended: build_vfr(metar),
            current_conditions: build_current(metar: metar, pirep_attempt: pirep_attempt,
                                              informational: partitioned[:informational]),
            destination_forecast: wrap('TAF') { build_destination(airport) },
            winds_aloft: wrap('winds aloft') { build_winds(airport) },
            afd: wfo.nil? ? unavailable_afd_for_no_wfo : wrap('AFD') { build_afd(wfo) }
          )
        end

        private

        def fetch_metar_or_raise(airport)
          metars = @metar_source.fetch(airport)
          raise Skywatch::Error, "no METAR for #{airport.upcase}" if metars.empty?

          metars.first
        end

        def wrap_wfo(lat, lon)
          AirportLocator.wfo_for(lat, lon)
        rescue StandardError
          nil
        end

        def unavailable_afd_for_no_wfo
          { available: false, reason: 'fetch failed: WFO lookup failed' }
        end

        def attempt
          { value: yield, error: nil }
        rescue StandardError => e
          { value: nil, error: "#{e.class}: #{e.message}" }
        end

        def wrap(_label)
          yield
        rescue StandardError => e
          { available: false, reason: "fetch failed: #{e.class}: #{e.message}" }
        end

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def build_adverse(lat:, lon:, urgent_pireps:, pirep_attempt:)
          sigmet_attempt = attempt { @sigmet_source.fetch.select { |s| AdverseFilter.covers?(s, lat, lon) } }
          airmet_attempt = attempt { @airmet_source.fetch.select { |a| AdverseFilter.covers?(a, lat, lon) } }
          alerts_attempt = attempt { @alerts_source.fetch(at: [lat, lon]) }
          storm_attempt = attempt do
            recent = recent_storms(@storm_source.fetch)
            AdverseFilter.within(recent, lat: lat, lon: lon, radius_nm: ADVERSE_RADIUS_NM)
          end

          attempts = {
            'sigmet' => sigmet_attempt, 'airmet' => airmet_attempt,
            'pirep' => pirep_attempt, 'convective_alert' => alerts_attempt,
            'storm_report' => storm_attempt
          }
          partial_failures = attempts.reject { |_, a| a[:error].nil? }
                                     .map { |s, a| { source: s, reason: a[:error] } }

          if partial_failures.size == attempts.size
            return { available: false,
                     reason: "all adverse sources failed: #{partial_failures.map { |f| f[:source] }.join(', ')}" }
          end

          items = []
          (sigmet_attempt[:value] || []).each { |s| items << { kind: 'sigmet' }.merge(s.to_h) }
          (airmet_attempt[:value] || []).each { |a| items << { kind: 'airmet' }.merge(a.to_h) }
          urgent_pireps.each { |p| items << { kind: 'pirep' }.merge(p.to_h) }
          (alerts_attempt[:value] || []).each { |a| items << { kind: 'convective_alert' }.merge(a.to_h) }
          (storm_attempt[:value] || []).each { |s| items << { kind: 'storm_report' }.merge(s.to_h) }

          { available: true, items: items, partial_failures: partial_failures }
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def recent_storms(storms)
          cutoff = Time.now.utc - (STORM_REPORT_LOOKBACK_HOURS * 3600)
          storms.select { |s| s.time && s.time >= cutoff }
        end

        def build_vfr(metar) # rubocop:disable Metrics/MethodLength
          case metar.flight_category
          when :lifr, :ifr
            { available: true, vfr_not_recommended: true,
              category: metar.flight_category.to_s.upcase, explanation: explanation_for(metar) }
          when :mvfr
            { available: true, vfr_not_recommended: false,
              category: 'MVFR', explanation: "marginal — #{explanation_for(metar)}" }
          else
            { available: true, vfr_not_recommended: false,
              category: 'VFR', explanation: 'VFR conditions' }
          end
        end

        def explanation_for(metar)
          parts = []
          parts << "ceiling #{metar.ceiling_ft} ft" if metar.ceiling_ft
          parts << "vis #{metar.visibility_sm} SM" if metar.visibility_sm
          parts.empty? ? 'see METAR' : parts.join(', ')
        end

        def build_current(metar:, pirep_attempt:, informational:)
          if pirep_attempt[:error]
            { available: true, metar: metar.to_h, pireps: [],
              partial_failure: { source: 'pirep', reason: pirep_attempt[:error] } }
          else
            { available: true, metar: metar.to_h, pireps: informational.map(&:to_h) }
          end
        end

        def build_destination(airport)
          tafs = @taf_source.fetch(airport)
          if tafs.empty?
            { available: false, reason: "no TAF for #{airport.upcase}" }
          else
            { available: true, taf: tafs.first.to_h }
          end
        end

        def build_winds(airport)
          forecasts = @winds_source.fetch(airport)
          if forecasts.empty?
            { available: false, reason: "no winds aloft for #{airport.upcase}" }
          else
            { available: true, station: airport.upcase, forecasts: forecasts.map(&:to_h) }
          end
        end

        def build_afd(wfo)
          afd = @afd_source.fetch(wfo)
          { available: true, wfo: afd.wfo, text: afd.text, issued_at: afd.issued_at&.iso8601 }
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/brief/analysis/composer_spec.rb
```

Expected: all tests pass (both happy-path and error-wrapping contexts).

- [ ] **Step 5: Run rubocop**

```bash
bundle exec rubocop lib/skywatch/brief/ spec/brief/
```

Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/brief/analysis/composer.rb spec/brief/analysis/composer_spec.rb
git commit -m "feat(brief): wrap composer slots with per-slot error handling"
```

---

## Task 7: `Skywatch.brief` convenience API

**Files:**
- Modify: `spec/brief_spec.rb` (creates the file)
- Modify: `lib/skywatch.rb`

The top-level convenience API adds `Skywatch.brief(airport:)` returning a `Skywatch::Brief::Models::Brief`.

- [ ] **Step 1: Write the spec**

Save as `spec/brief_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch, '.brief' do
  it 'composes a Brief for an airport' do
    composer = instance_double(Skywatch::Brief::Analysis::Composer)
    brief = instance_double(Skywatch::Brief::Models::Brief)
    expect(Skywatch::Brief::Analysis::Composer).to receive(:new).and_return(composer)
    expect(composer).to receive(:compose).with(airport: 'KCDW').and_return(brief)

    expect(described_class.brief(airport: 'KCDW')).to be(brief)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/brief_spec.rb
```

Expected: `NoMethodError: undefined method 'brief' for Skywatch:Module`.

- [ ] **Step 3: Add the convenience method**

In `lib/skywatch.rb`, find the existing method definitions (e.g. `def crosswind`). Add this method just before the `def crosswind` block, inside the `class << self` block:

```ruby
def brief(airport:)
  Brief::Analysis::Composer.new.compose(airport: airport)
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/brief_spec.rb
```

Expected: pass.

- [ ] **Step 5: Run rubocop**

```bash
bundle exec rubocop lib/skywatch.rb spec/brief_spec.rb
```

Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch.rb spec/brief_spec.rb
git commit -m "feat(brief): add Skywatch.brief convenience API"
```

---

## Task 8: CLI — `skywatch brief AIRPORT`

**Files:**
- Create: `spec/brief/cli_spec.rb`
- Modify: `lib/skywatch/cli.rb`

The CLI is a single direct command at the top level (not a subcommand class), since brief takes one argument and has no sub-actions. JSON-only output for MVP — text formatter is deferred per spec.

- [ ] **Step 1: Write the spec**

Save as `spec/brief/cli_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'skywatch brief CLI' do
  let(:brief) do
    instance_double(
      Skywatch::Brief::Models::Brief,
      to_h: { airport: 'KCDW', aim_section: '7-1-5' }
    )
  end

  before { allow(Skywatch).to receive(:brief).with(airport: 'KCDW').and_return(brief) }

  it 'prints the brief as JSON' do
    output = capture_stdout { Skywatch::CLI.start(%w[brief KCDW]) }
    parsed = JSON.parse(output)
    expect(parsed['airport']).to eq('KCDW')
    expect(parsed['aim_section']).to eq('7-1-5')
  end

  it 'exits non-zero on Skywatch::Error' do
    allow(Skywatch).to receive(:brief).and_raise(Skywatch::Error, 'no METAR for KZZZ')
    expect { Skywatch::CLI.start(%w[brief KZZZ]) }.to raise_error(SystemExit) do |e|
      expect(e.status).not_to eq(0)
    end
  end

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/brief/cli_spec.rb
```

Expected: `Could not find command "brief"`.

- [ ] **Step 3: Add `brief` to the top-level CLI**

Edit `lib/skywatch/cli.rb`. Add the `brief` command before the `desc 'version', 'Print version'` line:

```ruby
    desc 'brief AIRPORT', 'AIM 7-1-5 weather brief composed for AIRPORT'
    def brief(airport)
      result = Skywatch.brief(airport: airport)
      puts JSON.pretty_generate(result.to_h)
    rescue Skywatch::Error => e
      warn "Error: #{e.message}"
      exit 1
    end
```

Then add `require 'json'` at the top of the file (just below `require 'thor'`).

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/brief/cli_spec.rb
```

Expected: pass.

- [ ] **Step 5: Run rubocop**

```bash
bundle exec rubocop lib/skywatch/cli.rb spec/brief/cli_spec.rb
```

Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/cli.rb spec/brief/cli_spec.rb
git commit -m "feat(brief): add 'skywatch brief AIRPORT' CLI command"
```

---

## Task 9: Integration spec — full envelope shape

**Files:**
- Create: `spec/brief/integration_spec.rb`

This is the load-bearing acceptance test: stub every source, call `Skywatch.brief(airport: "KCDW")`, and assert the full JSON envelope matches a frozen expectation. Catches shape regressions cheaply.

- [ ] **Step 1: Write the spec**

Save as `spec/brief/integration_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Skywatch.brief integration' do
  let(:metar) do
    Skywatch::Briefer::Models::Metar.new(
      raw: 'KCDW 271800Z 27008KT 10SM FEW050 22/15 A3001',
      station_id: 'KCDW',
      observed_at: Time.utc(2026, 4, 27, 18),
      latitude: 40.875,
      longitude: -74.282,
      visibility_sm: 10,
      sky_condition: [{ cover: :few, base_ft: 5000 }],
      temperature_c: 22, dewpoint_c: 15
    )
  end
  let(:afd) do
    Skywatch::Briefer::Models::Afd.new(
      wfo: 'OKX', product_name: 'Area Forecast Discussion',
      issued_at: Time.utc(2026, 4, 27, 14),
      text: 'SYNOPSIS...High pressure builds in.'
    )
  end

  before do
    allow_any_instance_of(Skywatch::Briefer::Sources::Metar).to receive(:fetch).and_return([metar])
    allow_any_instance_of(Skywatch::Briefer::Sources::Taf).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::Pirep).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::WindsAloft).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::Sigmet).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::Airmet).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::Afd).to receive(:fetch).and_return(afd)
    allow_any_instance_of(Skywatch::Nimbus::Sources::Alerts).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Nimbus::Sources::StormReport).to receive(:fetch).and_return([])
    allow(Skywatch::Brief::Analysis::AirportLocator).to receive(:wfo_for).and_return('OKX')
  end

  it 'produces an AIM-9-aligned envelope' do
    hash = Skywatch.brief(airport: 'KCDW').to_h

    expect(hash[:airport]).to eq('KCDW')
    expect(hash[:coordinates]).to eq([40.875, -74.282])
    expect(hash[:wfo]).to eq('OKX')
    expect(hash[:aim_section]).to eq('7-1-5')

    aim9 = %i[adverse_conditions vfr_not_recommended synopsis current_conditions
              enroute_forecast destination_forecast winds_aloft notams atc_delays]
    aim9.each do |slot|
      expect(hash[slot]).to include(:available), "slot #{slot} missing :available"
    end

    # Six slots fillable in MVP: 2 truly populated here, 2 gracefully unavailable
    # (TAF / winds), 4 statically unavailable, plus AFD supplementary.
    expect(hash[:adverse_conditions][:available]).to be true
    expect(hash[:adverse_conditions][:items]).to eq([])
    expect(hash[:adverse_conditions][:partial_failures]).to eq([])

    expect(hash[:vfr_not_recommended][:available]).to be true
    expect(hash[:vfr_not_recommended][:vfr_not_recommended]).to be false
    expect(hash[:vfr_not_recommended][:category]).to eq('VFR')

    expect(hash[:current_conditions][:available]).to be true
    expect(hash[:current_conditions][:metar][:station_id]).to eq('KCDW')

    expect(hash[:destination_forecast][:available]).to be false
    expect(hash[:winds_aloft][:available]).to be false

    expect(hash[:synopsis]).to eq(Skywatch::Brief::Models::Brief::SYNOPSIS_UNAVAILABLE)
    expect(hash[:enroute_forecast]).to eq(Skywatch::Brief::Models::Brief::ENROUTE_UNAVAILABLE)
    expect(hash[:notams]).to eq(Skywatch::Brief::Models::Brief::NOTAMS_UNAVAILABLE)
    expect(hash[:atc_delays]).to eq(Skywatch::Brief::Models::Brief::ATC_DELAYS_UNAVAILABLE)

    expect(hash[:afd][:available]).to be true
    expect(hash[:afd][:wfo]).to eq('OKX')
    expect(hash[:afd][:text]).to include('SYNOPSIS')
  end

  it 'serializes round-trip through JSON without raising' do
    json = Skywatch.brief(airport: 'KCDW').to_json
    parsed = JSON.parse(json)
    expect(parsed['aim_section']).to eq('7-1-5')
  end
end
```

- [ ] **Step 2: Run test to verify it passes (the entire stack should already be in place)**

```bash
bundle exec rspec spec/brief/integration_spec.rb
```

Expected: pass.

- [ ] **Step 3: Run the full suite**

```bash
bundle exec rspec
```

Expected: all examples pass (371 baseline + new tests).

- [ ] **Step 4: Run rubocop**

```bash
bundle exec rubocop
```

Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add spec/brief/integration_spec.rb
git commit -m "test(brief): add integration spec snapshotting full envelope shape"
```

---

## Task 10: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add the brief command to the CLI usage block**

Open `CLAUDE.md`. Find the `## CLI Usage` block. Just before the `skywatch radar track UAL1234` line, insert:

```
skywatch brief KCDW
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document 'skywatch brief AIRPORT' command"
```

---

## Task 11: File follow-up GitHub issues

**Files:** none modified — uses `gh`.

The spec defers six items to follow-up issues. File them now (after spec is locked, before implementation merges) so the slot reasons in the brief envelope can be referenced from the issue tracker if anyone asks.

- [ ] **Step 1: Confirm `gh` auth works**

```bash
gh auth status
```

Expected: "Logged in to github.com as ..."

- [ ] **Step 2: File the route-input issue**

```bash
gh issue create --repo jayrav13/skywatch \
  --title "Skywatch.brief: support route input (from:/to:)" \
  --body "$(cat <<'EOF'
Deferred from the Skywatch.brief MVP design (see [`docs/superpowers/specs/2026-04-27-skywatch-brief-design.md`](docs/superpowers/specs/2026-04-27-skywatch-brief-design.md)).

The MVP takes a single airport. Real 1-800-WX-BRIEF calls take a route (departure → destination). This issue covers extending Skywatch.brief to accept `from:` / `to:` (or an n-airport list), populating the currently-static `enroute_forecast` slot with TAFs / PIREPs / area products along the corridor.

**Acceptance:** `Skywatch.brief(from: "KCDW", to: "KACK")` returns a Brief whose `enroute_forecast` slot is `available: true` with corridor data.
EOF
)"
```

- [ ] **Step 3: File the coordinate-input issue**

```bash
gh issue create --repo jayrav13/skywatch \
  --title "Skywatch.brief: support coordinate input (at: [lat, lon])" \
  --body "$(cat <<'EOF'
Deferred from the Skywatch.brief MVP design.

The MVP takes only `airport:`. For non-airport points, a pilot would want `Skywatch.brief(at: [lat, lon])`. Implementation needs a nearest-METAR / nearest-TAF lookup (we have METAR coords, but no station-search index yet), and must decide what to do when the nearest station is far enough away that its METAR isn't representative.

**Acceptance:** `Skywatch.brief(at: [40.688, -74.174])` returns a Brief whose data slots are populated from the nearest reporting stations, with explicit notes when those stations are >25 nm from the requested point.
EOF
)"
```

- [ ] **Step 4: File the ETD-aware issue**

```bash
gh issue create --repo jayrav13/skywatch \
  --title "Skywatch.brief: support ETD (departing_at:)" \
  --body "$(cat <<'EOF'
Deferred from the Skywatch.brief MVP design.

The MVP returns a "now" snapshot. A real brief is for a specific departure window. This issue covers `Skywatch.brief(airport:, departing_at: Time.parse(...))`, which forces decisions about TAF group selection (which FROM/BECMG/TEMPO is active at ETD?), winds-aloft interpolation between forecast hours, and how AIM 7-1-5's "destination forecast within one hour before/after ETA" rule should be honored.

**Acceptance:** `Skywatch.brief(airport: "KCDW", departing_at: 2.hours.from_now)` returns a Brief whose `destination_forecast` slot reflects the TAF group active at ETD, and `winds_aloft` reflects the forecast hour closest to ETD.
EOF
)"
```

- [ ] **Step 5: File the AFD synopsis-extraction issue**

```bash
gh issue create --repo jayrav13/skywatch \
  --title "Skywatch.brief: extract a real synopsis from AFD text" \
  --body "$(cat <<'EOF'
Deferred from the Skywatch.brief MVP design.

The MVP hardcodes `synopsis: { available: false, reason: "no synopsis source — see afd slot" }` and exposes the full AFD text as a supplementary slot. AFDs *sometimes* have a labeled "SYNOPSIS..." sub-paragraph; this issue covers parsing it out and populating the `synopsis` slot with structured `{ available: true, text: ... }`.

The risk is brittle parsing — AFD formatting varies by WFO and over time. Investigate before committing to a parser.

**Acceptance:** When AFD text contains a clearly-marked SYNOPSIS section, `Skywatch.brief(...).synopsis` is `{ available: true, text: ... }`. When the AFD is unparseable, the slot stays `available: false` with a reason explaining why.
EOF
)"
```

- [ ] **Step 6: File the text-formatter issue**

```bash
gh issue create --repo jayrav13/skywatch \
  --title "Skywatch.brief: human text formatter (--format text)" \
  --body "$(cat <<'EOF'
Deferred from the Skywatch.brief MVP design.

The MVP is JSON-only. Once validation confirms the LLM-briefer thesis, add a human-readable text formatter consumable in a terminal — likely briefer-cadence one-liners per AIM 7-1-5 element, similar to the existing `Nimbus::Formatters::Text.format_convection` style.

**Acceptance:** `skywatch brief KCDW --format text` prints a human-readable brief that follows the AIM 7-1-5 sequence and uses briefer-cadence phrasing.
EOF
)"
```

- [ ] **Step 7: File the parallelization issue**

```bash
gh issue create --repo jayrav13/skywatch \
  --title "Skywatch.brief: parallelize composer fetches if latency exceeds 5s" \
  --body "$(cat <<'EOF'
Deferred from the Skywatch.brief MVP design.

The MVP composer fetches sequentially — METAR → WFO lookup → 8 independent fetches. If real-world brief latency exceeds ~5s, parallelize the 8 independent fetches with Ruby threads + Faraday. Ruby threading + IO is well-behaved here; the gating concern is keeping the cache layer thread-safe (it already uses a Mutex internally).

**Acceptance:** `Skywatch.brief("KCDW")` p95 stays under 3s on a typical network. No correctness changes — same envelope shape, same error handling.
EOF
)"
```

- [ ] **Step 8: List the filed issues to confirm**

```bash
gh issue list --repo jayrav13/skywatch --search "Skywatch.brief in:title" --state open
```

Expected: 6 issues listed.

(No commit for this task — issues are external to the repo.)

---

## Task 12: Capture validation report + open PR

**Files:**
- Create: `docs/superpowers/specs/2026-04-27-skywatch-brief-validation-results.md`

This is the validation deliverable. Capture three real briefs, run the canonical 7-question protocol against each via Claude (paste-into-claude.ai is acceptable for MVP — automation is a deferred enhancement), and commit the results.

- [ ] **Step 1: Capture three briefs**

Pick three airports based on real conditions at validation time. Save each brief to a tempfile:

```bash
exe/skywatch brief KCDW > /tmp/brief_kcdw.json
# Example IFR airport — pick from current METARs at validation time:
exe/skywatch brief KSFO > /tmp/brief_ksfo.json
# Example active-convective airport — pick from current SPC convective outlook:
exe/skywatch brief KICT > /tmp/brief_kict.json
```

If KSFO/KICT are not actually IFR / under convective alerts at the time of validation, substitute airports that are. The point is hitting the three scenario types (VFR-clear, IFR, active convection).

Inspect each:

```bash
jq '.adverse_conditions.items | length, .vfr_not_recommended.category' /tmp/brief_*.json
```

- [ ] **Step 2: Run the canonical 7-question protocol against each brief**

For each captured brief, paste the JSON into a fresh Claude.ai conversation with the following prompt template:

```
Below is a JSON-shaped pre-flight weather brief for [AIRPORT]. It is shaped after FAA AIM 7-1-5 (Standard Preflight Briefing). Treat it as the only data source you have access to.

[paste JSON]

Please answer these 7 questions:
1. Is VFR flight recommended for this airport right now?
2. What's the synopsis / weather pattern in the area?
3. What are the current conditions on the field?
4. What's the destination/terminal forecast?
5. What are the winds and temperature at 6000 ft?
6. What adverse conditions should I worry about?
7. What's NOT in this brief that I'd need to get from elsewhere before I fly?
```

Save Claude's responses to `/tmp/brief_kcdw_responses.md`, `/tmp/brief_ksfo_responses.md`, `/tmp/brief_kict_responses.md`.

- [ ] **Step 3: Write the validation report**

Save as `docs/superpowers/specs/2026-04-27-skywatch-brief-validation-results.md`:

```markdown
# Skywatch.brief — validation results

**Date:** 2026-04-27
**Spec:** [`2026-04-27-skywatch-brief-design.md`](2026-04-27-skywatch-brief-design.md)

## Protocol

Three airport scenarios. For each, the captured `skywatch brief AIRPORT` JSON was pasted into a fresh Claude.ai conversation along with the canonical 7-question prompt. Pilot-grade judgment of substantive correctness on Q1–Q6; explicit anti-hallucination check on Q7 (LLM must identify NOTAMs and ATC delays as not-in-brief).

**Pass criteria:**
- Q1–Q6 substantively correct on at least 2 of 3 scenarios
- Q7 anti-hallucination clean on **all 3 scenarios**

## Scenario 1: KCDW — VFR-clear

**Captured at:** [TIMESTAMP from /tmp/brief_kcdw.json fetched_at]
**Conditions summary:** [one line — what was the weather]

### Brief JSON

```json
[paste contents of /tmp/brief_kcdw.json — the full envelope]
```

### LLM responses

[paste contents of /tmp/brief_kcdw_responses.md]

### Judgment

| Q | Pass / fail | Notes |
|---|---|---|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |
| 6 | | |
| 7 | | |

## Scenario 2: [IFR airport] — IFR

[same structure as scenario 1]

## Scenario 3: [convective airport] — active convection

[same structure as scenario 1]

## Verdict

**Pass / fail:** [verdict]

**Q1–Q6 substantive correctness:** [N of 3 scenarios passed]
**Q7 anti-hallucination:** [N of 3 scenarios clean]

**Discussion:** [a few sentences. What worked, what didn't, what surprised us. If pass: which expansion direction is most justified next? If fail: was it data-shape or data-quality, and what's the right re-rank?]
```

Fill in the bracketed sections with real data from steps 1–2.

- [ ] **Step 4: Run final pre-PR checks**

```bash
bundle exec rspec
bundle exec rubocop
```

Expected: both clean.

- [ ] **Step 5: Commit the validation report**

```bash
git add docs/superpowers/specs/2026-04-27-skywatch-brief-validation-results.md
git commit -m "docs(brief): capture validation results — 7-question protocol on 3 scenarios"
```

- [ ] **Step 6: Push the branch and open the PR**

```bash
git push -u origin skywatch-brief
gh pr create --repo jayrav13/skywatch \
  --title "feat: Skywatch.brief — AIM 7-1-5 weather brief composition layer" \
  --body "$(cat <<'EOF'
## Summary

- Adds `Skywatch.brief(airport:)` and `skywatch brief AIRPORT` — a single composition layer over existing Briefer + Nimbus primitives that produces an AIM 7-1-5-shaped weather brief for a single airport.
- Six slots fillable in MVP, four hardcoded-unavailable (synopsis, en route, NOTAMs, ATC delays — explicit per the spec), one supplementary (AFD).
- METAR is the only hard-fail; every other source degrades to `{ available: false, reason: ... }`. Adverse-conditions slot tracks per-source `partial_failures`.
- Bundled validation report against the canonical 7-question protocol (3 scenarios, paste-into-Claude). Verdict in `docs/superpowers/specs/2026-04-27-skywatch-brief-validation-results.md`.

Spec: [`docs/superpowers/specs/2026-04-27-skywatch-brief-design.md`](docs/superpowers/specs/2026-04-27-skywatch-brief-design.md).

## Test plan

- [ ] `bundle exec rspec` — all green
- [ ] `bundle exec rubocop` — clean
- [ ] `exe/skywatch brief KCDW` — JSON to stdout
- [ ] `exe/skywatch brief KZZZ` — error to stderr, non-zero exit
- [ ] Validation report committed and shows pass/fail verdict
- [ ] All 6 follow-up issues filed and linked from the spec doc

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed.

- [ ] **Step 7: Confirm CI passes**

Watch the PR's checks. Once green, the implementation is done.

---

## Self-Review

Run after the plan is fully written.

**1. Spec coverage:**
- [x] Goal & validation thesis — Task 12 captures the validation report
- [x] Scope (in for MVP) — Tasks 4 (envelope), 5+6 (composer), 7 (top-level API), 8 (CLI), 12 (validation report)
- [x] Out of scope (deferred) — Task 11 files the 6 follow-up issues
- [x] AIM 7-1-5 anchor — Task 4 hardcodes `aim_section: '7-1-5'`
- [x] Architecture (composition only, no new sources) — Tasks 2–6 use only existing sources
- [x] Two infra additions (lat/lon from METAR, WFO from /points) — Task 2
- [x] File layout — matches Tasks 2–8 exactly
- [x] Top-level shape with 9 AIM slots + supplementary AFD — Task 4
- [x] Uniform `{ available: bool, ... }` contract — Task 4 spec line and Task 6 wrap helper
- [x] Slot specifications (each slot's success/failure shape) — Tasks 4–6 cover all
- [x] Composition logic (METAR-hard-fail, WFO lookup, sequential fetches) — Task 5/6
- [x] Locators and filters table — Tasks 2 (locator), 3 (filter)
- [x] VFR-not-recommended rule — Task 5 `build_vfr`
- [x] Per-slot error wrapping — Task 6 `wrap` and `attempt`
- [x] Caching — Task 2 wraps the `/points` client in `Shared::Cache` with WFO_TTL = 1 day
- [x] CLI shape — Task 8 (no `--format text` for MVP, JSON only)
- [x] Error handling table (hard-fail METAR, partial_failures on adverse) — Tasks 5, 6
- [x] Three-layer testing strategy — unit (Tasks 2–6), integration (Task 9), validation report (Task 12)
- [x] Three scenarios + 7-question protocol + acceptance criteria — Task 12
- [x] Follow-up issues — Task 11 files all 6

**2. Placeholder scan:** No "TBD" / "TODO" / "implement later" in any code or test block. Bracketed `[TIMESTAMP]` / `[IFR airport]` placeholders in the validation report template are intentional — they get filled with real data at Task 12, by definition.

**3. Type consistency:**
- `AirportLocator.coordinates_from_metar(metar) → [lat, lon]` — used in Task 5 step 3 ✓
- `AirportLocator.wfo_for(lat, lon) → "OKX"` — used in Task 5/6 ✓
- `AdverseFilter.covers?(product, lat, lon) → bool` — used in Task 5/6 `build_adverse` ✓
- `AdverseFilter.within(items, lat:, lon:, radius_nm:) → array` — used in Task 5/6 `build_adverse` ✓
- `AdverseFilter.partition_pireps(pireps) → { urgent:, informational: }` — used in Task 5/6 `compose` ✓
- `Composer.new(metar_source:, taf_source:, ..., storm_source:)` — same kwargs in Task 5 spec, Task 5 impl, Task 6 impl ✓
- `Composer#compose(airport:) → Brief` — same signature throughout ✓
- `Brief.new(airport:, coordinates:, wfo:, fetched_at:, adverse_conditions:, vfr_not_recommended:, current_conditions:, destination_forecast:, winds_aloft:, afd:)` — Task 4 impl matches Task 5/6 callers ✓
- `Brief#to_h` includes the 9 AIM slots + `afd` + envelope metadata — Task 4 impl matches integration spec assertions in Task 9 ✓
- Constants: `SYNOPSIS_UNAVAILABLE`, `ENROUTE_UNAVAILABLE`, `NOTAMS_UNAVAILABLE`, `ATC_DELAYS_UNAVAILABLE` — defined Task 4, asserted Task 9 ✓

All checks pass.
