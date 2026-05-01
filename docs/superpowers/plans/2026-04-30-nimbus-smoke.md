# Nimbus PR 3 — smoke plumes (HMS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `Skywatch::Nimbus::Sources::Smoke`, `Skywatch::Nimbus::Models::Smoke`, `Skywatch.smoke(at:)`, and `skywatch nimbus smoke LAT LON` — pulling NOAA HMS smoke plume polygons from the ArcGIS feature service, classifying by Light/Medium/Heavy density, and integrating as the 6th adverse-conditions source in `Skywatch.brief`.

**Architecture:** One source + one model in the `Skywatch::Nimbus` namespace, mirroring the `Outlook` and `Alerts` patterns exactly. Source uses an ArcGIS REST `query` endpoint that does server-side polygon-intersect, so no client-side filtering. Model is density-classified with the same `raw / level / score / description` quartet as `Outlook`. CLI subcommand follows the `convection` shape. Brief composer gets a 6th `attempt` in `build_adverse`.

**Tech Stack:** Ruby gem · Thor (CLI) · Faraday + faraday-retry (HTTP) · `Shared::Http`/`Shared::Cache` (existing) · WebMock (test stubs) · RSpec · RGeo + rgeo-geojson (geometry).

**Reference:** Spec at `docs/superpowers/specs/2026-04-30-nimbus-smoke-design.md`. Read it once before starting. The branch `nimbus-smoke` already exists with the spec commit (`34685a2`).

---

## File Structure

**Create:**

| Path | Responsibility |
|---|---|
| `lib/skywatch/nimbus/models/smoke.rb` | Density-classified plume model with `from_arcgis_feature`, `parse_julian`, `parse_arcgis_polygon`, density accessors, `to_h` |
| `lib/skywatch/nimbus/sources/smoke.rb` | ArcGIS `query` endpoint client; point-intersect via `geometryType=esriGeometryPoint` |
| `spec/nimbus/models/smoke_spec.rb` | Model parsing, density accessors, `to_h` shape |
| `spec/nimbus/sources/smoke_spec.rb` | WebMock'd source: heavy-smoke fixture, empty fixture, API-error fixture |
| `spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json` | One Heavy GOES-EAST plume covering KMRY (36.587, -121.843) — used by source + integration specs |
| `spec/fixtures/hms_smoke/empty.json` | `{"features": []}` — used by source + CLI specs |

**Modify:**

| Path | Change |
|---|---|
| `lib/skywatch.rb` | Two new `require_relative` lines + `Skywatch.smoke(at:)` convenience method |
| `lib/skywatch/nimbus/cli.rb` | Add `smoke LAT LON` subcommand + `print_smoke` helper |
| `lib/skywatch/nimbus/formatters/text.rb` | Add `format_smoke` |
| `spec/nimbus/cli_spec.rb` | Add `describe 'smoke command'` block (3+ examples) |
| `spec/nimbus/formatters/text_spec.rb` | Add `describe '.format_smoke'` block |
| `lib/skywatch/brief/analysis/composer.rb` | Add `smoke_source:` keyword + 6th `attempt` in `build_adverse` |
| `spec/brief/analysis/composer_spec.rb` | Add `smoke_source` instance_double + happy/failure-path examples |
| `spec/brief/integration_spec.rb` | Stub `Nimbus::Sources::Smoke` (mirrors existing stubs) |
| `.claude/settings.local.json` | Already has `services2.arcgis.com` in `permissions.allow` ✓ — verify only |
| `CLAUDE.md` | Add `skywatch nimbus smoke 40.688 -74.174` to CLI usage block |

**Validation deliverable (filled at Task 9, not implementation):**

Captured live `exe/skywatch nimbus smoke <lat> <lon>` output for at least one reasonable point — embed in the PR body, not a separate spec doc. (HMS smoke is rare in late April / early May; if the live call returns no plumes, the no-smoke case is the validation evidence and the PR body documents that.)

---

## Pre-flight

Before Task 1, the implementer should:

1. `cd /Users/jravaliya/Code/skywatch`
2. Confirm we're on the right branch:
   ```bash
   git rev-parse --abbrev-ref HEAD
   # expected: nimbus-smoke
   ```
3. Confirm baseline:
   ```bash
   bundle exec rspec 2>&1 | tail -1
   # expected: 414 examples, 0 failures
   bundle exec rubocop 2>&1 | tail -1
   # expected: no offenses detected
   ```
4. Read `docs/superpowers/specs/2026-04-30-nimbus-smoke-design.md` end-to-end before touching code.
5. Each task ends with `git add <files> && git commit`. Do not push between tasks; Task 9 pushes the branch and opens the PR.

---

## Task 1: Capture HMS smoke ArcGIS fixtures

**Files:**
- Create: `spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json`
- Create: `spec/fixtures/hms_smoke/empty.json`

The source + integration specs need one canonical "heavy plume covering KMRY" fixture and one canonical "no smoke" fixture. KMRY (Monterey, CA, 36.587, -121.843) is a fire-prone Pacific coast field — a realistic smoke scenario. Coordinates and polygon geometry are synthetic but shaped like a real ArcGIS response.

- [ ] **Step 1: Make the fixture directory**

```bash
mkdir -p spec/fixtures/hms_smoke
```

- [ ] **Step 2: Write the heavy-smoke fixture**

Save as `spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json`:

```json
{
  "objectIdFieldName": "FID",
  "globalIdFieldName": "",
  "geometryType": "esriGeometryPolygon",
  "spatialReference": { "wkid": 4326, "latestWkid": 4326 },
  "fields": [
    { "name": "FID",       "type": "esriFieldTypeOID",     "alias": "FID" },
    { "name": "Satellite", "type": "esriFieldTypeString",  "alias": "Satellite" },
    { "name": "Start",     "type": "esriFieldTypeString",  "alias": "Start" },
    { "name": "End_",      "type": "esriFieldTypeString",  "alias": "End_" },
    { "name": "Density",   "type": "esriFieldTypeString",  "alias": "Density" }
  ],
  "features": [
    {
      "attributes": {
        "FID": 12345,
        "Satellite": "GOES-EAST",
        "Start": "2026120 1200",
        "End_": "2026120 1800",
        "Density": "Heavy"
      },
      "geometry": {
        "rings": [[
          [-122.5, 36.0],
          [-121.0, 36.0],
          [-121.0, 37.5],
          [-122.5, 37.5],
          [-122.5, 36.0]
        ]]
      }
    }
  ]
}
```

