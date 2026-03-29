# Phase 3: Hazards & Area Forecasts — Design Spec

## Scope

Four new data sources with models, sources, formatters, CLI commands, and rgeo integration for polygon geometry.

| Source | Endpoint | Format | Cache TTL |
|--------|----------|--------|-----------|
| SIGMETs | `aviationweather.gov/api/data/airsigmet?format=json` | JSON (coords array) | 15 min |
| G-AIRMETs | `aviationweather.gov/api/data/gairmet?format=json` | JSON (coords array, string lat/lon) | 30 min |
| TFRs | `tfr.faa.gov/geoserver/TFR/ows?service=WFS&version=1.1.0&request=GetFeature&typeName=TFR:V_TFR_LOC&outputFormat=application/json` | GeoJSON FeatureCollection | 30 min |
| Area Forecast Discussion | `aviationweather.gov/api/data/fcstdisc?cwa={wfo}` | Raw text | 60 min |

**Not included:** NOTAMs (FAA API portal registration issues, deferred).

## Dependencies

- `rgeo` — for `RGeo::Geographic::SphericalPointImpl` and polygon construction
- `rgeo-geojson` — for parsing TFR GeoJSON FeatureCollection responses

Add to `briefer.gemspec`:
```ruby
spec.add_dependency "rgeo", "~> 3.0"
spec.add_dependency "rgeo-geojson", "~> 2.0"
```

## Data Models

### Models::Sigmet

Parsed from `airsigmet` endpoint where `airSigmetType == "SIGMET"`.

```ruby
class Briefer::Models::Sigmet
  attr_reader :series_id,        # "1E"
              :issuing_center,   # "KKCI"
              :sigmet_type,      # :convective, :sigmet
              :hazard,           # "CONVECTIVE", "TURB", "ICE"
              :severity,         # Integer (1-5)
              :raw,              # Raw text
              :valid_from,       # Time (UTC)
              :valid_to,         # Time (UTC)
              :altitude_hi_ft,   # Integer or nil
              :altitude_low_ft,  # Integer or nil
              :movement_dir_deg, # Integer or nil
              :movement_speed_kt,# Integer or nil
              :coords            # Array of Position — polygon vertices

  def polygon     # => RGeo polygon from coords
  def to_h
  def to_json(*)
end
```

**Field mapping from API:**
- `icaoId` → `issuing_center`
- `seriesId` → `series_id`
- `airSigmetType` → `sigmet_type` (downcase, symbolize)
- `hazard` → `hazard`
- `severity` → `severity`
- `rawAirSigmet` → `raw`
- `validTimeFrom` → `valid_from` (Unix epoch → `Time.at().utc`)
- `validTimeTo` → `valid_to`
- `altitudeHi1` → `altitude_hi_ft`
- `altitudeLow1` → `altitude_low_ft`
- `movementDir` → `movement_dir_deg`
- `movementSpd` → `movement_speed_kt`
- `coords` → array of `Position.new(lat:, lon:)` from `[{lat:, lon:}]`

### Models::Airmet

Parsed from `gairmet` endpoint.

```ruby
class Briefer::Models::Airmet
  attr_reader :tag,              # "3E"
              :product,          # :sierra, :tango, :zulu
              :hazard,           # "MT_OBSC", "TURB-LO", "ICE", "IFR", etc.
              :due_to,           # "MTNS OBSC BY CLDS/BR" (free text cause)
              :severity,         # String or nil
              :forecast_hour,    # Integer (0, 3, 6, 9, 12)
              :valid_at,         # Time (UTC)
              :issued_at,        # Time (UTC)
              :expires_at,       # Time (UTC)
              :top,              # String altitude or nil
              :base,             # String altitude or nil
              :freeze_level_top, # String or nil
              :freeze_level_base,# String or nil
              :coords            # Array of Position — polygon vertices

  def polygon     # => RGeo polygon from coords
  def to_h
  def to_json(*)
end
```

**Field mapping from API:**
- `tag` → `tag`
- `product` → `product` (downcase, symbolize — "SIERRA" → :sierra)
- `hazard` → `hazard`
- `due_to` → `due_to` (blank string → nil)
- `severity` → `severity` (blank string → nil)
- `forecastHour` → `forecast_hour`
- `validTime` → `valid_at` (ISO 8601 string → `Time.parse().utc`)
- `issueTime` → `issued_at` (Unix epoch → `Time.at().utc`)
- `expireTime` → `expires_at` (Unix epoch → `Time.at().utc`)
- `top`, `base`, `fzltop`, `fzlbase` → corresponding fields (blank → nil)
- `coords` → array of `Position` — **note: lat/lon are strings in this API**, must `.to_f`

