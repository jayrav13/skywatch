# Phase 1: Foundation — Design Spec

**Goal**: `briefer metar KCDW` works from the CLI and returns structured data.

## Decisions

- **Ruby**: >= 3.2.0
- **METAR parsing**: AWC JSON-first. Map AWC API's pre-decoded JSON fields to model attributes. No raw METAR string parser.
- **Station data**: No bundled database. Station info (name, coords, elevation) extracted from AWC responses. Standalone station source deferred to Phase 4.

## Dependencies

### Runtime
- `thor` (~> 1.3) — CLI framework
- `faraday` (~> 2.0) — HTTP client
- `faraday-retry` (~> 2.0) — retry middleware

### Development
- `rspec` (~> 3.0)
- `webmock` (~> 3.0)
- `vcr` (~> 6.0)
- `rubocop` (~> 1.86)
- `rubocop-rspec` (~> 3.0)
- `rake` (~> 13.0)
- `lefthook` (~> 2.1)

## Linting & Git Hooks (mirrors njtransit)

Set up early — all code written in Phase 1 must pass lint from the start.

- **RuboCop**: double quotes, 120 char lines, `Style/Documentation` disabled, `rubocop-rspec` plugin
- **Lefthook**: pre-commit runs rubocop on staged .rb files (`stage_fixed: true`), pre-push runs rspec
- **`.rspec`**: `--format documentation --color --require spec_helper`

## Components

Listed in dependency order (each depends only on those above it).

### 1. Gem Scaffold

Standard `bundle gem briefer` structure. `bin/briefer` executable. Gemspec with metadata, Ruby version requirement, dependencies.

Entry point `lib/briefer.rb` exposes top-level convenience methods:
- `Briefer.metar(*station_ids)` — returns `[Models::Metar]`
- `Briefer.flight_category(station_id)` — returns symbol `:vfr`, `:mvfr`, `:ifr`, `:lifr`

### 2. `Briefer::Client::Http`

Faraday wrapper providing a shared HTTP client.

- Custom `User-Agent`: `Briefer/{version} (ruby; github.com/jay/briefer)`
- Timeouts: 10s open, 10s read
- Retry: 3 attempts with exponential backoff via `faraday-retry`
- JSON response parsing via `faraday` middleware
- Base URL: `https://aviationweather.gov`
- Accessed via `Briefer.client` (lazy-initialized singleton)

### 3. `Briefer::Models::Position`

Data class (Ruby 3.2 `Data.define`): `lat`, `lon`.

### 4. `Briefer::Models::Metar`

Initialized from an AWC JSON hash. Fields per BRIEFER_PLAN.md section 12:

**Direct from AWC JSON:**
- `raw` (original encoded METAR string)
- `station_id`
- `observed_at` (Time, UTC)
- `is_auto`, `is_speci` (boolean)
- `wind_direction_deg`, `wind_speed_kt`, `wind_gust_kt`
- `wind_variable_from_deg`, `wind_variable_to_deg`
- `visibility_sm` (float)
- `weather` (array of strings: `["+RA", "BR"]`)
- `sky_condition` (array of hashes: `[{ cover: :bkn, base_ft: 4500 }]`)
- `temperature_c`, `dewpoint_c` (float)
- `altimeter_inhg` (float)
- `station_name`, `latitude`, `longitude`, `elevation_ft`

**Computed:**
- `ceiling_ft` — lowest BKN/OVC base, or `nil` if clear/few/scattered only
- `flight_category` — via `Analysis::FlightCategory`
- `spread_c` — `temperature_c - dewpoint_c`
- `density_altitude_ft` — computed from temperature, altimeter, elevation
- `position` — `Models::Position` from lat/lon

**Convenience methods:** `vfr?`, `mvfr?`, `ifr?`, `lifr?`

### 5. `Briefer::Analysis::FlightCategory`

Pure function: `FlightCategory.classify(ceiling_ft:, visibility_sm:)` returns a symbol.

Rules (per FAA AIM):
| Category | Ceiling | Visibility |
|----------|---------|------------|
| VFR | > 3,000' | > 5 SM |
| MVFR | 1,000–3,000' | 3–5 SM |
| IFR | 500–999' | 1–2 SM |
| LIFR | < 500' | < 1 SM |

