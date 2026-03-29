# Radar — Flight Tracking (OpenSky MVP)

## Overview

A Ruby gem for real-time flight tracking using the OpenSky Network API. Part of the skywatch multi-agent system. Provides CLI and Ruby API for querying active flights near airports, tracking by callsign, and aircraft lookup.

## Data Source

**OpenSky Network REST API** (`https://opensky-network.org/api`)
- Free, no API key required
- Anonymous rate limit: ~10 requests/minute
- State vector updates every ~10 seconds
- Endpoints used:
  - `GET /states/all` — all aircraft (supports `icao24`, `lamin/lamax/lomin/lomax` bbox filters)
  - `GET /tracks/all?icao24=<addr>&time=0` — recent track waypoints

## CLI Commands

```
radar flights KSFO [--radius 50] [--format json|text]   # Active flights near airport
radar track UAL1234 [--format json|text]                 # Track by callsign
radar aircraft N12345 [--format json|text]               # Lookup by ICAO24/tail
radar version
radar install-skill
radar uninstall-skill
```

- `--format` defaults to `text` when TTY, `json` when piped
- Exit code 0 on success, 1 on error
- JSON to stdout, errors to stderr

## Gem Structure

```
radar/
├── exe/radar
├── lib/
│   ├── radar.rb                      # Top-level module + convenience API
│   └── radar/
│       ├── version.rb
│       ├── errors.rb
│       ├── client/
│       │   ├── http.rb               # Faraday wrapper with User-Agent, timeouts, retry
│       │   └── cache.rb              # Memory cache with TTLs
│       ├── sources/
│       │   └── opensky.rb            # OpenSky API: states, tracks
│       ├── models/
│       │   ├── state_vector.rb       # Single aircraft state
│       │   └── station.rb            # Airport lookup (bundled DB)
│       ├── analysis/
│       │   └── proximity.rb          # Bounding box + distance calculations
│       └── formatters/
│           └── text.rb               # Human-readable flight table
├── spec/
│   ├── spec_helper.rb
│   ├── fixtures/
│   │   └── opensky/                  # Saved JSON responses
│   │       ├── states_bbox.json
│   │       ├── states_callsign.json
│   │       └── states_icao24.json
│   ├── sources/
│   │   └── opensky_spec.rb
│   ├── models/
│   │   └── state_vector_spec.rb
│   └── analysis/
│       └── proximity_spec.rb
├── radar.gemspec
├── Gemfile
├── Rakefile
├── .rubocop.yml
├── .rspec
├── .gitignore
├── LICENSE.txt
└── CLAUDE.md
```

## Models

### StateVector

Represents a single aircraft's current state from OpenSky.

```ruby
module Radar
  module Models
    class StateVector
      attr_reader :icao24              # String — ICAO 24-bit transponder address (hex)
      attr_reader :callsign            # String or nil — e.g. "UAL1234"
      attr_reader :origin_country      # String
      attr_reader :time_position       # Integer (unix) or nil
      attr_reader :last_contact        # Integer (unix)
      attr_reader :longitude           # Float or nil
      attr_reader :latitude            # Float or nil
      attr_reader :baro_altitude_m     # Float or nil (meters)
      attr_reader :on_ground           # Boolean
      attr_reader :velocity_ms         # Float or nil (m/s)
      attr_reader :true_track_deg      # Float or nil (degrees from north)
      attr_reader :vertical_rate_ms    # Float or nil (m/s)
      attr_reader :geo_altitude_m      # Float or nil (meters)
      attr_reader :squawk              # String or nil — e.g. "7700"
      attr_reader :spi                 # Boolean — special purpose indicator

      def self.from_api(array)
        # OpenSky returns state vectors as arrays, not objects
      end

      # Computed
      def altitude_ft                  # baro_altitude in feet
      def velocity_kt                  # velocity in knots
      def vertical_rate_fpm            # vertical rate in ft/min
      def emergency?                   # squawk 7500/7600/7700
      def to_h
      def to_json
    end
  end
end
```

### Station

Airport lookup from bundled database. Fields: icao, name, latitude, longitude, elevation_ft.

For MVP, duplicate briefer's station data as a simple JSON file. Future: extract to a shared skywatch data gem or file.

## Sources

### Opensky

```ruby
module Radar
  module Sources
    class Opensky
      # Fetch all state vectors within a bounding box
      def states_bbox(lamin:, lamax:, lomin:, lomax:)

      # Fetch state vectors filtered by callsign (via full fetch + filter, OpenSky doesn't support callsign param)
      def states_by_callsign(callsign)

      # Fetch state vectors filtered by ICAO24 address
      def states_by_icao24(icao24)
    end
  end
end
```

**Note:** OpenSky's `/states/all` returns an array of arrays under the `"states"` key, plus a `"time"` timestamp. Each inner array has 17 positional elements mapping to StateVector fields.

## Analysis

### Proximity

```ruby
module Radar
  module Analysis
    class Proximity
      # Build a bounding box (lat/lon) around an airport at a given radius (nm)
      def self.bbox(station, radius_nm: 50)

      # Filter state vectors to those within radius of a point
      def self.within_radius(state_vectors, lat:, lon:, radius_nm:)

      # Haversine distance between two lat/lon points (returns nm)
      def self.distance_nm(lat1, lon1, lat2, lon2)
    end
  end
end
```

## Caching

- State vectors: 15-second TTL (data refreshes ~10s on OpenSky)
- Same cache pattern as briefer: `Radar::Client::Cache` wrapping `Radar::Client::Http`

## Formatters

### Text

`radar flights KSFO` output:
```
Flights near KSFO (50nm) — 23 aircraft
──────────────────────────────────────────────────────────
CALL      ALT     SPD    HDG   DIST   SQUAWK
UAL1234   18000   250kt  280°  12nm   1200
AAL567    FL350   450kt  090°  34nm   4521
...
```

`radar track UAL1234` output:
```
UAL1234 — United States
  Position:  37.6213°N, -122.3790°W
  Altitude:  18,000 ft (barometric)
  Speed:     250 kt, heading 280°
  Vertical:  -1,200 fpm (descending)
  Squawk:    1200
  On ground: No
  Last seen: 3s ago
```

## Shared Dependencies

```ruby
# radar.gemspec
spec.add_dependency "faraday", "~> 2.0"
spec.add_dependency "faraday-retry", "~> 2.0"
spec.add_dependency "thor", "~> 1.0"

spec.add_development_dependency "rspec", "~> 3.0"
spec.add_development_dependency "webmock", "~> 3.0"
spec.add_development_dependency "rubocop", "~> 1.0"
```

No rgeo needed — proximity calculations use simple haversine, no polygon operations.

## Test Strategy

- All source specs test against saved JSON fixtures in `spec/fixtures/opensky/`
- No live API calls in tests
- Model specs verify `.from_api` parsing from fixture data
- Analysis specs test bbox generation and distance calculations with known coordinates
- Integration specs verify CLI commands end-to-end with webmock
