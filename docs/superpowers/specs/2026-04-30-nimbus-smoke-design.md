# Nimbus PR 3 — smoke plumes (HMS) design

**Date:** 2026-04-30
**Domain:** `Skywatch::Nimbus`
**Decomposition reference:** [Nimbus is being shipped as multiple PRs](../../../.claude/projects/-Users-jravaliya-Code-skywatch/memory/project_nimbus_decomposition.md) — this is PR 3 (smoke plumes only; AQI deferred to [#13](https://github.com/jayrav13/skywatch/issues/13), fires deferred to [#14](https://github.com/jayrav13/skywatch/issues/14)).
**Predecessors merged:** Nimbus PR 1 (outlook + storms — GH #3), Nimbus PR 2 (convection — GH #4).

## Goal

Add satellite-detected smoke plume awareness to Skywatch. A pilot or LLM consumer should be able to ask **"is there smoke at this point right now, and how dense is it?"** and get an authoritative answer from the same NOAA HMS data the FAA uses for smoke advisories — without API keys, KML parsing, or external dependencies.

This is the third Nimbus sub-domain (after SPC outlook/storms and NWS convection), and the first to plug directly into `Skywatch.brief`'s `adverse_conditions` slot.

## Validation thesis

If a pilot is downwind of an active wildfire (or under a smoke pall transported from a distant fire), HMS smoke plume polygons are the canonical structured-data signal. The MVP shipping bar is: `Skywatch.brief(airport: 'KMRY')` (or any other smoke-affected field at validation time) surfaces a smoke item under `adverse_conditions.items` with `kind: 'smoke'` and a `density_score`, identical in shape to the existing SIGMET/AIRMET/PIREP items.

## Scope

### In for MVP

- New source `Skywatch::Nimbus::Sources::Smoke` (ArcGIS feature service client, point query)
- New model `Skywatch::Nimbus::Models::Smoke` (density-classified plume with polygon geometry)
- Top-level convenience `Skywatch.smoke(at:)` — returns `Array<Smoke>`
- CLI subcommand `skywatch nimbus smoke LAT LON` (text + JSON output)
- Brief composer integration: smoke is the 6th adverse-conditions source
- Add `services2.arcgis.com` to project `.claude/settings.json` allowlist for live development testing

### Out of scope (deferred)

- Surface AQI from AirNow → [#13](https://github.com/jayrav13/skywatch/issues/13)
- Fire detection points (HMS fire product) → [#14](https://github.com/jayrav13/skywatch/issues/14)
- `SmokeAnalysis` aggregate model (predicates + summary attrs) → [#15](https://github.com/jayrav13/skywatch/issues/15)
- Forecast smoke (HRRR-Smoke is a separate product, not ingested here)
- Historical smoke / time-range queries

## Architecture

```
Skywatch::Nimbus
├── Sources::Smoke              # NEW: ArcGIS HMS feature service client
├── Models::Smoke               # NEW: density-classified plume model
├── Formatters::Text            # extend: format_smoke
└── CLI                         # extend: 'smoke LAT LON' subcommand

Skywatch (top-level)
└── .smoke(at:)                 # NEW: convenience method

Skywatch::Brief::Analysis::Composer
└── #build_adverse              # extend: 6th attempt → 'smoke' source
```

No new shared infrastructure. Reuses `Skywatch::Shared::Http` + `Skywatch::Shared::Cache` per the existing source pattern.

## Data source

**Endpoint:** `https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/NOAA_Satellite_Smoke_Detection_(v1)/FeatureServer/0/query`

**Owner:** NESDIS Satellite Analysis Branch (NOAA), `orgId=C8EMgrsFcRFL6LrL`. Public ArcGIS feature service with `Query,Extract` capabilities, `maxRecordCount: 1000`. No auth required.

**Why this over canonical KML:** Native JSON, server-side polygon-intersect via point query, no KML parser. The canonical NOAA source is `satepsanone.nesdis.noaa.gov` KML files, which is also fine but would require KML parsing and isn't currently in the sandbox allowlist.

**Query shape (point intersect):**

```
GET /C8EMgrsFcRFL6LrL/arcgis/rest/services/NOAA_Satellite_Smoke_Detection_(v1)/FeatureServer/0/query
  ?geometry=<lon>,<lat>
  &geometryType=esriGeometryPoint
  &inSR=4326
  &spatialRel=esriSpatialRelIntersects
  &outFields=*
  &f=json
```

Returns: `{ "features": [ ... ] }`. Empty `features` array means no plume covers the point.

**Feature shape (per plume):**

```json
{
  "attributes": {
    "FID": 12345,
    "Satellite": "GOES-EAST",
    "Start": "2026120 1200",     // YYYYDDD HHMM (UTC)
    "End_": "2026120 1800",      // trailing underscore: ArcGIS reserved-word escape
    "Density": "Medium",          // "Light" | "Medium" | "Heavy"
    "Shape__Area": 1.234,
    "Shape__Length": 5.678
  },
  "geometry": {
    "rings": [ [ [<lon>, <lat>], ... ] ]   // ArcGIS polygon rings, in inSR=4326 (since we passed it)
  }
}
```

**Time format quirk:** `Start` and `End_` are strings shaped `"YYYYDDD HHMM"` — year + ordinal day-of-year + UTC hours/minutes. Requires a small parser: `Date.ordinal(year, doy)` + `Time.utc`. This is the only meaningful parsing complexity in the source.

**TTL:** 3600 seconds (1 hour). HMS analysis updates a few times per day; an hour of cache is appropriate and matches the AFD source's cadence.

## Source class

`lib/skywatch/nimbus/sources/smoke.rb`

```ruby
module Skywatch
  module Nimbus
    module Sources
      class Smoke
        BASE_URL = 'https://services2.arcgis.com'
        PATH = '/C8EMgrsFcRFL6LrL/arcgis/rest/services/NOAA_Satellite_Smoke_Detection_(v1)/FeatureServer/0/query'
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

Mirrors `Sources::Outlook` and `Sources::Alerts` exactly. Server does the polygon-intersect, so no client-side filtering — empty array means no covering plume.

## Model class

`lib/skywatch/nimbus/models/smoke.rb`

```ruby
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

        # parses "YYYYDDD HHMM" (e.g. "2026120 1200") to a UTC Time
        def self.parse_julian(str)
          return nil if str.nil? || str.empty?
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
          # ArcGIS rings: outer first, holes after. For MVP, build outer ring only;
          # smoke plumes don't have meaningful holes.
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
            density:       density_level,
            density_raw:   density_raw,
            density_score: density_score,
            description:   description,
            satellite:     satellite,
            start_time:    start_time&.iso8601,
            end_time:      end_time&.iso8601,
            geometry:      geometry && RGeo::GeoJSON.encode(geometry)
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
```

**Why `density_raw` AND `density_level` AND `density_score` AND `description`:** mirrors the `Outlook` model's `label` / `risk_level` / `risk_score` / `description` quartet exactly. `density_raw` keeps the source-of-truth string, `density_level` is the Ruby-friendly symbol, `density_score` lets consumers threshold/sort, `description` is the human-readable phrase.

**Why no `covers?` predicate on the model:** Source already filters server-side via point intersect, so this model never needs to ask "do I cover X?". If a future use case needs it, add it then.

## Top-level API

`lib/skywatch.rb`

```ruby
def self.smoke(at:)
  lat, lon = at
  Nimbus::Sources::Smoke.new.fetch(at: [lat, lon])
end
```

Plus the matching `require_relative` lines for the new model and source files.

Returns `Array<Models::Smoke>`. Empty array means no smoke at the point. Aggregate `SmokeAnalysis` wrapper is deferred to [#15](https://github.com/jayrav13/skywatch/issues/15).

## CLI

`lib/skywatch/nimbus/cli.rb` — add a new subcommand following the `convection` shape:

```ruby
desc 'smoke LAT LON', 'HMS satellite-detected smoke plumes covering the point'
def smoke(lat, lon)
  plumes = Skywatch.smoke(at: [lat.to_f, lon.to_f])
  print_smoke(plumes)
rescue Skywatch::Error => e
  warn "Error: #{e.message}"
  exit 1
end

private

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

**Text format** (one line per plume): `SMOKE Heavy (GOES-EAST) — 2026-04-30 12:00Z → 2026-04-30 18:00Z`.

`Formatters::Text.format_smoke` adds:

```ruby
def self.format_smoke(plume)
  valid = "#{format_time(plume.start_time)} → #{format_time(plume.end_time)}"
  sat = plume.satellite ? " (#{plume.satellite})" : ''
  "SMOKE #{plume.density_raw}#{sat} — #{valid}\n"
end
```

## Brief integration

`lib/skywatch/brief/analysis/composer.rb` — add smoke as the 6th adverse source.

**Constructor signature (add `smoke_source:` keyword):**

```ruby
def initialize(metar_source: Skywatch::Briefer::Sources::Metar.new,
               # ... existing 9 sources (taf, pirep, winds, sigmet, airmet, afd, alerts, storm) ...
               smoke_source: Skywatch::Nimbus::Sources::Smoke.new)
  # ... existing assignments ...
  @smoke_source = smoke_source
end
```

**`build_adverse` extension:**

```ruby
smoke_attempt = attempt { @smoke_source.fetch(at: [lat, lon]) }

attempts = {
  'sigmet'           => sigmet_attempt,
  'airmet'           => airmet_attempt,
  'pirep'            => pirep_attempt,
  'convective_alert' => alerts_attempt,
  'storm_report'     => storm_attempt,
  'smoke'            => smoke_attempt
}
# ... existing partial_failures aggregation ...

items.concat((smoke_attempt[:value] || []).map { |s| { kind: 'smoke' }.merge(s.to_h) })
```

**Why smoke joins `adverse_conditions` and not a separate slot:** the AIM 7-1-5 envelope already groups SIGMETs (in-flight weather advisories), AIRMETs, PIREPs, convective alerts, and storm reports under `adverse_conditions`. Smoke plumes are a structured weather hazard that affects flight (visibility-reducing); they belong with the others, not as a top-level slot. Same reasoning the spec used for SIGMETs/AIRMETs.

**Item shape in the brief:** `{ kind: 'smoke' }.merge(plume.to_h)` — produces:

```json
{
  "kind": "smoke",
  "density": "medium",
  "density_raw": "Medium",
  "density_score": 2,
  "description": "Medium smoke",
  "satellite": "GOES-EAST",
  "start_time": "2026-04-30T12:00:00Z",
  "end_time": "2026-04-30T18:00:00Z",
  "geometry": { "type": "Polygon", "coordinates": [...] }
}
```

`density_score` lets a consumer threshold (e.g., LLM filtering Light if user only cares about VFR-blocking smoke) without losing data fidelity.

## Sandbox allowlist

Add `services2.arcgis.com` to `.claude/settings.json` (project-level) so live development calls work without `dangerouslyDisableSandbox: true`. One-line change to the `Network.allowedHosts` array. Tests use WebMock fixtures — no network — so this is purely a development-ergonomics change.

## Error handling

| Scenario | Behavior |
|---|---|
| Network failure | `Skywatch::ConnectionError` raised by `Shared::Http`, propagates up. In Brief composer, captured by `attempt { }` and surfaces in `partial_failures`. |
| Non-200 response | `Skywatch::ApiError`. Same propagation as above. |
| Malformed feature (missing `attributes`, missing `Density`) | `Models::Smoke.from_arcgis_feature` builds the Smoke object with whatever's present; the eager `density_level` / `density_score` / `description` accessors will raise `KeyError` if `density_raw` isn't in `DENSITY_LEVELS`. This matches the existing `Outlook` pattern (`RISK_LEVELS.fetch(label)`) — we want loud failure when NOAA's schema changes, not silent default behavior. See "Unknown density string from API" row below. |
| Empty `features` array | Source returns `[]`. CLI prints `"No smoke detected at this point."`. Brief includes nothing under `kind: 'smoke'`. |
| Invalid lat/lon | Source passes them through to ArcGIS, which returns either no features or an error. Don't validate client-side; the API is the source of truth. |
| Unknown density string from API | Raise `Skywatch::ParseError` with the unknown value. Per existing pattern in `Outlook`, unknown source values should fail loudly so we notice when NOAA changes their schema. |

## Caching

`Shared::Cache.new(client: Shared::Http.new)` with `TTL = 3600`. Cache key is the full URL with query params, so different lat/lon pairs cache independently. One hour matches HMS analysis cadence (typically 4–6 updates per day).

## Test plan

Three layers, mirroring PR 2:

### 1. Unit (model) — `spec/nimbus/models/smoke_spec.rb`

- `from_arcgis_feature` parses density / satellite / Start / End_ / geometry into the model
- `parse_julian` correctly converts `"2026120 1200"` to `Time.utc(2026, 4, 30, 12, 0)` (April 30 = day 120 of 2026)
- `parse_julian` returns `nil` for nil/empty input
- `parse_arcgis_polygon` builds an RGeo polygon from `rings`
- `density_level` / `density_score` / `description` for each density level
- Unknown density raises `KeyError` (consumer responsibility) — covered explicitly
- `to_h` produces the expected JSON-shaped hash including geometry as GeoJSON
- `to_h` handles nil geometry / nil times gracefully

### 2. Unit (source) — `spec/nimbus/sources/smoke_spec.rb`

WebMock the ArcGIS query endpoint with three fixtures:

- **Heavy smoke covering point** — fixture returns one feature with `Density: "Heavy"`. Source returns `[Smoke]`.
- **No smoke** — fixture returns `{ "features": [] }`. Source returns `[]`.
- **API error** — fixture returns 500 + error envelope. Source raises `Skywatch::ApiError`.

Plus: verifies the request URL has the expected query params (`geometry=lon,lat`, `inSR=4326`, etc.).

### 3. Integration (Brief) — `spec/brief/integration_spec.rb` extension

Extend the existing snapshot test to include a smoke source mock returning one Heavy plume. Assert the `adverse_conditions.items` array contains an item with `kind: 'smoke'`, `density: :heavy`, `density_score: 3`. Plus a smoke-source-fails case in `composer_spec.rb` showing the partial_failures shape correctly captures the smoke source error.

### 4. CLI spec — `spec/nimbus/cli_smoke_spec.rb`

- `skywatch nimbus smoke 37.62 -122.38` (text mode, empty) → "No smoke detected at this point."
- `skywatch nimbus smoke 37.62 -122.38` (text mode, one plume) → text-formatted line
- `skywatch nimbus smoke 37.62 -122.38 --format json` (empty) → `[]`
- `skywatch nimbus smoke 37.62 -122.38 --format json` (one plume) → array with one `to_h`
- Error path: source raises → CLI prints `Error: ...` to stderr, exit 1

### 5. Top-level API spec — `spec/nimbus/smoke_spec.rb`

Light coverage of `Skywatch.smoke(at: [...])` — verifies the convenience method delegates to `Sources::Smoke#fetch`. Mirrors the existing `Skywatch.outlook` / `Skywatch.storms` specs.

## Validation (after merge)

`exe/skywatch nimbus smoke <lat> <lon>` for at least one currently smoke-affected coordinate (HMS smoke is reliably present somewhere in CONUS during fire season — but is rarer in late April / early May; if none found at validation time, document the no-smoke case as the validation evidence). Output should be a clean text line per plume, JSON shape matching the model `to_h`, and the brief integration should surface the plume under `adverse_conditions.items`.

## Documentation update

`CLAUDE.md` — add `skywatch nimbus smoke 40.688 -74.174` to the CLI usage block, right after the existing `nimbus convection` line.

## Follow-up issues already filed

| # | Title |
|---|---|
| [#13](https://github.com/jayrav13/skywatch/issues/13) | Add surface AQI from AirNow to Nimbus smoke/AQI |
| [#14](https://github.com/jayrav13/skywatch/issues/14) | Add `skywatch nimbus fires LAT LON` for HMS fire detection points |
| [#15](https://github.com/jayrav13/skywatch/issues/15) | Consider SmokeAnalysis aggregate model for Nimbus smoke |

These are explicitly out of MVP scope. After this PR ships, all three will be candidates for the **v1-scope triage** that precedes the next domain — figuring out which open issues are v1-must vs. post-v1 to push toward a shippable skyagent with limited scope first, before expanding depth/breadth.