Lowest qualifying condition wins. `nil` ceiling treated as unlimited (VFR ceiling).

### 6. `Briefer::Sources::Metar`

Fetches from AWC Data API: `GET /api/data/metar?ids={icao}&format=json`

- Accepts one or more ICAO station IDs
- Joins multiple IDs with commas in a single request
- Returns `[Models::Metar]`
- Raises `Briefer::Error` subclasses on HTTP/parse failures

### 7. `Briefer::Formatters::Json`

Serializes models via `#to_h` and `#to_json`. Each model implements `#to_h` returning a plain Ruby hash.

### 8. `Briefer::Formatters::Text`

Human-readable METAR display:
```
KCDW (Essex County) — VFR
  KCDW 151200Z 28012G18KT 10SM FEW045 BKN080 18/08 A3012
  Ceiling: 8,000' (BKN)  Vis: 10SM  Wind: 280° @ 12G18kt
  Temp: 18°C  Dew: 8°C  Spread: 10°C  Altimeter: 30.12
```

### 9. `Briefer::CLI`

Thor subclass with two commands:

**`briefer metar STATION [STATION...]`**
- Fetches and displays METARs for given stations
- `--format text|json` (default: `text` on TTY, `json` when piped)
- `--raw` includes only the raw METAR string

**`briefer categories STATION [STATION...]`**
- Displays flight category for each station
- `--format text|json`

## Error Handling

- `Briefer::Error` — base error class
- `Briefer::ConnectionError` — network failures
- `Briefer::ApiError` — non-200 responses from AWC
- `Briefer::ParseError` — unexpected response format

CLI catches all `Briefer::Error` subclasses and prints a user-friendly message to stderr with exit code 1.

## Test Strategy

### VCR Cassettes
Record real AWC responses for: KCDW, KACK, KTEB, KEWR (single and multi-station requests).

### Static Fixtures
Hand-crafted JSON for edge cases:
- Calm winds (`00000KT`)
- Variable winds with direction range
- Missing ceiling (clear sky)
- SPECI observation
- AUTO observation
- Visibility below 1 SM (fractional)
- Multiple weather phenomena

### Unit Specs
- `FlightCategory.classify` — boundary cases: exactly 1000' = IFR, exactly 3000' = MVFR, exactly 500' = IFR, nil ceiling + low vis
- `Models::Metar` — field mapping from AWC JSON, computed fields (ceiling, spread, density altitude, flight category)
- `Sources::Metar` — HTTP interaction (via VCR), error handling
- `Client::Http` — User-Agent header, timeout config, retry behavior

### Integration Specs
- CLI `metar` command: text and JSON output for single and multi-station
- CLI `categories` command: correct category display
- TTY detection: JSON default when piped

## File Structure (Phase 1)

```
briefer/
├── briefer.gemspec
├── Gemfile
├── Rakefile
├── LICENSE.txt
├── CLAUDE.md
├── BRIEFER_PLAN.md
├── bin/
│   └── briefer
├── lib/
│   ├── briefer.rb
│   └── briefer/
│       ├── version.rb
│       ├── errors.rb
│       ├── client/
│       │   └── http.rb
│       ├── models/
│       │   ├── position.rb
│       │   └── metar.rb
│       ├── sources/
│       │   └── metar.rb
│       ├── analysis/
│       │   └── flight_category.rb
│       ├── formatters/
│       │   ├── json.rb
│       │   └── text.rb
│       └── cli.rb
├── spec/
│   ├── spec_helper.rb
│   ├── briefer_spec.rb
│   ├── client/
│   │   └── http_spec.rb
│   ├── models/
│   │   ├── position_spec.rb
│   │   └── metar_spec.rb
│   ├── sources/
│   │   └── metar_spec.rb
│   ├── analysis/
│   │   └── flight_category_spec.rb
│   ├── formatters/
│   │   ├── json_spec.rb
│   │   └── text_spec.rb
│   ├── cli_spec.rb
│   └── fixtures/
│       └── metars/
│           ├── kcdw.json
│           ├── kack.json
│           ├── multi_station.json
│           └── edge_cases/
│               ├── calm_winds.json
│               ├── variable_winds.json
│               ├── clear_sky.json
│               ├── speci.json
│               ├── low_visibility.json
│               └── multi_weather.json
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-03-28-phase1-foundation-design.md
```
