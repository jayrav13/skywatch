# Phase 3: Hazards & Area Forecasts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add SIGMET, G-AIRMET, TFR, and Area Forecast Discussion data sources with rgeo polygon geometry support.

**Architecture:** Four new model+source pairs following the existing pattern (Metar, TAF, PIREP). A shared `Geometry` module wraps rgeo for polygon construction. TFR source uses its own Faraday connection (different base URL). AFD source uses a new `get_raw` HTTP client method for non-JSON responses.

**Tech Stack:** rgeo ~> 3.0, rgeo-geojson ~> 2.0, Faraday (existing)

---

### Task 1: Add rgeo Dependencies

**Files:**
- Modify: `briefer.gemspec`

- [ ] **Step 1: Add rgeo and rgeo-geojson to gemspec**

Add after the `thor` dependency line in `briefer.gemspec`:

```ruby
spec.add_dependency "rgeo", "~> 3.0"
spec.add_dependency "rgeo-geojson", "~> 2.0"
```

- [ ] **Step 2: Install dependencies**

Run: `bundle install`
Expected: Fetching rgeo and rgeo-geojson gems, Bundle complete

- [ ] **Step 3: Verify require works**

Run: `bundle exec ruby -e "require 'rgeo'; require 'rgeo/geo_json'; puts RGeo::Geographic.spherical_factory(srid: 4326).point(-74.28, 40.87)"`
Expected: Prints an RGeo point object, no errors

- [ ] **Step 4: Commit**

```bash
git add briefer.gemspec Gemfile.lock
git commit -m "Add rgeo and rgeo-geojson dependencies"
```

---

### Task 2: Geometry Module

**Files:**
- Create: `lib/briefer/geometry.rb`
- Create: `spec/geometry_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/geometry_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Geometry do
  describe ".polygon_from_coords" do
    it "builds an RGeo polygon from Position array" do
      coords = [
        Briefer::Models::Position.new(lat: 40.0, lon: -74.0),
        Briefer::Models::Position.new(lat: 41.0, lon: -74.0),
        Briefer::Models::Position.new(lat: 41.0, lon: -73.0),
        Briefer::Models::Position.new(lat: 40.0, lon: -74.0)
      ]
      polygon = described_class.polygon_from_coords(coords)
      expect(polygon).to be_a(RGeo::Geographic::SphericalPolygonImpl)
    end

    it "returns nil for fewer than 3 points" do
      coords = [
        Briefer::Models::Position.new(lat: 40.0, lon: -74.0),
        Briefer::Models::Position.new(lat: 41.0, lon: -74.0)
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
      expect(point.longitude).to be_within(0.001).of(-74.28)
    end
  end

  describe "FACTORY" do
    it "is a spherical factory with SRID 4326" do
      expect(described_class::FACTORY.srid).to eq(4326)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/geometry_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Geometry`

- [ ] **Step 3: Write the implementation**

Create `lib/briefer/geometry.rb`:

```ruby
# frozen_string_literal: true

require "rgeo"

module Briefer
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
```

- [ ] **Step 4: Add require to `lib/briefer.rb`**

Add after the `require_relative "briefer/analysis/crosswind_calculator"` line:

```ruby
require_relative "briefer/geometry"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/geometry_spec.rb`
Expected: 4 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/geometry.rb spec/geometry_spec.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/geometry.rb spec/geometry_spec.rb lib/briefer.rb
git commit -m "Add Geometry module with rgeo polygon and point helpers"
```

---

### Task 3: Sigmet Model

**Files:**
- Create: `spec/fixtures/sigmets/convective.json`
- Create: `lib/briefer/models/sigmet.rb`
- Create: `spec/models/sigmet_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Create SIGMET fixture**

Create `spec/fixtures/sigmets/convective.json`:

```json
{
  "icaoId": "KKCI",
  "alphaChar": "E",
  "seriesId": "3E",
  "receiptTime": "2026-03-29T01:50:55.441Z",
  "creationTime": "2026-03-29T01:55:00.000Z",
  "validTimeFrom": 1774749300,
  "validTimeTo": 1774752899,
  "airSigmetType": "SIGMET",
  "hazard": "CONVECTIVE",
  "altitudeHi1": 32000,
  "altitudeHi2": 32000,
  "altitudeLow1": null,
  "altitudeLow2": null,
  "movementDir": 10,
  "movementSpd": 15,
  "rawAirSigmet": "WSUS31 KKCI 290155\nSIGE \nCONVECTIVE SIGMET 3E\nVALID UNTIL 0355Z\nFL AND CSTL WTRS\nFROM 30NNE TRV-70ENE PBI-20ENE PBI-20W TRV-30NNE TRV\nAREA TS MOV FROM 01015KT. TOPS TO FL320.",
  "postProcessFlag": 0,
  "severity": 5,
  "coords": [
    {"lat": 28.145, "lon": -80.272},
    {"lat": 27.122, "lon": -78.878},
    {"lat": 26.807, "lon": -79.746},
    {"lat": 27.679, "lon": -80.865},
    {"lat": 28.145, "lon": -80.272}
  ]
}
```

- [ ] **Step 2: Write the failing test**

