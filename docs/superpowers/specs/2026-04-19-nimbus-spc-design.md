# Nimbus PR 1 — SPC Outlooks + Storm Reports — Design Spec

**Date:** 2026-04-19
**Status:** Draft, pending review
**Author:** Jay (with Claude)
**PR scope:** 1 of 3 for `Skywatch::Nimbus`

## Goal

Give an agent (or developer, or pilot) two one-shot questions against the Storm Prediction Center:

> *"What's today's severe-weather outlook (Day 1/2/3), and am I inside it?"*
>
> *"Any confirmed tornado / damaging wind / hail reports from the last 24h, near me or anywhere?"*

Both return small, structured, deterministic lists. No watch loops. No alerting.

## Design Principles (applied from north star)

- **Agent-first.** Caller invokes one tool, gets deterministic JSON. Cadence, alerting, and follow-up belong to the caller.
- **Developer-friendly underneath.** Keyword-arg library API mirroring `Skywatch.metar` / `Skywatch.mayday`.
- **Encapsulate domain knowledge.** Callers shouldn't know that `SLGT` is ordinal rank 3 out of 6 — the model exposes `risk_level` / `risk_score`.
- **Compose where possible.** SPC is a new host and a new data shape, so there is no existing source to compose over (unlike Mayday → Radar). This PR stands on its own.

## Scope

### In scope

1. **`Nimbus::Models::Outlook`** — one SPC categorical outlook region (Day 1, 2, or 3), with geometry.
2. **`Nimbus::Models::StormReport`** — one row from SPC's daily storm reports CSV (tornado / wind / hail).
3. **`Nimbus::Sources::Outlook`** — fetches Day N GeoJSON from SPC, returns `[Outlook, ...]`.
4. **`Nimbus::Sources::StormReport`** — fetches the daily CSV, parses three sections, returns `[StormReport, ...]`.
5. **`Nimbus::Formatters::Text`** — `format_outlook(outlook)` and `format_storm_report(report)`.
6. **CLI:**
   - `skywatch nimbus outlook DAY [--at LAT LON]`
   - `skywatch nimbus storms [--date YYYYMMDD] [--type tornado|wind|hail] [--near LAT LON --radius N]`
7. **Convenience API:**
   - `Skywatch.outlook(day:, at: nil)` → `[Outlook, ...]` (or the single covering `Outlook` when `at:` is given — see Edge Cases)
   - `Skywatch.storms(date: nil, type: nil, near: nil)` → `[StormReport, ...]`

### Out of scope (deliberately)

- **NEXRAD radar reflectivity.** PR 2.
- **Smoke / AQI / wildfire.** PR 3 (if a reliable free source exists).
- **Lightning.** Post-Nimbus investigation only.
- **Day 4–8 outlooks.** Different product, different schema, different caching behavior. Add if a real use case appears.
- **Tornado watches / severe thunderstorm watches.** Separate SPC product. Out of scope for this PR; revisit if the agent wants it.
- **Historical outlook archives.** SPC hosts archives, but the agent's question is "what's current"; archive queries are a different problem.
- **Storm-report data older than SPC's public CSV retention window.** We hit today.csv and YYMMDD.csv only; no scraping.
- **Client-side validation of lat/lon ranges.** Consistent with Mayday / Radar.

## Architecture

```
lib/skywatch/nimbus/
├── models/outlook.rb            # SPC categorical outlook region
├── models/storm_report.rb       # tornado / wind / hail report row
├── sources/outlook.rb           # fetches dayNotlk_cat.lyr.geojson
├── sources/storm_report.rb      # fetches today.csv / YYMMDD.csv
└── formatters/text.rb           # format_outlook, format_storm_report
```

```
lib/skywatch/nimbus/cli.rb       # Thor subcommand, registered in Skywatch::CLI
```

### HTTP client

SPC lives on `https://www.spc.noaa.gov`, which is neither `aviationweather.gov` (Briefer default) nor `api.weather.gov` (Briefer AFD). We add a **third host** via a dedicated `Shared::Http` instance, wrapped in its own `Shared::Cache`:

```ruby
# Pattern, lives inside each Nimbus source (not global)
@client = Shared::Cache.new(client: Shared::Http.new(base_url: 'https://www.spc.noaa.gov'))
```

This mirrors the global pattern (`Skywatch.client` is cached) while keeping the SPC connection isolated. AFD chose uncached HTTP; Nimbus caches because TTLs are meaningful (1h / 5min) and the SPC fetches are small and cheap to memoize.

### Data flow — outlook

```
Skywatch.outlook(day: 1)
  → Nimbus::Sources::Outlook.new.fetch(day: 1)
    → GET /products/outlook/day1otlk_cat.lyr.geojson            # cached 1h
    → parse GeoJSON FeatureCollection (via rgeo-geojson)
    → [Outlook, ...]
```

```
Skywatch.outlook(day: 1, at: [40.688, -74.174])
  → fetch day 1 outlooks → filter to the single highest-risk feature whose MultiPolygon covers the point → return that one (or nil)
```

### Data flow — storm reports

```
Skywatch.storms                                 # all of today
  → Sources::StormReport.new.fetch
  → GET /climo/reports/today.csv                # cached 5min
  → split into 3 sections (tornado, wind, hail) by re-encountering header rows
  → parse each row into StormReport
  → [StormReport, ...]

Skywatch.storms(date: Date.parse("2026-04-17"))
  → GET /climo/reports/260417.csv

Skywatch.storms(type: :tornado)                 # in-memory filter after fetch
Skywatch.storms(near: { lat: ..., lon: ..., radius_nm: 100 })
```

## API Endpoints

| Endpoint | Purpose | TTL | Parser |
|---|---|---|---|
| `GET https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson` | Day 1 categorical outlook | 1h | `JSON.parse` → FeatureCollection walk → MultiPolygon via `rgeo-geojson` |
| `GET https://www.spc.noaa.gov/products/outlook/day2otlk_cat.lyr.geojson` | Day 2 | 1h | same |
| `GET https://www.spc.noaa.gov/products/outlook/day3otlk_cat.lyr.geojson` | Day 3 | 1h | same |
| `GET https://www.spc.noaa.gov/climo/reports/today.csv` | Today's tornado/wind/hail reports | 5min | custom 3-section CSV walker |
| `GET https://www.spc.noaa.gov/climo/reports/YYMMDD.csv` | Historical day, YYMMDD two-digit year | 5min | same |

All use `@client.get_raw` for CSV and `@client.get` for GeoJSON (which is JSON-parseable). Both go through the cache layer so repeat calls in the same process reuse the response.

## New Components

### `Skywatch::Nimbus::Models::Outlook`

One SPC categorical outlook feature.

```ruby
outlook = Nimbus::Models::Outlook.new(...)

outlook.day                # 1
outlook.label              # "SLGT"
outlook.description        # "Slight Risk"
outlook.risk_level         # :slight
outlook.risk_score         # 3
outlook.valid_from         # Time, UTC
outlook.valid_to           # Time, UTC
outlook.issued_at          # Time, UTC
outlook.forecaster         # "GUYER"
outlook.geometry           # RGeo MultiPolygon

outlook.covers?(lat:, lon:)     # → true / false  (point-in-polygon)
outlook.to_h
outlook.to_json
```

**Risk-level lookup lives on the model as a frozen constant:**

| `LABEL` | `risk_level` | `risk_score` | `description` |
|---|---|---|---|
| `TSTM` | `:general_thunder` | 1 | General Thunderstorms |
| `MRGL` | `:marginal` | 2 | Marginal Risk |
| `SLGT` | `:slight` | 3 | Slight Risk |
| `ENH` | `:enhanced` | 4 | Enhanced Risk |
| `MDT` | `:moderate` | 5 | Moderate Risk |
| `HIGH` | `:high` | 6 | High Risk |

