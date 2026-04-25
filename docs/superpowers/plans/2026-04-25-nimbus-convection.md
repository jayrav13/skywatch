# Nimbus Convection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `Skywatch.convection(at:)` — one structured aggregate of active radar-driven warnings (TOR/SVR/FFW) and watches (TOR/SVR) at a point, plus a briefer-cadence text formatter consumable by an LLM as the convective section of a 1-800-WX-BRIEF preflight brief.

**Architecture:** Single source `Sources::Alerts` hits `api.weather.gov/alerts/active` (server-side polygon containment via `point=` parameter). Returns `[ConvectiveAlert, ...]` (warning OR watch — `kind` derived from event suffix). Aggregate `Convection` partitions warnings/watches and exposes briefer-relevant helpers. Text formatter renders one-line-per-alert briefer-cadence output.

**Tech Stack:** Ruby gem · Thor (CLI) · Faraday + faraday-retry (HTTP) · `Shared::Http`/`Shared::Cache` (existing) · WebMock (test stubs) · RSpec · RGeo (geometry) · rgeo-geojson (decode polygons).

**Reference:** Spec at `docs/superpowers/specs/2026-04-25-nimbus-convection-design.md`. Read it once before starting.

---

## File Structure

**Create:**

| Path | Responsibility |
|---|---|
| `lib/skywatch/nimbus/models/convective_alert.rb` | One NWS alert (warning or watch) — typed accessors, parameter-tag parsing |
| `lib/skywatch/nimbus/models/convection.rb` | Aggregate around `[ConvectiveAlert]` — `warnings`/`watches`/`active?`/`max_severity`/`to_h` |
| `lib/skywatch/nimbus/sources/alerts.rb` | Fetches `api.weather.gov/alerts/active` with point + event filter, wraps each feature into `ConvectiveAlert` |
| `spec/nimbus/models/convective_alert_spec.rb` | All tag/identity/time-parsing tests |
| `spec/nimbus/models/convection_spec.rb` | Aggregate behavior |
| `spec/nimbus/sources/alerts_spec.rb` | Source request shape, edge cases |
| `spec/nimbus/briefer_perspective_spec.rb` | Load-bearing acceptance test — full Skywatch.convection → format_convection snapshot |
| `spec/fixtures/nws_alerts/tornado_warning_active.json` | Single TOR Warning feature collection |
| `spec/fixtures/nws_alerts/severe_thunderstorm_warning_active.json` | Single SVR Warning |
| `spec/fixtures/nws_alerts/flash_flood_warning_active.json` | Single FFW |
| `spec/fixtures/nws_alerts/tornado_watch_active.json` | Single TOR Watch (no per-alert hail/wind tags) |
| `spec/fixtures/nws_alerts/multiple_active.json` | TOR Warn + SVR Warn + FFW + TOR Watch all active |
| `spec/fixtures/nws_alerts/none_active.json` | Empty FeatureCollection |
| `spec/fixtures/nws_alerts/missing_parameters.json` | SVR Warning with no `parameters` block |
| `spec/fixtures/nws_alerts/geometry_missing.json` | Watch with `geometry: null` |

**Modify:**

| Path | Change |
|---|---|
| `lib/skywatch/nimbus/formatters/text.rb` | Add `format_convection` + private phrase helpers |
| `lib/skywatch/nimbus/cli.rb` | Add `convection LAT LON [--events]` subcommand |
| `lib/skywatch.rb` | Add `Skywatch.convection`; require new files |
| `spec/nimbus/formatters/text_spec.rb` | Add `format_convection` snapshot tests |
| `spec/nimbus/cli_spec.rb` | Add `convection` subcommand tests (text + json) |
| `spec/nimbus_spec.rb` | Add `Skywatch.convection` end-to-end test |
| `CLAUDE.md` | Add `skywatch nimbus convection LAT LON` to CLI usage block |

---

## Pre-flight

Before Task 1, the implementer should:

1. `cd /Users/jravaliya/Code/skywatch/.worktrees/nimbus-convection`
2. `bundle install` (sandbox bypass needed for `~/.rvm` writes — re-run with `dangerouslyDisableSandbox: true`)
3. Confirm baseline: `bundle exec rspec` passes (334 examples) and `bundle exec rubocop` is clean.

Each task ends with `git add <files> && git commit`. Do not push between tasks; the final task pushes and opens the PR.

---

## Task 0: Capture or synthesize NWS alert fixtures

**Files:**
- Create: `spec/fixtures/nws_alerts/tornado_warning_active.json`
- Create: `spec/fixtures/nws_alerts/severe_thunderstorm_warning_active.json`
- Create: `spec/fixtures/nws_alerts/flash_flood_warning_active.json`
- Create: `spec/fixtures/nws_alerts/tornado_watch_active.json`
- Create: `spec/fixtures/nws_alerts/multiple_active.json`
- Create: `spec/fixtures/nws_alerts/none_active.json`
- Create: `spec/fixtures/nws_alerts/missing_parameters.json`
- Create: `spec/fixtures/nws_alerts/geometry_missing.json`

- [ ] **Step 1: Make the fixture directory**

```bash
mkdir -p spec/fixtures/nws_alerts
```

- [ ] **Step 2: Capture or synthesize each fixture**

Try a live capture first (sandbox bypass for the `curl` is acceptable per the project pattern):

```bash
# none_active.json — works any time, anywhere benign
curl -sS 'https://api.weather.gov/alerts/active?point=40.688,-74.174&event=Tornado%20Warning,Severe%20Thunderstorm%20Warning,Flash%20Flood%20Warning,Tornado%20Watch,Severe%20Thunderstorm%20Watch' \
  -H 'User-Agent: skywatch-test/0.0' \
  | jq '.' > spec/fixtures/nws_alerts/none_active.json
```

For the active alert fixtures, capture during a real event if convenient. Otherwise synthesize from the schema below. **Synthesis is acceptable** — fixtures only need to be schema-valid GeoJSON that round-trips through the parser.

