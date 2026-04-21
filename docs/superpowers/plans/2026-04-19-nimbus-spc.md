# Nimbus PR 1 — SPC Outlooks + Storm Reports — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `Skywatch::Nimbus` PR 1 — two one-shot SPC tools (`outlook DAY [--at ...]` and `storms [--date/--type/--near/--radius]`) backed by SPC categorical-outlook GeoJSON and SPC daily storm-reports CSV.

**Architecture:** New `Skywatch::Nimbus` domain (models/sources/formatters/cli) talking to `https://www.spc.noaa.gov` via a dedicated `Shared::Http` + `Shared::Cache` instance. Outlook model wraps an RGeo `MultiPolygon` (Cartesian factory, srid 4326) for point-in-polygon; StormReport model normalizes magnitude per type (mph for wind, inches for hail, F-scale string for tornado). Convenience API on top-level `Skywatch` (`Skywatch.outlook`, `Skywatch.storms`) mirrors existing `Skywatch.flights` / `Skywatch.mayday`. CLI follows the Thor subcommand pattern used by `weather` / `radar` / `mayday`.

**Tech Stack:** Ruby 3.2+, Thor 1.3, Faraday 2.0 + faraday-retry, rgeo 3.0, rgeo-geojson 2.0, RSpec 3 + WebMock 3, RuboCop 1.

---

## File Structure

Files this plan creates (absolute paths in the `nimbus` worktree — `/Users/jravaliya/Code/skywatch/.worktrees/nimbus`):

**Library:**
- `lib/skywatch/nimbus/models/outlook.rb` — single SPC outlook region; wraps a feature's MultiPolygon, exposes risk classification and `covers?`
- `lib/skywatch/nimbus/models/storm_report.rb` — single row from SPC daily reports CSV; type-normalized magnitude + `wind_kt` derived getter
- `lib/skywatch/nimbus/sources/outlook.rb` — fetch Day N categorical outlook GeoJSON
- `lib/skywatch/nimbus/sources/storm_report.rb` — fetch today's or a past day's CSV, walk the 3-section format
- `lib/skywatch/nimbus/formatters/text.rb` — `format_outlook`, `format_storm_report`
- `lib/skywatch/nimbus/cli.rb` — Thor subclass with `outlook` and `storms` commands

**Library wiring (modifications):**
- `lib/skywatch.rb` — `require_relative` the new files; add `Skywatch.outlook` and `Skywatch.storms` class methods
- `lib/skywatch/cli.rb` — register the `nimbus` subcommand

**Tests:**
- `spec/nimbus/models/outlook_spec.rb`
- `spec/nimbus/models/storm_report_spec.rb`
- `spec/nimbus/sources/outlook_spec.rb`
- `spec/nimbus/sources/storm_report_spec.rb`
- `spec/nimbus/formatters/text_spec.rb`
- `spec/nimbus/cli_spec.rb`
- `spec/nimbus_spec.rb` — `Skywatch.outlook(...)` and `Skywatch.storms(...)`

**Fixtures:**
- `spec/fixtures/spc/day1.geojson` — real Day 1 snapshot (captured via sandbox bypass)
- `spec/fixtures/spc/day2.geojson` — real Day 2 snapshot
- `spec/fixtures/spc/day3.geojson` — real Day 3 snapshot
- `spec/fixtures/spc/day1_empty.geojson` — synthetic empty FeatureCollection
- `spec/fixtures/spc/day1_synthetic.geojson` — synthetic fixture with a known rectangle over NYC (for deterministic `covers?` tests)
- `spec/fixtures/spc/today.csv` — real today's reports snapshot
- `spec/fixtures/spc/today_empty.csv` — synthetic headers-only CSV
- `spec/fixtures/spc/sample.csv` — synthetic CSV with one tornado / two wind / two hail rows (known lat/lon for `near:` tests)
- `spec/fixtures/spc/260415.csv` — real historical-day snapshot (2026-04-15)

**Docs:**
- `CLAUDE.md` — add `nimbus outlook` and `nimbus storms` to the CLI Usage section

---

## Task 0: Fixture capture and scaffolding

**Files:**
- Create: `spec/fixtures/spc/day1.geojson`
- Create: `spec/fixtures/spc/day2.geojson`
- Create: `spec/fixtures/spc/day3.geojson`
- Create: `spec/fixtures/spc/today.csv`
- Create: `spec/fixtures/spc/260415.csv`
- Create: `spec/fixtures/spc/day1_empty.geojson`
- Create: `spec/fixtures/spc/day1_synthetic.geojson`
- Create: `spec/fixtures/spc/today_empty.csv`
- Create: `spec/fixtures/spc/sample.csv`

- [ ] **Step 1: Make the fixture directory**

Run: `mkdir -p spec/fixtures/spc`

- [ ] **Step 2: Capture real SPC fixtures via sandbox bypass**

These four `curl`s hit `www.spc.noaa.gov` — the gem sandbox does not allow that host, so this step must be invoked with `dangerouslyDisableSandbox: true`. Announce the bypass per the skill's guidance; the user will approve.

```bash
curl -sS https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson -o spec/fixtures/spc/day1.geojson
curl -sS https://www.spc.noaa.gov/products/outlook/day2otlk_cat.lyr.geojson -o spec/fixtures/spc/day2.geojson
curl -sS https://www.spc.noaa.gov/products/outlook/day3otlk_cat.lyr.geojson -o spec/fixtures/spc/day3.geojson
curl -sS https://www.spc.noaa.gov/climo/reports/today.csv       -o spec/fixtures/spc/today.csv
curl -sS https://www.spc.noaa.gov/climo/reports/260415.csv      -o spec/fixtures/spc/260415.csv
```

Expected: each file exists and is non-empty (`ls -la spec/fixtures/spc/`). GeoJSON files begin with `{"type":"FeatureCollection"`. CSV files begin with `Time,...` section header (even if zero rows under some sections).

- [ ] **Step 3: Write `spec/fixtures/spc/day1_empty.geojson`**

```json
{
  "type": "FeatureCollection",
  "features": []
}
```

- [ ] **Step 4: Write `spec/fixtures/spc/day1_synthetic.geojson`**