### Models::Tfr

Parsed from FAA GeoServer WFS GeoJSON response.

```ruby
class Briefer::Models::Tfr
  attr_reader :notam_key,   # "6/3475-1-FDC-F"
              :title,        # "Beale AFB, CA, Sunday, March 8..."
              :state,        # "CA"
              :type,         # "SECURITY", "HAZARDS", "VIP", etc.
              :center_id,    # "ZOA"
              :last_modified,# Time or nil
              :coords        # Array of Position — polygon vertices

  def polygon     # => RGeo polygon from coords
  def to_h
  def to_json(*)
end
```

**Field mapping from GeoJSON:**
- `properties.NOTAM_KEY` → `notam_key`
- `properties.TITLE` → `title`
- `properties.STATE` → `state`
- `properties.LEGAL` → `type`
- `properties.CNS_LOCATION_ID` → `center_id`
- `properties.LAST_MODIFICATION_DATETIME` → `last_modified` (parse "YYYYMMDDHHmm" format)
- `geometry.coordinates[0]` → `coords` (GeoJSON polygon → array of Position, note: GeoJSON is [lon, lat])

### Models::ForecastDiscussion

Parsed from `fcstdisc` raw text endpoint.

```ruby
class Briefer::Models::ForecastDiscussion
  attr_reader :wfo,         # "KBOX" — Weather Forecast Office
              :text,         # Full discussion text
              :issued_at     # Time (UTC), parsed from text header

  def to_h
  def to_json(*)
end
```

The AFD endpoint returns raw text. The WFO identifier comes from the request parameter. The issued time is parsed from the text header line (e.g., `"726 PM EDT Sat Mar 28 2026"`). If parsing fails, use `Time.now.utc`.

## Geometry Module

A shared helper for building RGeo polygons from coordinate arrays.

```ruby
module Briefer::Geometry
  FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

  def self.polygon_from_coords(coords)
    # coords: Array of Position (or anything responding to .lat, .lon)
    # Returns: RGeo polygon, or nil if < 3 points
    return nil if coords.nil? || coords.size < 3

    points = coords.map { |c| FACTORY.point(c.lon, c.lat) }
    ring = FACTORY.linear_ring(points)
    FACTORY.polygon(ring)
  end

  def self.point(lat, lon)
    FACTORY.point(lon, lat)
  end
end
```

Each model's `#polygon` method delegates to `Geometry.polygon_from_coords(coords)`.

## Source Classes

### Sources::AirSigmet

Single source for both SIGMETs and international SIGMETs.

```ruby
class Briefer::Sources::AirSigmet
  ENDPOINT = "/api/data/airsigmet"
  TTL = 900  # 15 minutes

  def fetch(hazard: nil)
    # params: { format: "json" }
    # optional: hazard filter (conv, turb, ice, ifr)
    # Returns: Array of Models::Sigmet
    # Filters to airSigmetType == "SIGMET" only
  end
end
```

### Sources::Gairmet

```ruby
class Briefer::Sources::Gairmet
  ENDPOINT = "/api/data/gairmet"
  TTL = 1800  # 30 minutes

  def fetch(product: nil, hazard: nil)
    # params: { format: "json" }
    # optional: product filter (sierra, tango, zulu)
    # optional: hazard filter
    # Returns: Array of Models::Airmet
  end
end
```

### Sources::Tfr

Uses the FAA GeoServer WFS, not the AWC API. Needs its own Faraday connection since the base URL is different (`tfr.faa.gov`).

```ruby
class Briefer::Sources::Tfr
  ENDPOINT = "/geoserver/TFR/ows"
  BASE_URL = "https://tfr.faa.gov"
  TTL = 1800  # 30 minutes

  def fetch(state: nil)
    # WFS params: service=WFS, version=1.1.0, request=GetFeature,
    #   typeName=TFR:V_TFR_LOC, outputFormat=application/json
    # optional: CQL_FILTER for state
    # Returns: Array of Models::Tfr
  end
end
```

The TFR source uses a separate HTTP client instance (or the existing one with a different base URL). Since our `Client::Http` is hardcoded to `aviationweather.gov`, the TFR source will create its own Faraday connection internally. The cache layer can still wrap it.

### Sources::ForecastDiscussion

```ruby
class Briefer::Sources::ForecastDiscussion
  ENDPOINT = "/api/data/fcstdisc"
  TTL = 3600  # 60 minutes

  def fetch(wfo)
    # params: { cwa: wfo.upcase }
    # Returns raw text, wraps in Models::ForecastDiscussion
    # Note: this endpoint returns raw text, not JSON
  end
end
```