Create `spec/models/sigmet_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::Sigmet do
  let(:data) { JSON.parse(File.read("spec/fixtures/sigmets/convective.json")) }

  describe ".from_awc" do
    subject(:sigmet) { described_class.from_awc(data) }

    it "parses identification fields" do
      expect(sigmet.series_id).to eq("3E")
      expect(sigmet.issuing_center).to eq("KKCI")
      expect(sigmet.sigmet_type).to eq(:sigmet)
      expect(sigmet.hazard).to eq("CONVECTIVE")
      expect(sigmet.severity).to eq(5)
    end

    it "parses time fields" do
      expect(sigmet.valid_from).to be_a(Time)
      expect(sigmet.valid_from.utc?).to be(true)
      expect(sigmet.valid_to).to be_a(Time)
    end

    it "parses altitude fields" do
      expect(sigmet.altitude_hi_ft).to eq(32_000)
      expect(sigmet.altitude_low_ft).to be_nil
    end

    it "parses movement" do
      expect(sigmet.movement_dir_deg).to eq(10)
      expect(sigmet.movement_speed_kt).to eq(15)
    end

    it "parses coords as Position array" do
      expect(sigmet.coords).to all(be_a(Briefer::Models::Position))
      expect(sigmet.coords.size).to eq(5)
      expect(sigmet.coords.first.lat).to eq(28.145)
    end

    it "parses raw text" do
      expect(sigmet.raw).to include("CONVECTIVE SIGMET 3E")
    end
  end

  describe "#polygon" do
    subject(:sigmet) { described_class.from_awc(data) }

    it "returns an RGeo polygon" do
      expect(sigmet.polygon).to be_a(RGeo::Geographic::SphericalPolygonImpl)
    end
  end

  describe "#to_h" do
    subject(:sigmet) { described_class.from_awc(data) }

    it "returns a hash with key fields" do
      hash = sigmet.to_h
      expect(hash[:series_id]).to eq("3E")
      expect(hash[:hazard]).to eq("CONVECTIVE")
      expect(hash[:coords]).to be_an(Array)
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/models/sigmet_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models::Sigmet`

- [ ] **Step 4: Write the implementation**

Create `lib/briefer/models/sigmet.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Models
    class Sigmet
      attr_reader :series_id, :issuing_center, :sigmet_type, :hazard, :severity,
                  :raw, :valid_from, :valid_to,
                  :altitude_hi_ft, :altitude_low_ft,
                  :movement_dir_deg, :movement_speed_kt, :coords

      def self.from_awc(data) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        new(
          series_id: data["seriesId"],
          issuing_center: data["icaoId"],
          sigmet_type: data["airSigmetType"]&.downcase&.to_sym || :sigmet,
          hazard: data["hazard"],
          severity: data["severity"],
          raw: data["rawAirSigmet"],
          valid_from: Time.at(data["validTimeFrom"]).utc,
          valid_to: Time.at(data["validTimeTo"]).utc,
          altitude_hi_ft: data["altitudeHi1"],
          altitude_low_ft: data["altitudeLow1"],
          movement_dir_deg: data["movementDir"],
          movement_speed_kt: data["movementSpd"],
          coords: parse_coords(data["coords"])
        )
      end

      def initialize(**attrs) # rubocop:disable Metrics/MethodLength
        @series_id = attrs[:series_id]
        @issuing_center = attrs[:issuing_center]
        @sigmet_type = attrs[:sigmet_type]
        @hazard = attrs[:hazard]
        @severity = attrs[:severity]
        @raw = attrs[:raw]
        @valid_from = attrs[:valid_from]
        @valid_to = attrs[:valid_to]
        @altitude_hi_ft = attrs[:altitude_hi_ft]
        @altitude_low_ft = attrs[:altitude_low_ft]
        @movement_dir_deg = attrs[:movement_dir_deg]
        @movement_speed_kt = attrs[:movement_speed_kt]
        @coords = attrs[:coords]
      end

      def polygon
        Geometry.polygon_from_coords(coords)
      end

      def to_h # rubocop:disable Metrics/MethodLength
        {
          series_id: series_id, issuing_center: issuing_center,
          sigmet_type: sigmet_type, hazard: hazard, severity: severity,
          raw: raw,
          valid_from: valid_from&.iso8601, valid_to: valid_to&.iso8601,
          altitude_hi_ft: altitude_hi_ft, altitude_low_ft: altitude_low_ft,
          movement_dir_deg: movement_dir_deg, movement_speed_kt: movement_speed_kt,
          coords: coords&.map { |c| { lat: c.lat, lon: c.lon } }
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end

      def self.parse_coords(coords_data)
        return [] if coords_data.nil?

        coords_data.map { |c| Position.new(lat: c["lat"].to_f, lon: c["lon"].to_f) }
      end

      private_class_method :parse_coords
    end
  end
end
```

- [ ] **Step 5: Add require to `lib/briefer.rb`**

Add after `require_relative "briefer/models/winds_aloft"`:

```ruby
require_relative "briefer/models/sigmet"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/sigmet_spec.rb`
Expected: 7 examples, 0 failures

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/sigmet.rb spec/models/sigmet_spec.rb`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/models/sigmet.rb spec/models/sigmet_spec.rb \
  spec/fixtures/sigmets/ lib/briefer.rb
git commit -m "Add Sigmet model with AWC JSON parsing and polygon geometry"
```

---

### Task 4: Airmet Model