A hand-crafted fixture with two features, each a simple rectangular MultiPolygon. Coordinates are `[lon, lat]` pairs per GeoJSON convention. The MRGL rectangle covers roughly NJ+NYC; the SLGT rectangle covers a smaller inner area over NYC. A point at `(40.7, -74.0)` lies inside both — that's the overlap point used by `covers?` tests to assert highest-risk wins.

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "LABEL": "MRGL",
        "LABEL2": "Marginal Risk",
        "ISSUE_ISO": "2026-04-19T12:00:00Z",
        "VALID_ISO": "2026-04-19T12:00:00Z",
        "EXPIRE_ISO": "2026-04-20T12:00:00Z",
        "FORECASTER": "GUYER"
      },
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [[[
          [-75.0, 40.0], [-73.0, 40.0], [-73.0, 41.5], [-75.0, 41.5], [-75.0, 40.0]
        ]]]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "LABEL": "SLGT",
        "LABEL2": "Slight Risk",
        "ISSUE_ISO": "2026-04-19T12:00:00Z",
        "VALID_ISO": "2026-04-19T12:00:00Z",
        "EXPIRE_ISO": "2026-04-20T12:00:00Z",
        "FORECASTER": "GUYER"
      },
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [[[
          [-74.3, 40.5], [-73.7, 40.5], [-73.7, 41.0], [-74.3, 41.0], [-74.3, 40.5]
        ]]]
      }
    }
  ]
}
```

- [ ] **Step 5: Write `spec/fixtures/spc/today_empty.csv`**

```csv
Time,F_Scale,Location,County,State,Lat,Lon,Comments
Time,Speed,Location,County,State,Lat,Lon,Comments
Time,Size,Location,County,State,Lat,Lon,Comments
```

Three header-only sections, no data rows.

- [ ] **Step 6: Write `spec/fixtures/spc/sample.csv`**

A minimal three-section CSV with one tornado, two wind, two hail rows. Lat/lon are chosen so the `near:` tests around `(40.7, -74.0)` are deterministic: the first of each section is near NYC (should be returned); the second wind and second hail are far (Texas, Nebraska).

```csv
Time,F_Scale,Location,County,State,Lat,Lon,Comments
1842,EF2,NEWARK,ESSEX,NJ,40.73,-74.17,Brief path damage
Time,Speed,Location,County,State,Lat,Lon,Comments
1910,65,JERSEY CITY,HUDSON,NJ,40.72,-74.05,Downed trees
2000,82,LUBBOCK,LUBBOCK,TX,33.58,-101.85,EG 82
Time,Size,Location,County,State,Lat,Lon,Comments
2015,175,MANHATTAN,NEW YORK,NY,40.78,-73.97,1.75 inch hail
2100,100,OMAHA,DOUGLAS,NE,41.25,-95.93,Dime size
```

- [ ] **Step 7: Make the spec subdirectories**

Run: `mkdir -p spec/nimbus/models spec/nimbus/sources spec/nimbus/formatters`

- [ ] **Step 8: Commit fixtures + scaffolding**

```bash
git add spec/fixtures/spc spec/nimbus
git commit -m "test: capture SPC fixtures for nimbus PR 1"
```

---

## Task 1: `Nimbus::Models::Outlook` — skeleton + accessors (TDD)

**Files:**
- Create: `spec/nimbus/models/outlook_spec.rb`
- Create: `lib/skywatch/nimbus/models/outlook.rb`

- [ ] **Step 1: Write the failing test — constructor stores attrs and exposes accessors**

`spec/nimbus/models/outlook_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Models::Outlook do
  let(:attrs) do
    {
      day: 1,
      label: 'SLGT',
      valid_from: Time.utc(2026, 4, 19, 12),
      valid_to: Time.utc(2026, 4, 20, 12),
      issued_at: Time.utc(2026, 4, 19, 12),
      forecaster: 'GUYER',
      geometry: nil
    }
  end

  describe '#initialize' do
    it 'stores day, label, times, forecaster, geometry' do
      outlook = described_class.new(**attrs)
      expect(outlook.day).to eq(1)
      expect(outlook.label).to eq('SLGT')
      expect(outlook.valid_from).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.valid_to).to eq(Time.utc(2026, 4, 20, 12))
      expect(outlook.issued_at).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.forecaster).to eq('GUYER')
    end
  end
end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: FAIL with `uninitialized constant Skywatch::Nimbus::Models::Outlook`.

- [ ] **Step 3: Create the file with the minimal skeleton**

`lib/skywatch/nimbus/models/outlook.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Models
      class Outlook
        attr_reader :day, :label, :valid_from, :valid_to, :issued_at, :forecaster, :geometry

        def initialize(day:, label:, valid_from:, valid_to:, issued_at:, forecaster:, geometry:)
          @day = day
          @label = label
          @valid_from = valid_from
          @valid_to = valid_to
          @issued_at = issued_at
          @forecaster = forecaster
          @geometry = geometry
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire it into the load path**

Edit `lib/skywatch.rb`: after the mayday block (after `require_relative 'skywatch/mayday/formatters/text'`), add:

```ruby
require_relative 'skywatch/nimbus/models/outlook'
```

- [ ] **Step 5: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: PASS (1 example, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/models/outlook.rb lib/skywatch.rb spec/nimbus/models/outlook_spec.rb
git commit -m "feat: add Nimbus::Models::Outlook skeleton"
```

---

## Task 2: `Outlook` — risk classification table

**Files:**
- Modify: `spec/nimbus/models/outlook_spec.rb`
- Modify: `lib/skywatch/nimbus/models/outlook.rb`

- [ ] **Step 1: Add failing tests for `risk_level`, `risk_score`, `description`**

Append to `spec/nimbus/models/outlook_spec.rb` (inside `RSpec.describe`, after the `#initialize` describe block):

```ruby
  describe 'risk classification' do
    {
      'TSTM' => [:general_thunder, 1, 'General Thunderstorms'],
      'MRGL' => [:marginal,        2, 'Marginal Risk'],
      'SLGT' => [:slight,          3, 'Slight Risk'],
      'ENH'  => [:enhanced,        4, 'Enhanced Risk'],
      'MDT'  => [:moderate,        5, 'Moderate Risk'],
      'HIGH' => [:high,            6, 'High Risk']
    }.each do |label, (level, score, description)|
      it "maps #{label} → #{level} / #{score} / #{description.inspect}" do
        outlook = described_class.new(**attrs.merge(label: label))
        expect(outlook.risk_level).to eq(level)
        expect(outlook.risk_score).to eq(score)
        expect(outlook.description).to eq(description)
      end
    end

    it 'raises KeyError for an unknown LABEL' do
      outlook = described_class.new(**attrs.merge(label: 'XYZ'))
      expect { outlook.risk_level }.to raise_error(KeyError)
    end
  end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: FAIL with `undefined method 'risk_level'`.

- [ ] **Step 3: Add the `RISK_LEVELS` constant and three accessor methods**

Edit `lib/skywatch/nimbus/models/outlook.rb` — insert the constant + methods inside the class:

```ruby
        RISK_LEVELS = {
          'TSTM' => { level: :general_thunder, score: 1, description: 'General Thunderstorms' },
          'MRGL' => { level: :marginal,        score: 2, description: 'Marginal Risk' },
          'SLGT' => { level: :slight,          score: 3, description: 'Slight Risk' },
          'ENH'  => { level: :enhanced,        score: 4, description: 'Enhanced Risk' },
          'MDT'  => { level: :moderate,        score: 5, description: 'Moderate Risk' },
          'HIGH' => { level: :high,            score: 6, description: 'High Risk' }
        }.freeze

        def risk_level
          RISK_LEVELS.fetch(label)[:level]
        end

        def risk_score
          RISK_LEVELS.fetch(label)[:score]
        end

        def description
          RISK_LEVELS.fetch(label)[:description]
        end
```

- [ ] **Step 4: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: PASS (8 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/models/outlook.rb spec/nimbus/models/outlook_spec.rb
git commit -m "feat: classify Outlook risk label to level/score/description"
```

---

## Task 3: `Outlook.from_spc_feature` — decode GeoJSON Feature

**Files:**
- Modify: `spec/nimbus/models/outlook_spec.rb`
- Modify: `lib/skywatch/nimbus/models/outlook.rb`

- [ ] **Step 1: Add a failing test for `from_spc_feature`**

Append to `spec/nimbus/models/outlook_spec.rb`:

```ruby
  describe '.from_spc_feature' do
    let(:feature) do
      JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))
          .fetch('features').first
    end

    it 'builds an Outlook with day + parsed properties' do
      outlook = described_class.from_spc_feature(feature, day: 1)
      expect(outlook.day).to eq(1)
      expect(outlook.label).to eq('MRGL')
      expect(outlook.issued_at).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.valid_from).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.valid_to).to eq(Time.utc(2026, 4, 20, 12))
      expect(outlook.forecaster).to eq('GUYER')
    end

    it 'decodes geometry as an RGeo MultiPolygon' do
      outlook = described_class.from_spc_feature(feature, day: 1)
      expect(outlook.geometry).to be_a(RGeo::Feature::MultiPolygon)
    end

    it 'raises ParseError when geometry is missing' do
      broken = feature.merge('geometry' => nil)
      expect { described_class.from_spc_feature(broken, day: 1) }
        .to raise_error(Skywatch::ParseError)
    end
  end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: FAIL with `undefined method 'from_spc_feature'`.

- [ ] **Step 3: Add the `FACTORY` constant and the `from_spc_feature` class method**

Edit `lib/skywatch/nimbus/models/outlook.rb`. Add requires at the top, add FACTORY constant after `RISK_LEVELS`, add `from_spc_feature`:

```ruby
# frozen_string_literal: true

require 'rgeo'
require 'rgeo/geo_json'
require 'time'

