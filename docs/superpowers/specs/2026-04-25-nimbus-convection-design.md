# Nimbus PR 2 — Active Convective Warnings + Watches — Design Spec

**Date:** 2026-04-25
**Status:** Draft, pending review
**Author:** Jay (with Claude)
**PR scope:** 2 of 3 for `Skywatch::Nimbus`

## Goal

Give an agent (or developer, or pilot) one structured answer to the briefer-cadence question:

> *"At this point right now, what's actively warned or watched — tornado, severe thunderstorm, flash flood?"*

Returns a small, deterministic, JSON-shaped object that an LLM can read aloud as the convective section of a 1-800-WX-BRIEF-style preflight brief. No image decoding, no pixel sampling, no station-status plumbing.

## Briefer-perspective framing

A standard FAA preflight brief covers convection with three pieces of language:

1. **Warnings active in your area** — "There is a Severe Thunderstorm Warning for Essex County until 19:30Z, with reported 65mph winds and 1.5-inch hail."
2. **Watches active in your area** — "A Tornado Watch is in effect for northern New Jersey through 22:00Z, with conditions favorable for tornadoes through the afternoon."
3. **Convective outlook for the day** — already covered by Nimbus PR 1.

This PR delivers (1) and (2). Together with PR 1's outlooks/storm reports and Briefer's METAR/TAF/SIGMET/AIRMET, an agent can compose the full convective subsection of a briefer-style report.

## Why not "NEXRAD reflectivity" / dBZ-at-point

The original Nimbus decomposition framed PR 2 as "point-in-time dBZ near a coordinate." Every honest source for that requires heavy raster/GRIB2 work (NCEP MRMS, AWS NEXRAD Level II, IEM N0Q raster + colormap reverse-mapping) that is out of keeping with Skywatch's "small, deterministic, no scientific stack" posture and yields data that an LLM brief cannot meaningfully verbalize anyway.

Storm-Based Warning polygons (since 2007) are the *radar-derived structured product* — they're issued by humans interpreting radar in real time and tagged with hail size, wind speed, motion, and tornado-detection flags. That is the brief-readable form of "what is the radar showing." dBZ-at-point becomes a post-Nimbus investigation alongside lightning.

Updated decomposition:

```
Nimbus
├── PR 1 (merged) — SPC outlooks + storm reports
├── PR 2 (this)   — Active convective warnings + watches at point
├── PR 3          — Smoke/AQI (if reliable free source exists)
└── Post          — Lightning feasibility · MCDs · dBZ-at-point
```

## Design Principles (from north star)

- **Agent-first.** One call, one structured aggregate. No follow-up calls required to render the convective section of a brief.
- **Briefer-cadence text.** The text formatter writes one-liners that match how a human briefer would phrase each warning/watch in sequence.
- **Encapsulate domain knowledge.** Callers shouldn't have to know that "Severe Thunderstorm Warning" maps to a `:warning` kind with hail/wind tags from `parameters.maxHailSize` and `parameters.maxWindGust`. The model exposes typed fields.
- **Compose where possible.** Reuse the existing `api.weather.gov` host pattern (Briefer AFD already uses it). No new host added.

## Scope

### In scope

1. **`Nimbus::Models::ConvectiveAlert`** — one row, either a warning or a watch, parsed from a NWS alert GeoJSON feature.
2. **`Nimbus::Models::Convection`** — aggregate wrapping `[ConvectiveAlert, ...]` with helpers (`warnings`, `watches`, `active?`, `max_severity`).
3. **`Nimbus::Sources::Alerts`** — single source hitting `api.weather.gov/alerts/active?point=…&event=…`. Returns ungrouped `[ConvectiveAlert, ...]`; the convenience API wraps it.
4. **`Nimbus::Formatters::Text`** — extended with `format_convection(convection)`, which renders briefer-cadence one-liners (one per alert, plus a "no active convective warnings or watches" line when empty).
5. **CLI:** `skywatch nimbus convection LAT LON [--format json|text]`
6. **Convenience API:** `Skywatch.convection(at: [lat, lon])` → `Models::Convection`