- [ ] **Step 3: Write the empty fixture**

Save as `spec/fixtures/hms_smoke/empty.json`:

```json
{
  "objectIdFieldName": "FID",
  "globalIdFieldName": "",
  "geometryType": "esriGeometryPolygon",
  "spatialReference": { "wkid": 4326, "latestWkid": 4326 },
  "fields": [
    { "name": "FID",       "type": "esriFieldTypeOID",     "alias": "FID" },
    { "name": "Satellite", "type": "esriFieldTypeString",  "alias": "Satellite" },
    { "name": "Start",     "type": "esriFieldTypeString",  "alias": "Start" },
    { "name": "End_",      "type": "esriFieldTypeString",  "alias": "End_" },
    { "name": "Density",   "type": "esriFieldTypeString",  "alias": "Density" }
  ],
  "features": []
}
```

- [ ] **Step 4: Validate JSON parses**

```bash
ruby -rjson -e 'JSON.parse(File.read("spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json")); puts "heavy OK"'
ruby -rjson -e 'JSON.parse(File.read("spec/fixtures/hms_smoke/empty.json")); puts "empty OK"'
# expected: heavy OK / empty OK
```

- [ ] **Step 5: Commit**

```bash
git add spec/fixtures/hms_smoke/
git commit -m "test(nimbus-smoke): add HMS ArcGIS feature fixtures (heavy + empty)"
```

---

## Task 2: `Skywatch::Nimbus::Models::Smoke`

**Files:**
- Create: `lib/skywatch/nimbus/models/smoke.rb`
- Create: `spec/nimbus/models/smoke_spec.rb`

TDD: write the model spec first, run, fail, implement, pass, refactor, rubocop, commit.

- [ ] **Step 1: Write the spec**

Save as `spec/nimbus/models/smoke_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rgeo/geo_json'

RSpec.describe Skywatch::Nimbus::Models::Smoke do
  let(:feature) do
    JSON.parse(File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json'))
        .fetch('features').first
  end

  describe '.from_arcgis_feature' do
    it 'parses density / satellite / Start / End_ / geometry' do
      smoke = described_class.from_arcgis_feature(feature)

      expect(smoke.density_raw).to eq('Heavy')
      expect(smoke.satellite).to eq('GOES-EAST')
      expect(smoke.start_time).to eq(Time.utc(2026, 4, 30, 12, 0))
      expect(smoke.end_time).to eq(Time.utc(2026, 4, 30, 18, 0))
      expect(smoke.geometry).to be_a(RGeo::Feature::Polygon)
    end

    it 'tolerates missing attributes block' do
      smoke = described_class.from_arcgis_feature({ 'geometry' => nil })
      expect(smoke.density_raw).to be_nil
      expect(smoke.satellite).to be_nil
      expect(smoke.geometry).to be_nil
    end

    it 'tolerates missing geometry' do
      f = feature.dup
      f['geometry'] = nil
      smoke = described_class.from_arcgis_feature(f)
      expect(smoke.geometry).to be_nil
    end

    it 'tolerates empty rings' do
      f = feature.dup
      f['geometry'] = { 'rings' => [] }
      smoke = described_class.from_arcgis_feature(f)
      expect(smoke.geometry).to be_nil
    end
  end

  describe 'julian time parser' do
    it 'parses "2026120 1200" as April 30 2026 12:00 UTC' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Start' => '2026120 1200', 'Density' => 'Light' }, 'geometry' => nil }
      )
      expect(smoke.start_time).to eq(Time.utc(2026, 4, 30, 12, 0))
    end

    it 'parses "2026001 0000" as January 1 2026 00:00 UTC' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Start' => '2026001 0000', 'Density' => 'Light' }, 'geometry' => nil }
      )
      expect(smoke.start_time).to eq(Time.utc(2026, 1, 1, 0, 0))
    end

    it 'returns nil for nil or empty Start' do
      [nil, ''].each do |val|
        smoke = described_class.from_arcgis_feature(
          { 'attributes' => { 'Start' => val, 'Density' => 'Light' }, 'geometry' => nil }
        )
        expect(smoke.start_time).to be_nil
      end
    end
  end

  describe 'density accessors' do
    %w[Light Medium Heavy].each_with_index do |density, idx|
      it "exposes level / score / description for #{density}" do
        smoke = described_class.from_arcgis_feature(
          { 'attributes' => { 'Density' => density }, 'geometry' => nil }
        )
        expect(smoke.density_level).to eq(density.downcase.to_sym)
        expect(smoke.density_score).to eq(idx + 1)
        expect(smoke.description).to eq("#{density} smoke")
      end
    end

    it 'raises KeyError when density is unknown' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Density' => 'Apocalyptic' }, 'geometry' => nil }
      )
      expect { smoke.density_level }.to raise_error(KeyError)
      expect { smoke.density_score }.to raise_error(KeyError)
      expect { smoke.description }.to raise_error(KeyError)
    end
  end

  describe '#to_h' do
    it 'serializes density quartet, satellite, times, and geometry as GeoJSON' do
      smoke = described_class.from_arcgis_feature(feature)
      hash = smoke.to_h

      expect(hash).to include(
        density: :heavy,
        density_raw: 'Heavy',
        density_score: 3,
        description: 'Heavy smoke',
        satellite: 'GOES-EAST',
        start_time: '2026-04-30T12:00:00Z',
        end_time: '2026-04-30T18:00:00Z'
      )
      expect(hash[:geometry]).to be_a(Hash)
      expect(hash[:geometry]['type']).to eq('Polygon')
    end

    it 'returns nil geometry when geometry is nil' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Density' => 'Light' }, 'geometry' => nil }
      )
      expect(smoke.to_h[:geometry]).to be_nil
    end

    it 'returns nil times when source times are nil' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Density' => 'Light' }, 'geometry' => nil }
      )
      expect(smoke.to_h[:start_time]).to be_nil
      expect(smoke.to_h[:end_time]).to be_nil
    end
  end

  describe '#to_json' do
    it 'round-trips through JSON' do
      smoke = described_class.from_arcgis_feature(feature)
      parsed = JSON.parse(smoke.to_json)
      expect(parsed['density_raw']).to eq('Heavy')
      expect(parsed['satellite']).to eq('GOES-EAST')
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/nimbus/models/smoke_spec.rb 2>&1 | tail -10
```

Expected: `NameError: uninitialized constant Skywatch::Nimbus::Models::Smoke` or similar — the model doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Save as `lib/skywatch/nimbus/models/smoke.rb`:

```ruby
# frozen_string_literal: true

require 'rgeo'
require 'rgeo/geo_json'
require 'date'
require 'time'

module Skywatch
  module Nimbus
    module Models
      class Smoke
        FACTORY = RGeo::Cartesian.factory(srid: 4326)

        DENSITY_LEVELS = {
          'Light'  => { level: :light,  score: 1, description: 'Light smoke' },
          'Medium' => { level: :medium, score: 2, description: 'Medium smoke' },
          'Heavy'  => { level: :heavy,  score: 3, description: 'Heavy smoke' }
        }.freeze

        attr_reader :density_raw, :satellite, :start_time, :end_time, :geometry

        def self.from_arcgis_feature(feature)
          attrs = feature['attributes'] || {}
          new(
            density_raw: attrs['Density'],
            satellite:   attrs['Satellite'],
            start_time:  parse_julian(attrs['Start']),
            end_time:    parse_julian(attrs['End_']),
            geometry:    parse_arcgis_polygon(feature['geometry'])
          )
        end

        # Parses "YYYYDDD HHMM" (e.g. "2026120 1200") to a UTC Time.
        def self.parse_julian(str)
          return nil if str.nil? || str.to_s.empty?

          date_part, time_part = str.split(' ', 2)
          year = date_part[0, 4].to_i
          doy  = date_part[4..].to_i
          hh   = time_part ? time_part[0, 2].to_i : 0
          mm   = time_part && time_part.length >= 4 ? time_part[2, 2].to_i : 0
          d = Date.ordinal(year, doy)
          Time.utc(d.year, d.month, d.day, hh, mm)
        end
        private_class_method :parse_julian

        def self.parse_arcgis_polygon(geometry_data)
          return nil if geometry_data.nil?

          rings = geometry_data['rings'] || []
          return nil if rings.empty?

          outer = rings.first
          points = outer.map { |(lon, lat)| FACTORY.point(lon, lat) }
          ring = FACTORY.linear_ring(points)
          FACTORY.polygon(ring)
        end
        private_class_method :parse_arcgis_polygon

        def initialize(density_raw:, satellite:, start_time:, end_time:, geometry:)
          @density_raw = density_raw
          @satellite   = satellite
          @start_time  = start_time
          @end_time    = end_time
          @geometry    = geometry
        end

        def density_level
          DENSITY_LEVELS.fetch(density_raw)[:level]
        end

        def density_score
          DENSITY_LEVELS.fetch(density_raw)[:score]
        end

        def description
          DENSITY_LEVELS.fetch(density_raw)[:description]
        end

        def to_h
          {
            density:       density_level_or_nil,
            density_raw:   density_raw,
            density_score: density_score_or_nil,
            description:   description_or_nil,
            satellite:     satellite,
            start_time:    start_time&.iso8601,
            end_time:      end_time&.iso8601,
            geometry:      geometry && RGeo::GeoJSON.encode(geometry)
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end

        private

        def density_level_or_nil
          DENSITY_LEVELS.fetch(density_raw)[:level]
        rescue KeyError
          nil
        end

        def density_score_or_nil
          DENSITY_LEVELS.fetch(density_raw)[:score]
        rescue KeyError
          nil
        end

        def description_or_nil
          DENSITY_LEVELS.fetch(density_raw)[:description]
        rescue KeyError
          nil
        end
      end
    end
  end
end
```

**Note** on the rescue helpers in `to_h`: the eager accessors (`density_level` etc.) raise `KeyError` for unknown densities, but `to_h` should still serialize the model — the `density_raw` field carries the source value, and unknown-density `to_h` returns `nil` for the derived fields. This is the deliberate degrade-gracefully shape for serialization, while the eager API stays loud.

- [ ] **Step 4: Wire it into `lib/skywatch.rb`**

Open `lib/skywatch.rb`. Find this block:

```ruby
require_relative 'skywatch/nimbus/sources/storm_report'
require_relative 'skywatch/nimbus/sources/alerts'
require_relative 'skywatch/nimbus/formatters/text'
```

Add **only the model** require — **before** the `formatters/text` line:

```ruby
require_relative 'skywatch/nimbus/models/smoke'
```

The source `require_relative` is deliberately added in Task 3 Step 4 (after the source file exists). Adding it now would break `bundle exec rspec` at the require-resolution stage because the source file isn't in the tree yet.

- [ ] **Step 5: Run tests to verify they pass**

```bash
bundle exec rspec spec/nimbus/models/smoke_spec.rb 2>&1 | tail -5
```

Expected: all examples green.

- [ ] **Step 6: Run full suite and rubocop**

```bash
bundle exec rspec 2>&1 | tail -1
# expected: 414 + ~14 = ~428 examples, 0 failures (model spec adds ~14)
bundle exec rubocop 2>&1 | tail -1
# expected: no offenses detected
```

If rubocop flags `Metrics/ClassLength` or similar, address it (mark with `# rubocop:disable` comments matching the existing pattern in `Outlook` / `ConvectiveAlert`).

- [ ] **Step 7: Commit**

```bash
git add lib/skywatch/nimbus/models/smoke.rb spec/nimbus/models/smoke_spec.rb lib/skywatch.rb
git commit -m "feat(nimbus-smoke): add Models::Smoke with density classification"
```

---

## Task 3: `Skywatch::Nimbus::Sources::Smoke`

**Files:**
- Create: `lib/skywatch/nimbus/sources/smoke.rb`
- Create: `spec/nimbus/sources/smoke_spec.rb`

- [ ] **Step 1: Write the spec**

