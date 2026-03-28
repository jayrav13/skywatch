# Phase 2: Core Weather Sources — Design Spec

**Goal**: `briefer taf KACK`, `briefer pireps KCDW`, `briefer winds KCDW --altitude 6000`, and `briefer crosswind KCDW --runway 28` work from the CLI.

## Decisions

- **Caching**: Memory-only cache with per-data-type TTLs. No file or Redis backend.
- **Winds Aloft decoding**: Decode the AWC encoded strings (e.g. `"2835+06"`) ourselves — the API doesn't provide pre-decoded JSON for this data type.
- **Crosswind**: Accepts explicit runway heading for Phase 2. Automatic runway lookup deferred to Phase 4 (when station data with runways is available).

## AWC API Response Schemas

### TAF Response

```json
{
  "icaoId": "KACK",
  "rawTAF": "TAF KACK 280520Z 2806/2906 02014KT P6SM BKN070 FM281600 ...",
  "issueTime": "2026-03-28T05:20:00.000Z",
  "validTimeFrom": 1774677600,
  "validTimeTo": 1774764000,
  "lat": 41.25407, "lon": -70.05892, "elev": 12,
  "name": "Nantucket Mem Arpt",
  "fcsts": [
    {
      "timeFrom": 1774677600, "timeTo": 1774713600,
      "timeBec": null, "fcstChange": null, "probability": null,
      "wdir": 20, "wspd": 14, "wgst": null,
      "visib": "6+", "wxString": null,
      "clouds": [{"cover": "BKN", "base": 7000, "type": null}],
      "icgTurb": [], "temp": [],
      "vertVis": null, "altim": null
    }
  ]
}
```

`fcstChange` values: `null` (initial), `"FM"`, `"BECMG"`, `"TEMPO"`, `"PROB"`.

### PIREP Response

```json
{
  "receiptTime": "2026-03-28T04:40:07.395Z",
  "obsTime": 1774672320,
  "icaoId": "KWBC",
  "acType": "C17",
  "lat": 40.0143, "lon": -73.7172,
  "fltLvl": 70, "fltLvlType": "OTHER",
  "temp": -10,
  "wdir": null, "wspd": null,
  "icgBas1": null, "icgTop1": null, "icgInt1": "LGT", "icgType1": "RIME",
  "tbBas1": null, "tbTop1": null, "tbInt1": "", "tbType1": "",
  "pirepType": "PIREP",
  "rawOb": "MJX UA /OV CYN080035/TM 0432/FL070/TP C17/TA M10/IC LGT RIME"
}
```

Icing/turbulence have two slots each (`*1`, `*2`). Empty string = not reported.

### Winds Aloft Response

```json
{
  "station_id": "ABI",
  "ft_3000": "0823+05",
  "ft_6000": "1809+05",
  "ft_9000": "2510+05",
  "ft_12000": "3020-09",
  "ft_18000": "2920-22",
  "ft_24000": "272539",
  "ft_30000": "262849",
  "ft_34000": "262159",
  "ft_39000": null
}
```

Encoding rules:
- 4 digits: `DDSS` — direction DD*10, speed SS kt
- 4 digits + sign + temp: `DDSS±TT`
- Above 24,000': temp encoded without sign (always negative)
- `9900` = light and variable
- Direction > 36: subtract 50 from direction, add 100 to speed (speeds 100-199kt)

## Components

### 1. `Briefer::Client::Cache`

Memory-only cache wrapping `Client::Http`.

```ruby
cache = Briefer::Client::Cache.new(client: Briefer::Client::Http.new)
cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
```

- Keyed by `[path, sorted_params]`
- Returns cached response if within TTL
- Thread-safe via `Mutex`
- `#clear` to flush all entries
- `#size` for diagnostics

Default TTLs (seconds):
| Data | TTL |
|------|-----|
| METAR | 300 (5 min) |
| TAF | 1800 (30 min) |
| PIREP | 600 (10 min) |
| Winds Aloft | 3600 (60 min) |