### Out of scope (deliberately)

- **Pixel-level reflectivity / dBZ-at-point.** Documented above.
- **Image URLs to RIDGE/IEM tiles.** An LLM brief cannot verbalize a PNG; deferring until a clear use case appears (likely tied to a multimodal-consumer skill).
- **Station status / scan mode.** Operationally not part of a briefer-style brief.
- **Mesoscale Convective Discussions (MCDs).** Useful narrative context, but adds an SPC HTML/JSON parser and roughly doubles PR scope. Defer to post-Nimbus.
- **Marine warnings (Special Marine Warning).** Skywatch is aviation-first.
- **Watches/warnings for non-convective hazards** (Winter Storm, Coastal Flood, etc.). Out of scope for the convection view; can be added later as a separate `Skywatch::Nimbus::Hazards` lookup if there's demand.
- **Polling / push notifications when a new warning issues.** Caller's responsibility; this is a one-shot lookup.
- **Client-side validation of lat/lon ranges.** Consistent with PR 1.

## Architecture

```
lib/skywatch/nimbus/
├── models/
│   ├── outlook.rb              # PR 1
│   ├── storm_report.rb         # PR 1
│   ├── convective_alert.rb     # NEW — one warning or watch
│   └── convection.rb           # NEW — aggregate
├── sources/
│   ├── outlook.rb              # PR 1
│   ├── storm_report.rb         # PR 1
│   └── alerts.rb               # NEW — api.weather.gov/alerts/active
└── formatters/
    └── text.rb                 # PR 1 + format_convection
```

```
lib/skywatch/nimbus/cli.rb      # PR 1 + 'convection' subcommand
```

### HTTP client

Reuse the existing `api.weather.gov` host — same host as Briefer's AFD. Each source instantiates its own client, consistent with the existing pattern. Wrap in `Shared::Cache` for the alerts fetch (60s TTL is meaningful — without it, an LLM consumer making repeated calls in a session would hammer the endpoint).

```ruby
# In Nimbus::Sources::Alerts
@client = Shared::Cache.new(client: Shared::Http.new(base_url: 'https://api.weather.gov'))
```