**Files:**
- Create: `spec/fixtures/airmets/sierra.json`
- Create: `lib/briefer/models/airmet.rb`
- Create: `spec/models/airmet_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Create G-AIRMET fixture**

Create `spec/fixtures/airmets/sierra.json`:

```json
{
  "tag": "3E",
  "forecastHour": 6,
  "validTime": "2026-03-29T03:00:00.000Z",
  "hazard": "MT_OBSC",
  "geometryType": "AREA",
  "latlonpairs": 13,
  "frequency": "",
  "severity": "",
  "due_to": "MTNS OBSC BY CLDS/BR",
  "status": "",
  "top": "",
  "base": "",
  "fzltop": "",
  "fzlbase": "",
  "level": "",
  "receiptTime": 1774737035,
  "issueTime": 1774737000,
  "expireTime": 1774753200,
  "product": "SIERRA",
  "geom": "AREA",
  "coords": [
    {"lat": "47.62", "lon": "-69.30"},
    {"lat": "45.66", "lon": "-68.59"},
    {"lat": "44.69", "lon": "-70.87"},
    {"lat": "43.61", "lon": "-72.72"},
    {"lat": "43.80", "lon": "-73.18"},
    {"lat": "44.93", "lon": "-74.57"},
    {"lat": "45.18", "lon": "-71.49"},
    {"lat": "47.62", "lon": "-69.30"}
  ]
}
```

- [ ] **Step 2: Write the failing test**

Create `spec/models/airmet_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::Airmet do
  let(:data) { JSON.parse(File.read("spec/fixtures/airmets/sierra.json")) }

  describe ".from_awc" do
    subject(:airmet) { described_class.from_awc(data) }

    it "parses identification fields" do
      expect(airmet.tag).to eq("3E")
      expect(airmet.product).to eq(:sierra)
      expect(airmet.hazard).to eq("MT_OBSC")
      expect(airmet.forecast_hour).to eq(6)
    end

    it "parses cause text" do
      expect(airmet.due_to).to eq("MTNS OBSC BY CLDS/BR")
    end

    it "converts blank strings to nil" do
      expect(airmet.severity).to be_nil
      expect(airmet.top).to be_nil
      expect(airmet.base).to be_nil
      expect(airmet.freeze_level_top).to be_nil
    end

    it "parses time fields" do
      expect(airmet.valid_at).to be_a(Time)
      expect(airmet.valid_at.utc?).to be(true)
      expect(airmet.issued_at).to be_a(Time)
      expect(airmet.expires_at).to be_a(Time)
    end

    it "parses coords with string lat/lon" do
      expect(airmet.coords).to all(be_a(Briefer::Models::Position))
      expect(airmet.coords.first.lat).to be_within(0.01).of(47.62)
      expect(airmet.coords.first.lon).to be_within(0.01).of(-69.30)
    end
  end

  describe "#polygon" do
    subject(:airmet) { described_class.from_awc(data) }

    it "returns an RGeo polygon" do
      expect(airmet.polygon).to be_a(RGeo::Geographic::SphericalPolygonImpl)
    end
  end

  describe "#to_h" do
    subject(:airmet) { described_class.from_awc(data) }

    it "returns a hash with key fields" do
      hash = airmet.to_h
      expect(hash[:tag]).to eq("3E")
      expect(hash[:product]).to eq(:sierra)
      expect(hash[:hazard]).to eq("MT_OBSC")
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/models/airmet_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models::Airmet`

- [ ] **Step 4: Write the implementation**

Create `lib/briefer/models/airmet.rb`:

```ruby
# frozen_string_literal: true

require "time"