TTL is passed by each source at call time, not configured globally.

### 2. `Briefer::Models::TafGroup`

Individual forecast period. Fields from AWC `fcsts` entry:

- `time_from`, `time_to` (Time, UTC)
- `change_type` — `:initial`, `:fm`, `:becmg`, `:tempo`, `:prob`
- `probability` — Integer or nil (e.g. 30 for PROB30)
- `wind_direction_deg`, `wind_speed_kt`, `wind_gust_kt`
- `visibility_sm` (float, parsed same as METAR)
- `weather` (array of strings from `wxString`)
- `sky_condition` (array of hashes, same format as METAR)
- `ceiling_ft` (computed, same logic as METAR)
- `flight_category` (computed via `Analysis::FlightCategory`)

Constructor: `TafGroup.from_awc(fcst_hash)`

### 3. `Briefer::Models::Taf`

Top-level TAF. Fields:

- `station_id`, `raw`, `issued_at` (Time), `valid_from`, `valid_to` (Time)
- `station_name`, `latitude`, `longitude`, `elevation_ft`
- `forecast_groups` — `[TafGroup]`
- `position` — `Models::Position`

Constructor: `Taf.from_awc(data)` — parses top-level fields and maps `fcsts` to `TafGroup` objects.

Methods:
- `#group_at(time)` — returns the applicable TafGroup for a given time
- `#to_h`, `#to_json`

### 4. `Briefer::Sources::Taf`

`GET /api/data/taf?ids={icao}&format=json`

- Same pattern as `Sources::Metar`
- Joins multiple IDs, returns `[Models::Taf]`
- Passes TTL 1800 to cache

### 5. `Briefer::Models::Pirep`

Fields:

- `raw`, `observed_at` (Time), `pirep_type` (`:pirep` or `:urgent`)
- `aircraft_type`, `latitude`, `longitude`, `position`
- `flight_level` (integer, hundreds of feet)
- `altitude_ft` (computed: `flight_level * 100`)
- `temperature_c`
- `wind_direction_deg`, `wind_speed_kt`
- `icing_intensity`, `icing_type`, `icing_base_ft`, `icing_top_ft` (from `*1` fields; `*2` ignored for simplicity)
- `turbulence_intensity`, `turbulence_type`, `turbulence_base_ft`, `turbulence_top_ft`

Constructor: `Pirep.from_awc(data)` — maps AWC fields, converts empty strings to nil, converts `fltLvl` to hundreds.

Methods: `#to_h`, `#to_json`, `#icing?`, `#turbulence?`

### 6. `Briefer::Sources::Pirep`

`GET /api/data/pirep?id={icao}&dist={nm}&format=json`

- Single station + radius
- Returns `[Models::Pirep]`
- Passes TTL 600 to cache

### 7. `Briefer::Models::WindsAloft`

Value object for a single station/altitude data point:

- `station_id`, `altitude_ft`
- `wind_direction_deg` (nil if light and variable)
- `wind_speed_kt` (nil if light and variable)
- `temperature_c` (nil if not reported)
- `light_and_variable` (boolean)

Class method: `WindsAloft.decode(station_id:, altitude_ft:, encoded:)` — decodes the AWC encoded string per the encoding rules above.

### 8. `Briefer::Sources::WindsAloft`

`GET /api/data/windtemp?region=all&level=low&fcst=06&format=json`

- Fetches bulk data, filters to requested station(s)
- Parses each `ft_XXXX` column through `WindsAloft.decode`
- Optional altitude filter: return only the requested altitude ± one level
- Returns `[Models::WindsAloft]`
- Passes TTL 3600 to cache

### 9. `Briefer::Analysis::CrosswindCalculator`

Pure function:

```ruby
CrosswindCalculator.calculate(
  wind_direction_deg: 330, wind_speed_kt: 15, runway_heading: 280
)
# => { crosswind_kt: 11.5, headwind_kt: 9.6 }
```

Handles: calm winds (return zeros), variable winds (return nil components with the full speed as max crosswind).

### 10. `Briefer::Formatters::Text` (extend)

Add methods:
- `.format_taf(taf)` — header line + each group on its own line with change type, wind, vis, clouds, category
- `.format_pirep(pirep)` — one line: aircraft, location, FL, icing/turbulence summary
- `.format_winds_aloft(winds)` — table: station, altitude, direction, speed, temp
- `.format_crosswind(result, station_id, runway)` — crosswind and headwind components

### 11. CLI Commands (extend `Briefer::CLI`)

- `briefer taf STATION [STATION...]` — `--format text|json`
- `briefer pireps STATION` — `--radius 100`, `--format text|json`
- `briefer winds STATION [STATION...]` — `--altitude 6000`, `--format text|json`
- `briefer crosswind STATION` — `--runway 28` (required), `--format text|json`

### 12. Top-level Convenience Methods (extend `Briefer`)

- `Briefer.taf(*station_ids)` — returns `[Models::Taf]`
- `Briefer.pireps(station_id, radius_nm: 100)` — returns `[Models::Pirep]`
- `Briefer.winds_aloft(*station_ids, altitude_ft: nil)` — returns `[Models::WindsAloft]`
- `Briefer.crosswind(station_id, runway_heading:)` — returns `{ crosswind_kt:, headwind_kt: }`

## Test Strategy

Same patterns as Phase 1:
- Static JSON fixtures from real AWC responses for each source
- Hand-crafted edge case fixtures (TEMPO groups, PROB30, icing PIREPs, light-and-variable winds, >100kt winds aloft)
- Unit specs for each model, source, and analysis module
- Crosswind calculator: boundary cases (90° cross, 0° headwind, calm, variable)
- Winds aloft decoder: all encoding variants
- Cache: TTL expiry, cache hit/miss, thread safety
- CLI integration specs for all new commands

## File Structure (Phase 2 additions)

```
lib/briefer/
├── client/
│   ├── http.rb          (existing)
│   └── cache.rb         (new)
├── models/
│   ├── position.rb      (existing)
│   ├── metar.rb         (existing)
│   ├── taf.rb           (new)
│   ├── taf_group.rb     (new)
│   ├── pirep.rb         (new)
│   └── winds_aloft.rb   (new)
├── sources/
│   ├── metar.rb         (existing)
│   ├── taf.rb           (new)
│   ├── pirep.rb         (new)
│   └── winds_aloft.rb   (new)
├── analysis/
│   ├── flight_category.rb    (existing)
│   └── crosswind_calculator.rb (new)
├── formatters/
│   └── text.rb          (modify — add TAF/PIREP/winds/crosswind formatting)
└── cli.rb               (modify — add taf/pireps/winds/crosswind commands)

spec/
├── client/
│   └── cache_spec.rb
├── models/
│   ├── taf_spec.rb
│   ├── taf_group_spec.rb
│   ├── pirep_spec.rb
│   └── winds_aloft_spec.rb
├── sources/
│   ├── taf_spec.rb
│   ├── pirep_spec.rb
│   └── winds_aloft_spec.rb
├── analysis/
│   └── crosswind_calculator_spec.rb
├── formatters/
│   └── text_spec.rb     (modify — add TAF/PIREP/winds/crosswind tests)
├── cli_spec.rb           (modify — add new command tests)
└── fixtures/
    ├── metars/           (existing)
    ├── tafs/
    │   ├── kack.json
    │   ├── kcdw.json
    │   └── tempo_prob.json
    ├── pireps/
    │   ├── near_kcdw.json
    │   ├── icing.json
    │   └── turbulence.json
    └── winds_aloft/
        ├── low_level.json
        └── encoded_edge_cases.json
```