(Briefer's AFD uses uncached `Shared::Http` because AFD is a one-shot fetch with a long product cycle. Alerts deserve caching with a short TTL.)

### Data flow

```
Skywatch.convection(at: [40.688, -74.174])
  → Nimbus::Sources::Alerts.new.fetch(at: [40.688, -74.174])
    → GET /alerts/active?point=40.688,-74.174
        &event=Tornado Warning,Severe Thunderstorm Warning,Flash Flood Warning,
               Tornado Watch,Severe Thunderstorm Watch
      cached 60s
    → parse GeoJSON FeatureCollection
    → [ConvectiveAlert, ...]
  → wrap in Nimbus::Models::Convection.new(at:, fetched_at:, alerts:)
```

NWS does the polygon-containment server-side via the `point=` parameter, so the source doesn't need to do point-in-polygon itself. We still keep the polygon on each `ConvectiveAlert` (callers may want to render the affected area).

## API Endpoints

| Endpoint | Purpose | TTL | Parser |
|---|---|---|---|
| `GET https://api.weather.gov/alerts/active?point=LAT,LON&event=…` | Active warnings/watches whose polygon contains the point | 60s | `JSON.parse` → FeatureCollection walk → `ConvectiveAlert.from_nws_feature` |

The `event=` filter is a comma-separated list of NWS event names. Default set:

- `Tornado Warning`
- `Severe Thunderstorm Warning`
- `Flash Flood Warning`
- `Tornado Watch`
- `Severe Thunderstorm Watch`

## New Components

### `Skywatch::Nimbus::Models::ConvectiveAlert`

One NWS alert (warning or watch) parsed from `api.weather.gov/alerts/active`.

```ruby
alert = Nimbus::Models::ConvectiveAlert.new(...)

alert.id                    # NWS alert URI ('urn:oid:2.49.0.1.840.0.…')
alert.kind                  # :warning | :watch (derived from event)
alert.event                 # "Severe Thunderstorm Warning"
alert.headline              # short NWS-provided headline
alert.description           # full NWS description text (long-form)
alert.severity              # :extreme | :severe | :moderate | :minor | :unknown
alert.certainty             # :observed | :likely | :possible | :unlikely | :unknown
alert.urgency               # :immediate | :expected | :future | :past | :unknown

alert.sent_at               # Time UTC
alert.effective_at          # Time UTC
alert.onset_at              # Time UTC (nil if same as effective)
alert.expires_at            # Time UTC
alert.ends_at               # Time UTC (nil if same as expires)

alert.area_description      # NWS-provided "Essex, NJ; Bergen, NJ"
alert.geometry              # RGeo Polygon | MultiPolygon | nil

# Tag fields parsed from NWS 'parameters' (warnings only — watches don't carry these)
alert.hail_size_in          # Float inches | nil
alert.wind_gust_kt          # Float knots (converted from mph) | nil
alert.wind_gust_mph         # Float mph (raw NWS value) | nil
alert.tornado_detection     # :observed | :radar_indicated | nil
alert.thunderstorm_damage_threat   # :destructive | :considerable | nil
alert.flash_flood_damage_threat    # :catastrophic | :considerable | nil

alert.warning?              # kind == :warning
alert.watch?                # kind == :watch
alert.to_h
alert.to_json
```

**`kind` derivation** — the `event` string ends in either "Warning" or "Watch". Map at parse time:

```ruby
KIND_BY_EVENT_SUFFIX = { 'Warning' => :warning, 'Watch' => :watch }.freeze
```

**`severity`/`certainty`/`urgency`** — NWS provides these as PascalCase strings. Downcase and intern. Unknown / missing values map to `:unknown`.

**Tag parsing** — NWS alert `properties.parameters` is a hash of arrays:

```json
"parameters": {
  "maxHailSize": ["1.50"],
  "maxWindGust": ["65 MPH"],
  "tornadoDetection": ["RADAR INDICATED"],
  "thunderstormDamageThreat": ["CONSIDERABLE"]
}
```

Parser is total — missing keys → nil. Bad values (unparseable hail size, etc.) → nil with the raw value preserved on `alert.raw_parameters` for debugging. Never raise for a malformed parameter.

Construction path is `ConvectiveAlert.from_nws_feature(feature)`. Direct `.new(**attrs)` supported for tests.

### `Skywatch::Nimbus::Models::Convection`

Aggregate. Wraps the alerts list with briefer-relevant accessors.

```ruby
conv = Nimbus::Models::Convection.new(at: [40.688, -74.174], fetched_at: Time.now.utc, alerts: [alert1, alert2])

conv.at                 # [40.688, -74.174]
conv.fetched_at         # Time UTC
conv.alerts             # [ConvectiveAlert, ...] — all of them, in NWS-returned order
conv.warnings           # alerts.select(&:warning?)
conv.watches            # alerts.select(&:watch?)
conv.active?            # alerts.any?
conv.max_severity       # :extreme | :severe | … | nil if empty

conv.to_h               # { at:, fetched_at:, warnings: [...], watches: [...] }
conv.to_json
```

The aggregate's `to_h` partitions warnings and watches because that's the briefer-readable shape; the raw `alerts` list is for callers that want NWS-ordered access (e.g., to render in priority order via `severity`).

### `Skywatch::Nimbus::Sources::Alerts`

```ruby
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
    lat, lon = at
    params = {
      point: "#{lat},#{lon}",
      event: events.join(',')
    }
    data = @client.get('/alerts/active', params, ttl: TTL)
    features = data['features'] || []
    features.map { |f| Models::ConvectiveAlert.from_nws_feature(f) }
  end

  private

  def default_client
    Skywatch::Shared::Cache.new(client: Skywatch::Shared::Http.new(base_url: BASE_URL))
  end
end
```

`events:` is exposed as a kwarg so the CLI's `--events` flag can override the default (e.g., to scope down to just warnings, or to add Special Marine Warning if the caller really wants it).

### `Skywatch::Nimbus::Formatters::Text` — extension

Add `format_convection(conv)` that emits briefer-cadence one-liners. Format pattern (one per alert, ordered warnings-first then watches, severity-descending within each kind, NWS-returned order as tiebreak):

```
TORNADO WARNING — Essex, NJ until 19:30Z. Tornado observed; 1.50" hail, 65kt wind gust.
SEVERE THUNDERSTORM WARNING — Bergen, Passaic, NJ until 20:00Z. Radar-indicated; 1.00" hail, 52kt wind gust.
FLASH FLOOD WARNING — Hudson, NJ until 23:00Z. Considerable damage threat.
TORNADO WATCH #142 — NJ/NY/CT until 22:00Z.
```

Empty convection (no active alerts):

```
NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.
```

Lines end with `\n`; format returns the joined block. The format is intentionally close to how a briefer reads them so that an LLM consuming the text can paraphrase or pass through without further structuring.

**Helpers (private to the formatter):**
- `wind_gust_phrase(alert)` — `"65kt wind gust"` when `wind_gust_kt` present; omitted otherwise (mph and kt are set together, since kt is derived from mph)
- `hail_phrase(alert)` — `'1.50" hail'`
- `tornado_phrase(alert)` — `"Tornado observed"` / `"Radar-indicated"` / nil
- `damage_threat_phrase(alert)` — `"Considerable damage threat"` / `"Destructive damage threat"` / nil
- `until_phrase(alert)` — `"until 19:30Z"` from `expires_at`

Watch number (`#142` etc.) — NWS embeds this in the `headline` field (`"Tornado Watch 142 issued April 25 at 1:30PM EDT until April 25 at 10:00PM EDT by NWS Storm Prediction Center"`); extract via regex if present, otherwise omit.

### CLI

```bash
skywatch nimbus convection 40.688 -74.174
skywatch nimbus convection 40.688 -74.174 --format json
skywatch nimbus convection 40.688 -74.174 --events "Tornado Warning,Severe Thunderstorm Warning"
```

Positional `LAT LON` (matches Mayday). `--events` is comma-separated; if omitted, defaults to the full convective set. `--format` auto-detects TTY as elsewhere.

Wired into `Skywatch::Nimbus::CLI` alongside `outlook` and `storms`. Update `CLAUDE.md` CLI usage block in the same commit.

### Convenience API (added to top-level `Skywatch`)

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

`at:` is a 2-element `[lat, lon]` array, matching `Skywatch.outlook(at:)` from PR 1.

## Edge Cases

| Case | Behavior |
|---|---|
| Point outside CONUS / Alaska / Hawaii (no NWS coverage) | NWS returns 200 with empty `features` → `Convection` with `alerts: []`, `active? == false`. No raise. |
| No active warnings or watches at the point | Same as above — empty `Convection`. Formatter prints `NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.` |
| NWS feature with missing `geometry` (some watch-area-wide alerts) | `alert.geometry = nil`. Don't raise; the alert is still real, just not polygon-shaped on this feed. |
| NWS feature with missing `properties.parameters.maxHailSize` etc. | Tag field is `nil`; raw value (if any) preserved on `raw_parameters`. |
| Unparseable hail size / wind gust string | Tag field `nil`; never raise for a single bad parameter. |
| Wind gust given in MPH (always — NWS standard) | Convert to kt for `wind_gust_kt`; preserve `wind_gust_mph`. |
| Wind gust string with units other than MPH (rare but possible) | Parse only the numeric prefix; assume MPH if unit absent; if not MPH, leave both `_mph` and `_kt` `nil`, preserve raw. |
| Alert with `event` not in our default set (somehow returned) | Wrap normally; `kind` is derived from suffix. If suffix is neither "Warning" nor "Watch", `kind = :unknown`. |
| Alert `expires_at` in the past (race between issue and fetch) | Pass through; the formatter still says "until …Z" but the caller can filter on `expires_at` if they want. |
| `at:` not a 2-element array | `ArgumentError` raised by `Sources::Alerts.fetch` (destructure failure). |
| `events:` empty array | NWS returns 200 with empty filter → all alerts at point → unbounded list. Source raises `ArgumentError, 'events must be non-empty'` to prevent accidental over-fetch. |
| NWS 5xx / network error | `Skywatch::ApiError` / `ConnectionError` propagates; CLI catches and prints `Error: …` (existing top-level pattern). |
| NWS 503 with retry-after | `Shared::Http`'s faraday-retry handles transient failure; if retries exhausted, propagate. |

## Testing

Fixture-based, briefer-perspective scenarios. WebMock against saved fixtures; live API never hit in CI.

**New fixtures (`spec/fixtures/nws_alerts/`):**

| Fixture | Scenario |
|---|---|
| `tornado_warning_active.json` | Single Tornado Warning with full parameter tags (radar-indicated, 1.50" hail, 65 MPH wind gust) |
| `severe_thunderstorm_warning_active.json` | Single SVR Warning with hail/wind tags |
| `flash_flood_warning_active.json` | Single FFW with damage threat parameter |
| `tornado_watch_active.json` | Single Tornado Watch (broader area, no per-alert hail/wind tags) |
| `multiple_active.json` | TOR Warning + SVR Warning + Tornado Watch all active simultaneously (most-severe-day scenario) |
| `none_active.json` | Empty FeatureCollection |
| `missing_parameters.json` | SVR Warning with no `parameters` block (defensive parse path) |
| `geometry_missing.json` | Alert with `geometry: null` (some watch-area-wide alerts) |

**New spec files:**

- `spec/nimbus/models/convective_alert_spec.rb`
  - `from_nws_feature` produces correct kind/severity/certainty/urgency for each fixture
  - Tag parsing: hail size, wind gust (mph + kt conversion), tornado detection, damage threats
  - `warning?` / `watch?` predicates
  - `to_h` / `to_json` shape includes all briefer-relevant fields
  - Defensive: missing parameters → nil tags, no raise
  - Defensive: missing geometry → `geometry: nil`, no raise
- `spec/nimbus/models/convection_spec.rb`
  - `warnings` / `watches` partitioning
  - `active?` true/false
  - `max_severity` returns highest of `:extreme > :severe > :moderate > :minor > :unknown`
  - `to_h` shape
- `spec/nimbus/sources/alerts_spec.rb`
  - Default fetch builds correct point + event query string
  - Custom `events:` overrides default set
  - Empty `events:` raises
  - Empty FeatureCollection returns `[]`
  - Caches at TTL=60
- `spec/nimbus/formatters/text_spec.rb` — extended
  - `format_convection` for each scenario fixture, snapshotting briefer-cadence text:
    - "TORNADO WARNING — Essex, NJ until 19:30Z. Tornado observed; 1.50\" hail, 65kt wind gust."
    - "SEVERE THUNDERSTORM WARNING — …"
    - "FLASH FLOOD WARNING — …"
    - "TORNADO WATCH #142 — …"
    - "NO ACTIVE CONVECTIVE WARNINGS OR WATCHES."
  - Verifies ordering: warnings before watches; severity-desc within kind
- `spec/nimbus_spec.rb` — extended
  - `Skywatch.convection(at: [lat, lon])` end-to-end through the multi-alert fixture
  - Returns `Models::Convection` with the right `warnings.count` and `watches.count`
  - `at:` round-trips into the model
  - `events:` override flows through to the source
- `spec/nimbus/cli_spec.rb` — extended
  - `convection LAT LON` text mode emits briefer-cadence block
  - `convection LAT LON --format json` emits the partitioned aggregate JSON
  - `--events` flag splits and forwards
  - Empty result text: `NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.`

**Briefer-perspective acceptance test (`spec/nimbus/briefer_perspective_spec.rb`):**

A single integration spec that fetches `multiple_active.json` end-to-end through `Skywatch.convection`, formats with `Nimbus::Formatters::Text.format_convection`, and asserts the output is byte-identical to a hand-written briefer-cadence reference block in the spec. This is the load-bearing test that the briefer-narrative goal is preserved across refactors. Future briefer-composition work (a hypothetical `Skywatch.brief(at:)` aggregating Briefer + Nimbus outputs) can extend this same file.

**Fixture capture:**

Implementer subagent uses sandbox bypass per fixture-capture step (same pattern as PR 1 / Briefer) to run `curl -sS 'https://api.weather.gov/alerts/active?point=…&event=…'` once during a real convective event, save the response, and commit it. CI stays fully stubbed. `api.weather.gov` does not need to be in the gem's runtime sandbox allowlist.

For the multi-alert fixture, the implementer may need to either (a) wait for a real severe-weather day to capture a fixture with a Tornado Warning + SVR Warning + Watch all simultaneously, or (b) hand-assemble the fixture by combining real single-alert responses. Option (b) is acceptable; the fixture only needs to be schema-valid GeoJSON.

## Conventions reuse

- `Shared::Http` (existing, accepts `base_url:`)
- `Shared::Cache` (existing, wraps any HTTP-ish client)
- `rgeo-geojson` (existing dep) — decode polygon / multipolygon geometries
- `Skywatch::ApiError` / `ParseError` / `ConnectionError` — raised by Shared layer; CLI converts to `Error: …` output
- CLI `--format json|text` TTY auto-detection from PR 1 / Mayday / Briefer
- Convenience-API `at: [lat, lon]` shape from PR 1 (`Skywatch.outlook(at:)`)
- Source-instantiates-its-own-client pattern from PR 1 (each Nimbus source owns its `Shared::Cache`/`Shared::Http`)

## Naming

- Module additions: `Skywatch::Nimbus::Models::Convection`, `Skywatch::Nimbus::Models::ConvectiveAlert`, `Skywatch::Nimbus::Sources::Alerts`
- Convenience: `Skywatch.convection`
- CLI: `skywatch nimbus convection LAT LON`

"Convection" is the standard FAA briefer term for the family of warnings/watches in scope (TOR/SVR/FFW are all radar-observed convective phenomena). It's narrower than "alerts" (which would include Winter Storm, Coastal Flood, etc.) and more honest than "radar" (which would imply pixel data we're not delivering). The PR name in the decomposition memory is updated from "NEXRAD radar reflectivity" to "Active convective warnings + watches at point" to reflect the pivot.

## Deferred to the plan

Items called out here but resolved during planning / execution, not design:

- Exact path for `wind_gust_mph` parsing — NWS strings observed include `"65 MPH"`, `"65 mph"`, `"65"`, `"EG 70 MPH"` (estimated gust). Plan picks the regex.
- Whether `Convection#to_h` includes the `alerts` array (NWS-order) in addition to `warnings`/`watches` — leaning yes for round-trip fidelity, defer to plan.
- Severity-comparison helper location — likely a private module-level constant on `ConvectiveAlert` (`SEVERITY_RANK = { extreme: 4, severe: 3, … }`); plan confirms.
- Whether `format_convection` accepts a single alert vs. only the aggregate — leaning aggregate-only (briefer reads them as a block); plan confirms.
- Update text in `CLAUDE.md` CLI usage section — done in the implementation commit.

## Briefer-composition future hook (informational, not in this PR)

Eventually a `Skywatch.brief(at:, airport:)` skill or method will compose:

- METAR / TAF (Briefer)
- AFD synopsis (Briefer)
- Winds aloft (Briefer)
- SIGMETs / AIRMETs / PIREPs (Briefer)
- SPC outlook + storm reports (Nimbus PR 1)
- **Active convection** (this PR)
- Smoke/AQI (Nimbus PR 3, if it ships)

Designing the `Convection` aggregate's `to_h` shape with that composition in mind: it carries `at:`, `fetched_at:`, partitioned `warnings:`/`watches:`, each with all briefer-relevant fields. The composition layer just merges these top-level into the brief envelope; no shape rework needed at compose time.