`tornado_warning_active.json` template (single feature in a `FeatureCollection`):

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.tor-warn-1",
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[-74.30,40.65],[-74.05,40.65],[-74.05,40.85],[-74.30,40.85],[-74.30,40.65]]]
      },
      "properties": {
        "id": "urn:oid:2.49.0.1.840.0.tor-warn-1",
        "areaDesc": "Essex, NJ",
        "sent": "2026-04-25T18:30:00+00:00",
        "effective": "2026-04-25T18:30:00+00:00",
        "onset": "2026-04-25T18:30:00+00:00",
        "expires": "2026-04-25T19:30:00+00:00",
        "ends": "2026-04-25T19:30:00+00:00",
        "severity": "Extreme",
        "certainty": "Observed",
        "urgency": "Immediate",
        "event": "Tornado Warning",
        "headline": "Tornado Warning issued April 25 at 2:30PM EDT until April 25 at 3:30PM EDT by NWS New York NY",
        "description": "TORNADO WARNING IN EFFECT UNTIL 330 PM EDT ...",
        "parameters": {
          "maxHailSize": ["1.50"],
          "maxWindGust": ["65 MPH"],
          "tornadoDetection": ["RADAR INDICATED"],
          "thunderstormDamageThreat": ["CONSIDERABLE"]
        }
      }
    }
  ]
}
```

`severe_thunderstorm_warning_active.json` — same shape, change `event` to `"Severe Thunderstorm Warning"`, drop `tornadoDetection`, set hail `"1.00"` and wind `"52 MPH"`. Headline and times shifted appropriately.

`flash_flood_warning_active.json` — `event: "Flash Flood Warning"`, area `"Hudson, NJ"`, expires `"2026-04-25T23:00:00+00:00"`, parameters: `{"flashFloodDamageThreat": ["CONSIDERABLE"]}` only.

`tornado_watch_active.json` — `event: "Tornado Watch"`, headline `"Tornado Watch 142 issued April 25 at 1:30PM EDT until April 25 at 10:00PM EDT by NWS Storm Prediction Center"`, area `"NJ; NY; CT"`, no `parameters` block (or empty `{}`), `severity: "Severe"`, `certainty: "Possible"`.

`multiple_active.json` — combine the four features above into one `FeatureCollection` (TOR Warning + SVR Warning + FFW + TOR Watch). Order in the file: TOR Warning, SVR Warning, FFW, TOR Watch (matches a typical NWS-returned ordering).

`none_active.json` — `{"type":"FeatureCollection","features":[]}`.

`missing_parameters.json` — copy SVR Warning fixture, delete the entire `parameters` key.

`geometry_missing.json` — copy TOR Watch fixture, set `"geometry": null`.

- [ ] **Step 3: Validate JSON parses**

```bash
for f in spec/fixtures/nws_alerts/*.json; do
  jq -e . "$f" > /dev/null && echo "OK $f" || echo "BAD $f"
done
```

Expected: every line says `OK`.

- [ ] **Step 4: Commit**

```bash
git add spec/fixtures/nws_alerts/
git commit -m "test: capture NWS alert fixtures for nimbus convection"
```

---

## Task 1: Write the briefer-perspective integration spec (aspirational target)

**Files:**
- Create: `spec/nimbus/briefer_perspective_spec.rb`

This is the load-bearing acceptance test. We write it first (failing), let every other task push toward making it pass, and verify it goes green at the end without further changes.

- [ ] **Step 1: Write the spec**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe 'briefer-perspective convection output' do
  before do
    fixture = File.read(File.expand_path('../fixtures/nws_alerts/multiple_active.json', __dir__))
    stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
      .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })
  end

  it 'renders the convective section as briefer-cadence one-liners' do
    convection = Skywatch.convection(at: [40.688, -74.174])
    output = Skywatch::Nimbus::Formatters::Text.format_convection(convection)

    expected = <<~BRIEF
      TORNADO WARNING — Essex, NJ until 19:30Z. Radar-indicated; 1.50" hail, 65kt wind gust.
      SEVERE THUNDERSTORM WARNING — Bergen, NJ until 20:00Z. 1.00" hail, 52kt wind gust.
      FLASH FLOOD WARNING — Hudson, NJ until 23:00Z. Considerable damage threat.
      TORNADO WATCH #142 — NJ; NY; CT until 22:00Z.
    BRIEF

    expect(output).to eq(expected)
  end

  it 'emits the empty-state line when no convective alerts are active' do
    fixture = File.read(File.expand_path('../fixtures/nws_alerts/none_active.json', __dir__))
    stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
      .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })

    convection = Skywatch.convection(at: [40.688, -74.174])
    output = Skywatch::Nimbus::Formatters::Text.format_convection(convection)

    expect(output).to eq("NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.\n")
  end
end
```

The fixture content from Task 0 must produce these expected times (`19:30Z`, `20:00Z`, `23:00Z`, `22:00Z`) and area descriptions. If you adjusted any fixture values, update the `expected` string here to match.

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/briefer_perspective_spec.rb
```

Expected: FAIL with `NoMethodError: undefined method 'convection' for Skywatch:Module` (or similar — `format_convection` may also be undefined). This is the aspirational state. Tasks 2-12 build the pieces; Task 13 verifies this test goes green.

- [ ] **Step 3: Commit**

```bash
git add spec/nimbus/briefer_perspective_spec.rb
git commit -m "test: pin briefer-perspective convection output as acceptance target"
```

---

## Task 2: ConvectiveAlert model skeleton

**Files:**
- Create: `lib/skywatch/nimbus/models/convective_alert.rb`
- Create: `spec/nimbus/models/convective_alert_spec.rb`

Establish the constructor + attr_readers + `warning?`/`watch?` predicates. No NWS parsing yet.

- [ ] **Step 1: Write the failing test**

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Nimbus::Models::ConvectiveAlert do
  describe 'construction and predicates' do
    it 'exposes attrs and predicates for a warning' do
      alert = described_class.new(
        id: 'urn:oid:2.49.0.1.840.0.x',
        kind: :warning,
        event: 'Tornado Warning',
        headline: 'Tornado Warning issued ... by NWS NY',
        description: 'TORNADO WARNING IN EFFECT ...',
        severity: :extreme,
        certainty: :observed,
        urgency: :immediate,
        sent_at: Time.utc(2026, 4, 25, 18, 30),
        effective_at: Time.utc(2026, 4, 25, 18, 30),
        onset_at: Time.utc(2026, 4, 25, 18, 30),
        expires_at: Time.utc(2026, 4, 25, 19, 30),
        ends_at: Time.utc(2026, 4, 25, 19, 30),
        area_description: 'Essex, NJ',
        geometry: nil,
        hail_size_in: 1.5,
        wind_gust_mph: 65.0,
        wind_gust_kt: 56.5,
        tornado_detection: :radar_indicated,
        thunderstorm_damage_threat: :considerable,
        flash_flood_damage_threat: nil,
        raw_parameters: {}
      )

      expect(alert.warning?).to be true
      expect(alert.watch?).to be false
      expect(alert.event).to eq('Tornado Warning')
      expect(alert.severity).to eq(:extreme)
      expect(alert.hail_size_in).to eq(1.5)
    end

    it 'exposes predicates for a watch' do
      alert = described_class.new(
        id: 'x', kind: :watch, event: 'Tornado Watch',
        headline: '', description: '',
        severity: :severe, certainty: :possible, urgency: :expected,
        sent_at: nil, effective_at: nil, onset_at: nil,
        expires_at: nil, ends_at: nil,
        area_description: '', geometry: nil,
        hail_size_in: nil, wind_gust_mph: nil, wind_gust_kt: nil,
        tornado_detection: nil, thunderstorm_damage_threat: nil,
        flash_flood_damage_threat: nil, raw_parameters: {}
      )

      expect(alert.watch?).to be true
      expect(alert.warning?).to be false
    end
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/models/convective_alert_spec.rb
```

Expected: FAIL with `uninitialized constant Skywatch::Nimbus::Models::ConvectiveAlert`.

- [ ] **Step 3: Implement the skeleton**

```ruby
# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Models
      class ConvectiveAlert
        ATTRS = %i[
          id kind event headline description
          severity certainty urgency
          sent_at effective_at onset_at expires_at ends_at
          area_description geometry
          hail_size_in wind_gust_mph wind_gust_kt
          tornado_detection thunderstorm_damage_threat flash_flood_damage_threat
          raw_parameters
        ].freeze

        attr_reader(*ATTRS)

        def initialize(**attrs) # rubocop:disable Metrics/MethodLength
          ATTRS.each { |a| instance_variable_set(:"@#{a}", attrs[a]) }
        end

        def warning?
          kind == :warning
        end

        def watch?
          kind == :watch
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire the require so the spec can load**

Add to `lib/skywatch.rb` immediately after `require_relative 'skywatch/nimbus/models/storm_report'`:

```ruby
require_relative 'skywatch/nimbus/models/convective_alert'
```

- [ ] **Step 5: Run to verify it passes**

```bash
bundle exec rspec spec/nimbus/models/convective_alert_spec.rb
```

Expected: PASS, 2 examples.

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/models/convective_alert.rb \
         spec/nimbus/models/convective_alert_spec.rb \
         lib/skywatch.rb
git commit -m "feat: add Nimbus::Models::ConvectiveAlert skeleton"
```

---

## Task 3: ConvectiveAlert.from_nws_feature — identity, times, area, geometry

**Files:**
- Modify: `lib/skywatch/nimbus/models/convective_alert.rb`
- Modify: `spec/nimbus/models/convective_alert_spec.rb`

Parse the non-parameter fields from a real NWS feature.

- [ ] **Step 1: Write the failing test**

Append to `spec/nimbus/models/convective_alert_spec.rb` inside the `RSpec.describe` block:

```ruby
  describe '.from_nws_feature — identity / times / geometry' do
    let(:feature) do
      JSON.parse(File.read(File.expand_path('../../fixtures/nws_alerts/tornado_warning_active.json', __dir__)))
        .fetch('features').first
    end

    it 'parses identity, severity tier, times, area, and geometry' do
      alert = described_class.from_nws_feature(feature)

      expect(alert.id).to eq('urn:oid:2.49.0.1.840.0.tor-warn-1')
      expect(alert.kind).to eq(:warning)
      expect(alert.event).to eq('Tornado Warning')
      expect(alert.headline).to start_with('Tornado Warning issued')

      expect(alert.severity).to eq(:extreme)
      expect(alert.certainty).to eq(:observed)
      expect(alert.urgency).to eq(:immediate)

      expect(alert.sent_at).to eq(Time.utc(2026, 4, 25, 18, 30))
      expect(alert.effective_at).to eq(Time.utc(2026, 4, 25, 18, 30))
      expect(alert.onset_at).to eq(Time.utc(2026, 4, 25, 18, 30))
      expect(alert.expires_at).to eq(Time.utc(2026, 4, 25, 19, 30))
      expect(alert.ends_at).to eq(Time.utc(2026, 4, 25, 19, 30))

      expect(alert.area_description).to eq('Essex, NJ')
      expect(alert.geometry).to be_a(RGeo::Feature::Polygon)
    end

    it 'derives kind :watch from a watch event' do
      watch = JSON.parse(File.read(File.expand_path('../../fixtures/nws_alerts/tornado_watch_active.json', __dir__)))
        .fetch('features').first
      alert = described_class.from_nws_feature(watch)

      expect(alert.kind).to eq(:watch)
      expect(alert.event).to eq('Tornado Watch')
    end

    it 'tolerates a null geometry' do
      feature = JSON.parse(File.read(File.expand_path('../../fixtures/nws_alerts/geometry_missing.json', __dir__)))
        .fetch('features').first
      alert = described_class.from_nws_feature(feature)

      expect(alert.geometry).to be_nil
      expect(alert.id).not_to be_nil
    end

    it 'maps unknown severity / certainty / urgency to :unknown' do
      feature = JSON.parse(File.read(File.expand_path('../../fixtures/nws_alerts/tornado_warning_active.json', __dir__)))
        .fetch('features').first
      feature['properties']['severity'] = 'Wat'
      feature['properties']['certainty'] = nil
      alert = described_class.from_nws_feature(feature)

      expect(alert.severity).to eq(:unknown)
      expect(alert.certainty).to eq(:unknown)
    end
  end
```

Also add this require near the top of the file (just below `require 'spec_helper'`):

```ruby
require 'json'
require 'rgeo/geo_json'
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/models/convective_alert_spec.rb -e 'from_nws_feature'
```

Expected: FAIL with `undefined method 'from_nws_feature'`.

- [ ] **Step 3: Implement parsing**

Add to `lib/skywatch/nimbus/models/convective_alert.rb` inside the class, before `def warning?`:

```ruby
        KIND_BY_EVENT_SUFFIX = { 'Warning' => :warning, 'Watch' => :watch }.freeze

        SEVERITY_VALUES  = %w[Extreme Severe Moderate Minor Unknown].freeze
        CERTAINTY_VALUES = %w[Observed Likely Possible Unlikely Unknown].freeze
        URGENCY_VALUES   = %w[Immediate Expected Future Past Unknown].freeze

        FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)
        GEOJSON_ENTITY_FACTORY = RGeo::GeoJSON::EntityFactory.instance

        def self.from_nws_feature(feature) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          props = feature.fetch('properties')
          event = props['event'].to_s

          new(
            id: props['id'] || feature['id'],
            kind: kind_for(event),
            event: event,
            headline: props['headline'].to_s,
            description: props['description'].to_s,
            severity: enum_or_unknown(props['severity'], SEVERITY_VALUES),
            certainty: enum_or_unknown(props['certainty'], CERTAINTY_VALUES),
            urgency: enum_or_unknown(props['urgency'], URGENCY_VALUES),
            sent_at: parse_time(props['sent']),
            effective_at: parse_time(props['effective']),
            onset_at: parse_time(props['onset']),
            expires_at: parse_time(props['expires']),
            ends_at: parse_time(props['ends']),
            area_description: props['areaDesc'].to_s,
            geometry: parse_geometry(feature['geometry']),
            hail_size_in: nil,
            wind_gust_mph: nil,
            wind_gust_kt: nil,
            tornado_detection: nil,
            thunderstorm_damage_threat: nil,
            flash_flood_damage_threat: nil,
            raw_parameters: props['parameters'] || {}
          )
        end

        def self.kind_for(event)
          suffix = event.split.last
          KIND_BY_EVENT_SUFFIX[suffix] || :unknown
        end
        private_class_method :kind_for

        def self.enum_or_unknown(value, allowed)
          return :unknown if value.nil?
          return :unknown unless allowed.include?(value)

          value.downcase.to_sym
        end
        private_class_method :enum_or_unknown

        def self.parse_time(str)
          return nil if str.nil? || str.empty?

          Time.parse(str).utc
        end
        private_class_method :parse_time

        def self.parse_geometry(geo_data)
          return nil if geo_data.nil?

          RGeo::GeoJSON.decode(geo_data, geo_factory: FACTORY, json_parser: :json)
        rescue StandardError
          nil
        end
        private_class_method :parse_geometry
```

Also add `require 'time'` and `require 'rgeo/geo_json'` at the top of the file.

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/nimbus/models/convective_alert_spec.rb
```

Expected: PASS, 6 examples (2 from Task 2 + 4 new).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/models/convective_alert.rb spec/nimbus/models/convective_alert_spec.rb
git commit -m "feat: parse NWS alert identity, times, and geometry"
```

---

## Task 4: ConvectiveAlert.from_nws_feature — parameter tag parsing

**Files:**
- Modify: `lib/skywatch/nimbus/models/convective_alert.rb`
- Modify: `spec/nimbus/models/convective_alert_spec.rb`

Parse the `properties.parameters` block: hail size, wind gust (mph + derived kt), tornado detection, damage threats. Tolerate missing/malformed parameters.

- [ ] **Step 1: Write the failing tests**

Append to the spec inside the `RSpec.describe` block:

```ruby
  describe '.from_nws_feature — parameter tags' do
    def feature_for(name)
      JSON.parse(File.read(File.expand_path("../../fixtures/nws_alerts/#{name}", __dir__)))
        .fetch('features').first
    end

    it 'parses hail, wind gust, tornado detection, and damage threat from a TOR Warning' do
      alert = described_class.from_nws_feature(feature_for('tornado_warning_active.json'))

      expect(alert.hail_size_in).to eq(1.5)
      expect(alert.wind_gust_mph).to eq(65.0)
      expect(alert.wind_gust_kt).to be_within(0.5).of(56.5)
      expect(alert.tornado_detection).to eq(:radar_indicated)
      expect(alert.thunderstorm_damage_threat).to eq(:considerable)
    end

    it 'parses flash flood damage threat from an FFW' do
      alert = described_class.from_nws_feature(feature_for('flash_flood_warning_active.json'))

      expect(alert.flash_flood_damage_threat).to eq(:considerable)
      expect(alert.hail_size_in).to be_nil
      expect(alert.wind_gust_mph).to be_nil
    end

    it 'leaves all tags nil when parameters block is absent' do
      alert = described_class.from_nws_feature(feature_for('missing_parameters.json'))

      expect(alert.hail_size_in).to be_nil
      expect(alert.wind_gust_mph).to be_nil
      expect(alert.wind_gust_kt).to be_nil
      expect(alert.tornado_detection).to be_nil
      expect(alert.thunderstorm_damage_threat).to be_nil
      expect(alert.raw_parameters).to eq({})
    end

    it 'preserves raw_parameters for debugging' do
      alert = described_class.from_nws_feature(feature_for('tornado_warning_active.json'))
      expect(alert.raw_parameters).to include('maxHailSize', 'maxWindGust', 'tornadoDetection')
    end
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/models/convective_alert_spec.rb -e 'parameter tags'
```

Expected: FAIL — `hail_size_in` etc. are still nil (Task 3 hard-coded them).

- [ ] **Step 3: Wire parameter parsing into `from_nws_feature`**

Replace the six `nil` parameter values in `new(...)` inside `from_nws_feature` with calls to a new `parse_parameters` private helper. The method body becomes:

```ruby
        def self.from_nws_feature(feature) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          props = feature.fetch('properties')
          event = props['event'].to_s
          params = parse_parameters(props['parameters'] || {})

          new(
            id: props['id'] || feature['id'],
            kind: kind_for(event),
            event: event,
            headline: props['headline'].to_s,
            description: props['description'].to_s,
            severity: enum_or_unknown(props['severity'], SEVERITY_VALUES),
            certainty: enum_or_unknown(props['certainty'], CERTAINTY_VALUES),
            urgency: enum_or_unknown(props['urgency'], URGENCY_VALUES),
            sent_at: parse_time(props['sent']),
            effective_at: parse_time(props['effective']),
            onset_at: parse_time(props['onset']),
            expires_at: parse_time(props['expires']),
            ends_at: parse_time(props['ends']),
            area_description: props['areaDesc'].to_s,
            geometry: parse_geometry(feature['geometry']),
            **params,
            raw_parameters: props['parameters'] || {}
          )
        end
```

Add the parser as a private class method:

```ruby
        MPH_TO_KT = 0.868976

        def self.parse_parameters(params) # rubocop:disable Metrics/MethodLength
          mph = parse_float_prefix(first_value(params['maxWindGust']))
          {
            hail_size_in: parse_float_prefix(first_value(params['maxHailSize'])),
            wind_gust_mph: mph,
            wind_gust_kt: mph ? (mph * MPH_TO_KT).round(2) : nil,
            tornado_detection: parse_tornado_detection(first_value(params['tornadoDetection'])),
            thunderstorm_damage_threat: parse_threat(first_value(params['thunderstormDamageThreat'])),
            flash_flood_damage_threat: parse_threat(first_value(params['flashFloodDamageThreat']))
          }
        end
        private_class_method :parse_parameters

        def self.first_value(array_or_nil)
          return nil if array_or_nil.nil? || array_or_nil.empty?

          array_or_nil.first
        end
        private_class_method :first_value

        def self.parse_float_prefix(str)
          return nil if str.nil?

          match = str.to_s.match(/-?\d+(?:\.\d+)?/)
          match ? match[0].to_f : nil
        end
        private_class_method :parse_float_prefix

        def self.parse_tornado_detection(str)
          case str.to_s.upcase
          when 'OBSERVED' then :observed
          when 'RADAR INDICATED' then :radar_indicated
          end
        end
        private_class_method :parse_tornado_detection

        def self.parse_threat(str)
          case str.to_s.upcase
          when 'CATASTROPHIC' then :catastrophic
          when 'DESTRUCTIVE' then :destructive
          when 'CONSIDERABLE' then :considerable
          end
        end
        private_class_method :parse_threat
```

- [ ] **Step 4: Run to verify all alert specs pass**

```bash
bundle exec rspec spec/nimbus/models/convective_alert_spec.rb
```

Expected: PASS, 10 examples.

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/models/convective_alert.rb spec/nimbus/models/convective_alert_spec.rb
git commit -m "feat: parse NWS alert parameter tags (hail, wind gust, tornado, damage threat)"
```

---

## Task 5: ConvectiveAlert#to_h

**Files:**
- Modify: `lib/skywatch/nimbus/models/convective_alert.rb`
- Modify: `spec/nimbus/models/convective_alert_spec.rb`

JSON-serializable hash for the briefer-composition layer.

- [ ] **Step 1: Write the failing test**

Append to the spec:

```ruby
  describe '#to_h' do
    it 'serializes all briefer-relevant fields' do
      feature = JSON.parse(File.read(File.expand_path('../../fixtures/nws_alerts/tornado_warning_active.json', __dir__)))
        .fetch('features').first
      alert = described_class.from_nws_feature(feature)
      hash = alert.to_h

      expect(hash).to include(
        kind: :warning,
        event: 'Tornado Warning',
        severity: :extreme,
        area_description: 'Essex, NJ',
        hail_size_in: 1.5,
        wind_gust_mph: 65.0,
        tornado_detection: :radar_indicated,
        thunderstorm_damage_threat: :considerable
      )
      expect(hash[:expires_at]).to eq('2026-04-25T19:30:00Z')
      expect(hash[:wind_gust_kt]).to be_within(0.5).of(56.5)
    end
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/models/convective_alert_spec.rb -e 'to_h'
```

Expected: FAIL with `undefined method 'to_h'`.

- [ ] **Step 3: Implement `to_h`**

Add to the class (after `def watch?`):

```ruby
        def to_h # rubocop:disable Metrics/MethodLength
          {
            id: id,
            kind: kind,
            event: event,
            headline: headline,
            description: description,
            severity: severity,
            certainty: certainty,
            urgency: urgency,
            sent_at: iso(sent_at),
            effective_at: iso(effective_at),
            onset_at: iso(onset_at),
            expires_at: iso(expires_at),
            ends_at: iso(ends_at),
            area_description: area_description,
            hail_size_in: hail_size_in,
            wind_gust_mph: wind_gust_mph,
            wind_gust_kt: wind_gust_kt,
            tornado_detection: tornado_detection,
            thunderstorm_damage_threat: thunderstorm_damage_threat,
            flash_flood_damage_threat: flash_flood_damage_threat
          }
        end

        def to_json(*args)
          to_h.to_json(*args)
        end

        private

        def iso(time)
          time&.iso8601
        end
```

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/nimbus/models/convective_alert_spec.rb
```

Expected: PASS, 11 examples.

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/models/convective_alert.rb spec/nimbus/models/convective_alert_spec.rb
git commit -m "feat: serialize ConvectiveAlert to_h / to_json"
```

---

## Task 6: Convection aggregate model

**Files:**
- Create: `lib/skywatch/nimbus/models/convection.rb`
- Create: `spec/nimbus/models/convection_spec.rb`
- Modify: `lib/skywatch.rb`

Aggregate around `[ConvectiveAlert]` with briefer-relevant accessors.

- [ ] **Step 1: Write the failing test**

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Nimbus::Models::Convection do
  let(:warning) do
    Skywatch::Nimbus::Models::ConvectiveAlert.new(
      kind: :warning, severity: :extreme, event: 'Tornado Warning'
    )
  end
  let(:warning_minor) do
    Skywatch::Nimbus::Models::ConvectiveAlert.new(
      kind: :warning, severity: :minor, event: 'Flash Flood Warning'
    )
  end
  let(:watch) do
    Skywatch::Nimbus::Models::ConvectiveAlert.new(
      kind: :watch, severity: :severe, event: 'Tornado Watch'
    )
  end

  it 'partitions warnings and watches' do
    conv = described_class.new(at: [40.0, -74.0], fetched_at: Time.utc(2026, 4, 25, 18), alerts: [warning, watch])
    expect(conv.warnings).to eq([warning])
    expect(conv.watches).to eq([watch])
  end

  it 'preserves NWS-returned alerts order on .alerts' do
    conv = described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [watch, warning])
    expect(conv.alerts).to eq([watch, warning])
  end

  it 'is active? when any alert exists' do
    expect(described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [warning]).active?).to be true
    expect(described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: []).active?).to be false
  end

  it 'returns the highest severity across alerts' do
    conv = described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [warning_minor, warning])
    expect(conv.max_severity).to eq(:extreme)
  end

  it 'returns nil max_severity when empty' do
    conv = described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [])
    expect(conv.max_severity).to be_nil
  end

  it 'serializes to a partitioned hash' do
    conv = described_class.new(
      at: [40.688, -74.174],
      fetched_at: Time.utc(2026, 4, 25, 18, 30),
      alerts: [warning, watch]
    )
    hash = conv.to_h

    expect(hash[:at]).to eq([40.688, -74.174])
    expect(hash[:fetched_at]).to eq('2026-04-25T18:30:00Z')
    expect(hash[:warnings]).to be_an(Array)
    expect(hash[:warnings].first[:event]).to eq('Tornado Warning')
    expect(hash[:watches].first[:event]).to eq('Tornado Watch')
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/models/convection_spec.rb
```

Expected: FAIL with `uninitialized constant Skywatch::Nimbus::Models::Convection`.

- [ ] **Step 3: Implement the aggregate**

```ruby
# frozen_string_literal: true

require 'time'

module Skywatch
  module Nimbus
    module Models
      class Convection
        SEVERITY_RANK = { extreme: 4, severe: 3, moderate: 2, minor: 1, unknown: 0 }.freeze

        attr_reader :at, :fetched_at, :alerts

        def initialize(at:, fetched_at:, alerts:)
          @at = at
          @fetched_at = fetched_at
          @alerts = alerts
        end

        def warnings
          alerts.select(&:warning?)
        end

        def watches
          alerts.select(&:watch?)
        end

        def active?
          !alerts.empty?
        end

        def max_severity
          return nil if alerts.empty?

          alerts.max_by { |a| SEVERITY_RANK.fetch(a.severity, 0) }.severity
        end

        def to_h
          {
            at: at,
            fetched_at: fetched_at&.iso8601,
            warnings: warnings.map(&:to_h),
            watches: watches.map(&:to_h)
          }
        end

        def to_json(*args)
          to_h.to_json(*args)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire the require**

In `lib/skywatch.rb`, immediately after `require_relative 'skywatch/nimbus/models/convective_alert'` (added in Task 2):

```ruby
require_relative 'skywatch/nimbus/models/convection'
```

- [ ] **Step 5: Run to verify it passes**

```bash
bundle exec rspec spec/nimbus/models/convection_spec.rb
```

Expected: PASS, 6 examples.

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/models/convection.rb spec/nimbus/models/convection_spec.rb lib/skywatch.rb
git commit -m "feat: add Nimbus::Models::Convection aggregate"
```

---

## Task 7: Sources::Alerts happy path

**Files:**
- Create: `lib/skywatch/nimbus/sources/alerts.rb`
- Create: `spec/nimbus/sources/alerts_spec.rb`
- Modify: `lib/skywatch.rb`

Single source. Hits `api.weather.gov/alerts/active` with `point=` + `event=` filters.

- [ ] **Step 1: Write the failing test**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe Skywatch::Nimbus::Sources::Alerts do
  let(:fixture) { File.read(File.expand_path('../../fixtures/nws_alerts/multiple_active.json', __dir__)) }

  describe '#fetch' do
    it 'requests api.weather.gov/alerts/active with point and event params and wraps each feature' do
      stub = stub_request(:get, 'https://api.weather.gov/alerts/active')
        .with(query: hash_including(
          'point' => '40.688,-74.174',
          'event' => 'Tornado Warning,Severe Thunderstorm Warning,Flash Flood Warning,Tornado Watch,Severe Thunderstorm Watch'
        ))
        .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })

      alerts = described_class.new.fetch(at: [40.688, -74.174])

      expect(stub).to have_been_requested
      expect(alerts.size).to eq(4)
      expect(alerts.map(&:event)).to include('Tornado Warning', 'Severe Thunderstorm Warning', 'Flash Flood Warning', 'Tornado Watch')
    end
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/sources/alerts_spec.rb
```

Expected: FAIL with `uninitialized constant Skywatch::Nimbus::Sources::Alerts`.

- [ ] **Step 3: Implement the source**

```ruby
# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Sources
      class Alerts
        BASE_URL = 'https://api.weather.gov'
        TTL = 60

        EVENTS = [
          'Tornado Warning',
          'Severe Thunderstorm Warning',
          'Flash Flood Warning',
          'Tornado Watch',
          'Severe Thunderstorm Watch'
        ].freeze

        def initialize(client: default_client)
          @client = client
        end

        def fetch(at:, events: EVENTS)
          raise ArgumentError, 'events must be non-empty' if events.empty?

          lat, lon = at
          params = { point: "#{lat},#{lon}", event: events.join(',') }
          data = @client.get('/alerts/active', params, ttl: TTL)
          features = data['features'] || []
          features.map { |f| Models::ConvectiveAlert.from_nws_feature(f) }
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

- [ ] **Step 4: Wire the require**

In `lib/skywatch.rb`, immediately after the convection require:

```ruby
require_relative 'skywatch/nimbus/sources/alerts'
```

- [ ] **Step 5: Run to verify it passes**

```bash
bundle exec rspec spec/nimbus/sources/alerts_spec.rb
```

Expected: PASS, 1 example.

- [ ] **Step 6: Commit**

```bash
git add lib/skywatch/nimbus/sources/alerts.rb spec/nimbus/sources/alerts_spec.rb lib/skywatch.rb
git commit -m "feat: add Nimbus::Sources::Alerts (api.weather.gov/alerts/active)"
```

---

## Task 8: Sources::Alerts edge cases

**Files:**
- Modify: `spec/nimbus/sources/alerts_spec.rb`

Pin: empty event list raises, custom events override the default, empty FeatureCollection returns `[]`.

- [ ] **Step 1: Write the failing tests**

Append inside `RSpec.describe`:

```ruby
  describe '#fetch — edge cases' do
    it 'raises when events is empty' do
      expect { described_class.new.fetch(at: [0, 0], events: []) }
        .to raise_error(ArgumentError, /events must be non-empty/)
    end

    it 'forwards a custom events list to the query' do
      stub = stub_request(:get, 'https://api.weather.gov/alerts/active')
        .with(query: hash_including('event' => 'Tornado Warning'))
        .to_return(status: 200, body: '{"features":[]}', headers: { 'Content-Type' => 'application/geo+json' })

      described_class.new.fetch(at: [0, 0], events: ['Tornado Warning'])

      expect(stub).to have_been_requested
    end

    it 'returns [] when NWS returns an empty FeatureCollection' do
      stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
        .to_return(status: 200, body: '{"features":[]}', headers: { 'Content-Type' => 'application/geo+json' })

      expect(described_class.new.fetch(at: [0, 0])).to eq([])
    end
  end
```

- [ ] **Step 2: Run to verify**

```bash
bundle exec rspec spec/nimbus/sources/alerts_spec.rb
```

Expected: PASS, 4 examples (1 existing + 3 new). All three behaviors are already implemented in Task 7's `fetch`; these tests pin them.

- [ ] **Step 3: Commit**

```bash
git add spec/nimbus/sources/alerts_spec.rb
git commit -m "test: pin Sources::Alerts edge cases (empty events, custom events, empty result)"
```

---

## Task 9: Formatters::Text — phrase helpers

**Files:**
- Modify: `lib/skywatch/nimbus/formatters/text.rb`
- Modify: `spec/nimbus/formatters/text_spec.rb`

Build the briefer-cadence phrase helpers (private). They turn each typed alert field into the wording a briefer would use.

- [ ] **Step 1: Write the failing tests**

Append to `spec/nimbus/formatters/text_spec.rb`:

```ruby
  describe 'convection phrase helpers' do
    let(:warning) do
      Skywatch::Nimbus::Models::ConvectiveAlert.new(
        kind: :warning, event: 'Tornado Warning',
        expires_at: Time.utc(2026, 4, 25, 19, 30),
        area_description: 'Essex, NJ',
        hail_size_in: 1.5, wind_gust_mph: 65.0, wind_gust_kt: 56.48,
        tornado_detection: :radar_indicated,
        thunderstorm_damage_threat: :considerable,
        headline: 'Tornado Warning issued ...'
      )
    end
    let(:watch) do
      Skywatch::Nimbus::Models::ConvectiveAlert.new(
        kind: :watch, event: 'Tornado Watch',
        expires_at: Time.utc(2026, 4, 25, 22, 0),
        area_description: 'NJ; NY; CT',
        headline: 'Tornado Watch 142 issued April 25 at 1:30PM EDT until April 25 at 10:00PM EDT by NWS Storm Prediction Center'
      )
    end

    it 'formats the until-time helper as HH:MMZ' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:until_phrase, warning)).to eq('until 19:30Z')
    end

    it 'formats hail and wind gust phrases' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:hail_phrase, warning)).to eq('1.50" hail')
      expect(Skywatch::Nimbus::Formatters::Text.send(:wind_gust_phrase, warning)).to eq('65kt wind gust')
    end

    it 'formats tornado detection' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:tornado_phrase, warning)).to eq('Radar-indicated')
    end

    it 'formats damage threat' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:damage_threat_phrase, warning)).to eq('Considerable damage threat')
    end

    it 'extracts watch number from headline' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:watch_number, watch)).to eq(142)
    end

    it 'returns nil when watch number is absent' do
      empty_watch = Skywatch::Nimbus::Models::ConvectiveAlert.new(kind: :watch, event: 'Tornado Watch', headline: '')
      expect(Skywatch::Nimbus::Formatters::Text.send(:watch_number, empty_watch)).to be_nil
    end
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/formatters/text_spec.rb -e 'convection phrase helpers'
```

Expected: FAIL — helpers don't exist.

- [ ] **Step 3: Implement the helpers**

In `lib/skywatch/nimbus/formatters/text.rb`, **before** the existing `private_class_method :format_time, :label_for, :magnitude_label` line, add:

```ruby
        def self.until_phrase(alert)
          "until #{alert.expires_at.utc.strftime('%H:%MZ')}"
        end

        def self.hail_phrase(alert)
          return nil if alert.hail_size_in.nil?

          format('%<size>.2f" hail', size: alert.hail_size_in)
        end

        def self.wind_gust_phrase(alert)
          return nil if alert.wind_gust_kt.nil?

          "#{alert.wind_gust_kt.round}kt wind gust"
        end

        def self.tornado_phrase(alert)
          case alert.tornado_detection
          when :observed       then 'Tornado observed'
          when :radar_indicated then 'Radar-indicated'
          end
        end

        def self.damage_threat_phrase(alert)
          threat = alert.thunderstorm_damage_threat || alert.flash_flood_damage_threat
          return nil if threat.nil?

          "#{threat.to_s.capitalize} damage threat"
        end

        def self.watch_number(alert)
          match = alert.headline.to_s.match(/\b(?:Tornado|Severe Thunderstorm) Watch (\d+)\b/)
          match ? match[1].to_i : nil
        end
```

Then update the `private_class_method` line to:

```ruby
        private_class_method :format_time, :label_for, :magnitude_label,
                             :until_phrase, :hail_phrase, :wind_gust_phrase,
                             :tornado_phrase, :damage_threat_phrase, :watch_number
```

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/nimbus/formatters/text_spec.rb
```

Expected: PASS, all examples (existing + 6 new).

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/formatters/text.rb spec/nimbus/formatters/text_spec.rb
git commit -m "feat: add briefer-cadence phrase helpers for convection formatter"
```

---

## Task 10: Formatters::Text.format_convection — main + ordering + empty

**Files:**
- Modify: `lib/skywatch/nimbus/formatters/text.rb`
- Modify: `spec/nimbus/formatters/text_spec.rb`

Compose the helpers into a one-line-per-alert block. Order: warnings first then watches, severity-descending within each kind, NWS-order tiebreak. Empty: `NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.`.

- [ ] **Step 1: Write the failing tests**

Append to `spec/nimbus/formatters/text_spec.rb`:

```ruby
  describe '.format_convection' do
    def alert(**attrs)
      Skywatch::Nimbus::Models::ConvectiveAlert.new(**attrs)
    end

    it 'renders one line per alert in briefer cadence' do
      tor = alert(
        kind: :warning, severity: :extreme, event: 'Tornado Warning',
        expires_at: Time.utc(2026, 4, 25, 19, 30), area_description: 'Essex, NJ',
        hail_size_in: 1.5, wind_gust_mph: 65.0, wind_gust_kt: 56.48,
        tornado_detection: :radar_indicated, headline: 'Tornado Warning ...'
      )
      svr = alert(
        kind: :warning, severity: :severe, event: 'Severe Thunderstorm Warning',
        expires_at: Time.utc(2026, 4, 25, 20, 0), area_description: 'Bergen, NJ',
        hail_size_in: 1.0, wind_gust_mph: 52.0, wind_gust_kt: 45.19,
        headline: 'Severe Thunderstorm Warning ...'
      )
      ffw = alert(
        kind: :warning, severity: :severe, event: 'Flash Flood Warning',
        expires_at: Time.utc(2026, 4, 25, 23, 0), area_description: 'Hudson, NJ',
        flash_flood_damage_threat: :considerable, headline: 'Flash Flood Warning ...'
      )
      watch = alert(
        kind: :watch, severity: :severe, event: 'Tornado Watch',
        expires_at: Time.utc(2026, 4, 25, 22, 0), area_description: 'NJ; NY; CT',
        headline: 'Tornado Watch 142 issued ...'
      )

      conv = Skywatch::Nimbus::Models::Convection.new(
        at: [40.688, -74.174], fetched_at: Time.now.utc,
        alerts: [svr, ffw, tor, watch] # intentionally out of severity order
      )

      output = Skywatch::Nimbus::Formatters::Text.format_convection(conv)

      expect(output).to eq(<<~BRIEF)
        TORNADO WARNING — Essex, NJ until 19:30Z. Radar-indicated; 1.50" hail, 65kt wind gust.
        SEVERE THUNDERSTORM WARNING — Bergen, NJ until 20:00Z. 1.00" hail, 52kt wind gust.
        FLASH FLOOD WARNING — Hudson, NJ until 23:00Z. Considerable damage threat.
        TORNADO WATCH #142 — NJ; NY; CT until 22:00Z.
      BRIEF
    end

    it 'returns the empty-state line when no alerts are active' do
      conv = Skywatch::Nimbus::Models::Convection.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [])
      expect(Skywatch::Nimbus::Formatters::Text.format_convection(conv))
        .to eq("NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.\n")
    end
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/formatters/text_spec.rb -e 'format_convection'
```

Expected: FAIL with `undefined method 'format_convection'`.

- [ ] **Step 3: Implement the formatter**

In `lib/skywatch/nimbus/formatters/text.rb`, after `format_storm_report`, add:

```ruby
        SEVERITY_RANK = { extreme: 4, severe: 3, moderate: 2, minor: 1, unknown: 0 }.freeze

        def self.format_convection(convection)
          return "NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.\n" unless convection.active?

          ordered = order_alerts(convection.alerts)
          ordered.map { |a| format_alert(a) }.join
        end

        def self.order_alerts(alerts)
          warnings = alerts.select(&:warning?).sort_by.with_index { |a, i| [-SEVERITY_RANK.fetch(a.severity, 0), i] }
          watches  = alerts.select(&:watch?).sort_by.with_index { |a, i| [-SEVERITY_RANK.fetch(a.severity, 0), i] }
          warnings + watches
        end

        def self.format_alert(alert) # rubocop:disable Metrics/AbcSize
          number = alert.watch? ? watch_number(alert) : nil
          number_part = number ? " ##{number}" : ''
          base = "#{alert.event.upcase}#{number_part} — #{alert.area_description} #{until_phrase(alert)}."
          extras = build_extras(alert)
          extras.empty? ? "#{base}\n" : "#{base} #{extras}\n"
        end

        def self.build_extras(alert)
          parts = []
          parts << tornado_phrase(alert) if tornado_phrase(alert)

          measurements = [hail_phrase(alert), wind_gust_phrase(alert)].compact
          parts << measurements.join(', ') unless measurements.empty?

          parts << damage_threat_phrase(alert) if damage_threat_phrase(alert)

          parts.empty? ? '' : "#{parts.join('; ')}."
        end
```

Update the `private_class_method` line again to include the new helpers:

```ruby
        private_class_method :format_time, :label_for, :magnitude_label,
                             :until_phrase, :hail_phrase, :wind_gust_phrase,
                             :tornado_phrase, :damage_threat_phrase, :watch_number,
                             :order_alerts, :format_alert, :build_extras
```

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/nimbus/formatters/text_spec.rb
```

Expected: PASS, all examples.

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/formatters/text.rb spec/nimbus/formatters/text_spec.rb
git commit -m "feat: render Convection as briefer-cadence one-liners"
```

---

## Task 11: Skywatch.convection convenience API

**Files:**
- Modify: `lib/skywatch.rb`
- Modify: `spec/nimbus_spec.rb`

- [ ] **Step 1: Write the failing test**

Append to `spec/nimbus_spec.rb` inside the existing `RSpec.describe Skywatch` block (or open it):

```ruby
  describe '.convection' do
    let(:fixture) { File.read(File.expand_path('fixtures/nws_alerts/multiple_active.json', __dir__)) }

    before do
      stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
        .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })
    end

    it 'returns a Convection aggregate with warnings and watches partitioned' do
      conv = Skywatch.convection(at: [40.688, -74.174])

      expect(conv).to be_a(Skywatch::Nimbus::Models::Convection)
      expect(conv.at).to eq([40.688, -74.174])
      expect(conv.warnings.size).to eq(3)
      expect(conv.watches.size).to eq(1)
      expect(conv.active?).to be true
    end

    it 'forwards events: override to the source' do
      stub = stub_request(:get, 'https://api.weather.gov/alerts/active')
        .with(query: hash_including('event' => 'Tornado Warning'))
        .to_return(status: 200, body: '{"features":[]}', headers: { 'Content-Type' => 'application/geo+json' })

      Skywatch.convection(at: [0, 0], events: ['Tornado Warning'])

      expect(stub).to have_been_requested
    end
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus_spec.rb -e 'convection'
```

Expected: FAIL with `undefined method 'convection' for Skywatch:Module`.

- [ ] **Step 3: Implement the convenience method**

In `lib/skywatch.rb`, inside `module Skywatch; class << self`, after the `storms` method:

```ruby
    def convection(at:, events: nil)
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

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/nimbus_spec.rb
```

Expected: PASS, all nimbus_spec examples.

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch.rb spec/nimbus_spec.rb
git commit -m "feat: add Skywatch.convection convenience API"
```

---

## Task 12: Nimbus::CLI convection subcommand

**Files:**
- Modify: `lib/skywatch/nimbus/cli.rb`
- Modify: `spec/nimbus/cli_spec.rb`

Wire `skywatch nimbus convection LAT LON [--events] [--format]` into the existing CLI.

- [ ] **Step 1: Write the failing test**

Append to `spec/nimbus/cli_spec.rb`:

```ruby
  describe 'convection' do
    let(:fixture) do
      File.read(File.expand_path('../fixtures/nws_alerts/multiple_active.json', __dir__))
    end

    before do
      stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
        .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })
    end

    it 'prints briefer-cadence text by default on a TTY' do
      allow($stdout).to receive(:tty?).and_return(true)
      expect { Skywatch::Nimbus::CLI.start(%w[convection 40.688 -74.174]) }
        .to output(/TORNADO WARNING/).to_stdout
    end

    it 'prints JSON when --format json is passed' do
      expect { Skywatch::Nimbus::CLI.start(%w[convection 40.688 -74.174 --format json]) }
        .to output(/"warnings"/).to_stdout
    end

    it 'forwards --events filter to the source' do
      stub = stub_request(:get, 'https://api.weather.gov/alerts/active')
        .with(query: hash_including('event' => 'Tornado Warning'))
        .to_return(status: 200, body: '{"features":[]}', headers: { 'Content-Type' => 'application/geo+json' })

      Skywatch::Nimbus::CLI.start(%w[convection 40.688 -74.174 --events Tornado\ Warning --format json])

      expect(stub).to have_been_requested
    end

    it 'prints the empty-state line on a TTY when nothing is active' do
      stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
        .to_return(status: 200, body: '{"features":[]}', headers: { 'Content-Type' => 'application/geo+json' })
      allow($stdout).to receive(:tty?).and_return(true)

      expect { Skywatch::Nimbus::CLI.start(%w[convection 40.688 -74.174]) }
        .to output(/NO ACTIVE CONVECTIVE WARNINGS OR WATCHES/).to_stdout
    end
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/nimbus/cli_spec.rb -e 'convection'
```

Expected: FAIL — `Could not find command "convection"`.

- [ ] **Step 3: Add the subcommand**

In `lib/skywatch/nimbus/cli.rb`, after the `storms` action and before `private`:

```ruby
      desc 'convection LAT LON', 'Active radar-driven warnings + watches at point'
      option :events, type: :string,
                      desc: 'Comma-separated NWS event names (default: TOR/SVR/FFW Warnings + TOR/SVR Watches)'
      def convection(lat, lon)
        events = options[:events]&.split(',')&.map(&:strip)
        conv = if events && !events.empty?
                 Skywatch.convection(at: [lat.to_f, lon.to_f], events: events)
               else
                 Skywatch.convection(at: [lat.to_f, lon.to_f])
               end
        print_convection(conv)
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end
```

Then add the printer in the `private` section:

```ruby
      def print_convection(conv)
        if output_format == 'json'
          puts JSON.pretty_generate(conv.to_h)
        else
          print Skywatch::Nimbus::Formatters::Text.format_convection(conv)
        end
      end
```

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/nimbus/cli_spec.rb
```

Expected: PASS, all examples.

- [ ] **Step 5: Commit**

```bash
git add lib/skywatch/nimbus/cli.rb spec/nimbus/cli_spec.rb
git commit -m "feat: add 'skywatch nimbus convection LAT LON' CLI command"
```

---

## Task 13: Verify briefer-perspective integration spec passes

**Files:**
- (none modified — sanity check)

This is the Task 1 acceptance test. Everything since Task 2 has been pushing toward it. Verify it lights up without changes.

- [ ] **Step 1: Run the briefer-perspective spec**

```bash
bundle exec rspec spec/nimbus/briefer_perspective_spec.rb
```

Expected: PASS, 2 examples. Output snapshot is byte-identical to the expected briefer-cadence block.

If a discrepancy appears (whitespace, ordering, time format), **do not** edit the spec to match — the spec is the contract. Fix the formatter or model so the output matches. Likely culprits:
- `wind_gust_kt` rounded differently than `.round` (we round to integer; if a fixture has `.5+`, banker's rounding might surprise — use `.round` not `.round_half_to_even`).
- `area_description` includes a trailing space or different separator (NWS sometimes uses `;` vs `, `; the fixture should match the expected output).
- Watch number regex misses a fixture variant (adjust regex if NWS uses a different headline format).

- [ ] **Step 2: Run the full test suite**

```bash
bundle exec rspec
```

Expected: PASS, all examples (PR 1's 334 + the new ones from this PR).

- [ ] **Step 3: Run RuboCop**

```bash
bundle exec rubocop
```

Expected: 0 offenses. Fix any inline; never edit `.rubocop.yml`.

- [ ] **Step 4: No commit needed (verification only)**

If Steps 1-3 all passed without changes, proceed. If you had to fix something, commit those fixes:

```bash
git add <changed-files>
git commit -m "fix: align <specifically what> with briefer-perspective expected output"
```

---

## Task 14: Update CLAUDE.md CLI usage

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add the convection line to the CLI Usage block**

In `CLAUDE.md`, find the `## CLI Usage` section. After the line `skywatch mayday near 40.875 -74.282 --radius 100`, add:

```bash
skywatch nimbus convection 40.688 -74.174
```

(Place it grouped with the other `skywatch nimbus …` commands if there's a clearer existing grouping; otherwise after mayday is fine.)

- [ ] **Step 2: Verify the change**

```bash
grep -A 1 'nimbus convection' CLAUDE.md
```

Expected: the new line appears.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add 'skywatch nimbus convection' to CLI usage"
```

---

## Final: Push and open PR

After Task 14:

- [ ] **Step 1: Confirm green**

```bash
bundle exec rspec && bundle exec rubocop
```

Expected: all pass, 0 offenses.

- [ ] **Step 2: Push**

```bash
git push -u origin nimbus-convection
```

- [ ] **Step 3: Open the PR**

```bash
gh pr create --title "feat(nimbus): active convective warnings + watches at point (Nimbus PR 2)" --body "$(cat <<'EOF'
## Summary

Second slice of \`Skywatch::Nimbus\` — active radar-driven warnings (TOR/SVR/FFW) and watches (TOR/SVR) at a point.

- \`skywatch nimbus convection LAT LON [--events ...] [--format json|text]\`
- \`Skywatch.convection(at: [lat, lon])\` → \`Models::Convection\` (partitioned warnings/watches, briefer-relevant tag fields)
- Briefer-cadence text formatter — output is the convective section of a 1-800-WX-BRIEF preflight brief, consumable by an LLM as-is

Pivots scope from "NEXRAD reflectivity / dBZ-at-point" to active warnings (rationale in design spec). dBZ-at-point and image URLs deferred to post-Nimbus investigations.

## Test plan

- [x] \`bundle exec rspec\` — full suite green
- [x] \`bundle exec rubocop\` — 0 offenses
- [x] \`spec/nimbus/briefer_perspective_spec.rb\` — load-bearing acceptance test
- [ ] CI green
- [ ] Smoke: \`exe/skywatch nimbus convection 40.688 -74.174\`
- [ ] Smoke: \`exe/skywatch nimbus convection 40.688 -74.174 --format json\`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review

**Spec coverage check:**

| Spec section | Task(s) |
|---|---|
| ConvectiveAlert: identity / kind / event / headline / description | Task 3 |
| ConvectiveAlert: severity / certainty / urgency tiering | Task 3 |
| ConvectiveAlert: time fields | Task 3 |
| ConvectiveAlert: area_description / geometry (incl. null) | Task 3 |
| ConvectiveAlert: hail / wind_gust_mph / wind_gust_kt | Task 4 |
| ConvectiveAlert: tornado_detection / damage threats | Task 4 |
| ConvectiveAlert: raw_parameters preservation | Task 4 |
| ConvectiveAlert: warning? / watch? predicates | Task 2 |
| ConvectiveAlert: to_h / to_json | Task 5 |
| Convection aggregate: warnings/watches partition, active?, max_severity, to_h | Task 6 |
| Sources::Alerts: point + event query, default cached client | Task 7 |
| Sources::Alerts: empty events raises, custom override, empty result | Task 8 |
| Formatter: phrase helpers (until/hail/wind/tornado/threat/watch_number) | Task 9 |
| Formatter: ordering (warnings-first, severity-desc, NWS-order tiebreak) | Task 10 |
| Formatter: empty-state line | Task 10 |
| Skywatch.convection convenience | Task 11 |
| CLI: text / json / --events | Task 12 |
| Briefer-perspective integration test | Task 1 (write) + Task 13 (verify) |
| CLAUDE.md update | Task 14 |
| Fixtures (8 scenarios) | Task 0 |

All spec sections covered.

**Placeholder scan:** No "TBD"/"TODO"/"implement later" present. Each step shows complete code or exact commands.

**Type / signature consistency:**
- `from_nws_feature(feature)` — single positional arg, used identically across Tasks 3-5.
- `Sources::Alerts#fetch(at:, events: EVENTS)` — used identically in Tasks 7, 8, 11, 12.
- `Skywatch.convection(at:, events: nil)` — used identically in Tasks 11, 12.
- `Models::Convection.new(at:, fetched_at:, alerts:)` — keyword args only, consistent across Tasks 6, 11.
- `Formatters::Text.format_convection(convection)` — single positional arg, consistent across Tasks 10, 11, 12, 13.
- `SEVERITY_RANK` exists in two places (`Convection` model and `Formatters::Text`) — duplication is intentional and small; the alternative is a shared `Shared::Severity` module which is over-abstraction for two callers. Plan accepts the dup.

No type inconsistencies found.