module Briefer
  module Models
    class Airmet
      attr_reader :tag, :product, :hazard, :due_to, :severity,
                  :forecast_hour, :valid_at, :issued_at, :expires_at,
                  :top, :base, :freeze_level_top, :freeze_level_base, :coords

      def self.from_awc(data) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        new(
          tag: data["tag"],
          product: data["product"]&.downcase&.to_sym,
          hazard: data["hazard"],
          due_to: blank_to_nil(data["due_to"]),
          severity: blank_to_nil(data["severity"]),
          forecast_hour: data["forecastHour"],
          valid_at: Time.parse(data["validTime"]).utc,
          issued_at: Time.at(data["issueTime"]).utc,
          expires_at: Time.at(data["expireTime"]).utc,
          top: blank_to_nil(data["top"]),
          base: blank_to_nil(data["base"]),
          freeze_level_top: blank_to_nil(data["fzltop"]),
          freeze_level_base: blank_to_nil(data["fzlbase"]),
          coords: parse_coords(data["coords"])
        )
      end

      def initialize(**attrs) # rubocop:disable Metrics/MethodLength
        @tag = attrs[:tag]
        @product = attrs[:product]
        @hazard = attrs[:hazard]
        @due_to = attrs[:due_to]
        @severity = attrs[:severity]
        @forecast_hour = attrs[:forecast_hour]
        @valid_at = attrs[:valid_at]
        @issued_at = attrs[:issued_at]
        @expires_at = attrs[:expires_at]
        @top = attrs[:top]
        @base = attrs[:base]
        @freeze_level_top = attrs[:freeze_level_top]
        @freeze_level_base = attrs[:freeze_level_base]
        @coords = attrs[:coords]
      end

      def polygon
        Geometry.polygon_from_coords(coords)
      end

      def to_h # rubocop:disable Metrics/MethodLength
        {
          tag: tag, product: product, hazard: hazard, due_to: due_to,
          severity: severity, forecast_hour: forecast_hour,
          valid_at: valid_at&.iso8601, issued_at: issued_at&.iso8601,
          expires_at: expires_at&.iso8601,
          top: top, base: base,
          freeze_level_top: freeze_level_top, freeze_level_base: freeze_level_base,
          coords: coords&.map { |c| { lat: c.lat, lon: c.lon } }
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end

      def self.blank_to_nil(value)
        return nil if value.nil? || (value.is_a?(String) && value.strip.empty?)

        value
      end

      def self.parse_coords(coords_data)
        return [] if coords_data.nil?

        coords_data.map { |c| Position.new(lat: c["lat"].to_f, lon: c["lon"].to_f) }
      end

      private_class_method :blank_to_nil, :parse_coords
    end
  end
end
```

- [ ] **Step 5: Add require to `lib/briefer.rb`**

Add after `require_relative "briefer/models/sigmet"`:

```ruby
require_relative "briefer/models/airmet"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/airmet_spec.rb`
Expected: 6 examples, 0 failures

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/airmet.rb spec/models/airmet_spec.rb`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/models/airmet.rb spec/models/airmet_spec.rb \
  spec/fixtures/airmets/ lib/briefer.rb
git commit -m "Add Airmet model with G-AIRMET parsing and polygon geometry"
```

---

### Task 5: Tfr Model

**Files:**
- Create: `spec/fixtures/tfrs/feature_collection.json`
- Create: `lib/briefer/models/tfr.rb`
- Create: `spec/models/tfr_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Create TFR fixture**

Create `spec/fixtures/tfrs/feature_collection.json`:

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": "V_TFR_LOC.6/3475",
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [-121.65169634, 39.13396987],
            [-121.64835586, 39.1050079],
            [-121.63861653, 39.07693711],
            [-121.62278111, 39.05060886],
            [-121.60133575, 39.0268208],
            [-121.65169634, 39.13396987]
          ]
        ]
      },
      "geometry_name": "SHAPE",
      "properties": {
        "GID": 223040,
        "CNS_LOCATION_ID": "ZOA",
        "NOTAM_KEY": "6/3475-1-FDC-F",
        "TITLE": "Beale AFB, CA, Sunday, March 8, 2026 through Sunday, November 1, 2026 Local",
        "LAST_MODIFICATION_DATETIME": "202603041739",
        "STATE": "CA",
        "LEGAL": "SECURITY"
      }
    }
  ],
  "totalFeatures": 84,
  "numberMatched": 84,
  "numberReturned": 1,
  "timeStamp": "2026-03-29T03:04:24.881Z"
}
```

- [ ] **Step 2: Write the failing test**

Create `spec/models/tfr_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::Tfr do
  let(:geojson) { JSON.parse(File.read("spec/fixtures/tfrs/feature_collection.json")) }
  let(:feature) { geojson["features"].first }

  describe ".from_geojson_feature" do
    subject(:tfr) { described_class.from_geojson_feature(feature) }

    it "parses properties" do
      expect(tfr.notam_key).to eq("6/3475-1-FDC-F")
      expect(tfr.title).to include("Beale AFB")
      expect(tfr.state).to eq("CA")
      expect(tfr.type).to eq("SECURITY")
      expect(tfr.center_id).to eq("ZOA")
    end

    it "parses last_modified" do
      expect(tfr.last_modified).to be_a(Time)
      expect(tfr.last_modified.year).to eq(2026)
      expect(tfr.last_modified.month).to eq(3)
    end

    it "parses GeoJSON coords (lon,lat) into Position (lat,lon)" do
      expect(tfr.coords).to all(be_a(Briefer::Models::Position))
      expect(tfr.coords.first.lat).to be_within(0.01).of(39.13)
      expect(tfr.coords.first.lon).to be_within(0.01).of(-121.65)
    end
  end

  describe "#polygon" do
    subject(:tfr) { described_class.from_geojson_feature(feature) }

    it "returns an RGeo polygon" do
      expect(tfr.polygon).to be_a(RGeo::Geographic::SphericalPolygonImpl)
    end
  end

  describe "#to_h" do
    subject(:tfr) { described_class.from_geojson_feature(feature) }

    it "returns a hash with key fields" do
      hash = tfr.to_h
      expect(hash[:notam_key]).to eq("6/3475-1-FDC-F")
      expect(hash[:state]).to eq("CA")
      expect(hash[:type]).to eq("SECURITY")
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/models/tfr_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models::Tfr`

- [ ] **Step 4: Write the implementation**

Create `lib/briefer/models/tfr.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Models
    class Tfr
      attr_reader :notam_key, :title, :state, :type, :center_id,
                  :last_modified, :coords

      def self.from_geojson_feature(feature) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        props = feature["properties"]
        geom = feature["geometry"]

        new(
          notam_key: props["NOTAM_KEY"],
          title: props["TITLE"],
          state: props["STATE"],
          type: props["LEGAL"],
          center_id: props["CNS_LOCATION_ID"],
          last_modified: parse_datetime(props["LAST_MODIFICATION_DATETIME"]),
          coords: parse_geojson_coords(geom)
        )
      end

      def initialize(**attrs)
        @notam_key = attrs[:notam_key]
        @title = attrs[:title]
        @state = attrs[:state]
        @type = attrs[:type]
        @center_id = attrs[:center_id]
        @last_modified = attrs[:last_modified]
        @coords = attrs[:coords]
      end

      def polygon
        Geometry.polygon_from_coords(coords)
      end

      def to_h
        {
          notam_key: notam_key, title: title, state: state, type: type,
          center_id: center_id, last_modified: last_modified&.iso8601,
          coords: coords&.map { |c| { lat: c.lat, lon: c.lon } }
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end

      def self.parse_datetime(str)
        return nil if str.nil? || str.empty?

        Time.utc(str[0, 4].to_i, str[4, 2].to_i, str[6, 2].to_i, str[8, 2].to_i, str[10, 2].to_i)
      end

      def self.parse_geojson_coords(geom)
        return [] if geom.nil? || geom["coordinates"].nil?

        # GeoJSON is [lon, lat], Position is (lat, lon)
        geom["coordinates"][0].map { |lon, lat| Position.new(lat: lat, lon: lon) }
      end

      private_class_method :parse_datetime, :parse_geojson_coords
    end
  end
end
```

- [ ] **Step 5: Add require to `lib/briefer.rb`**

Add after `require_relative "briefer/models/airmet"`:

```ruby
require_relative "briefer/models/tfr"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/tfr_spec.rb`
Expected: 5 examples, 0 failures

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/tfr.rb spec/models/tfr_spec.rb`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/models/tfr.rb spec/models/tfr_spec.rb \
  spec/fixtures/tfrs/ lib/briefer.rb
git commit -m "Add Tfr model with GeoJSON parsing and polygon geometry"
```

---

### Task 6: ForecastDiscussion Model

**Files:**
- Create: `spec/fixtures/afd/kbox.txt`
- Create: `lib/briefer/models/forecast_discussion.rb`
- Create: `spec/models/forecast_discussion_spec.rb`
- Modify: `lib/briefer.rb`

- [ ] **Step 1: Create AFD fixture**

Create `spec/fixtures/afd/kbox.txt`:

```
(EXTRACTED FROM FXUS61 KBOX 282326)
National Weather Service Boston/Norton MA
726 PM EDT Sat Mar 28 2026

Low - less than 30 percent.
Moderate - 30 to 60 percent.
High - greater than 60 percent.

00Z TAF Update...

Tonight through Sunday night...High Confidence

Diminishing wind overnight becoming SW by daybreak then gusts
to 25 kt developing in the afternoon. S-SW wind 5-15 kt Sun
night.

KBOS Terminal...High confidence in TAF.

KBDL Terminal...High confidence in TAF.
```

- [ ] **Step 2: Write the failing test**

Create `spec/models/forecast_discussion_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Models::ForecastDiscussion do
  let(:text) { File.read("spec/fixtures/afd/kbox.txt") }

  describe ".from_raw" do
    subject(:afd) { described_class.from_raw(wfo: "KBOX", text: text) }

    it "stores the WFO identifier" do
      expect(afd.wfo).to eq("KBOX")
    end

    it "stores the full text" do
      expect(afd.text).to include("00Z TAF Update")
      expect(afd.text).to include("KBOS Terminal")
    end

    it "parses issued_at from header" do
      expect(afd.issued_at).to be_a(Time)
    end
  end

  describe "#to_h" do
    subject(:afd) { described_class.from_raw(wfo: "KBOX", text: text) }

    it "returns a hash with key fields" do
      hash = afd.to_h
      expect(hash[:wfo]).to eq("KBOX")
      expect(hash[:text]).to include("TAF Update")
      expect(hash[:issued_at]).not_to be_nil
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/models/forecast_discussion_spec.rb`
Expected: FAIL — `uninitialized constant Briefer::Models::ForecastDiscussion`

- [ ] **Step 4: Write the implementation**

Create `lib/briefer/models/forecast_discussion.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Models
    class ForecastDiscussion
      attr_reader :wfo, :text, :issued_at

      def self.from_raw(wfo:, text:)
        new(wfo: wfo, text: text, issued_at: parse_issued_at(text))
      end

      def initialize(wfo:, text:, issued_at:)
        @wfo = wfo
        @text = text
        @issued_at = issued_at
      end

      def to_h
        { wfo: wfo, text: text, issued_at: issued_at&.iso8601 }
      end

      def to_json(*)
        to_h.to_json(*)
      end

      def self.parse_issued_at(text)
        # Look for lines like "726 PM EDT Sat Mar 28 2026"
        return Time.now.utc unless text.match?(/\d{3,4}\s+[AP]M\s+\w+\s+\w+\s+\w+\s+\d+\s+\d{4}/)

        match = text.match(/(\d{3,4}\s+[AP]M\s+\w+\s+\w+\s+\w+\s+\d+\s+\d{4})/)
        # Strip timezone abbreviation for Time.parse compatibility
        time_str = match[1].sub(/\s+[A-Z]{2,4}\s+/, " ")
        Time.parse(time_str).utc
      rescue ArgumentError
        Time.now.utc
      end

      private_class_method :parse_issued_at
    end
  end
end
```

- [ ] **Step 5: Add require to `lib/briefer.rb`**

Add after `require_relative "briefer/models/tfr"`:

```ruby
require_relative "briefer/models/forecast_discussion"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/forecast_discussion_spec.rb`
Expected: 4 examples, 0 failures

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop lib/briefer/models/forecast_discussion.rb spec/models/forecast_discussion_spec.rb`
Expected: no offenses

- [ ] **Step 8: Commit**

```bash
git add lib/briefer/models/forecast_discussion.rb spec/models/forecast_discussion_spec.rb \
  spec/fixtures/afd/ lib/briefer.rb
git commit -m "Add ForecastDiscussion model with raw text parsing"
```

---

### Task 7: HTTP Client get_raw Method

**Files:**
- Modify: `lib/briefer/client/http.rb`
- Modify: `lib/briefer/client/cache.rb`
- Create: `spec/client/http_raw_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/client/http_raw_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Client::Http do
  subject(:client) { described_class.new }

  describe "#get_raw" do
    it "returns response body as a string" do
      stub_request(:get, "https://aviationweather.gov/api/data/fcstdisc")
        .with(query: { cwa: "KBOX" })
        .to_return(status: 200, body: "This is raw text", headers: { "Content-Type" => "text/plain" })

      result = client.get_raw("/api/data/fcstdisc", { cwa: "KBOX" })
      expect(result).to eq("This is raw text")
      expect(result).to be_a(String)
    end

    it "raises ApiError on HTTP failure" do
      stub_request(:get, "https://aviationweather.gov/api/data/fcstdisc")
        .with(query: { cwa: "INVALID" })
        .to_return(status: 400, body: "Bad Request")

      expect { client.get_raw("/api/data/fcstdisc", { cwa: "INVALID" }) }
        .to raise_error(Briefer::ApiError)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/client/http_raw_spec.rb`
Expected: FAIL — `undefined method 'get_raw'`

- [ ] **Step 3: Add get_raw to Http client**

Add this method to `lib/briefer/client/http.rb` after the existing `get` method:

```ruby
def get_raw(path, params = {}, ttl: nil) # rubocop:disable Lint/UnusedMethodArgument
  response = connection.get(path, params)
  raise ApiError.new("HTTP #{response.status}", response: response) unless response.success?

  response.body
rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
  raise ConnectionError, e.message
end
```

- [ ] **Step 4: Add get_raw to Cache wrapper**

Add this method to `lib/briefer/client/cache.rb` after the existing `get` method:

```ruby
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/client/http_raw_spec.rb`
Expected: 2 examples, 0 failures

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop lib/briefer/client/http.rb lib/briefer/client/cache.rb spec/client/http_raw_spec.rb`
Expected: no offenses

- [ ] **Step 7: Commit**

```bash
git add lib/briefer/client/http.rb lib/briefer/client/cache.rb spec/client/http_raw_spec.rb
git commit -m "Add get_raw HTTP client method for non-JSON responses"
```

---

### Task 8: AirSigmet Source + CLI

**Files:**
- Create: `lib/briefer/sources/air_sigmet.rb`
- Create: `spec/sources/air_sigmet_spec.rb`
- Modify: `lib/briefer.rb`
- Modify: `lib/briefer/formatters/text.rb`
- Modify: `lib/briefer/cli.rb`

- [ ] **Step 1: Write the source test**

Create `spec/sources/air_sigmet_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Sources::AirSigmet do
  subject(:source) { described_class.new(client: Briefer.client) }

  let(:sigmet_response) do
    [
      JSON.parse(File.read("spec/fixtures/sigmets/convective.json")),
      { "airSigmetType" => "AIRMET", "hazard" => "IFR", "seriesId" => "1S",
        "icaoId" => "KKCI", "rawAirSigmet" => "test", "severity" => 1,
        "validTimeFrom" => 1774749300, "validTimeTo" => 1774752899, "coords" => [] }
    ]
  end

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/airsigmet")
      .with(query: { format: "json" })
      .to_return(status: 200, body: sigmet_response.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  describe "#fetch" do
    it "returns only SIGMET entries" do
      sigmets = source.fetch
      expect(sigmets.size).to eq(1)
      expect(sigmets).to all(be_a(Briefer::Models::Sigmet))
      expect(sigmets.first.hazard).to eq("CONVECTIVE")
    end
  end
end
```

- [ ] **Step 2: Write the source implementation**

Create `lib/briefer/sources/air_sigmet.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Sources
    class AirSigmet
      ENDPOINT = "/api/data/airsigmet"
      TTL = 900

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(hazard: nil)
        params = { format: "json" }
        params[:hazard] = hazard if hazard
        data = @client.get(ENDPOINT, params, ttl: TTL)
        data.select { |entry| entry["airSigmetType"] == "SIGMET" }
            .map { |entry| Models::Sigmet.from_awc(entry) }
      end
    end
  end
end
```

- [ ] **Step 3: Add text formatter**

Add to `lib/briefer/formatters/text.rb` before the `private_class_method` line:

```ruby
def self.format_sigmet(sigmet) # rubocop:disable Metrics/AbcSize
  alt_range = [sigmet.altitude_low_ft, sigmet.altitude_hi_ft].compact
  alt_str = alt_range.empty? ? "" : "  FL#{alt_range.map { |a| format("%03d", a / 100) }.join("-")}"
  move = sigmet.movement_dir_deg ? "  Moving #{format("%03d", sigmet.movement_dir_deg)}° at #{sigmet.movement_speed_kt}kt" : ""
  "SIGMET #{sigmet.series_id} (#{sigmet.hazard}) — valid #{sigmet.valid_from.strftime("%H%MZ")}-#{sigmet.valid_to.strftime("%H%MZ")}\n" \
    "#{alt_str}#{move}\n" \
    "  #{sigmet.raw&.lines&.first&.strip}\n"
end
```

- [ ] **Step 4: Add require, convenience method, and CLI command**

Add to `lib/briefer.rb` after `require_relative "briefer/sources/winds_aloft"`:

```ruby
require_relative "briefer/sources/air_sigmet"
```

Add to `lib/briefer.rb` in the `class << self` block after the `crosswind` method:

```ruby
def sigmets(hazard: nil)
  Sources::AirSigmet.new.fetch(hazard: hazard)
end
```

Add to `lib/briefer/cli.rb` before the `categories` command:

```ruby
desc "sigmets", "Fetch active SIGMETs"
option :hazard, type: :string, desc: "Filter by hazard (conv, turb, ice, ifr)"
def sigmets
  sigs = Briefer.sigmets(hazard: options[:hazard])

  if output_format == "json"
    puts JSON.pretty_generate(sigs.map(&:to_h))
  elsif sigs.empty?
    puts "No active SIGMETs"
  else
    puts "Active SIGMETs (#{sigs.size}):"
    sigs.each { |s| print Formatters::Text.format_sigmet(s) }
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
git add lib/briefer/sources/air_sigmet.rb spec/sources/air_sigmet_spec.rb \
  lib/briefer.rb lib/briefer/formatters/text.rb lib/briefer/cli.rb
git commit -m "Add SIGMET source, formatter, and CLI command"
```

---

### Task 9: Gairmet Source + CLI

**Files:**
- Create: `lib/briefer/sources/gairmet.rb`
- Create: `spec/sources/gairmet_spec.rb`
- Modify: `lib/briefer.rb`
- Modify: `lib/briefer/formatters/text.rb`
- Modify: `lib/briefer/cli.rb`

- [ ] **Step 1: Write the source test**

Create `spec/sources/gairmet_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Sources::Gairmet do
  subject(:source) { described_class.new(client: Briefer.client) }

  let(:gairmet_response) do
    [JSON.parse(File.read("spec/fixtures/airmets/sierra.json"))]
  end

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/gairmet")
      .with(query: { format: "json" })
      .to_return(status: 200, body: gairmet_response.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  describe "#fetch" do
    it "returns Airmet models" do
      airmets = source.fetch
      expect(airmets.size).to eq(1)
      expect(airmets).to all(be_a(Briefer::Models::Airmet))
      expect(airmets.first.product).to eq(:sierra)
    end
  end
end
```

- [ ] **Step 2: Write the source implementation**

Create `lib/briefer/sources/gairmet.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Sources
    class Gairmet
      ENDPOINT = "/api/data/gairmet"
      TTL = 1800

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(product: nil, hazard: nil)
        params = { format: "json" }
        params[:product] = product if product
        params[:hazard] = hazard if hazard
        data = @client.get(ENDPOINT, params, ttl: TTL)
        data.map { |entry| Models::Airmet.from_awc(entry) }
      end
    end
  end
end
```

- [ ] **Step 3: Add text formatter**

Add to `lib/briefer/formatters/text.rb` after the `format_sigmet` method:

```ruby
def self.format_airmet(airmet)
  cause = airmet.due_to ? " (#{airmet.due_to})" : ""
  "G-AIRMET #{airmet.product.upcase}: #{airmet.hazard}#{cause}\n" \
    "  Valid #{airmet.valid_at.strftime("%H%MZ")}  Fcst hour +#{airmet.forecast_hour}" \
    "  Expires #{airmet.expires_at.strftime("%H%MZ")}\n"
end
```

- [ ] **Step 4: Add require, convenience method, and CLI command**

Add to `lib/briefer.rb` after `require_relative "briefer/sources/air_sigmet"`:

```ruby
require_relative "briefer/sources/gairmet"
```

Add to `lib/briefer.rb` in `class << self` after `sigmets`:

```ruby
def airmets(product: nil, hazard: nil)
  Sources::Gairmet.new.fetch(product: product, hazard: hazard)
end
```

Add to `lib/briefer/cli.rb` after the `sigmets` command:

```ruby
desc "airmets", "Fetch active G-AIRMETs"
option :product, type: :string, desc: "Filter by product (sierra, tango, zulu)"
option :hazard, type: :string, desc: "Filter by hazard type"
def airmets
  reports = Briefer.airmets(product: options[:product], hazard: options[:hazard])

  if output_format == "json"
    puts JSON.pretty_generate(reports.map(&:to_h))
  elsif reports.empty?
    puts "No active G-AIRMETs"
  else
    puts "Active G-AIRMETs (#{reports.size}):"
    reports.each { |a| print Formatters::Text.format_airmet(a) }
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
git add lib/briefer/sources/gairmet.rb spec/sources/gairmet_spec.rb \
  lib/briefer.rb lib/briefer/formatters/text.rb lib/briefer/cli.rb
git commit -m "Add G-AIRMET source, formatter, and CLI command"
```

---

### Task 10: TFR Source + CLI

**Files:**
- Create: `lib/briefer/sources/tfr.rb`
- Create: `spec/sources/tfr_spec.rb`
- Modify: `lib/briefer.rb`
- Modify: `lib/briefer/formatters/text.rb`
- Modify: `lib/briefer/cli.rb`

- [ ] **Step 1: Write the source test**

Create `spec/sources/tfr_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Sources::Tfr do
  subject(:source) { described_class.new }

  let(:geojson_response) { File.read("spec/fixtures/tfrs/feature_collection.json") }

  before do
    stub_request(:get, "https://tfr.faa.gov/geoserver/TFR/ows")
      .with(query: hash_including(service: "WFS", typeName: "TFR:V_TFR_LOC"))
      .to_return(status: 200, body: geojson_response,
                 headers: { "Content-Type" => "application/json" })
  end

  describe "#fetch" do
    it "returns Tfr models from GeoJSON" do
      tfrs = source.fetch
      expect(tfrs.size).to eq(1)
      expect(tfrs).to all(be_a(Briefer::Models::Tfr))
      expect(tfrs.first.notam_key).to eq("6/3475-1-FDC-F")
    end
  end
end
```

- [ ] **Step 2: Write the source implementation**

Create `lib/briefer/sources/tfr.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Sources
    class Tfr
      BASE_URL = "https://tfr.faa.gov"
      ENDPOINT = "/geoserver/TFR/ows"
      TTL = 1800

      def initialize
        @connection = build_connection
      end

      def fetch(state: nil)
        params = {
          service: "WFS", version: "1.1.0", request: "GetFeature",
          typeName: "TFR:V_TFR_LOC", outputFormat: "application/json"
        }
        params[:CQL_FILTER] = "STATE='#{state.upcase}'" if state

        response = @connection.get(ENDPOINT, params)
        raise ApiError.new("HTTP #{response.status}", response: response) unless response.success?

        geojson = JSON.parse(response.body)
        geojson["features"].map { |feature| Models::Tfr.from_geojson_feature(feature) }
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
          f.options.open_timeout = 15
          f.options.timeout = 30
        end
      end
    end
  end
end
```

- [ ] **Step 3: Add text formatter**

Add to `lib/briefer/formatters/text.rb` after the `format_airmet` method:

```ruby
def self.format_tfr(tfr)
  key_short = tfr.notam_key&.split("-")&.first || tfr.notam_key
  "TFR #{key_short} (#{tfr.type}) — #{tfr.state}\n" \
    "  #{tfr.title}\n"
end
```

- [ ] **Step 4: Add require, convenience method, and CLI command**

Add to `lib/briefer.rb` after `require_relative "briefer/sources/gairmet"`:

```ruby
require_relative "briefer/sources/tfr"
```

Add to `lib/briefer.rb` in `class << self` after `airmets`:

```ruby
def tfrs(state: nil)
  Sources::Tfr.new.fetch(state: state)
end
```

Add to `lib/briefer/cli.rb` after the `airmets` command:

```ruby
desc "tfrs", "Fetch active TFRs"
option :state, type: :string, desc: "Filter by state (e.g., CA)"
def tfrs
  restrictions = Briefer.tfrs(state: options[:state])

  if output_format == "json"
    puts JSON.pretty_generate(restrictions.map(&:to_h))
  elsif restrictions.empty?
    puts "No active TFRs"
  else
    puts "Active TFRs (#{restrictions.size}):"
    restrictions.each { |t| print Formatters::Text.format_tfr(t) }
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
git add lib/briefer/sources/tfr.rb spec/sources/tfr_spec.rb \
  lib/briefer.rb lib/briefer/formatters/text.rb lib/briefer/cli.rb
git commit -m "Add TFR source, formatter, and CLI command"
```

---

### Task 11: ForecastDiscussion Source + CLI

**Files:**
- Create: `lib/briefer/sources/forecast_discussion.rb`
- Create: `spec/sources/forecast_discussion_spec.rb`
- Modify: `lib/briefer.rb`
- Modify: `lib/briefer/formatters/text.rb`
- Modify: `lib/briefer/cli.rb`

- [ ] **Step 1: Write the source test**

Create `spec/sources/forecast_discussion_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Briefer::Sources::ForecastDiscussion do
  subject(:source) { described_class.new(client: Briefer.client) }

  let(:afd_text) { File.read("spec/fixtures/afd/kbox.txt") }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/fcstdisc")
      .with(query: { cwa: "KBOX" })
      .to_return(status: 200, body: afd_text, headers: { "Content-Type" => "text/plain" })
  end

  describe "#fetch" do
    it "returns a ForecastDiscussion model" do
      afd = source.fetch("KBOX")
      expect(afd).to be_a(Briefer::Models::ForecastDiscussion)
      expect(afd.wfo).to eq("KBOX")
      expect(afd.text).to include("TAF Update")
    end
  end
end
```

- [ ] **Step 2: Write the source implementation**

Create `lib/briefer/sources/forecast_discussion.rb`:

```ruby
# frozen_string_literal: true

module Briefer
  module Sources
    class ForecastDiscussion
      ENDPOINT = "/api/data/fcstdisc"
      TTL = 3600

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(wfo)
        text = @client.get_raw(ENDPOINT, { cwa: wfo.upcase }, ttl: TTL)
        Models::ForecastDiscussion.from_raw(wfo: wfo.upcase, text: text)
      end
    end
  end
end
```

- [ ] **Step 3: Add text formatter**

Add to `lib/briefer/formatters/text.rb` after the `format_tfr` method:

```ruby
def self.format_forecast_discussion(afd)
  preview = afd.text.lines.reject { |l| l.strip.empty? }.first(10).join
  "Area Forecast Discussion — #{afd.wfo}\n\n#{preview}\n"
end
```

- [ ] **Step 4: Add require, convenience method, and CLI command**

Add to `lib/briefer.rb` after `require_relative "briefer/sources/tfr"`:

```ruby
require_relative "briefer/sources/forecast_discussion"
```

Add to `lib/briefer.rb` in `class << self` after `tfrs`:

```ruby
def afd(wfo)
  Sources::ForecastDiscussion.new.fetch(wfo)
end
```

Add to `lib/briefer/cli.rb` after the `tfrs` command:

```ruby
desc "afd WFO", "Fetch Area Forecast Discussion"
def afd(wfo)
  discussion = Briefer.afd(wfo)

  if output_format == "json"
    puts JSON.pretty_generate(discussion.to_h)
  else
    print Formatters::Text.format_forecast_discussion(discussion)
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
git add lib/briefer/sources/forecast_discussion.rb spec/sources/forecast_discussion_spec.rb \
  lib/briefer.rb lib/briefer/formatters/text.rb lib/briefer/cli.rb
git commit -m "Add Forecast Discussion source, formatter, and CLI command"
```

---

### Task 12: Integration Tests & Full Verification

**Files:**
- Modify: `spec/briefer_spec.rb`

- [ ] **Step 1: Add integration tests**

Add to `spec/briefer_spec.rb` after the `.crosswind` describe block:

```ruby
describe ".sigmets" do
  let(:sigmet_data) { [JSON.parse(File.read("spec/fixtures/sigmets/convective.json"))] }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/airsigmet")
      .with(query: { format: "json" })
      .to_return(status: 200, body: sigmet_data.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  it "returns an array of Sigmet models" do
    sigmets = described_class.sigmets
    expect(sigmets.first).to be_a(Briefer::Models::Sigmet)
  end
end

describe ".airmets" do
  let(:airmet_data) { [JSON.parse(File.read("spec/fixtures/airmets/sierra.json"))] }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/gairmet")
      .with(query: { format: "json" })
      .to_return(status: 200, body: airmet_data.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  it "returns an array of Airmet models" do
    airmets = described_class.airmets
    expect(airmets.first).to be_a(Briefer::Models::Airmet)
  end
end

describe ".afd" do
  let(:afd_text) { File.read("spec/fixtures/afd/kbox.txt") }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/fcstdisc")
      .with(query: { cwa: "KBOX" })
      .to_return(status: 200, body: afd_text, headers: { "Content-Type" => "text/plain" })
  end

  it "returns a ForecastDiscussion model" do
    afd = described_class.afd("KBOX")
    expect(afd).to be_a(Briefer::Models::ForecastDiscussion)
    expect(afd.wfo).to eq("KBOX")
  end
end
```

- [ ] **Step 2: Run the full test suite**

Run: `bundle exec rspec`
Expected: all pass

- [ ] **Step 3: Run rubocop**

Run: `bundle exec rubocop`
Expected: no offenses

- [ ] **Step 4: Run default rake task**

Run: `bundle exec rake`
Expected: all pass

- [ ] **Step 5: Commit**

```bash
git add spec/briefer_spec.rb
git commit -m "Add Phase 3 integration tests and verify full suite"
```