Save as `spec/nimbus/sources/smoke_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe Skywatch::Nimbus::Sources::Smoke do
  let(:heavy_fixture) { File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json') }
  let(:empty_fixture) { File.read('spec/fixtures/hms_smoke/empty.json') }

  let(:base_url) do
    'https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/' \
      'NOAA_Satellite_Smoke_Detection_(v1)/FeatureServer/0/query'
  end

  describe '#fetch' do
    it 'requests the ArcGIS query endpoint with point-intersect params and wraps each feature' do
      stub = stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
             .with(query: hash_including(
               'geometry' => '-121.843,36.587',
               'geometryType' => 'esriGeometryPoint',
               'inSR' => '4326',
               'spatialRel' => 'esriSpatialRelIntersects',
               'outFields' => '*',
               'f' => 'json'
             ))
             .to_return(status: 200, body: heavy_fixture, headers: { 'Content-Type' => 'application/json' })

      plumes = described_class.new.fetch(at: [36.587, -121.843])

      expect(stub).to have_been_requested
      expect(plumes.size).to eq(1)
      expect(plumes.first.density_raw).to eq('Heavy')
      expect(plumes.first.satellite).to eq('GOES-EAST')
    end

    it 'returns [] when ArcGIS returns an empty FeatureCollection' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: empty_fixture, headers: { 'Content-Type' => 'application/json' })

      expect(described_class.new.fetch(at: [37.62, -122.38])).to eq([])
    end

    it 'raises Skywatch::ApiError on a non-200 response' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 500, body: '{"error":{"code":500,"message":"server boom"}}')

      expect { described_class.new.fetch(at: [37.62, -122.38]) }
        .to raise_error(Skywatch::ApiError)
    end

    it 'raises Skywatch::ConnectionError on a network failure' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query}).to_timeout

      expect { described_class.new.fetch(at: [37.62, -122.38]) }
        .to raise_error(Skywatch::ConnectionError)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/nimbus/sources/smoke_spec.rb 2>&1 | tail -5
```

Expected: `NameError: uninitialized constant Skywatch::Nimbus::Sources::Smoke`.

- [ ] **Step 3: Write the implementation**