The AFD endpoint returns plain text, not JSON. The source must make a raw GET and not parse as JSON. This means the HTTP client needs to handle non-JSON responses — either a new method or a flag on the existing `get`.

## HTTP Client Changes

The existing `Client::Http#get` always parses JSON. Two changes needed:

1. **`get_raw(path, params, ttl:)`** — returns the response body as a string without JSON parsing. Used by `Sources::ForecastDiscussion`.

2. **TFR base URL** — `Sources::Tfr` creates its own Faraday connection to `tfr.faa.gov`. It can use `Client::Cache` wrapping by keying on the full URL.

## Text Formatters

### format_sigmet(sigmet)
```
SIGMET 1E (CONVECTIVE) — valid 0155Z-0355Z
  FL000-FL360  Moving 010° at 10kt
  WSUS31 KKCI 290055...
```

### format_airmet(airmet)
```
G-AIRMET SIERRA: MT_OBSC (MTNS OBSC BY CLDS/BR)
  Valid 0300Z  Fcst hour +6  Expires 0900Z
```

### format_tfr(tfr)
```
TFR 6/3475 (SECURITY) — CA
  Beale AFB, CA, Sunday, March 8, 2026 through Sunday, November 1, 2026 Local
```

### format_forecast_discussion(afd)
```
Area Forecast Discussion — KBOX
  Issued 726 PM EDT Sat Mar 28 2026

  [first ~500 chars of text]...
```

## CLI Commands

### `briefer sigmets`
Fetch active SIGMETs. Optional `--hazard conv|turb|ice|ifr` filter.

### `briefer airmets`
Fetch active G-AIRMETs. Optional `--product sierra|tango|zulu` and `--hazard` filters.

### `briefer tfrs`
Fetch active TFRs. Optional `--state CA` filter.

### `briefer afd WFO`
Fetch Area Forecast Discussion for a Weather Forecast Office (e.g., `KBOX`).

All commands support `--format text|json`.

## Convenience Methods

```ruby
Briefer.sigmets(hazard: nil)           # => [Models::Sigmet]
Briefer.airmets(product: nil, hazard: nil)  # => [Models::Airmet]
Briefer.tfrs(state: nil)              # => [Models::Tfr]
Briefer.afd(wfo)                       # => Models::ForecastDiscussion
```

## Testing Strategy

- Fixture files for each API response (saved from live responses above)
- Webmock stubs for all HTTP calls
- Model specs: parse fixtures, verify all fields
- Source specs: stub HTTP, verify model construction
- CLI specs: stub source, verify text/JSON output
- Geometry specs: verify polygon construction from coords, edge cases (< 3 points → nil)
- TFR source needs separate Faraday stub (different base URL)
- AFD source needs raw text stub (not JSON)

## File Inventory

**New files:**
- `lib/briefer/geometry.rb`
- `lib/briefer/models/sigmet.rb`
- `lib/briefer/models/airmet.rb`
- `lib/briefer/models/tfr.rb`
- `lib/briefer/models/forecast_discussion.rb`
- `lib/briefer/sources/air_sigmet.rb`
- `lib/briefer/sources/gairmet.rb`
- `lib/briefer/sources/tfr.rb`
- `lib/briefer/sources/forecast_discussion.rb`
- `spec/geometry_spec.rb`
- `spec/models/sigmet_spec.rb`
- `spec/models/airmet_spec.rb`
- `spec/models/tfr_spec.rb`
- `spec/models/forecast_discussion_spec.rb`
- `spec/sources/air_sigmet_spec.rb`
- `spec/sources/gairmet_spec.rb`
- `spec/sources/tfr_spec.rb`
- `spec/sources/forecast_discussion_spec.rb`
- `spec/fixtures/sigmets/convective.json`
- `spec/fixtures/airmets/sierra.json`
- `spec/fixtures/tfrs/feature_collection.json`
- `spec/fixtures/afd/kbox.txt`

**Modified files:**
- `briefer.gemspec` — add rgeo, rgeo-geojson
- `lib/briefer.rb` — add requires and convenience methods
- `lib/briefer/client/http.rb` — add `get_raw` method
- `lib/briefer/client/cache.rb` — add `get_raw` passthrough with caching
- `lib/briefer/formatters/text.rb` — add format methods
- `lib/briefer/cli.rb` — add commands
- `spec/briefer_spec.rb` — integration tests
- `spec/cli_spec.rb` — CLI tests