module Skywatch
  module Nimbus
    module Models
      class Outlook
        FACTORY = RGeo::Cartesian.factory(srid: 4326)

        # ... existing RISK_LEVELS, attr_reader, initialize, risk_level/score/description ...

        def self.from_spc_feature(feature, day:)
          geometry_data = feature['geometry']
          raise Skywatch::ParseError, "SPC outlook feature missing geometry" if geometry_data.nil?

          props = feature['properties'] || {}
          new(
            day: day,
            label: props['LABEL'],
            valid_from: parse_time(props['VALID_ISO']),
            valid_to: parse_time(props['EXPIRE_ISO']),
            issued_at: parse_time(props['ISSUE_ISO']),
            forecaster: props['FORECASTER'],
            geometry: RGeo::GeoJSON.decode(geometry_data, geo_factory: FACTORY)
          )
        end

        def self.parse_time(value)
          return nil if value.nil? || value.empty?

          Time.parse(value).utc
        end
        private_class_method :parse_time
      end
    end
  end
end
```

(Keep the previously-added `RISK_LEVELS`, accessors, and instance methods — the above shows only what's added.)

- [ ] **Step 4: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: PASS (11 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/models/outlook.rb spec/nimbus/models/outlook_spec.rb
git commit -m "feat: build Outlook from SPC GeoJSON feature"
```

---

## Task 4: `Outlook#covers?` — point-in-polygon

**Files:**
- Modify: `spec/nimbus/models/outlook_spec.rb`
- Modify: `lib/skywatch/nimbus/models/outlook.rb`

- [ ] **Step 1: Add failing tests**

Append to `spec/nimbus/models/outlook_spec.rb`:

```ruby
  describe '#covers?' do
    let(:features) { JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))['features'] }
    let(:mrgl) { described_class.from_spc_feature(features[0], day: 1) }
    let(:slgt) { described_class.from_spc_feature(features[1], day: 1) }

    it 'is true for a point inside the polygon' do
      # NYC is inside the MRGL rectangle
      expect(mrgl.covers?(lat: 40.7, lon: -74.0)).to be(true)
    end

    it 'is false for a point outside the polygon' do
      # Middle of the Atlantic
      expect(mrgl.covers?(lat: 30.0, lon: -40.0)).to be(false)
    end

    it 'distinguishes an inner polygon from an outer one' do
      # Point inside MRGL rectangle but outside SLGT inner rectangle (edge NE corner)
      expect(mrgl.covers?(lat: 41.4, lon: -74.9)).to be(true)
      expect(slgt.covers?(lat: 41.4, lon: -74.9)).to be(false)
    end
  end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: FAIL with `undefined method 'covers?'`.

- [ ] **Step 3: Implement `covers?`**

Edit `lib/skywatch/nimbus/models/outlook.rb` — add inside the class:

```ruby
        def covers?(lat:, lon:)
          return false if geometry.nil?

          geometry.contains?(FACTORY.point(lon, lat))
        end
```

- [ ] **Step 4: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: PASS (14 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/models/outlook.rb spec/nimbus/models/outlook_spec.rb
git commit -m "feat: add Outlook#covers? point-in-polygon"
```

---

## Task 5: `Outlook#to_h` / `#to_json`

**Files:**
- Modify: `spec/nimbus/models/outlook_spec.rb`
- Modify: `lib/skywatch/nimbus/models/outlook.rb`

- [ ] **Step 1: Add failing tests**

Append to `spec/nimbus/models/outlook_spec.rb`:

```ruby
  describe '#to_h' do
    let(:feature) { JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))['features'].first }
    let(:outlook) { described_class.from_spc_feature(feature, day: 1) }

    it 'includes classification + timing + forecaster + GeoJSON geometry' do
      hash = outlook.to_h
      expect(hash[:day]).to eq(1)
      expect(hash[:label]).to eq('MRGL')
      expect(hash[:risk_level]).to eq(:marginal)
      expect(hash[:risk_score]).to eq(2)
      expect(hash[:description]).to eq('Marginal Risk')
      expect(hash[:valid_from]).to eq('2026-04-19T12:00:00Z')
      expect(hash[:valid_to]).to eq('2026-04-20T12:00:00Z')
      expect(hash[:issued_at]).to eq('2026-04-19T12:00:00Z')
      expect(hash[:forecaster]).to eq('GUYER')
      expect(hash[:geometry]).to be_a(Hash)
      expect(hash[:geometry]['type']).to eq('MultiPolygon')
    end
  end

  describe '#to_json' do
    let(:feature) { JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))['features'].first }
    let(:outlook) { described_class.from_spc_feature(feature, day: 1) }

    it 'is the JSON encoding of #to_h' do
      expect(JSON.parse(outlook.to_json)).to eq(JSON.parse(outlook.to_h.to_json))
    end
  end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: FAIL with `undefined method 'to_h'`.

- [ ] **Step 3: Implement `to_h` and `to_json`**

Edit `lib/skywatch/nimbus/models/outlook.rb` — add inside the class:

```ruby
        def to_h
          {
            day: day,
            label: label,
            risk_level: risk_level,
            risk_score: risk_score,
            description: description,
            valid_from: valid_from&.iso8601,
            valid_to: valid_to&.iso8601,
            issued_at: issued_at&.iso8601,
            forecaster: forecaster,
            geometry: geometry && RGeo::GeoJSON.encode(geometry)
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end
```

- [ ] **Step 4: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/models/outlook_spec.rb`
Expected: PASS (16 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/models/outlook.rb spec/nimbus/models/outlook_spec.rb
git commit -m "feat: serialize Outlook to hash and JSON"
```

---

## Task 6: `Nimbus::Sources::Outlook.fetch(day:)` — happy path

**Files:**
- Create: `spec/nimbus/sources/outlook_spec.rb`
- Create: `lib/skywatch/nimbus/sources/outlook.rb`

- [ ] **Step 1: Write the failing test — happy path**

`spec/nimbus/sources/outlook_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Sources::Outlook do
  subject(:source) { described_class.new }

  describe '#fetch' do
    let(:fixture) { File.read('spec/fixtures/spc/day1_synthetic.geojson') }

    before do
      stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson')
        .to_return(status: 200, body: fixture,
                   headers: { 'Content-Type' => 'application/geo+json' })
    end

    it 'returns an Outlook per feature' do
      result = source.fetch(day: 1)
      expect(result).to all(be_a(Skywatch::Nimbus::Models::Outlook))
      expect(result.map(&:label)).to eq(%w[MRGL SLGT])
    end

    it 'stamps each Outlook with the requested day' do
      result = source.fetch(day: 1)
      expect(result.map(&:day)).to all(eq(1))
    end
  end
end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/sources/outlook_spec.rb`
Expected: FAIL with `uninitialized constant Skywatch::Nimbus::Sources::Outlook`.

- [ ] **Step 3: Create the source**

`lib/skywatch/nimbus/sources/outlook.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Sources
      class Outlook
        BASE_URL = 'https://www.spc.noaa.gov'
        TTL = 3600
        VALID_DAYS = [1, 2, 3].freeze

        def initialize(client: default_client)
          @client = client
        end

        def fetch(day:)
          raise ArgumentError, "day must be 1, 2, or 3 (got #{day.inspect})" unless VALID_DAYS.include?(day)

          data = @client.get("/products/outlook/day#{day}otlk_cat.lyr.geojson", {}, ttl: TTL)
          features = data['features'] || []
          features.map { |f| Skywatch::Nimbus::Models::Outlook.from_spc_feature(f, day: day) }
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

- [ ] **Step 4: Add the require to `lib/skywatch.rb`**

Edit `lib/skywatch.rb` — add after `require_relative 'skywatch/nimbus/models/outlook'` from Task 1:

```ruby
require_relative 'skywatch/nimbus/sources/outlook'
```

- [ ] **Step 5: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/sources/outlook_spec.rb`
Expected: PASS (2 examples, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/sources/outlook.rb lib/skywatch.rb spec/nimbus/sources/outlook_spec.rb
git commit -m "feat: fetch SPC day-N outlook GeoJSON"
```

---

## Task 7: `Outlook` source — invalid day + empty features

**Files:**
- Modify: `spec/nimbus/sources/outlook_spec.rb`

- [ ] **Step 1: Add failing tests for error and empty cases**

Append to `spec/nimbus/sources/outlook_spec.rb` inside the `describe '#fetch'` block:

```ruby
    it 'raises ArgumentError for day 0, 4, 99, or nil' do
      [0, 4, 99, nil].each do |bad|
        expect { source.fetch(day: bad) }.to raise_error(ArgumentError, /day must be 1, 2, or 3/)
      end
    end

    it 'returns [] when the FeatureCollection is empty' do
      stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/day1_empty.geojson'),
                   headers: { 'Content-Type' => 'application/geo+json' })

      expect(source.fetch(day: 1)).to eq([])
    end

    it 'builds the day-2 URL correctly' do
      stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day2otlk_cat.lyr.geojson')
        .to_return(status: 200, body: fixture,
                   headers: { 'Content-Type' => 'application/geo+json' })

      expect(source.fetch(day: 2).map(&:day)).to all(eq(2))
    end
```

- [ ] **Step 2: Run the test — verify it passes (implementation already handles these)**

Run: `bundle exec rspec spec/nimbus/sources/outlook_spec.rb`
Expected: PASS (5 examples, 0 failures) — the existing implementation handles all three cases; this task locks them in with tests.

- [ ] **Step 3: Commit**

```bash
git add spec/nimbus/sources/outlook_spec.rb
git commit -m "test: pin Outlook source edge cases (invalid day, empty)"
```

---

## Task 8: `Nimbus::Models::StormReport` — skeleton + accessors (TDD)

**Files:**
- Create: `spec/nimbus/models/storm_report_spec.rb`
- Create: `lib/skywatch/nimbus/models/storm_report.rb`

- [ ] **Step 1: Write the failing test**

`spec/nimbus/models/storm_report_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Models::StormReport do
  let(:attrs) do
    {
      time: Time.utc(2026, 4, 19, 18, 42),
      type: :tornado,
      magnitude: nil,
      magnitude_raw: 'EF2',
      location: 'NEWARK',
      county: 'ESSEX',
      state: 'NJ',
      latitude: 40.73,
      longitude: -74.17,
      comments: 'Brief path damage'
    }
  end

  describe '#initialize' do
    it 'stores every attribute' do
      r = described_class.new(**attrs)
      expect(r.time).to eq(Time.utc(2026, 4, 19, 18, 42))
      expect(r.type).to eq(:tornado)
      expect(r.magnitude).to be_nil
      expect(r.magnitude_raw).to eq('EF2')
      expect(r.location).to eq('NEWARK')
      expect(r.county).to eq('ESSEX')
      expect(r.state).to eq('NJ')
      expect(r.latitude).to eq(40.73)
      expect(r.longitude).to eq(-74.17)
      expect(r.comments).to eq('Brief path damage')
    end
  end
end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/models/storm_report_spec.rb`
Expected: FAIL with `uninitialized constant Skywatch::Nimbus::Models::StormReport`.

- [ ] **Step 3: Create the model**

`lib/skywatch/nimbus/models/storm_report.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Models
      class StormReport
        attr_reader :time, :type, :magnitude, :magnitude_raw,
                    :location, :county, :state,
                    :latitude, :longitude, :comments

        def initialize(time:, type:, magnitude:, magnitude_raw:,
                       location:, county:, state:,
                       latitude:, longitude:, comments:)
          @time = time
          @type = type
          @magnitude = magnitude
          @magnitude_raw = magnitude_raw
          @location = location
          @county = county
          @state = state
          @latitude = latitude
          @longitude = longitude
          @comments = comments
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire it into the load path**

Edit `lib/skywatch.rb` — add after `require_relative 'skywatch/nimbus/sources/outlook'`:

```ruby
require_relative 'skywatch/nimbus/models/storm_report'
```

(Ordering: model must load before source. The outlook model/source pair is already in the right order; the storm_report model will go before the storm_report source added in Task 10.)

- [ ] **Step 5: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/models/storm_report_spec.rb`
Expected: PASS (1 example, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/models/storm_report.rb lib/skywatch.rb spec/nimbus/models/storm_report_spec.rb
git commit -m "feat: add Nimbus::Models::StormReport skeleton"
```

---

## Task 9: `StormReport.from_spc_row` — magnitude normalization + `wind_kt` + `to_h`

**Files:**
- Modify: `spec/nimbus/models/storm_report_spec.rb`
- Modify: `lib/skywatch/nimbus/models/storm_report.rb`

- [ ] **Step 1: Add failing tests for `from_spc_row`, `wind_kt`, `to_h`, `to_json`**

Append to `spec/nimbus/models/storm_report_spec.rb`:

```ruby
  describe '.from_spc_row' do
    let(:report_date) { Date.new(2026, 4, 19) }

    it 'parses a tornado row (F_Scale column → magnitude nil, magnitude_raw passthrough)' do
      row = %w[1842 EF2 NEWARK ESSEX NJ 40.73 -74.17] + ['Brief path damage']
      r = described_class.from_spc_row(row, type: :tornado, report_date: report_date)
      expect(r.type).to eq(:tornado)
      expect(r.time).to eq(Time.utc(2026, 4, 19, 18, 42))
      expect(r.magnitude).to be_nil
      expect(r.magnitude_raw).to eq('EF2')
      expect(r.location).to eq('NEWARK')
      expect(r.county).to eq('ESSEX')
      expect(r.state).to eq('NJ')
      expect(r.latitude).to eq(40.73)
      expect(r.longitude).to eq(-74.17)
      expect(r.comments).to eq('Brief path damage')
    end

    it 'parses a wind row (Speed column → magnitude mph Float, raw preserved)' do
      row = %w[1910 65 JERSEY\ CITY HUDSON NJ 40.72 -74.05] + ['Downed trees']
      r = described_class.from_spc_row(row, type: :wind, report_date: report_date)
      expect(r.type).to eq(:wind)
      expect(r.magnitude).to eq(65.0)
      expect(r.magnitude_raw).to eq('65')
    end

    it 'parses a hail row (Size column → inches Float, raw preserved)' do
      row = %w[2015 175 MANHATTAN NEW\ YORK NY 40.78 -73.97] + ['1.75 inch hail']
      r = described_class.from_spc_row(row, type: :hail, report_date: report_date)
      expect(r.type).to eq(:hail)
      expect(r.magnitude).to eq(1.75)
      expect(r.magnitude_raw).to eq('175')
    end

    it 'preserves magnitude_raw when Speed is unparseable (magnitude nil)' do
      row = ['1910', 'EG 70', 'JERSEY CITY', 'HUDSON', 'NJ', '40.72', '-74.05', 'Estimated gust']
      r = described_class.from_spc_row(row, type: :wind, report_date: report_date)
      expect(r.magnitude).to be_nil
      expect(r.magnitude_raw).to eq('EG 70')
    end

    it 'preserves magnitude_raw when Size is unparseable (magnitude nil)' do
      row = ['2015', 'UNK', 'MANHATTAN', 'NEW YORK', 'NY', '40.78', '-73.97', 'Size unknown']
      r = described_class.from_spc_row(row, type: :hail, report_date: report_date)
      expect(r.magnitude).to be_nil
      expect(r.magnitude_raw).to eq('UNK')
    end
  end

  describe '#wind_kt' do
    let(:report_date) { Date.new(2026, 4, 19) }

    it 'converts mph to knots for wind reports' do
      row = %w[1910 65 JERSEY\ CITY HUDSON NJ 40.72 -74.05] + ['Downed trees']
      r = described_class.from_spc_row(row, type: :wind, report_date: report_date)
      expect(r.wind_kt).to be_within(0.01).of(56.48) # 65 * 0.868976
    end

    it 'is nil when magnitude is nil (unparseable wind)' do
      row = ['1910', 'EG 70', 'JERSEY CITY', 'HUDSON', 'NJ', '40.72', '-74.05', 'Estimated gust']
      r = described_class.from_spc_row(row, type: :wind, report_date: report_date)
      expect(r.wind_kt).to be_nil
    end

    it 'is nil for non-wind report types' do
      r = described_class.new(**attrs) # tornado
      expect(r.wind_kt).to be_nil
    end
  end

  describe '#to_h and #to_json' do
    it 'to_h includes all serializable attributes with ISO-8601 time' do
      r = described_class.new(**attrs)
      hash = r.to_h
      expect(hash[:time]).to eq('2026-04-19T18:42:00Z')
      expect(hash[:type]).to eq(:tornado)
      expect(hash[:magnitude]).to be_nil
      expect(hash[:magnitude_raw]).to eq('EF2')
      expect(hash[:latitude]).to eq(40.73)
    end

    it 'to_json matches the JSON encoding of to_h' do
      r = described_class.new(**attrs)
      expect(JSON.parse(r.to_json)).to eq(JSON.parse(r.to_h.to_json))
    end
  end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/models/storm_report_spec.rb`
Expected: FAIL with `undefined method 'from_spc_row'`.

- [ ] **Step 3: Implement `from_spc_row`, `wind_kt`, `to_h`, `to_json`**

Edit `lib/skywatch/nimbus/models/storm_report.rb` — replace the file with:

```ruby
# frozen_string_literal: true

require 'date'
require 'time'
require 'json'

module Skywatch
  module Nimbus
    module Models
      class StormReport
        MPH_TO_KT = 0.868976

        attr_reader :time, :type, :magnitude, :magnitude_raw,
                    :location, :county, :state,
                    :latitude, :longitude, :comments

        def self.from_spc_row(row, type:, report_date:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          hhmm, mag_raw, location, county, state, lat, lon, comments = row
          new(
            time: parse_time(report_date, hhmm),
            type: type,
            magnitude: parse_magnitude(mag_raw, type: type),
            magnitude_raw: mag_raw.to_s,
            location: location,
            county: county,
            state: state,
            latitude: lat.to_f,
            longitude: lon.to_f,
            comments: comments.to_s
          )
        end

        def initialize(time:, type:, magnitude:, magnitude_raw:,
                       location:, county:, state:,
                       latitude:, longitude:, comments:)
          @time = time
          @type = type
          @magnitude = magnitude
          @magnitude_raw = magnitude_raw
          @location = location
          @county = county
          @state = state
          @latitude = latitude
          @longitude = longitude
          @comments = comments
        end

        def wind_kt
          return nil unless type == :wind && magnitude

          (magnitude * MPH_TO_KT).round(2)
        end

        def to_h
          {
            time: time&.iso8601,
            type: type,
            magnitude: magnitude,
            magnitude_raw: magnitude_raw,
            location: location,
            county: county,
            state: state,
            latitude: latitude,
            longitude: longitude,
            comments: comments
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end

        def self.parse_time(report_date, hhmm)
          return nil if hhmm.nil? || hhmm.empty?

          hh = hhmm[0..1].to_i
          mm = hhmm[2..3].to_i
          Time.utc(report_date.year, report_date.month, report_date.day, hh, mm)
        end

        def self.parse_magnitude(raw, type:)
          return nil if raw.nil? || raw.to_s.strip.empty?

          case type
          when :tornado then nil                 # F-scale is categorical
          when :wind
            raw.to_s.match?(/\A-?\d+(\.\d+)?\z/) ? raw.to_f : nil
          when :hail
            # SPC encodes hail as integer hundredths of an inch: "100" → 1.00
            raw.to_s.match?(/\A\d+\z/) ? raw.to_i / 100.0 : nil
          end
        end

        private_class_method :parse_time, :parse_magnitude
      end
    end
  end
end
```

- [ ] **Step 4: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/models/storm_report_spec.rb`
Expected: PASS (10 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/models/storm_report.rb spec/nimbus/models/storm_report_spec.rb
git commit -m "feat: parse SPC storm report row with type-aware magnitude"
```

---

## Task 10: `Nimbus::Sources::StormReport.fetch` — today's CSV, 3-section walk

**Files:**
- Create: `spec/nimbus/sources/storm_report_spec.rb`
- Create: `lib/skywatch/nimbus/sources/storm_report.rb`

- [ ] **Step 1: Write failing tests**

`spec/nimbus/sources/storm_report_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Sources::StormReport do
  subject(:source) { described_class.new }

  describe '#fetch default (today.csv)' do
    let(:csv) { File.read('spec/fixtures/spc/sample.csv') }

    before do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200, body: csv,
                   headers: { 'Content-Type' => 'text/csv' })
    end

    it 'returns StormReport models' do
      result = source.fetch
      expect(result).to all(be_a(Skywatch::Nimbus::Models::StormReport))
    end

    it 'splits the CSV into tornado / wind / hail sections' do
      result = source.fetch
      by_type = result.group_by(&:type).transform_values(&:count)
      expect(by_type).to eq(tornado: 1, wind: 2, hail: 2)
    end

    it 'stamps each report time against today in UTC' do
      today = Date.today
      result = source.fetch
      expect(result.map { |r| r.time.to_date }).to all(eq(today))
      expect(result.first.time).to be_utc
    end

    it 'returns [] when every section is header-only' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/today_empty.csv'),
                   headers: { 'Content-Type' => 'text/csv' })
      expect(source.fetch).to eq([])
    end
  end

  describe '#fetch with explicit date' do
    before do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/260415.csv'),
                   headers: { 'Content-Type' => 'text/csv' })
    end

    it 'builds the YYMMDD URL and stamps times against that date' do
      date = Date.new(2026, 4, 15)
      result = source.fetch(date: date)
      expect(result).to all(be_a(Skywatch::Nimbus::Models::StormReport))
      result.each { |r| expect(r.time.to_date).to eq(date) } unless result.empty?
    end
  end
end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/sources/storm_report_spec.rb`
Expected: FAIL with `uninitialized constant Skywatch::Nimbus::Sources::StormReport`.

- [ ] **Step 3: Create the source**

`lib/skywatch/nimbus/sources/storm_report.rb`:

```ruby
# frozen_string_literal: true

require 'csv'
require 'date'

module Skywatch
  module Nimbus
    module Sources
      class StormReport
        BASE_URL = 'https://www.spc.noaa.gov'
        TTL = 300
        SECTION_HEADERS = {
          'F_Scale' => :tornado,
          'Speed'   => :wind,
          'Size'    => :hail
        }.freeze

        def initialize(client: default_client)
          @client = client
        end

        def fetch(date: nil)
          path = date ? "/climo/reports/#{date.strftime('%y%m%d')}.csv" : '/climo/reports/today.csv'
          report_date = date || Date.today
          body = @client.get_raw(path, {}, ttl: TTL)
          parse_sections(body, report_date: report_date)
        end

        private

        def parse_sections(body, report_date:)
          current_type = nil
          reports = []

          CSV.parse(body) do |row|
            next if row.nil? || row.empty?

            type_for_header = section_for_header(row)
            if type_for_header
              current_type = type_for_header
              next
            end

            next if current_type.nil?

            reports << Skywatch::Nimbus::Models::StormReport.from_spc_row(
              row, type: current_type, report_date: report_date
            )
          end

          reports
        end

        def section_for_header(row)
          return nil if row.length < 2

          SECTION_HEADERS[row[1]]
        end

        def default_client
          Skywatch::Shared::Cache.new(client: Skywatch::Shared::Http.new(base_url: BASE_URL))
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire it into `lib/skywatch.rb`**

Edit `lib/skywatch.rb` — add after `require_relative 'skywatch/nimbus/models/storm_report'`:

```ruby
require_relative 'skywatch/nimbus/sources/storm_report'
```

- [ ] **Step 5: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/sources/storm_report_spec.rb`
Expected: PASS (5 examples, 0 failures).

If the `260415.csv` fixture has no rows at all (SPC returned an empty day), the `.each { ... }` block is skipped and the test still passes.

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/sources/storm_report.rb lib/skywatch.rb spec/nimbus/sources/storm_report_spec.rb
git commit -m "feat: fetch and parse SPC daily storm reports CSV"
```

---

## Task 11: `Nimbus::Formatters::Text` — `format_outlook` + `format_storm_report` (TDD)

**Files:**
- Create: `spec/nimbus/formatters/text_spec.rb`
- Create: `lib/skywatch/nimbus/formatters/text.rb`

- [ ] **Step 1: Write failing tests**

`spec/nimbus/formatters/text_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Formatters::Text do
  describe '.format_outlook' do
    let(:feature) { JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))['features'].first }
    let(:outlook) { Skywatch::Nimbus::Models::Outlook.from_spc_feature(feature, day: 1) }

    it 'renders day, label, description, validity window, forecaster' do
      line = described_class.format_outlook(outlook)
      expect(line).to include('OUTLOOK DAY 1')
      expect(line).to include('MRGL')
      expect(line).to include('Marginal Risk')
      expect(line).to include('2026-04-19 12:00Z')
      expect(line).to include('2026-04-20 12:00Z')
      expect(line).to include('GUYER')
      expect(line).to end_with("\n")
    end
  end

  describe '.format_storm_report' do
    let(:report_date) { Date.new(2026, 4, 19) }

    def report_for(type, row)
      Skywatch::Nimbus::Models::StormReport.from_spc_row(row, type: type, report_date: report_date)
    end

    it 'renders a tornado' do
      row = %w[1842 EF2 NEWARK ESSEX NJ 40.73 -74.17] + ['Brief path damage']
      line = described_class.format_storm_report(report_for(:tornado, row))
      expect(line).to include('TORNADO EF2')
      expect(line).to include('18:42Z')
      expect(line).to include('NEWARK, ESSEX NJ')
      expect(line).to include('(40.73, -74.17)')
      expect(line).to include('Brief path damage')
    end

    it 'renders wind with mph and kt' do
      row = %w[1910 65 JERSEY\ CITY HUDSON NJ 40.72 -74.05] + ['Downed trees']
      line = described_class.format_storm_report(report_for(:wind, row))
      expect(line).to include('WIND 65mph')
      expect(line).to include('kt ~56')
    end

    it 'renders hail in inches' do
      row = %w[2015 175 MANHATTAN NEW\ YORK NY 40.78 -73.97] + ['1.75 inch hail']
      line = described_class.format_storm_report(report_for(:hail, row))
      expect(line).to include('HAIL 1.75"')
    end

    it 'falls back to magnitude_raw when magnitude is unparseable' do
      row = ['1910', 'EG 70', 'JERSEY CITY', 'HUDSON', 'NJ', '40.72', '-74.05', 'Estimated gust']
      line = described_class.format_storm_report(report_for(:wind, row))
      expect(line).to include('WIND EG 70')
    end
  end
end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/formatters/text_spec.rb`
Expected: FAIL with `uninitialized constant Skywatch::Nimbus::Formatters::Text`.

- [ ] **Step 3: Implement the formatter**

`lib/skywatch/nimbus/formatters/text.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Formatters
      module Text
        def self.format_outlook(outlook)
          valid = "#{format_time(outlook.valid_from)} → #{format_time(outlook.valid_to)}"
          forecaster = outlook.forecaster ? " (forecaster #{outlook.forecaster})" : ''
          "OUTLOOK DAY #{outlook.day}: #{outlook.label} (#{outlook.description}) — valid #{valid}#{forecaster}\n"
        end

        def self.format_storm_report(report)
          time = report.time ? report.time.strftime('%H:%MZ') : '--:--Z'
          loc = "#{report.location}, #{report.county} #{report.state}"
          coords = format('(%<lat>.2f, %<lon>.2f)', lat: report.latitude, lon: report.longitude)
          comments = report.comments.to_s.strip.empty? ? '' : " — #{report.comments.strip}"

          "#{label_for(report)} @ #{time} #{loc} #{coords}#{comments}\n"
        end

        def self.format_time(time)
          return '---' if time.nil?

          time.strftime('%Y-%m-%d %H:%MZ')
        end

        def self.label_for(report)
          magnitude_part = magnitude_label(report)

          case report.type
          when :tornado then "TORNADO #{magnitude_part}".rstrip
          when :wind    then "WIND #{magnitude_part}".rstrip
          when :hail    then "HAIL #{magnitude_part}".rstrip
          end
        end

        def self.magnitude_label(report)
          case report.type
          when :tornado
            report.magnitude_raw.to_s
          when :wind
            report.magnitude ? "#{report.magnitude.to_i}mph (kt ~#{report.wind_kt.to_i})" : report.magnitude_raw.to_s
          when :hail
            report.magnitude ? format('%<m>.2f"', m: report.magnitude) : report.magnitude_raw.to_s
          end
        end

        private_class_method :format_time, :label_for, :magnitude_label
      end
    end
  end
end
```

- [ ] **Step 4: Wire it into `lib/skywatch.rb`**

Edit `lib/skywatch.rb` — add after `require_relative 'skywatch/nimbus/sources/storm_report'`:

```ruby
require_relative 'skywatch/nimbus/formatters/text'
```

- [ ] **Step 5: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/formatters/text_spec.rb`
Expected: PASS (5 examples, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/formatters/text.rb lib/skywatch.rb spec/nimbus/formatters/text_spec.rb
git commit -m "feat: render Outlook and StormReport as single-line text"
```

---

## Task 12: Convenience API — `Skywatch.outlook`

**Files:**
- Create: `spec/nimbus_spec.rb`
- Modify: `lib/skywatch.rb`

- [ ] **Step 1: Write failing tests**

`spec/nimbus_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch do
  describe '.outlook' do
    let(:fixture) { File.read('spec/fixtures/spc/day1_synthetic.geojson') }

    before do
      stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson')
        .to_return(status: 200, body: fixture,
                   headers: { 'Content-Type' => 'application/geo+json' })
    end

    it 'returns every outlook for the given day when no :at is provided' do
      result = described_class.outlook(day: 1)
      expect(result.map(&:label)).to eq(%w[MRGL SLGT])
    end

    it 'returns the highest-risk covering outlook when :at is inside both regions' do
      # (40.7, -74.0) is inside both MRGL and SLGT rectangles; SLGT wins by score
      result = described_class.outlook(day: 1, at: [40.7, -74.0])
      expect(result).to be_a(Skywatch::Nimbus::Models::Outlook)
      expect(result.label).to eq('SLGT')
    end

    it 'returns the only covering outlook when :at is inside just one region' do
      # (41.4, -74.9) is inside MRGL but outside SLGT
      result = described_class.outlook(day: 1, at: [41.4, -74.9])
      expect(result.label).to eq('MRGL')
    end

    it 'returns nil when :at is covered by no features' do
      result = described_class.outlook(day: 1, at: [30.0, -40.0])
      expect(result).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus_spec.rb`
Expected: FAIL with `undefined method 'outlook' for Skywatch:Module`.

- [ ] **Step 3: Add `Skywatch.outlook` to `lib/skywatch.rb`**

Edit `lib/skywatch.rb` — inside `class << self`, alongside the other convenience methods (e.g., after `def self.mayday ... end`, before `def self.crosswind ...`):

```ruby
    def outlook(day:, at: nil)
      outlooks = Nimbus::Sources::Outlook.new.fetch(day: day)
      return outlooks if at.nil?

      lat, lon = at
      covering = outlooks.select { |o| o.covers?(lat: lat, lon: lon) }
      covering.max_by(&:risk_score)
    end
```

- [ ] **Step 4: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus_spec.rb`
Expected: PASS (4 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch.rb spec/nimbus_spec.rb
git commit -m "feat: add Skywatch.outlook convenience API"
```

---

## Task 13: Convenience API — `Skywatch.storms`

**Files:**
- Modify: `spec/nimbus_spec.rb`
- Modify: `lib/skywatch.rb`

- [ ] **Step 1: Write failing tests**

Append to `spec/nimbus_spec.rb`:

```ruby
  describe '.storms' do
    let(:csv) { File.read('spec/fixtures/spc/sample.csv') }

    before do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200, body: csv,
                   headers: { 'Content-Type' => 'text/csv' })
    end

    it 'returns all reports when called with no filters' do
      result = described_class.storms
      expect(result.length).to eq(5) # 1 tornado + 2 wind + 2 hail
    end

    it 'filters by type when :type is given' do
      result = described_class.storms(type: :wind)
      expect(result.map(&:type).uniq).to eq([:wind])
      expect(result.length).to eq(2)
    end

    it 'filters by proximity when :near is given' do
      result = described_class.storms(near: { lat: 40.7, lon: -74.0, radius_nm: 100 })
      # The NYC-area reports (tornado, wind #1, hail #1) are within 100nm; TX and NE are not
      expect(result.length).to eq(3)
      expect(result.map(&:type)).to contain_exactly(:tornado, :wind, :hail)
    end

    it 'combines :type and :near' do
      result = described_class.storms(type: :wind, near: { lat: 40.7, lon: -74.0, radius_nm: 100 })
      expect(result.length).to eq(1)
      expect(result.first.location).to eq('JERSEY CITY')
    end

    it 'raises KeyError when :near is missing a required key' do
      expect {
        described_class.storms(near: { lat: 40.7, lon: -74.0 }) # missing :radius_nm
      }.to raise_error(KeyError)
    end

    it 'fetches YYMMDD.csv when :date is given' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
        .to_return(status: 200, body: csv, # same body is fine — we're asserting URL
                   headers: { 'Content-Type' => 'text/csv' })

      described_class.storms(date: Date.new(2026, 4, 15))
      expect(WebMock).to have_requested(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
    end
  end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus_spec.rb`
Expected: FAIL with `undefined method 'storms' for Skywatch:Module`.

- [ ] **Step 3: Add `Skywatch.storms` to `lib/skywatch.rb`**

Edit `lib/skywatch.rb` — inside `class << self`, after `def self.outlook`:

```ruby
    def storms(date: nil, type: nil, near: nil)
      reports = Nimbus::Sources::StormReport.new.fetch(date: date)
      reports = reports.select { |r| r.type == type } if type
      return reports if near.nil?

      lat = near.fetch(:lat)
      lon = near.fetch(:lon)
      radius_nm = near.fetch(:radius_nm)
      reports.select do |r|
        Radar::Analysis::Proximity.distance_nm(lat, lon, r.latitude, r.longitude) <= radius_nm
      end
    end
```

- [ ] **Step 4: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus_spec.rb`
Expected: PASS (10 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch.rb spec/nimbus_spec.rb
git commit -m "feat: add Skywatch.storms convenience API with type/near/date filters"
```

---

## Task 14: `Nimbus::CLI.outlook` command (TDD)

**Files:**
- Create: `spec/nimbus/cli_spec.rb`
- Create: `lib/skywatch/nimbus/cli.rb`
- Modify: `lib/skywatch.rb` (require for CLI load order)
- Modify: `lib/skywatch/cli.rb` (register subcommand)

- [ ] **Step 1: Write failing tests for the CLI**

`spec/nimbus/cli_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::CLI do
  before do
    stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson')
      .to_return(status: 200,
                 body: File.read('spec/fixtures/spc/day1_synthetic.geojson'),
                 headers: { 'Content-Type' => 'application/geo+json' })
  end

  describe 'outlook command' do
    it 'renders every outlook in text format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--format', 'text'])
      end
      expect(output).to include('OUTLOOK DAY 1: MRGL')
      expect(output).to include('OUTLOOK DAY 1: SLGT')
    end

    it 'renders every outlook in JSON format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--format', 'json'])
      end
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.map { |o| o['label'] }).to eq(%w[MRGL SLGT])
    end

    it 'with --at returns the highest-risk covering outlook in text format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '40.7', '-74.0', '--format', 'text'])
      end
      expect(output).to include('OUTLOOK DAY 1: SLGT')
      expect(output).not_to include('OUTLOOK DAY 1: MRGL')
    end

    it 'with --at returns the covering outlook in JSON format (single object)' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '40.7', '-74.0', '--format', 'json'])
      end
      parsed = JSON.parse(output)
      expect(parsed).to be_a(Hash)
      expect(parsed['label']).to eq('SLGT')
    end

    it 'with --at outside any feature prints a "No outlook covers" message in text format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '30.0', '-40.0', '--format', 'text'])
      end
      expect(output).to include('No outlook covers 30.0, -40.0')
    end

    it 'with --at outside any feature prints "null" in JSON format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '30.0', '-40.0', '--format', 'json'])
      end
      expect(output.strip).to eq('null')
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

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/cli_spec.rb`
Expected: FAIL with `uninitialized constant Skywatch::Nimbus::CLI`.

- [ ] **Step 3: Create the CLI with just the `outlook` command**

`lib/skywatch/nimbus/cli.rb`:

```ruby
# frozen_string_literal: true

require 'thor'
require 'json'

module Skywatch
  module Nimbus
    class CLI < Thor
      class_option :format, type: :string, enum: %w[text json],
                            desc: 'Output format (default: text on TTY, json when piped)'

      desc 'outlook DAY', 'SPC categorical convective outlook for day 1, 2, or 3'
      option :at, type: :array, desc: 'Point query: --at LAT LON — returns the covering outlook only'
      def outlook(day) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        day_i = Integer(day)
        if options[:at]
          lat, lon = options[:at].map(&:to_f)
          result = Skywatch.outlook(day: day_i, at: [lat, lon])
          print_single_outlook(result, lat: lat, lon: lon)
        else
          outlooks = Skywatch.outlook(day: day_i)
          print_outlook_list(outlooks)
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      private

      def print_outlook_list(outlooks)
        if output_format == 'json'
          puts JSON.pretty_generate(outlooks.map(&:to_h))
        else
          outlooks.each { |o| print Skywatch::Nimbus::Formatters::Text.format_outlook(o) }
        end
      end

      def print_single_outlook(outlook, lat:, lon:)
        if output_format == 'json'
          puts(outlook ? JSON.pretty_generate(outlook.to_h) : 'null')
        elsif outlook.nil?
          puts "No outlook covers #{lat}, #{lon}"
        else
          print Skywatch::Nimbus::Formatters::Text.format_outlook(outlook)
        end
      end

      def output_format
        options[:format] || ($stdout.tty? ? 'text' : 'json')
      end
    end
  end
end
```

- [ ] **Step 4: Wire it into `lib/skywatch.rb` and register the subcommand**

Edit `lib/skywatch.rb` — add before `require_relative 'skywatch/cli'` (with the other CLIs):

```ruby
require_relative 'skywatch/nimbus/cli'
```

Edit `lib/skywatch/cli.rb` — add the nimbus subcommand registration alongside weather/radar/mayday:

```ruby
    desc 'nimbus SUBCOMMAND', 'SPC convective outlooks and storm reports'
    subcommand 'nimbus', Skywatch::Nimbus::CLI
```

- [ ] **Step 5: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/cli_spec.rb`
Expected: PASS (6 examples, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/cli.rb lib/skywatch.rb lib/skywatch/cli.rb spec/nimbus/cli_spec.rb
git commit -m "feat: add 'skywatch nimbus outlook' CLI command"
```

---

## Task 15: `Nimbus::CLI.storms` command (TDD)

**Files:**
- Modify: `spec/nimbus/cli_spec.rb`
- Modify: `lib/skywatch/nimbus/cli.rb`

- [ ] **Step 1: Write failing tests**

Append to `spec/nimbus/cli_spec.rb` (inside the outer `RSpec.describe`, before the private section):

```ruby
  describe 'storms command' do
    before do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/sample.csv'),
                   headers: { 'Content-Type' => 'text/csv' })
    end

    it 'renders all reports in text format by default' do
      output = capture_stdout { described_class.start(['storms', '--format', 'text']) }
      expect(output).to include('TORNADO EF2')
      expect(output).to include('WIND 65mph')
      expect(output).to include('HAIL 1.75"')
    end

    it 'renders all reports as a JSON array' do
      output = capture_stdout { described_class.start(['storms', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.length).to eq(5)
    end

    it 'filters by --type tornado' do
      output = capture_stdout { described_class.start(['storms', '--type', 'tornado', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed.length).to eq(1)
      expect(parsed.first['type']).to eq('tornado')
    end

    it 'filters by --near and --radius' do
      output = capture_stdout do
        described_class.start(['storms', '--near', '40.7', '-74.0', '--radius', '100', '--format', 'json'])
      end
      parsed = JSON.parse(output)
      expect(parsed.length).to eq(3)
      expect(parsed.map { |r| r['state'] }).to all(satisfy { |s| %w[NJ NY].include?(s) })
    end

    it 'fetches YYMMDD.csv when --date is given' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/sample.csv'),
                   headers: { 'Content-Type' => 'text/csv' })

      capture_stdout { described_class.start(['storms', '--date', '20260415', '--format', 'json']) }
      expect(WebMock).to have_requested(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
    end

    it 'prints a friendly empty message in text mode' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/today_empty.csv'),
                   headers: { 'Content-Type' => 'text/csv' })

      output = capture_stdout { described_class.start(['storms', '--format', 'text']) }
      expect(output).to include('No storm reports')
    end

    it 'prints [] in JSON mode when empty' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/today_empty.csv'),
                   headers: { 'Content-Type' => 'text/csv' })

      output = capture_stdout { described_class.start(['storms', '--format', 'json']) }
      expect(output.strip).to eq('[]')
    end
  end
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `bundle exec rspec spec/nimbus/cli_spec.rb`
Expected: FAIL with `Unknown command 'storms'`.

- [ ] **Step 3: Implement the `storms` command**

Edit `lib/skywatch/nimbus/cli.rb` — add inside the class, above the `private` keyword:

```ruby
      desc 'storms', 'Recent SPC storm reports (tornado / wind / hail)'
      option :date,   type: :string,  desc: 'Report date YYYYMMDD (default: today)'
      option :type,   type: :string,  enum: %w[tornado wind hail],
                                      desc: 'Filter to one report type'
      option :near,   type: :array,   desc: 'Point filter: --near LAT LON'
      option :radius, type: :numeric, default: 100, desc: 'Radius in NM (used with --near)'
      def storms # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        date = options[:date] ? Date.strptime(options[:date], '%Y%m%d') : nil
        type = options[:type]&.to_sym
        near = if options[:near]
                 lat, lon = options[:near].map(&:to_f)
                 { lat: lat, lon: lon, radius_nm: options[:radius] }
               end

        reports = Skywatch.storms(date: date, type: type, near: near)
        print_storm_reports(reports)
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end
```

And add the helper to the `private` section:

```ruby
      def print_storm_reports(reports)
        if output_format == 'json'
          puts(reports.empty? ? '[]' : JSON.pretty_generate(reports.map(&:to_h)))
        elsif reports.empty?
          puts 'No storm reports'
        else
          reports.each { |r| print Skywatch::Nimbus::Formatters::Text.format_storm_report(r) }
        end
      end
```

Also add `require 'date'` to the top of `lib/skywatch/nimbus/cli.rb` (below `require 'json'`).

- [ ] **Step 4: Re-run the test — verify it passes**

Run: `bundle exec rspec spec/nimbus/cli_spec.rb`
Expected: PASS (13 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/cli.rb spec/nimbus/cli_spec.rb
git commit -m "feat: add 'skywatch nimbus storms' CLI command"
```

---

## Task 16: Full-suite + rubocop check

**Files:**
- (read-only) everything under `spec/` and `lib/`

- [ ] **Step 1: Run the full spec suite**

Run: `bundle exec rspec`
Expected: all specs pass (existing + new). Existing test counts should be unchanged.

- [ ] **Step 2: Run RuboCop**

Run: `bundle exec rubocop`
Expected: 0 offenses. If there are offenses in the new Nimbus files, fix them (prefer rewriting over `rubocop:disable`; use per-method disables only for metrics cops that the rest of the gem already disables — `Metrics/AbcSize`, `Metrics/MethodLength`, `Metrics/PerceivedComplexity`).

- [ ] **Step 3: Run the default rake task**

Run: `bundle exec rake`
Expected: spec + rubocop both succeed.

- [ ] **Step 4: Commit if any rubocop fixes were made**

```bash
git add -p
git commit -m "style: satisfy rubocop for nimbus domain"
```

(Skip if no changes.)

---

## Task 17: Document in `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add the new CLI invocations to the CLI Usage section**

Edit `CLAUDE.md` — inside the `## CLI Usage` code fence, add lines for the two new commands. Place them after the `skywatch mayday near ...` line and before the `skywatch radar track ...` line:

```
skywatch nimbus outlook 1
skywatch nimbus outlook 1 --at 40.688 -74.174
skywatch nimbus storms
skywatch nimbus storms --type tornado --near 40.688 -74.174 --radius 100
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document nimbus CLI in CLAUDE.md"
```

---

## Task 18: Live smoke test (optional, post-implementation)

**Files:**
- (no file changes)

- [ ] **Step 1: Hit live SPC via the built CLI**

This step actually calls `www.spc.noaa.gov` — the gem has no sandbox policy for runtime, but this session's Bash sandbox blocks that host. Invoke with `dangerouslyDisableSandbox: true` or skip this task.

```bash
bundle exec exe/skywatch nimbus outlook 1 --format json | head -c 400
bundle exec exe/skywatch nimbus storms --format json | head -c 400
```

Expected: well-formed JSON in both cases; no crash. If SPC returns an empty FeatureCollection or a headers-only CSV (slow news day), we'll see `[]` — that's a pass too.

- [ ] **Step 2: (No commit)**

Smoke test output is not committed.

---

## Task 19: Open the PR

**Files:**
- (no file changes)

- [ ] **Step 1: Push the branch**

```bash
git push -u origin nimbus
```

- [ ] **Step 2: Open the PR**

Use the skill: **commit-commands:commit-push-pr** OR run `gh pr create` manually. PR title: `Add Nimbus PR 1 — SPC outlooks and storm reports`. PR body should mention:

- New `skywatch nimbus outlook DAY [--at LAT LON]` and `skywatch nimbus storms [--date / --type / --near / --radius]` commands
- New `Skywatch.outlook` and `Skywatch.storms` convenience methods
- Design and plan docs in `docs/superpowers/`
- Test plan: `bundle exec rake` is green; live smoke verified against SPC

- [ ] **Step 3: Confirm CI is green before requesting review**

---

## Self-review notes (pre-delivery)

Applied checklist verbatim before handoff:

1. **Spec coverage.** Every spec section is claimed by a task:
   - In-scope 1 (Outlook model) → Tasks 1–5
   - In-scope 2 (StormReport model) → Tasks 8–9
   - In-scope 3 (Outlook source) → Tasks 6–7
   - In-scope 4 (StormReport source) → Task 10
   - In-scope 5 (Text formatters) → Task 11
   - In-scope 6 (CLI) → Tasks 14–15
   - In-scope 7 (Convenience API) → Tasks 12–13
   - Fixture capture via sandbox bypass → Task 0
   - Full-suite + rubocop → Task 16
   - CLAUDE.md docs → Task 17
   - Live smoke → Task 18
   - PR → Task 19

2. **Placeholder scan.** No "TBD", "implement later", or shape-only steps. Every code-changing step ships the actual code.

3. **Type consistency.**
   - `Skywatch::Nimbus::Models::Outlook` — `day/label/valid_from/valid_to/issued_at/forecaster/geometry` + derived `risk_level/risk_score/description` + `covers?(lat:, lon:)`. Used consistently in source (Task 6), formatter (Task 11), convenience API (Task 12), and CLI (Task 14).
   - `Skywatch::Nimbus::Models::StormReport` — `time/type/magnitude/magnitude_raw/location/county/state/latitude/longitude/comments` + `wind_kt`. Used consistently in source (Task 10), formatter (Task 11), convenience API (Task 13), and CLI (Task 15).
   - `Skywatch.outlook(day:, at:)` — keyword args match CLI option parsing in Task 14.
   - `Skywatch.storms(date:, type:, near:)` — `near:` is always `{lat:, lon:, radius_nm:}`; CLI in Task 15 constructs this hash.
   - Spec's "Deferred to the plan" item about `Shared::Geometry.distance_nm` is resolved: `Radar::Analysis::Proximity.distance_nm` already exists publicly, so the convenience API calls it directly — no refactor needed.

4. **No surprises.**
   - `rgeo-geojson` decodes SPC GeoJSON MultiPolygons against a `RGeo::Cartesian.factory(srid: 4326)` — Cartesian is the factory that supports `contains?` reliably.
   - CSV 3-section parse: the `SECTION_HEADERS` map keys on the second column (`F_Scale` / `Speed` / `Size`) — that's the column that distinguishes the three sections; column 1 is always `Time`.
   - `Skywatch::Nimbus::CLI` follows the `class_option :format` + `output_format` TTY-autodetect pattern used by `Briefer::CLI` and `Mayday::CLI` verbatim.