The constant is the single source of truth for label → level / score / description. No other consumers of this table exist today; keeping it on the `Outlook` model is correct until another caller appears.

Construction path is `Outlook.from_spc_feature(feature, day:)`. Direct `.new(**attrs)` is also supported for tests.

### `Skywatch::Nimbus::Models::StormReport`

One row from the SPC daily CSV.

```ruby
report = Nimbus::Models::StormReport.new(...)

report.time              # Time (UTC, today's date + HHMM from CSV)
report.type              # :tornado | :wind | :hail
report.magnitude         # Float (see table below)
report.magnitude_raw     # String — original CSV value, lossless
report.location          # "NEWARK"
report.county            # "ESSEX"
report.state             # "NJ"
report.latitude          # Float
report.longitude         # Float
report.comments          # free-text summary
report.to_h
report.to_json
```

**Magnitude normalization:**

| type | CSV column | `magnitude` (Float) | `magnitude_raw` (String) |
|---|---|---|---|
| `:tornado` | `F_Scale` | `nil` (tornado magnitude is categorical, not numeric) | `"EF2"`, `"UNK"`, `""` passthrough |
| `:wind` | `Speed` | mph as Float (e.g., `65.0`) | original string (`"65"`, `"EG 70"` for estimated gust) |
| `:hail` | `Size` | inches as Float (raw `100` → `1.00`, raw `175` → `1.75`) | original string (`"100"`) |

Wind additionally exposes a derived `wind_kt` getter (`magnitude * 0.868976` for `:wind`, `nil` otherwise) so callers don't repeat the conversion. We keep native mph on `magnitude` to match CSV fidelity and to avoid an implicit double-conversion when the field is later consumed for analysis.

Construction path is `StormReport.from_spc_row(row, type:, report_date:)`.

### `Skywatch::Nimbus::Sources::Outlook`

```ruby
class Outlook
  BASE_URL = 'https://www.spc.noaa.gov'
  TTL = 3600

  def initialize(client: default_client)
    @client = client
  end

  def fetch(day:)
    raise ArgumentError, "day must be 1, 2, or 3" unless [1, 2, 3].include?(day)

    data = @client.get("/products/outlook/day#{day}otlk_cat.lyr.geojson", {}, ttl: TTL)
    features = data['features'] || []
    features.map { |f| Models::Outlook.from_spc_feature(f, day: day) }
  end

  private

  def default_client
    Skywatch::Shared::Cache.new(client: Skywatch::Shared::Http.new(base_url: BASE_URL))
  end
end
```

Keyword-arg `fetch(day:)` is used rather than positional because `day` is enumerated (1, 2, 3) and the call site reads clearer that way.

### `Skywatch::Nimbus::Sources::StormReport`

```ruby
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
    csv = @client.get_raw(path, {}, ttl: TTL)
    parse_sections(csv, report_date: report_date)
  end

  private

  def parse_sections(csv, report_date:)
    # Walk lines. On a header-row match, flip current_type. Otherwise parse the row
    # with the current header and emit a StormReport.
  end
end
```

### `Skywatch::Nimbus::Formatters::Text`

```ruby
def self.format_outlook(outlook)
  # Single-line per outlook, mirroring how sigmets format:
  #   OUTLOOK DAY 1: SLGT (Slight Risk) — valid 2026-04-19 12:00Z → 2026-04-20 12:00Z, issued by GUYER
end

def self.format_storm_report(report)
  # Single-line:
  #   TORNADO EF2 @ 18:42Z NEWARK, ESSEX NJ (40.73, -74.17) — brief path damage
  #   WIND 65mph @ 19:10Z ... (kt ~56)
  #   HAIL 1.75" @ 20:00Z ...
end
```

### CLI: `Skywatch::Nimbus::CLI`

New Thor subclass, registered alongside `weather`, `radar`, `mayday` in `Skywatch::CLI`.