Save as `lib/skywatch/nimbus/sources/smoke.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Sources
      class Smoke
        BASE_URL = 'https://services2.arcgis.com'
        PATH = '/C8EMgrsFcRFL6LrL/arcgis/rest/services/' \
               'NOAA_Satellite_Smoke_Detection_(v1)/FeatureServer/0/query'
        TTL = 3600

        def initialize(client: default_client)
          @client = client
        end

        def fetch(at:)
          lat, lon = at
          params = {
            geometry: "#{lon},#{lat}",
            geometryType: 'esriGeometryPoint',
            inSR: 4326,
            spatialRel: 'esriSpatialRelIntersects',
            outFields: '*',
            f: 'json'
          }
          data = @client.get(PATH, params, ttl: TTL)
          features = data['features'] || []
          features.map { |f| Models::Smoke.from_arcgis_feature(f) }
        end

        private

        def default_client
          Skywatch::Shared::Cache.new(client: Skywatch::Shared::Http.new(base_url: BASE_URL))
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire it into `lib/skywatch.rb`**

Open `lib/skywatch.rb`. Find:

```ruby
require_relative 'skywatch/nimbus/models/smoke'
```

(added in Task 2). Add **immediately after**:

```ruby
require_relative 'skywatch/nimbus/sources/smoke'
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bundle exec rspec spec/nimbus/sources/smoke_spec.rb 2>&1 | tail -5
```

Expected: all 4 examples green.

- [ ] **Step 6: Run full suite and rubocop**

```bash
bundle exec rspec 2>&1 | tail -1
# expected: ~432 examples, 0 failures
bundle exec rubocop 2>&1 | tail -1
# expected: no offenses detected
```

- [ ] **Step 7: Commit**

```bash
git add lib/skywatch/nimbus/sources/smoke.rb spec/nimbus/sources/smoke_spec.rb lib/skywatch.rb
git commit -m "feat(nimbus-smoke): add Sources::Smoke (ArcGIS HMS feature service client)"
```

---

## Task 4: Top-level `Skywatch.smoke(at:)` convenience method

**Files:**
- Modify: `lib/skywatch.rb`
- Create: `spec/nimbus/smoke_spec.rb`

- [ ] **Step 1: Write the spec**

Save as `spec/nimbus/smoke_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe 'Skywatch.smoke' do
  let(:heavy_fixture) { File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json') }
  let(:empty_fixture) { File.read('spec/fixtures/hms_smoke/empty.json') }

  it 'delegates to Nimbus::Sources::Smoke#fetch and returns plumes' do
    stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
      .to_return(status: 200, body: heavy_fixture, headers: { 'Content-Type' => 'application/json' })

    plumes = Skywatch.smoke(at: [36.587, -121.843])

    expect(plumes).to all(be_a(Skywatch::Nimbus::Models::Smoke))
    expect(plumes.first.density_level).to eq(:heavy)
  end

  it 'returns [] when the source returns no features' do
    stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
      .to_return(status: 200, body: empty_fixture, headers: { 'Content-Type' => 'application/json' })

    expect(Skywatch.smoke(at: [37.62, -122.38])).to eq([])
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/nimbus/smoke_spec.rb 2>&1 | tail -5
```

Expected: `NoMethodError: undefined method 'smoke' for Skywatch:Module`.

- [ ] **Step 3: Add the convenience method to `lib/skywatch.rb`**

Open `lib/skywatch.rb`. Find:

```ruby
def self.convection(at:, events: nil)
  alerts = if events
             Nimbus::Sources::Alerts.new.fetch(at: at, events: events)
           else
             Nimbus::Sources::Alerts.new.fetch(at: at)
           end

  Nimbus::Models::Convection.new(
    at: at,
    fetched_at: Time.now.utc,
    alerts: alerts
  )
end
```

Add **immediately after**:

```ruby
def self.smoke(at:)
  Nimbus::Sources::Smoke.new.fetch(at: at)
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/nimbus/smoke_spec.rb 2>&1 | tail -5
```

Expected: 2 examples green.

- [ ] **Step 5: Full suite + rubocop**

```bash
bundle exec rspec 2>&1 | tail -1
# expected: ~434 examples, 0 failures
bundle exec rubocop 2>&1 | tail -1
# expected: no offenses detected
```

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch.rb spec/nimbus/smoke_spec.rb
git commit -m "feat(nimbus-smoke): add Skywatch.smoke(at:) convenience method"
```

---

## Task 5: `Formatters::Text.format_smoke`

**Files:**
- Modify: `lib/skywatch/nimbus/formatters/text.rb`
- Modify: `spec/nimbus/formatters/text_spec.rb`

- [ ] **Step 1: Add the formatter spec**

Open `spec/nimbus/formatters/text_spec.rb`. Add a new `describe` block at the bottom of the file (above the closing `end` of `RSpec.describe Skywatch::Nimbus::Formatters::Text do`):

```ruby
  describe '.format_smoke' do
    let(:plume) do
      Skywatch::Nimbus::Models::Smoke.from_arcgis_feature(
        JSON.parse(File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json'))
            .fetch('features').first
      )
    end

    it 'renders density, satellite, and validity window' do
      line = described_class.format_smoke(plume)
      expect(line).to start_with('SMOKE Heavy')
      expect(line).to include('(GOES-EAST)')
      expect(line).to include('2026-04-30 12:00Z')
      expect(line).to include('2026-04-30 18:00Z')
      expect(line).to end_with("\n")
    end

    it 'omits the satellite parenthetical when satellite is nil' do
      plume_no_sat = Skywatch::Nimbus::Models::Smoke.new(
        density_raw: 'Light', satellite: nil,
        start_time: Time.utc(2026, 4, 30, 12),
        end_time: Time.utc(2026, 4, 30, 18),
        geometry: nil
      )
      line = described_class.format_smoke(plume_no_sat)
      expect(line).to start_with('SMOKE Light —')
      expect(line).not_to include('(')
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/nimbus/formatters/text_spec.rb -e 'format_smoke' 2>&1 | tail -10
```

Expected: `NoMethodError: undefined method 'format_smoke'`.

- [ ] **Step 3: Add the formatter**

Open `lib/skywatch/nimbus/formatters/text.rb`. Find the existing methods. Add **after** `format_storm_report` (or anywhere convenient — placement doesn't matter logically):

```ruby
        def self.format_smoke(plume)
          valid = "#{format_time(plume.start_time)} → #{format_time(plume.end_time)}"
          sat = plume.satellite ? " (#{plume.satellite})" : ''
          "SMOKE #{plume.density_raw}#{sat} — #{valid}\n"
        end
```

`format_time` is already defined and `private_class_method`'d in this module — `format_smoke` can call it directly.

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/nimbus/formatters/text_spec.rb 2>&1 | tail -5
```

Expected: all examples green (including pre-existing).

- [ ] **Step 5: Full suite + rubocop**

```bash
bundle exec rspec 2>&1 | tail -1
# expected: ~436 examples, 0 failures
bundle exec rubocop 2>&1 | tail -1
# expected: no offenses detected
```

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/formatters/text.rb spec/nimbus/formatters/text_spec.rb
git commit -m "feat(nimbus-smoke): add Formatters::Text.format_smoke"
```

---

## Task 6: CLI `smoke LAT LON` subcommand

**Files:**
- Modify: `lib/skywatch/nimbus/cli.rb`
- Modify: `spec/nimbus/cli_spec.rb`

- [ ] **Step 1: Add CLI specs**

Open `spec/nimbus/cli_spec.rb`. Add a new `describe 'smoke command' do` block **after** the `describe 'convection' do` block (before the `private` line near the bottom):

```ruby
  describe 'smoke command' do
    let(:heavy_fixture) { File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json') }
    let(:empty_fixture) { File.read('spec/fixtures/hms_smoke/empty.json') }

    it 'prints a one-line text summary on a TTY' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: heavy_fixture, headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(%w[smoke 36.587 -121.843 --format text]) }
      expect(output).to include('SMOKE Heavy')
      expect(output).to include('GOES-EAST')
    end

    it 'prints a JSON array when --format json' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: heavy_fixture, headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(%w[smoke 36.587 -121.843 --format json]) }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.length).to eq(1)
      expect(parsed.first['density_raw']).to eq('Heavy')
    end

    it 'prints a friendly empty message in text mode' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: empty_fixture, headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(%w[smoke 37.62 -122.38 --format text]) }
      expect(output).to include('No smoke detected')
    end

    it 'prints [] in JSON mode when empty' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: empty_fixture, headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(%w[smoke 37.62 -122.38 --format json]) }
      expect(output.strip).to eq('[]')
    end

    it 'prints Error: ... and exits 1 when the source raises' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 500, body: '{"error":{"code":500}}')

      stderr = capture_stderr do
        expect do
          described_class.start(%w[smoke 37.62 -122.38 --format json])
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
      expect(stderr).to include('Error:')
    end
  end
```

Then add a `capture_stderr` helper alongside `capture_stdout` in the `private` section at the bottom:

```ruby
  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/nimbus/cli_spec.rb -e 'smoke command' 2>&1 | tail -10
```

Expected: failures of the form "Could not find command 'smoke'" or similar.

- [ ] **Step 3: Add the CLI subcommand**

Open `lib/skywatch/nimbus/cli.rb`. Find the `convection` subcommand definition. **After** it (before `private` if there is one — there should be), add:

```ruby
      desc 'smoke LAT LON', 'HMS satellite-detected smoke plumes covering the point'
      def smoke(lat, lon)
        plumes = Skywatch.smoke(at: [lat.to_f, lon.to_f])
        print_smoke(plumes)
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end
```

In the `private` section of the same class, add:

```ruby
      def print_smoke(plumes)
        if output_format == 'json'
          puts(plumes.empty? ? '[]' : JSON.pretty_generate(plumes.map(&:to_h)))
        elsif plumes.empty?
          puts 'No smoke detected at this point.'
        else
          plumes.each { |p| print Skywatch::Nimbus::Formatters::Text.format_smoke(p) }
        end
      end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/nimbus/cli_spec.rb -e 'smoke command' 2>&1 | tail -10
```

Expected: all 5 smoke examples green.

- [ ] **Step 5: Full suite + rubocop**

```bash
bundle exec rspec 2>&1 | tail -1
# expected: ~441 examples, 0 failures
bundle exec rubocop 2>&1 | tail -1
# expected: no offenses detected
```

If rubocop flags `Metrics/MethodLength` on the CLI class or the new `print_smoke`, address with the same pattern as nearby methods (often a `# rubocop:disable` comment on the line above).

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/cli.rb spec/nimbus/cli_spec.rb
git commit -m "feat(nimbus-smoke): add 'skywatch nimbus smoke LAT LON' CLI command"
```

---

## Task 7: Brief composer integration

**Files:**
- Modify: `lib/skywatch/brief/analysis/composer.rb`
- Modify: `spec/brief/analysis/composer_spec.rb`
- Modify: `spec/brief/integration_spec.rb`

This task makes smoke the 6th adverse-conditions source. It changes the composer's constructor signature, the `build_adverse` method, and the existing brief tests that already exercise the composer.

- [ ] **Step 1: Update the integration spec stub list (red)**

Open `spec/brief/integration_spec.rb`. Find the `before do` block that calls `allow_any_instance_of(...)` for each existing source. Add **before the line** `allow(Skywatch::Brief::Analysis::AirportLocator).to receive(:wfo_for)...`:

```ruby
    allow_any_instance_of(Skywatch::Nimbus::Sources::Smoke).to receive(:fetch).and_return([])
```

(This stubs smoke to return no plumes — the existing snapshot test should keep passing once the composer is wired.)

Also: add a new `it` block after the existing 2 examples that exercises the smoke happy path. After the `it 'serializes round-trip through JSON without raising' do ... end` block, add:

```ruby
  it 'surfaces a heavy smoke plume in adverse_conditions.items with kind: smoke' do
    feature = JSON.parse(File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json'))
                  .fetch('features').first
    plume = Skywatch::Nimbus::Models::Smoke.from_arcgis_feature(feature)
    allow_any_instance_of(Skywatch::Nimbus::Sources::Smoke).to receive(:fetch).and_return([plume])

    hash = Skywatch.brief(airport: 'KCDW').to_h

    smoke_items = hash[:adverse_conditions][:items].select { |i| i[:kind] == 'smoke' }
    expect(smoke_items.size).to eq(1)
    expect(smoke_items.first).to include(
      kind: 'smoke',
      density: :heavy,
      density_raw: 'Heavy',
      density_score: 3,
      satellite: 'GOES-EAST'
    )
  end
```

- [ ] **Step 2: Update composer_spec.rb (red)**

Open `spec/brief/analysis/composer_spec.rb`. Find the `let` block defining each source double. **After** `let(:storm_source) ...` add:

```ruby
  let(:smoke_source) { instance_double(Skywatch::Nimbus::Sources::Smoke, fetch: []) }
```

Find the `let(:composer) do described_class.new(...)` block. **Add** `smoke_source: smoke_source` to the constructor call (anywhere in the keyword list — match the existing comma-formatted style):

```ruby
  let(:composer) do
    described_class.new(
      metar_source: metar_source, taf_source: taf_source, pirep_source: pirep_source,
      winds_source: winds_source, sigmet_source: sigmet_source, airmet_source: airmet_source,
      afd_source: afd_source, alerts_source: alerts_source, storm_source: storm_source,
      smoke_source: smoke_source
    )
  end
```

In the `context 'error wrapping'` block, find the existing test `'records partial_failures on adverse_conditions when one sub-source raises'` and add a new sibling test below it:

```ruby
    it 'records smoke partial_failure when smoke source raises' do
      allow(smoke_source).to receive(:fetch).and_raise(StandardError, 'smoke boom')
      slot = composer.compose(airport: 'KCDW').adverse_conditions
      expect(slot[:available]).to be true
      expect(slot[:partial_failures]).to contain_exactly(
        hash_including(source: 'smoke', reason: a_string_including('smoke boom'))
      )
    end

    it 'surfaces a smoke plume under items when smoke source returns one' do
      feature = JSON.parse(File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json'))
                    .fetch('features').first
      plume = Skywatch::Nimbus::Models::Smoke.from_arcgis_feature(feature)
      allow(smoke_source).to receive(:fetch).and_return([plume])
      slot = composer.compose(airport: 'KCDW').adverse_conditions
      expect(slot[:available]).to be true
      expect(slot[:items].map { |i| i[:kind] }).to include('smoke')
    end
```

Also update the "all sub-sources raise" test to include the smoke source:

```ruby
    it 'sets adverse_conditions unavailable when every sub-source raises' do
      allow(sigmet_source).to receive(:fetch).and_raise(StandardError, 'a')
      allow(airmet_source).to receive(:fetch).and_raise(StandardError, 'b')
      allow(pirep_source).to receive(:fetch).and_raise(StandardError, 'c')
      allow(alerts_source).to receive(:fetch).and_raise(StandardError, 'd')
      allow(storm_source).to receive(:fetch).and_raise(StandardError, 'e')
      allow(smoke_source).to receive(:fetch).and_raise(StandardError, 'f')
      slot = composer.compose(airport: 'KCDW').adverse_conditions
      expect(slot[:available]).to be false
      expect(slot[:reason]).to include('all adverse sources failed')
    end
```

Add `require 'json'` at the top of `composer_spec.rb` if it isn't already there (the new tests `JSON.parse` a fixture).

- [ ] **Step 3: Run tests to verify they fail**

```bash
bundle exec rspec spec/brief/ 2>&1 | tail -10
```

Expected: failures of the form "unexpected keyword argument :smoke_source" — the composer constructor doesn't take it yet. Plus failures on the new smoke happy-path / failure-path tests.

- [ ] **Step 4: Update the composer**

Open `lib/skywatch/brief/analysis/composer.rb`.

**Constructor:** find the existing `def initialize(metar_source: ...` block. Add `smoke_source:` keyword (default `Skywatch::Nimbus::Sources::Smoke.new`) and assignment. The block should look like:

```ruby
        # rubocop:disable Metrics/ParameterLists
        def initialize(metar_source: Skywatch::Briefer::Sources::Metar.new,
                       taf_source: Skywatch::Briefer::Sources::Taf.new,
                       pirep_source: Skywatch::Briefer::Sources::Pirep.new,
                       winds_source: Skywatch::Briefer::Sources::WindsAloft.new,
                       sigmet_source: Skywatch::Briefer::Sources::Sigmet.new,
                       airmet_source: Skywatch::Briefer::Sources::Airmet.new,
                       afd_source: Skywatch::Briefer::Sources::Afd.new,
                       alerts_source: Skywatch::Nimbus::Sources::Alerts.new,
                       storm_source: Skywatch::Nimbus::Sources::StormReport.new,
                       smoke_source: Skywatch::Nimbus::Sources::Smoke.new)
          @metar_source = metar_source
          @taf_source = taf_source
          @pirep_source = pirep_source
          @winds_source = winds_source
          @sigmet_source = sigmet_source
          @airmet_source = airmet_source
          @afd_source = afd_source
          @alerts_source = alerts_source
          @storm_source = storm_source
          @smoke_source = smoke_source
        end
        # rubocop:enable Metrics/ParameterLists
```

**`build_adverse` method:** find this section:

```ruby
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
```

Replace it with:

```ruby
        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def build_adverse(lat:, lon:, urgent_pireps:, pirep_attempt:)
          sigmet_attempt = attempt { @sigmet_source.fetch.select { |s| AdverseFilter.covers?(s, lat, lon) } }
          airmet_attempt = attempt { @airmet_source.fetch.select { |a| AdverseFilter.covers?(a, lat, lon) } }
          alerts_attempt = attempt { @alerts_source.fetch(at: [lat, lon]) }
          storm_attempt = attempt do
            recent = recent_storms(@storm_source.fetch)
            AdverseFilter.within(recent, lat: lat, lon: lon, radius_nm: ADVERSE_RADIUS_NM)
          end
          smoke_attempt = attempt { @smoke_source.fetch(at: [lat, lon]) }

          attempts = {
            'sigmet' => sigmet_attempt, 'airmet' => airmet_attempt,
            'pirep' => pirep_attempt, 'convective_alert' => alerts_attempt,
            'storm_report' => storm_attempt, 'smoke' => smoke_attempt
          }
```

Find the items aggregation block at the bottom of `build_adverse`:

```ruby
          items.concat((sigmet_attempt[:value] || []).map { |s| { kind: 'sigmet' }.merge(s.to_h) })
          items.concat((airmet_attempt[:value] || []).map { |a| { kind: 'airmet' }.merge(a.to_h) })
          items.concat(urgent_pireps.map { |p| { kind: 'pirep' }.merge(p.to_h) })
          items.concat((alerts_attempt[:value] || []).map { |a| { kind: 'convective_alert' }.merge(a.to_h) })
          items.concat((storm_attempt[:value] || []).map { |s| { kind: 'storm_report' }.merge(s.to_h) })

          { available: true, items: items, partial_failures: partial_failures }
        end
```

Add a new line **before** `{ available: true, ... }`:

```ruby
          items.concat((sigmet_attempt[:value] || []).map { |s| { kind: 'sigmet' }.merge(s.to_h) })
          items.concat((airmet_attempt[:value] || []).map { |a| { kind: 'airmet' }.merge(a.to_h) })
          items.concat(urgent_pireps.map { |p| { kind: 'pirep' }.merge(p.to_h) })
          items.concat((alerts_attempt[:value] || []).map { |a| { kind: 'convective_alert' }.merge(a.to_h) })
          items.concat((storm_attempt[:value] || []).map { |s| { kind: 'storm_report' }.merge(s.to_h) })
          items.concat((smoke_attempt[:value] || []).map { |s| { kind: 'smoke' }.merge(s.to_h) })

          { available: true, items: items, partial_failures: partial_failures }
        end
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bundle exec rspec spec/brief/ 2>&1 | tail -10
```

Expected: all brief specs green, including the new smoke ones.

- [ ] **Step 6: Full suite + rubocop**

```bash
bundle exec rspec 2>&1 | tail -1
# expected: ~445 examples, 0 failures
bundle exec rubocop 2>&1 | tail -1
# expected: no offenses detected
```

- [ ] **Step 7: Commit**

```bash
git add lib/skywatch/brief/analysis/composer.rb spec/brief/analysis/composer_spec.rb spec/brief/integration_spec.rb
git commit -m "feat(brief): wire Nimbus smoke as 6th adverse-conditions source"
```

---

## Task 8: CLAUDE.md update

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Open CLAUDE.md and find the CLI usage block**

Look for the section starting `## CLI Usage` and the line `skywatch nimbus convection 40.688 -74.174`.

- [ ] **Step 2: Add the smoke command**

Insert **immediately after** the convection line:

```
skywatch nimbus smoke 40.688 -74.174
```

So the relevant block reads:

```bash
skywatch nimbus outlook 1 --at 40.688,-74.174
skywatch nimbus storms --type tornado --near 40.688,-74.174 --radius 100
skywatch nimbus convection 40.688 -74.174
skywatch nimbus smoke 40.688 -74.174
skywatch brief KCDW
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(nimbus-smoke): document 'skywatch nimbus smoke LAT LON' command"
```

---

## Task 9: Final pre-PR checks + push + open PR

**Files:** none new — verification + remote work only.

- [ ] **Step 1: Final test + lint pass**

```bash
bundle exec rspec 2>&1 | tail -1
# expected: ~445 examples, 0 failures
bundle exec rubocop 2>&1 | tail -1
# expected: no offenses detected
```

If anything is red, fix it before proceeding.

- [ ] **Step 2: Capture live validation evidence**

Run a real call against the live ArcGIS endpoint for one or two reasonable points. KMRY (Monterey) is fire-prone; KCDW is a sanity-check. Note: this needs network access — if the sandbox blocks it, retry with `dangerouslyDisableSandbox: true`.

```bash
exe/skywatch nimbus smoke 36.587 -121.843 --format json
exe/skywatch nimbus smoke 40.875 -74.282 --format json
exe/skywatch nimbus smoke 40.875 -74.282 --format text
```

Expected: a clean JSON array (likely empty `[]` in late April / early May since fire season is summer-fall) for each call. Save the output snippets — they go in the PR body.

- [ ] **Step 3: Capture brief integration evidence**

```bash
exe/skywatch brief KCDW --format json | jq '.adverse_conditions | { available, items_count: (.items | length), smoke_items: [.items[] | select(.kind == "smoke")], partial_failures }'
```

Expected: `partial_failures` should NOT include `"smoke"` (it's reachable now). If smoke fires today, `smoke_items` will be non-empty; otherwise empty array. Save this snippet — it also goes in the PR body.

- [ ] **Step 4: Push the branch**

```bash
git push -u origin nimbus-smoke
```

- [ ] **Step 5: Open the PR**

```bash
gh pr create --repo jayrav13/skywatch \
  --base main \
  --head nimbus-smoke \
  --title "feat(nimbus): smoke plumes via NOAA HMS — Nimbus PR 3" \
  --body "$(cat <<'EOF'
## Summary

- Adds `Skywatch.smoke(at:)` and `skywatch nimbus smoke LAT LON` — pulls NOAA HMS smoke plume polygons from the public ArcGIS feature service and classifies by Light/Medium/Heavy density.
- Wires smoke into `Skywatch.brief` as the 6th adverse-conditions source (sigmet, airmet, pirep, convective_alert, storm_report, **smoke**). Smoke plumes covering the airport surface as items in `adverse_conditions.items` with \`kind: 'smoke'\` and a \`density_score\` (1/2/3).
- No API key required. Server-side polygon-intersect via point query — no client-side filtering, no KML parsing.

## Architecture

Mirrors the existing `Outlook` / `Alerts` source patterns exactly. One source + one model + top-level convenience method + Thor subcommand + brief composer integration. \`density_raw\` / \`density_level\` / \`density_score\` / \`description\` quartet matches \`Outlook\`'s \`label\` / \`risk_level\` / \`risk_score\` / \`description\`.

Spec: [\`docs/superpowers/specs/2026-04-30-nimbus-smoke-design.md\`](docs/superpowers/specs/2026-04-30-nimbus-smoke-design.md).
Plan: [\`docs/superpowers/plans/2026-04-30-nimbus-smoke.md\`](docs/superpowers/plans/2026-04-30-nimbus-smoke.md).

## Validation evidence

\`\`\`
[paste output from Task 9 Step 2 — exe/skywatch nimbus smoke 36.587 -121.843 --format json]
\`\`\`

\`\`\`
[paste output from Task 9 Step 3 — exe/skywatch brief KCDW | jq ...]
\`\`\`

(If smoke is sparse at validation time, the empty-array case is the validation evidence — the system correctly reports no plumes, no errors, no partial failures from the smoke source.)

## Follow-up issues already filed

- [#13](https://github.com/jayrav13/skywatch/issues/13) — Add surface AQI from AirNow
- [#14](https://github.com/jayrav13/skywatch/issues/14) — Add \`skywatch nimbus fires LAT LON\`
- [#15](https://github.com/jayrav13/skywatch/issues/15) — Consider SmokeAnalysis aggregate model

## Test plan

- [x] \`bundle exec rspec\` — all green (414 → ~445 examples)
- [x] \`bundle exec rubocop\` — clean
- [x] \`exe/skywatch nimbus smoke LAT LON\` — JSON + text output verified
- [x] \`exe/skywatch brief KCDW | jq '.adverse_conditions.partial_failures'\` — no smoke entry (source reachable end-to-end)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed.

- [ ] **Step 6: Confirm CI passes**

```bash
gh pr view <PR#> --repo jayrav13/skywatch --json state,mergeable,statusCheckRollup
```

Expected: `state: OPEN`, `mergeable: MERGEABLE`, all checks `SUCCESS` (or `QUEUED` then `SUCCESS` after a moment).

---

## Self-Review

Run after the plan is fully written.

**1. Spec coverage:**
- [x] Goal & validation thesis — Task 9 captures the validation evidence in the PR body
- [x] In-scope: source, model, top-level API, CLI, brief integration, sandbox allowlist — Tasks 1–8 cover each
- [x] Out-of-scope: AQI / fires / SmokeAnalysis aggregate — already filed as #13/#14/#15
- [x] ArcGIS query shape with all 6 params — Task 3 source code matches spec exactly
- [x] Julian time parser ("YYYYDDD HHMM") — Task 2 model + dedicated spec example for `2026120 1200`
- [x] ArcGIS polygon parser (rings → RGeo polygon) — Task 2 model
- [x] Density quartet (raw / level / score / description) — Task 2 model
- [x] CLI shape — Task 6 (text + JSON, empty + non-empty + error)
- [x] Brief integration as 6th adverse source — Task 7 (composer + composer spec + integration spec)
- [x] Error handling (loud failure on unknown density via eager accessors; degrade-gracefully in to_h) — Task 2 includes both
- [x] Sandbox allowlist — pre-flight verifies it's already in place (services2.arcgis.com is in `.claude/settings.local.json` `permissions.allow`)
- [x] CLAUDE.md update — Task 8

**2. Placeholder scan:** No "TBD" / "TODO" / "implement later" in any code or test block. The bracketed `[paste output ...]` markers in the PR body template are intentional — they get filled with real validation output at Task 9, by definition.

**3. Type consistency:**
- `Models::Smoke.from_arcgis_feature(feature) → Smoke` — used in Tasks 2 (spec/impl), 5 (formatter spec), 7 (composer spec + integration spec), 6 (CLI spec) ✓
- `Sources::Smoke#fetch(at: [lat, lon]) → Array<Smoke>` — used in Tasks 3 (spec/impl), 4 (top-level spec), 6 (CLI), 7 (composer) ✓
- `plume.density_raw / density_level / density_score / description / start_time / end_time / satellite / geometry / to_h` — consistent across all tasks
- `Skywatch.smoke(at: [lat, lon]) → Array<Smoke>` — Task 4 spec + Task 6 CLI calls it ✓
- Composer constructor `smoke_source:` keyword + `@smoke_source.fetch(at: [lat, lon])` — Task 7 ✓
- Item shape `{ kind: 'smoke', density: :heavy, density_score: 3, ... }` — Task 7 composer impl + composer/integration specs assert this exact shape ✓

**4. File path consistency:** All `lib/skywatch/nimbus/...` and `spec/nimbus/...` paths match the existing project layout. Fixture path `spec/fixtures/hms_smoke/` is new but follows the existing convention (one directory per data source: `spc/`, `nws_alerts/`, `nws_points/`, `metars/`, etc.).

**5. Step counts:** Each task is 5–7 steps; each step is 2–5 minutes of work. Total: ~9 tasks × ~6 steps = ~54 steps. Plan is appropriately bite-sized.

---

## Notes for the implementer

- **Sandbox & live calls:** WebMock-stubbed tests work without any network. Live calls (Task 9 Step 2) hit `services2.arcgis.com` which is already in `.claude/settings.local.json` `permissions.allow`. If the sandbox blocks the request anyway (depends on the runtime sandbox layer vs. the permission layer), retry with `dangerouslyDisableSandbox: true`. Don't add the host yourself — the user's system-prompt sandbox config is the authority.
- **The `(v1)` in the URL:** `NOAA_Satellite_Smoke_Detection_(v1)` is the literal service name. Faraday URL-encodes the parens into `%28v1%29` on the wire, but RFC 3986 sub-delim parens are technically valid unencoded too. Both work. WebMock specs use a regex match (`%r{...FeatureServer/0/query}`) to avoid encoding ambiguity.
- **April 30 = day 120 of 2026:** verified with `Date.ordinal(2026, 120) == Date.new(2026, 4, 30)`. The Julian parser test fixtures use this date specifically because it's the spec date.
- **Don't introduce a `covers?` predicate on `Models::Smoke`:** the source already does server-side polygon-intersect, so the model never needs it. If you find yourself reaching for one, stop — that's a sign you're filtering somewhere you shouldn't.
- **The `degrade-gracefully` behavior in `to_h`:** unknown density returns `nil` for the derived fields (level/score/description) but keeps `density_raw` populated. The eager accessors (`density_level` etc.) still raise `KeyError`. This split is intentional: the API stays loud, but JSON serialization stays safe — never produces a half-broken hash that crashes downstream consumers.
- **Don't try to be clever with rubocop disables.** Match the existing pattern (`# rubocop:disable Metrics/X` on the line before, `# rubocop:enable Metrics/X` after the block). Don't add new comment styles.