```bash
skywatch nimbus outlook 1                            # all day-1 regions, text
skywatch nimbus outlook 1 --at 40.688 -74.174        # single covering outlook at that point (or "No outlook covers ...")
skywatch nimbus outlook 2 --format json

skywatch nimbus storms                               # all of today, text
skywatch nimbus storms --type tornado
skywatch nimbus storms --date 20260418
skywatch nimbus storms --near 40.688 -74.174 --radius 100
skywatch nimbus storms --format json
```

`--format` auto-detects TTY as elsewhere.

### Convenience API (added to top-level `Skywatch`)

```ruby
def self.outlook(day:, at: nil)
  outlooks = Nimbus::Sources::Outlook.new.fetch(day: day)
  return outlooks if at.nil?

  lat, lon = at
  covering = outlooks.select { |o| o.covers?(lat: lat, lon: lon) }
  covering.max_by(&:risk_score)   # the highest-ranked covering region, or nil
end

def self.storms(date: nil, type: nil, near: nil)
  reports = Nimbus::Sources::StormReport.new.fetch(date: date)
  reports = reports.select { |r| r.type == type } if type
  return reports unless near

  lat = near.fetch(:lat); lon = near.fetch(:lon); radius_nm = near.fetch(:radius_nm)
  reports.select { |r| haversine_nm(r.latitude, r.longitude, lat, lon) <= radius_nm }
end
```

Proximity math: reuse the existing haversine in `Radar::Analysis::Proximity` (private helper) — if it's not already accessible, expose a `distance_nm(lat1, lon1, lat2, lon2)` module function on `Shared::Geometry` and have `Radar::Analysis::Proximity` delegate to it. (Picking this up in the plan; it is a small refactor, not a blocker.)

## Edge Cases

| Case | Behavior |
|---|---|
| Day outside 1–3 | `ArgumentError` raised by `Outlook.fetch(day:)` |
| Outlook GeoJSON has empty `features` array | Return `[]` (no severe-weather activity — TSTM region may also be absent) |
| Outlook `at:` point covered by multiple features (e.g., general thunder + slight) | Return the single highest `risk_score` (slight in that case), not the list |
| Outlook `at:` covered by no features | Return `nil` |
| Outlook GeoJSON feature with missing `geometry` | Skip the feature with a warning log? → **No:** raise `Skywatch::ParseError`; SPC GeoJSON is well-formed by contract. Fail loud, not silent. |
| Storm reports CSV with 0 rows under a section (e.g., no tornadoes today) | Return the other sections' rows; empty section contributes nothing |
| Storm reports CSV entirely empty (start of day, no reports yet) | Return `[]` |
| Storm reports row with unparseable `Speed` / `Size` | `magnitude: nil`, `magnitude_raw` preserves the string. Never raise for a single bad row. |
| Storm reports `date:` in the future | Whatever SPC returns (likely 404 → `ApiError`). Don't pre-validate. |
| Storm reports `date:` more than SPC's retention window | SPC 404 → `ApiError` propagates |
| `near:` hash missing one of `:lat`/`:lon`/`:radius_nm` | `KeyError` from `fetch` — explicit failure, don't silently default |
| CSV HHMM on a report that belongs to the *previous* UTC day (SPC's "convective day" starts 12Z) | Accept the HHMM at face value against the fetched date — we do not try to disambiguate the 12Z rollover. Document this in the model comment. Revisit if it causes problems. |
| SPC 5xx / network error | `Skywatch::ApiError` / `ConnectionError` propagates; CLI catches and prints `Error: ...` (existing top-level pattern) |

## Testing

Fixture-based, following the existing pattern (WebMock against saved fixtures; live APIs never hit in CI).

**New fixtures:**
- `spec/fixtures/spc/day1otlk_cat.lyr.geojson` — real Day 1 GeoJSON with at least one MRGL + one SLGT feature
- `spec/fixtures/spc/day2otlk_cat.lyr.geojson` — Day 2, at least one feature
- `spec/fixtures/spc/day3otlk_cat.lyr.geojson` — Day 3, at least one feature
- `spec/fixtures/spc/day1otlk_cat_empty.lyr.geojson` — FeatureCollection with empty `features`
- `spec/fixtures/spc/today.csv` — real today.csv with at least 1 tornado, 2 wind, 2 hail rows
- `spec/fixtures/spc/today_empty.csv` — headers only
- `spec/fixtures/spc/260418.csv` — a historical-date CSV (any recent day)

**New spec files:**
- `spec/nimbus/models/outlook_spec.rb`
  - `from_spc_feature` produces correct label / risk_level / risk_score / description
  - `covers?` returns true for a point inside the MultiPolygon, false outside
  - `to_h` / `to_json` shape
- `spec/nimbus/models/storm_report_spec.rb`
  - `from_spc_row` for each of the three types, magnitude normalization per table
  - `wind_kt` derived getter is correct and nil for non-wind
  - `magnitude_raw` is preserved for unparseable values, `magnitude` is nil
- `spec/nimbus/sources/outlook_spec.rb`
  - Webmocks a day-1 fetch, asserts all features wrapped
  - `day: 4` raises `ArgumentError`
  - Empty FeatureCollection returns `[]`
- `spec/nimbus/sources/storm_report_spec.rb`
  - Default fetch hits `today.csv`
  - `date:` builds `YYMMDD.csv` path
  - Three-section parsing yields reports with correct `type`
- `spec/nimbus/formatters/text_spec.rb` — single-line output snapshots for each type
- `spec/nimbus_spec.rb` — `Skywatch.outlook(day:, at:)` and `Skywatch.storms(...)` end-to-end through fixtures

**Modified:**
- `spec/cli_spec.rb` — `nimbus outlook` and `nimbus storms` text + JSON modes, empty-result message

**Fixture capture:**
Implementer subagent(s) will use **sandbox bypass per fixture-capture step** (same pattern Briefer used for `aviationweather.gov`) to run `curl -sS https://www.spc.noaa.gov/...` once, save the response, and commit it. CI stays fully stubbed. `www.spc.noaa.gov` does not need to be added to the gem's runtime sandbox allowlist — tests never hit the network.

## Conventions reuse

- `Shared::Http` (existing, accepts `base_url:`)
- `Shared::Cache` (existing, wraps any HTTP-ish client)
- `Shared::Position` — used indirectly if we want to expose any lat/lon pairs; otherwise plain Floats
- `Shared::Geometry` — extend with `distance_nm(lat1, lon1, lat2, lon2)` helper (small follow-up; will call it out in the plan)
- `rgeo-geojson` (existing dep) — decode SPC MultiPolygons into `RGeo::Feature::MultiPolygon`
- `Skywatch::ApiError` / `ParseError` / `ConnectionError` — raised by Shared layer, propagate to CLI where they turn into `Error: ...` output
- CLI `--format json|text` TTY auto-detection pattern from `Skywatch::Briefer::CLI` / `Skywatch::Mayday::CLI`

## Naming

- Module: `Skywatch::Nimbus`
- Convenience: `Skywatch.outlook`, `Skywatch.storms`
- CLI: `skywatch nimbus outlook DAY`, `skywatch nimbus storms`

"Nimbus" is the cloud-family / weather-family root — the domain will grow to include radar, smoke, and (maybe) lightning in later PRs. Models are named for what they are (`Outlook`, `StormReport`), not for the domain (`Nimbus::Outlook` rather than `Nimbus::Models::Nimbus`), to keep the API grammatical.

## Deferred to the plan

Items called out here but resolved during planning / execution, not design:

- Exact `Shared::Geometry.distance_nm` signature and whether to refactor `Radar::Analysis::Proximity` to delegate (vs. duplicate the tiny formula)
- File-level require order in `lib/skywatch.rb` (follows the existing alphabetical-within-domain pattern)
- Whether `Skywatch::Nimbus::CLI` goes through the same `with_format` helper shape as Mayday's CLI (expected: yes)
