# Briefer

**A Ruby gem that delivers FAA-standard preflight weather briefings for pilots and AI agents.**

`briefer` consolidates aviation weather data from free, public FAA/NWS sources into structured preflight briefings — the same information a Flight Service specialist would give you when you call 1-800-WX-BRIEF. It's designed to work as both a standalone Ruby library for developers and a CLI-backed tool for Claude Code agents.

---

## Mission

Give a pilot (or an agent acting on behalf of a pilot) a departure airport, destination airport, ETD, and ETA — and get back a complete standard briefing in seconds. No API keys required for core functionality. No paid services. Just public aviation weather data, structured intelligently.

```ruby
# Developer usage
briefing = Briefer.brief(
  from: "KCDW",
  to: "KACK",
  etd: Time.parse("2026-04-15 14:00 UTC"),
  eta: Time.parse("2026-04-15 16:30 UTC"),
  alternates: ["KHYA"],
  altitude: 6000
)

briefing.go_no_go          # => :marginal
briefing.adverse_conditions # => [<TFR near JFK>, <AIRMET Sierra NEng>]
briefing.departure.metar    # => decoded METAR for KCDW
briefing.destination.taf    # => decoded TAF for KACK
```

```bash
# Claude Code / CLI usage
$ briefer brief KCDW KACK --etd "2026-04-15 14:00Z" --altitude 6000
$ briefer metar KCDW KTEB KEWR
$ briefer taf KACK
$ briefer notams KCDW
$ briefer tfrs --near KCDW --radius 50
$ briefer go-no-go KCDW KACK --profile bonanza
```

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Data Sources](#2-data-sources)
3. [Internal Module Structure](#3-internal-module-structure)
4. [The Briefing Object](#4-the-briefing-object)
5. [CLI Interface (Claude Code Integration)](#5-cli-interface-claude-code-integration)
6. [Ruby API (Developer Integration)](#6-ruby-api-developer-integration)
7. [Route Geometry Engine](#7-route-geometry-engine)
8. [Go/No-Go Engine](#8-gono-go-engine)
9. [Caching Strategy](#9-caching-strategy)
10. [Configuration](#10-configuration)
11. [Gem File Structure](#11-gem-file-structure)
12. [Data Models](#12-data-models)
13. [Build Phases](#13-build-phases)
14. [Test Strategy](#14-test-strategy)
15. [Future Possibilities](#15-future-possibilities)

---

## 1. Architecture Overview

`briefer` is a single gem with internal modularity. No gem-per-data-source sprawl — just clean Ruby modules behind one dependency.

```
┌──────────────────────────────────────────────────────────┐
│                      briefer (gem)                       │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                  CLI (Thor)                         │ │
│  │  briefer brief / metar / taf / notams / go-no-go   │ │
│  └──────────────────────┬──────────────────────────────┘ │
│                         │                                │
│  ┌──────────────────────▼──────────────────────────────┐ │
│  │             Briefing Orchestrator                   │ │
│  │  Assembles a complete briefing from all sources     │ │
│  │  Sequences per FAA standard briefing order          │ │
│  └──────────────────────┬──────────────────────────────┘ │
│                         │                                │
│  ┌──────────────────────▼──────────────────────────────┐ │
│  │             Intelligence Layer                      │ │
│  │  • Route corridor geometry & station selection      │ │
│  │  • Flight category classification (VFR/IFR/etc)     │ │
│  │  • SIGMET/TFR/AIRMET route intersection             │ │
│  │  • Go/No-Go evaluation against personal minimums    │ │
│  │  • NOTAM relevance filtering & prioritization       │ │
│  └──────────────────────┬──────────────────────────────┘ │
│                         │                                │
│  ┌──────────────────────▼──────────────────────────────┐ │
│  │               Data Layer (Modules)                  │ │
│  │                                                     │ │
│  │  Briefer::Sources::Metar     (aviationweather.gov)  │ │
│  │  Briefer::Sources::Taf       (aviationweather.gov)  │ │
│  │  Briefer::Sources::Pirep     (aviationweather.gov)  │ │
│  │  Briefer::Sources::Sigmet    (aviationweather.gov)  │ │
│  │  Briefer::Sources::Airmet    (aviationweather.gov)  │ │
│  │  Briefer::Sources::Notam     (FAA NMS / NASA DIP)  │ │
│  │  Briefer::Sources::Tfr       (tfr.faa.gov)         │ │
│  │  Briefer::Sources::WindsAloft(aviationweather.gov)  │ │
│  │  Briefer::Sources::Station   (local airport DB)     │ │
│  └──────────────────────┬──────────────────────────────┘ │
│                         │                                │
│  ┌──────────────────────▼──────────────────────────────┐ │
│  │                HTTP Client                          │ │
│  │  • Faraday-based, shared across all sources         │ │
│  │  • Rate limiting (respect AWC guidelines)           │ │
│  │  • Retry with backoff                               │ │
│  │  • Custom User-Agent header (AWC requests this)     │ │
│  │  • Response caching (see §9)                        │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### Design Principles

- **Single gem, many modules.** Install one thing, get everything. Internal boundaries are Ruby modules, not gem boundaries.
- **CLI-first, library-always.** Every CLI command maps to a Ruby method. Claude Code calls the CLI; Rails apps call the library.
- **Offline-capable airport database.** Station data (ICAO codes, coordinates, elevations, runways, frequencies) ships with the gem as a compressed SQLite or JSON file derived from FAA's 28-day NASR subscription. No API call needed to look up an airport.
- **No API keys for core functionality.** The AWC Data API and TFR feed require no authentication. NOTAM sources (FAA NMS, NASA DIP) are public. Paid sources (Notamify, CheckWX, AVWX Pro) can be added later via adapter pattern.
- **Structured data out.** Every response is a Ruby object with typed attributes. JSON serialization is built in. No raw METAR strings unless you ask for them.

---

## 2. Data Sources

All free. All public. No API keys required for v1.

| Data | Source | Endpoint Pattern | Format | Auth |
|------|--------|-----------------|--------|------|
| METAR | AWC Data API | `aviationweather.gov/api/data/metar?ids={icao}&format=json` | JSON | None |
| TAF | AWC Data API | `aviationweather.gov/api/data/taf?ids={icao}&format=json` | JSON | None |
| PIREP | AWC Data API | `aviationweather.gov/api/data/pirep?id={icao}&dist={nm}&format=json` | JSON | None |
| SIGMET | AWC Data API | `aviationweather.gov/api/data/sigmet?format=json` | GeoJSON | None |
| G-AIRMET | AWC Data API | `aviationweather.gov/api/data/gairmet?format=json` | GeoJSON | None |
| Winds Aloft | AWC Data API | `aviationweather.gov/api/data/windtemp?region=all&format=json` | JSON | None |
| TFR | FAA TFR Site | `tfr.faa.gov/tfr3/` (JSON list) + individual TFR XML/AIXM | JSON/XML | None |
| NOTAM | FAA NMS API | `nms.aim.faa.gov` (transitioning, live ~April 2026) | JSON | Free acct |
| NOTAM (alt) | NASA DIP | `dip.amesaero.nasa.gov` (SWIM-sourced, structured) | JSON | Free acct |
| Airport/Station | NASR 28-day | Bundled with gem (updated via rake task) | SQLite | None |
| Area Fcst Disc. | AWC Data API | `aviationweather.gov/api/data/afd?cwa={wfo}&format=json` | JSON | None |

### AWC API Rate Limiting Notes

The AWC asks users to keep requests limited in scope and frequency. The gem should:
- Set a custom `User-Agent` header: `Briefer/1.0 (ruby; github.com/jay/briefer)`
- Cache responses per TTL (METARs: 5 min, TAFs: 30 min, SIGMETs: 15 min)
- Prefer cache files for bulk data pulls over repeated individual queries
- Never make concurrent requests to the same endpoint

---

## 3. Internal Module Structure

```ruby
module Briefer
  # Top-level convenience methods
  def self.brief(from:, to:, etd:, **opts)     # => Briefer::Briefing
  def self.metar(*station_ids)                  # => [Briefer::Models::Metar]
  def self.taf(*station_ids)                    # => [Briefer::Models::Taf]
  def self.pireps(station_id, radius_nm: 100)   # => [Briefer::Models::Pirep]
  def self.notams(*station_ids)                 # => [Briefer::Models::Notam]
  def self.tfrs(near: nil, radius_nm: nil)      # => [Briefer::Models::Tfr]
  def self.go_no_go(from:, to:, etd:, **opts)  # => Briefer::GoNoGo::Result

  # Configuration
  module Configuration                # API keys (optional), cache settings, personal minimums

  # HTTP infrastructure
  module Client                       # Faraday wrapper, rate limiter, caching middleware

  # Data source adapters
  module Sources
    class Metar                       # Fetches & parses METAR data from AWC
    class Taf                         # Fetches & parses TAF data from AWC
    class Pirep                       # Fetches & parses PIREPs from AWC
    class Sigmet                      # Fetches & parses SIGMETs from AWC
    class Airmet                      # Fetches & parses G-AIRMETs from AWC
    class WindsAloft                  # Fetches & parses winds/temps aloft from AWC
    class Notam                       # Fetches from FAA NMS or NASA DIP
    class Tfr                         # Fetches from FAA TFR site
    class AreaForecast                # Fetches AFD from AWC
    class Station                     # Looks up airport data from bundled DB
  end

  # Decoded data models
  module Models
    class Metar                       # Decoded observation with typed fields
    class Taf                         # Decoded forecast with change groups
    class TafGroup                    # Individual forecast period within a TAF
    class Pirep                       # Decoded pilot report
    class Sigmet                      # SIGMET with polygon geometry
    class Airmet                      # G-AIRMET with polygon geometry
    class WindsAloft                  # Winds & temps at altitude
    class Notam                       # Structured NOTAM
    class Tfr                         # TFR with polygon/circle geometry
    class Station                     # Airport: ICAO, name, coords, elev, runways
    class Runway                      # Runway: designation, length, width, surface
    class Position                    # Lat/lon coordinate pair
    class Altitude                    # Value + reference (MSL/AGL/FL)
  end

  # Intelligence / analysis
  module Analysis
    class FlightCategory              # VFR / MVFR / IFR / LIFR classification
    class RouteBuilder                # Great circle route with corridor
    class StationSelector             # Picks relevant en-route stations
    class HazardFilter                # Filters SIGMETs/AIRMETs/TFRs by route intersection
    class NotamRanker                 # Prioritizes NOTAMs by relevance & severity
    class CrosswindCalculator         # Computes crosswind component for runway
  end

  # Go/No-Go decision engine
  module GoNoGo
    class Evaluator                   # Runs all checks, produces result
    class Result                      # :go, :marginal, :no_go + reasons
    class Profile                     # Personal minimums configuration
    # Individual rule classes:
    class CeilingCheck                # Min ceiling at dep/dest/alt
    class VisibilityCheck             # Min visibility
    class CrosswindCheck              # Max crosswind component
    class IcingCheck                  # Icing avoidance (known icing for non-FIKI)
    class TurbulenceCheck             # Turbulence severity threshold
    class ThunderstormCheck           # Convective avoidance
    class TfrCheck                    # TFR route intersection
    class FuelCheck                   # Winds aloft impact on fuel planning
    class NightCheck                  # Currency / comfort for night ops
  end

  # Briefing assembly
  class Briefing                      # The assembled briefing object
    # Contains all sections in FAA standard order
    # Serializable to JSON, text, or structured hash
  end

  # Formatters
  module Formatters
    class Text                        # Human-readable narrative (like an FSS briefer)
    class Json                        # Structured JSON for agent consumption
    class Summary                     # One-paragraph synopsis
  end

  # CLI
  class CLI < Thor                    # Command-line interface
end
```

---

## 4. The Briefing Object

A `Briefer::Briefing` follows the FAA standard briefing order (per AC 91-92). Every briefing has these sections, assembled in order:

```ruby
class Briefer::Briefing
  # Metadata
  attr_reader :briefing_type          # :standard, :abbreviated, :outlook
  attr_reader :route                  # { from: "KCDW", to: "KACK", alternates: ["KHYA"] }
  attr_reader :time_window            # { etd: Time, eta: Time }
  attr_reader :requested_altitude     # Integer (feet MSL)
  attr_reader :generated_at           # Time (UTC)

  # === Section 1: Adverse Conditions ===
  attr_reader :adverse_conditions     # Array of hazards affecting the route
  # Includes: SIGMETs, Convective SIGMETs, CWAs, TFRs, AIRMETs that
  # intersect the route corridor during the flight time window.
  # Each item has: type, severity, description, geometry, valid_time

  # === Section 2: VFR Flight Not Recommended (if applicable) ===
  attr_reader :vfr_not_recommended    # Boolean + reasoning string
  # Set true when conditions along route are predominantly IFR/LIFR
  # and flight is planned as VFR

  # === Section 3: Synopsis ===
  attr_reader :synopsis               # String - weather system summary
  # Derived from Area Forecast Discussion for the relevant CWA(s)

  # === Section 4: Current Conditions ===
  attr_reader :departure_metar        # Briefer::Models::Metar
  attr_reader :destination_metar      # Briefer::Models::Metar
  attr_reader :alternate_metars       # [Briefer::Models::Metar]
  attr_reader :enroute_metars         # [Briefer::Models::Metar] - stations along route

  # === Section 5: Forecast Conditions ===
  attr_reader :departure_taf          # Briefer::Models::Taf
  attr_reader :destination_taf        # Briefer::Models::Taf
  attr_reader :alternate_tafs         # [Briefer::Models::Taf]

  # === Section 6: Winds Aloft ===
  attr_reader :winds_aloft            # [Briefer::Models::WindsAloft]
  # Filtered to requested altitude +/- one level, relevant stations

  # === Section 7: NOTAMs ===
  attr_reader :departure_notams       # [Briefer::Models::Notam] - sorted by relevance
  attr_reader :destination_notams     # [Briefer::Models::Notam]
  attr_reader :enroute_notams         # [Briefer::Models::Notam] - FDC NOTAMs, TFRs
  attr_reader :alternate_notams       # [Briefer::Models::Notam]

  # === Section 8: PIREPs ===
  attr_reader :pireps                 # [Briefer::Models::Pirep]
  # Filtered to route corridor, recent (last 2-3 hours)

  # === Section 9: TFRs ===
  attr_reader :tfrs                   # [Briefer::Models::Tfr]
  # Filtered to route corridor + buffer

  # === Computed / Analysis ===
  attr_reader :flight_categories      # Hash { "KCDW" => :vfr, "KACK" => :mvfr, ... }
  attr_reader :crosswinds             # Hash { "KCDW/28" => 8.5, ... } (knots)
  attr_reader :go_no_go               # Briefer::GoNoGo::Result

  # === Output ===
  def to_text                         # Narrative briefing (like hearing it from FSS)
  def to_json                         # Structured JSON
  def to_summary                      # One-paragraph executive summary
  def to_h                            # Ruby hash
end
```

### Example Text Output

```
═══════════════════════════════════════════════════════════
  STANDARD WEATHER BRIEFING
  KCDW (Caldwell, NJ) → KACK (Nantucket, MA)
  ETD: 15 Apr 2026 1400Z  |  ETA: 15 Apr 2026 1630Z
  Requested Altitude: 6,000'
  Briefing generated: 15 Apr 2026 1215Z
═══════════════════════════════════════════════════════════

ADVERSE CONDITIONS:
  ⚠  AIRMET Sierra (IFR) — New England coastal areas. Ceilings
     below 1000' and visibility below 3SM in mist. Valid until 2000Z.
  ⚠  TFR 6/1234 — Temporary flight restriction within 3nm of
     JFK (40.6413°N, 73.7781°W). SFC–3000' MSL. VIP movement.

SYNOPSIS:
  A slow-moving cold front extends from eastern PA through central
  CT, moving east at 15 knots. Post-frontal clearing expected at
  KCDW by 1600Z. KACK remains in warm sector with lowering ceilings
  through the afternoon.

CURRENT CONDITIONS:
  KCDW 151200Z 28012G18KT 10SM FEW045 BKN080 18/08 A3012  [VFR]
  KACK 151155Z 19008KT 6SM BR BKN012 OVC025 14/12 A3008   [IFR]

FORECAST CONDITIONS:
  KCDW TAF: VFR improving. BKN080 becoming SKC by 1800Z.
  KACK TAF: IFR through 1800Z. BECMG 1800/2000 BKN025, improving
            to MVFR. TEMPO 1400-1700 3SM BR OVC008.

WINDS ALOFT (FD):
  6,000': JFK 2835+06, BDR 2730+04, ACK 2025+08

NOTAMs:
  KCDW: RWY 4/22 CLSD (construction). PAPI 28 U/S.
  KACK: ILS RWY 6 LOC U/S. VOR/DME RWY 24 AVBL.

PIREPs:
  B738 FL060 20nm NW of BDR — Moderate turbulence.
  C172 3,500' 10nm S of HPN — Light rime icing in clouds.

───────────────────────────────────────────────────────────
GO/NO-GO ASSESSMENT: MARGINAL
  ✓ Departure (KCDW): VFR, crosswind 8kt (within limits)
  ✗ Destination (KACK): IFR at ETA, below VFR minimums
  ⚠ AIRMET Sierra along route — IFR conditions coastal areas
  ✓ No convective activity along route
  ✓ TFR near JFK: outside route corridor

  RECOMMENDATION: Consider delaying departure to 1700Z for
  post-frontal improvement at KACK, or file IFR with KHYA
  as alternate (TAF shows VFR through 2100Z).
───────────────────────────────────────────────────────────
```

---

## 5. CLI Interface (Claude Code Integration)

The CLI is the primary interface for Claude Code. Built with Thor. Every command returns structured output (JSON by default for agent consumption, text with `--format text`).

### Commands

```
briefer brief <from> <to> [options]    # Full standard briefing
briefer metar <station> [station...]   # Current METAR(s)
briefer taf <station> [station...]     # Current TAF(s)
briefer pireps <station> [options]     # PIREPs near station
briefer sigmet [options]               # Active SIGMETs
briefer airmet [options]               # Active G-AIRMETs
briefer notams <station> [station...]  # NOTAMs for station(s)
briefer tfrs [options]                 # Active TFRs
briefer winds <station> [options]      # Winds aloft
briefer station <identifier>           # Airport/station info
briefer go-no-go <from> <to> [options] # Go/no-go evaluation only
briefer categories <station> [...]     # Flight category check
briefer crosswind <station> [options]  # Crosswind calculation
```

### Common Options

```
--format text|json|summary     # Output format (default: json for piped, text for tty)
--altitude <feet>              # Planned cruise altitude
--etd <datetime>               # Estimated time of departure (ISO 8601 or Zulu)
--eta <datetime>               # Estimated time of arrival
--alternates <ICAO,ICAO>       # Alternate airport(s)
--profile <name>               # Go/no-go profile name (from config)
--raw                          # Include raw/encoded source data
--no-cache                     # Force fresh data fetch
--radius <nm>                  # Search radius for PIREPs/TFRs (default: 100nm)
```

### Claude Code Agent Integration

The gem ships with a `briefer.tool` manifest (or equivalent tool definition) so Claude Code can discover and call it. The agent workflow:

```
User: "What's the weather looking like for a flight from Caldwell to Nantucket this afternoon?"

Agent thinks: I should pull a briefing for this route.
Agent calls: $ briefer brief KCDW KACK --etd "2026-04-15T14:00:00Z" --altitude 6000 --format json
Agent receives: structured JSON briefing
Agent responds: natural language interpretation of the briefing, with go/no-go recommendation
```

The CLI should detect whether stdout is a TTY:
- **TTY (human):** default to `--format text`, colorized output
- **Piped (agent):** default to `--format json`, no color

---

## 6. Ruby API (Developer Integration)

The library API mirrors the CLI but returns Ruby objects.

```ruby
# Configuration (optional — works with zero config)
Briefer.configure do |config|
  config.cache_store = :memory            # :memory, :file, :redis
  config.cache_dir = "~/.briefer/cache"   # for :file store
  config.user_agent = "MyApp/1.0"
  config.notam_source = :faa_nms          # :faa_nms, :nasa_dip
  config.default_pirep_radius_nm = 100

  # Go/No-Go profile
  config.go_no_go_profile = Briefer::GoNoGo::Profile.new(
    name: "bonanza_vfr",
    min_ceiling_ft: 2000,
    min_visibility_sm: 5,
    max_crosswind_kt: 15,
    max_gust_kt: 25,
    avoid_known_icing: true,
    max_turbulence: :moderate,    # :light, :moderate, :severe
    avoid_convective: true,
    night_current: false,
    fuel_reserve_minutes: 45
  )
end

# Individual data queries
metar = Briefer.metar("KCDW")              # => Briefer::Models::Metar
taf   = Briefer.taf("KACK")                # => Briefer::Models::Taf
pireps = Briefer.pireps("KCDW", radius_nm: 150)

# Station lookup (offline, from bundled DB)
station = Briefer.station("KCDW")
station.name          # => "Essex County Airport"
station.elevation_ft  # => 173
station.runways       # => [<Runway 04/22, 4552'>, <Runway 10/28, 3718'>]
station.latitude      # => 40.8752
station.longitude     # => -74.2814

# Flight category
Briefer.flight_category("KCDW")   # => :vfr
# or from a METAR object:
metar.flight_category              # => :vfr

# Crosswind
Briefer.crosswind("KCDW", runway: "28")  # => { component_kt: 8.5, headwind_kt: 12.3 }

# Full briefing
briefing = Briefer.brief(from: "KCDW", to: "KACK", etd: ..., altitude: 6000)

# Go/No-Go only
result = Briefer.go_no_go(from: "KCDW", to: "KACK", etd: ..., profile: "bonanza_vfr")
result.verdict     # => :marginal
result.reasons     # => ["Destination IFR at ETA", "AIRMET Sierra along route"]
result.details     # => [<CeilingCheck :fail>, <VisibilityCheck :fail>, ...]
```

---

## 7. Route Geometry Engine

For a briefing to be useful, it needs to know what's *along the route*, not just at the endpoints. This module handles spatial reasoning.

### Route Corridor

Given departure and destination coordinates, build a corridor:

1. **Great circle route** between the two points (or a series of waypoints if provided)
2. **Corridor buffer** — default ±25nm either side of the route centerline
3. **Altitude band** — the planned altitude ±2,000' for hazard filtering

### Station Selection

For en route weather, the gem picks METAR stations along the corridor:
- Query the bundled station database for all stations within the corridor polygon
- Filter to stations that actually have METAR/TAF service (flag in NASR data)
- Limit to ~5–8 en route stations max (spaced reasonably, not clustered)
- Always include stations near the midpoint and any significant terrain/weather boundaries

### Hazard Intersection

SIGMETs, G-AIRMETs, and TFRs come with polygon geometries (GeoJSON). The gem needs to:
- Test if any hazard polygon intersects the route corridor polygon
- If intersection exists, include it in the `adverse_conditions` section
- Simple polygon intersection via the `rgeo` gem (no heavy GIS dependency)

### Implementation Notes

- Use the `rgeo` gem for geospatial operations (point-in-polygon, polygon intersection, great circle distance)
- The `rgeo-geojson` extension handles GeoJSON parsing from the AWC API directly
- Haversine distance for simpler calculations where full geometry isn't needed
- Consider `rgeo-proj4` only if coordinate projection becomes necessary (unlikely for this use case)

---

## 8. Go/No-Go Engine

The decision support layer. This is opinionated but configurable.

### Profiles

A profile represents a pilot's personal minimums for a given aircraft and flight type. Profiles are stored in `~/.briefer/profiles/` as YAML files.

```yaml
# ~/.briefer/profiles/bonanza_vfr.yml
name: bonanza_vfr
description: "Bonanza P35, VFR day, single pilot"
aircraft:
  type: "BE35-B33"
  approach_speed_kt: 80
  max_demonstrated_crosswind_kt: 17
  fiki_equipped: false

minimums:
  ceiling_ft: 2000           # Minimum ceiling at departure and destination
  visibility_sm: 5           # Minimum visibility
  max_crosswind_kt: 15       # Max crosswind component
  max_gust_kt: 25            # Max gust factor
  max_gust_spread_kt: 15     # Max difference between sustained and gust

hazard_avoidance:
  known_icing: true           # Avoid any reported/forecast icing (non-FIKI)
  max_turbulence: moderate    # Accept up to moderate turbulence
  convective: true            # Avoid any convective activity on route
  mountain_obscuration: true  # Avoid when reported

operational:
  night_current: false        # Not current for night ops
  ifr_current: false          # Not current for IFR (drives VFR-only logic)
  fuel_reserve_min: 45        # Minutes of fuel reserve required

# Future: could add instrument approach minimums for IFR profiles
```

```yaml
# ~/.briefer/profiles/bonanza_ifr.yml
name: bonanza_ifr
description: "Bonanza P35, IFR, single pilot"
minimums:
  ceiling_ft: 500
  visibility_sm: 1.5
  max_crosswind_kt: 15
  max_gust_kt: 25
hazard_avoidance:
  known_icing: true
  max_turbulence: moderate
  convective: true
operational:
  night_current: true
  ifr_current: true
  fuel_reserve_min: 60
```

### Evaluation Logic

The evaluator runs each check independently and aggregates:

```ruby
module Briefer::GoNoGo
  class Evaluator
    CHECKS = [
      CeilingCheck,
      VisibilityCheck,
      CrosswindCheck,
      GustCheck,
      IcingCheck,
      TurbulenceCheck,
      ThunderstormCheck,
      TfrCheck,
      NightCheck,
    ].freeze

    def evaluate(briefing, profile)
      results = CHECKS.map { |check| check.new(briefing, profile).call }

      verdict = if results.any?(&:no_go?)
                  :no_go
                elsif results.any?(&:marginal?)
                  :marginal
                else
                  :go
                end

      Result.new(verdict: verdict, checks: results)
    end
  end
end
```

Each check returns `:go`, `:marginal`, or `:no_go` with a human-readable reason. This lets the agent explain *why* a flight is marginal, not just that it is.

---

## 9. Caching Strategy

Aviation weather data has natural freshness intervals. The cache should respect these.

| Data Type | Cache TTL | Rationale |
|-----------|-----------|-----------|
| METAR | 5 minutes | Issued hourly, special obs anytime; 5 min balances freshness vs. load |
| TAF | 30 minutes | Issued every 6 hours, amended as needed |
| PIREP | 10 minutes | Continuous reporting, but older PIREPs still relevant |
| SIGMET | 15 minutes | Valid for 4-6 hours, but new ones can be issued anytime |
| G-AIRMET | 30 minutes | Issued every 3 hours at fixed times |
| NOTAM | 60 minutes | Changes infrequently, high volume per station |
| TFR | 30 minutes | Changes infrequently |
| Winds Aloft | 60 minutes | Issued every 6 hours |
| Station data | ∞ (bundled) | Updated with gem releases / rake task |

### Cache Backends

```ruby
# Memory (default, good for CLI one-shots and agent calls)
config.cache_store = :memory

# File (good for repeated use, persists between CLI invocations)
config.cache_store = :file
config.cache_dir = "~/.briefer/cache"

# Redis (good for Rails app integration)
config.cache_store = :redis
config.redis_url = "redis://localhost:6379/0"
```

---

## 10. Configuration

Configuration lives in `~/.briefer/config.yml` and/or programmatic `Briefer.configure` block. Environment variables override file config.

```yaml
# ~/.briefer/config.yml
cache:
  store: file
  dir: ~/.briefer/cache

defaults:
  pirep_radius_nm: 100
  corridor_width_nm: 25
  format: text               # CLI default when running interactively

home_airport: KCDW            # Used as default departure if not specified

notam:
  source: faa_nms             # faa_nms | nasa_dip
  # api_key: "..."            # If required by source

go_no_go:
  default_profile: bonanza_vfr

# Future: optional paid source credentials
# paid_sources:
#   notamify_api_key: "..."
#   checkwx_api_key: "..."
#   avwx_api_key: "..."
```

### Environment Variables

```
BRIEFER_CACHE_STORE=file
BRIEFER_CACHE_DIR=~/.briefer/cache
BRIEFER_HOME_AIRPORT=KCDW
BRIEFER_NOTAM_SOURCE=faa_nms
BRIEFER_DEFAULT_PROFILE=bonanza_vfr
```

---

## 11. Gem File Structure

```
briefer/
├── briefer.gemspec
├── Gemfile
├── Rakefile
├── README.md
├── LICENSE.txt
├── CHANGELOG.md
│
├── bin/
│   └── briefer                          # CLI executable
│
├── lib/
│   ├── briefer.rb                       # Entry point, top-level methods
│   ├── briefer/
│   │   ├── version.rb
│   │   ├── configuration.rb
│   │   ├── briefing.rb                  # The assembled briefing object
│   │   │
│   │   ├── client/
│   │   │   ├── http.rb                  # Faraday wrapper
│   │   │   ├── rate_limiter.rb
│   │   │   └── cache.rb                 # Cache middleware
│   │   │
│   │   ├── sources/
│   │   │   ├── base.rb                  # Shared source behavior
│   │   │   ├── metar.rb
│   │   │   ├── taf.rb
│   │   │   ├── pirep.rb
│   │   │   ├── sigmet.rb
│   │   │   ├── airmet.rb
│   │   │   ├── winds_aloft.rb
│   │   │   ├── notam.rb
│   │   │   ├── tfr.rb
│   │   │   ├── area_forecast.rb
│   │   │   └── station.rb
│   │   │
│   │   ├── models/
│   │   │   ├── metar.rb
│   │   │   ├── taf.rb
│   │   │   ├── taf_group.rb
│   │   │   ├── pirep.rb
│   │   │   ├── sigmet.rb
│   │   │   ├── airmet.rb
│   │   │   ├── winds_aloft.rb
│   │   │   ├── notam.rb
│   │   │   ├── tfr.rb
│   │   │   ├── station.rb
│   │   │   ├── runway.rb
│   │   │   ├── position.rb
│   │   │   └── altitude.rb
│   │   │
│   │   ├── analysis/
│   │   │   ├── flight_category.rb
│   │   │   ├── route_builder.rb
│   │   │   ├── station_selector.rb
│   │   │   ├── hazard_filter.rb
│   │   │   ├── notam_ranker.rb
│   │   │   └── crosswind_calculator.rb
│   │   │
│   │   ├── go_no_go/
│   │   │   ├── evaluator.rb
│   │   │   ├── result.rb
│   │   │   ├── profile.rb
│   │   │   └── checks/
│   │   │       ├── base_check.rb
│   │   │       ├── ceiling_check.rb
│   │   │       ├── visibility_check.rb
│   │   │       ├── crosswind_check.rb
│   │   │       ├── gust_check.rb
│   │   │       ├── icing_check.rb
│   │   │       ├── turbulence_check.rb
│   │   │       ├── thunderstorm_check.rb
│   │   │       ├── tfr_check.rb
│   │   │       └── night_check.rb
│   │   │
│   │   ├── formatters/
│   │   │   ├── text.rb
│   │   │   ├── json.rb
│   │   │   └── summary.rb
│   │   │
│   │   └── cli.rb                       # Thor CLI definition
│   │
│   └── data/
│       └── stations.json.gz             # Bundled airport database
│
├── config/
│   └── profiles/
│       ├── bonanza_vfr.yml              # Example profile
│       └── bonanza_ifr.yml              # Example profile
│
├── spec/
│   ├── spec_helper.rb
│   ├── briefer_spec.rb
│   ├── sources/
│   │   ├── metar_spec.rb
│   │   ├── taf_spec.rb
│   │   ├── pirep_spec.rb
│   │   └── ...
│   ├── models/
│   │   ├── metar_spec.rb
│   │   └── ...
│   ├── analysis/
│   │   ├── flight_category_spec.rb
│   │   ├── route_builder_spec.rb
│   │   ├── crosswind_calculator_spec.rb
│   │   └── ...
│   ├── go_no_go/
│   │   ├── evaluator_spec.rb
│   │   └── checks/
│   │       └── ...
│   ├── formatters/
│   │   └── ...
│   └── fixtures/
│       ├── metars/                      # Saved JSON responses for testing
│       │   ├── kcdw.json
│       │   ├── kack.json
│       │   └── multi_station.json
│       ├── tafs/
│       ├── pireps/
│       ├── sigmets/
│       ├── airmets/
│       ├── notams/
│       └── tfrs/
│
└── tasks/
    └── stations.rake                    # Rake task to update bundled station DB
```

---

## 12. Data Models

### METAR Model (example of field decomposition)

```ruby
module Briefer::Models
  class Metar
    attr_reader :raw                     # Original encoded METAR string
    attr_reader :station_id              # "KCDW"
    attr_reader :observed_at             # Time (UTC)
    attr_reader :is_auto                 # Boolean
    attr_reader :is_speci                # Boolean (special observation)

    # Wind
    attr_reader :wind_direction_deg      # Integer (0-360, or nil for variable)
    attr_reader :wind_speed_kt           # Integer
    attr_reader :wind_gust_kt            # Integer or nil
    attr_reader :wind_variable_from_deg  # Integer or nil
    attr_reader :wind_variable_to_deg    # Integer or nil

    # Visibility
    attr_reader :visibility_sm           # Float (statute miles)
    attr_reader :rvr                     # Hash { "28" => { feet: 2400, trend: :up } } or nil

    # Weather phenomena
    attr_reader :weather                 # ["+RA", "BR", "FG", ...] or []

    # Sky condition
    attr_reader :sky_condition           # [{ cover: :bkn, base_ft: 4500 }, ...]
    attr_reader :ceiling_ft              # Integer or nil (lowest BKN/OVC)

    # Temp / Dewpoint / Altimeter
    attr_reader :temperature_c           # Float
    attr_reader :dewpoint_c              # Float
    attr_reader :altimeter_inhg          # Float

    # Remarks (selected fields)
    attr_reader :sea_level_pressure_mb   # Float or nil
    attr_reader :precip_hourly_in        # Float or nil
    attr_reader :remarks_raw             # String (full remarks section)

    # Computed
    attr_reader :flight_category         # :vfr, :mvfr, :ifr, :lifr
    attr_reader :density_altitude_ft     # Integer (computed from temp/altimeter/elevation)
    attr_reader :spread_c                # Float (temp - dewpoint)
    attr_reader :station                 # Briefer::Models::Station (if available)

    def vfr?;  flight_category == :vfr;  end
    def mvfr?; flight_category == :mvfr; end
    def ifr?;  flight_category == :ifr;  end
    def lifr?; flight_category == :lifr; end
  end
end
```

### Flight Category Classification Rules

Per FAA AIM / AWC definitions:

| Category | Ceiling | Visibility |
|----------|---------|------------|
| **VFR** | > 3,000' AGL | > 5 SM |
| **MVFR** | 1,000–3,000' AGL | 3–5 SM |
| **IFR** | 500–999' AGL | 1–2 SM |
| **LIFR** | < 500' AGL | < 1 SM |

The *lowest* qualifying condition determines the category. If ceiling is VFR but visibility is IFR, the station is IFR.

---

## 13. Build Phases

### Phase 1: Foundation (Week 1–2)
**Goal: `briefer metar KCDW` works from the CLI and returns structured data.**

- [ ] Gem scaffold (`bundle gem briefer`, gemspec, Thor CLI skeleton)
- [ ] `Briefer::Client::Http` — Faraday wrapper with User-Agent, timeouts, error handling
- [ ] `Briefer::Sources::Metar` — fetch from AWC API, parse JSON response
- [ ] `Briefer::Models::Metar` — full field decomposition from AWC JSON
- [ ] `Briefer::Analysis::FlightCategory` — VFR/MVFR/IFR/LIFR classification
- [ ] `Briefer::Formatters::Json` — JSON output
- [ ] `Briefer::Formatters::Text` — human-readable METAR display
- [ ] CLI: `briefer metar <station> [stations...]`
- [ ] CLI: `briefer categories <station> [stations...]`
- [ ] Basic RSpec setup with VCR cassettes for AWC responses
- [ ] Bundled station database (ICAO, name, lat, lon, elevation) — at minimum US airports

### Phase 2: Core Weather Sources (Week 3–4)
**Goal: `briefer taf KACK` and `briefer pireps KCDW` work.**

- [ ] `Briefer::Sources::Taf` + `Briefer::Models::Taf` + `Briefer::Models::TafGroup`
- [ ] `Briefer::Sources::Pirep` + `Briefer::Models::Pirep`
- [ ] `Briefer::Sources::WindsAloft` + `Briefer::Models::WindsAloft`
- [ ] `Briefer::Analysis::CrosswindCalculator` — crosswind/headwind from METAR + runway
- [ ] CLI: `briefer taf`, `briefer pireps`, `briefer winds`, `briefer crosswind`
- [ ] Cache layer (`Briefer::Client::Cache`) — memory store with TTLs
- [ ] File-based cache store option

### Phase 3: Hazards & NOTAMs (Week 5–6)
**Goal: `briefer sigmet`, `briefer tfrs`, `briefer notams KCDW` work.**

- [ ] `Briefer::Sources::Sigmet` + `Briefer::Models::Sigmet` (GeoJSON parsing)
- [ ] `Briefer::Sources::Airmet` + `Briefer::Models::Airmet` (GeoJSON parsing)
- [ ] `Briefer::Sources::Tfr` + `Briefer::Models::Tfr` (FAA JSON/XML parsing)
- [ ] `Briefer::Sources::Notam` + `Briefer::Models::Notam` (FAA NMS or NASA DIP)
- [ ] `Briefer::Sources::AreaForecast` — Area Forecast Discussion
- [ ] Add `rgeo` + `rgeo-geojson` for geometry operations
- [ ] CLI: `briefer sigmet`, `briefer airmet`, `briefer tfrs`, `briefer notams`

### Phase 4: Route Intelligence (Week 7–8)
**Goal: `briefer brief KCDW KACK --etd ... --altitude 6000` assembles a full briefing.**

- [ ] `Briefer::Analysis::RouteBuilder` — great circle route + corridor polygon
- [ ] `Briefer::Analysis::StationSelector` — en route station selection
- [ ] `Briefer::Analysis::HazardFilter` — SIGMET/AIRMET/TFR intersection with corridor
- [ ] `Briefer::Analysis::NotamRanker` — relevance scoring and prioritization
- [ ] `Briefer::Briefing` — full assembly of all sections in FAA standard order
- [ ] `Briefer::Formatters::Text` — narrative briefing output (the FSS-style text)
- [ ] `Briefer::Formatters::Summary` — one-paragraph synopsis
- [ ] CLI: `briefer brief <from> <to> [options]`

### Phase 5: Go/No-Go Engine (Week 9–10)
**Goal: `briefer go-no-go KCDW KACK --profile bonanza_vfr` returns a verdict.**

- [ ] `Briefer::GoNoGo::Profile` — YAML loading, validation
- [ ] `Briefer::GoNoGo::Evaluator` — orchestrator
- [ ] All check classes (ceiling, visibility, crosswind, gust, icing, turbulence, thunderstorm, TFR, night)
- [ ] `Briefer::GoNoGo::Result` — verdict + reasons + recommendation
- [ ] Example profiles: `bonanza_vfr.yml`, `bonanza_ifr.yml`
- [ ] CLI: `briefer go-no-go <from> <to> [options]`
- [ ] Integration with briefing object (`briefing.go_no_go`)

### Phase 6: Polish & Distribution (Week 11–12)
**Goal: Publishable gem. Claude Code tool definition. README with examples.**

- [ ] Configuration system (`~/.briefer/config.yml`, env vars)
- [ ] Colorized terminal output (TTY detection)
- [ ] `briefer station <id>` command with full airport detail
- [ ] `rake stations:update` task to refresh bundled airport DB from NASR
- [ ] Comprehensive RSpec suite with fixtures
- [ ] README with installation, quickstart, CLI reference, Ruby API examples
- [ ] Claude Code tool definition file (`.claude/tools/briefer.json` or equivalent)
- [ ] Publish to RubyGems
- [ ] `~/Code/briefer` repository setup

---

## 14. Test Strategy

### Fixture-Based Testing

All source modules are tested against saved API responses (VCR cassettes or static JSON fixtures). This means:
- Tests don't hit live APIs
- Tests are deterministic
- Fixtures document the API response format
- Tests run offline

### Fixture Collection

A rake task to capture fresh fixtures from live APIs:

```bash
$ rake fixtures:refresh              # Refresh all fixtures
$ rake fixtures:refresh:metar        # Refresh METAR fixtures only
$ rake fixtures:refresh:taf          # etc.
```

### Key Test Scenarios

- **METAR parsing**: All weather phenomena, variable winds, SPECI, AUTO, ceiling edge cases
- **TAF parsing**: BECMG, TEMPO, FM, PROB30 groups
- **Flight category**: Edge cases at category boundaries (exactly 1000' ceiling = IFR, not MVFR)
- **Crosswind calculation**: 90° crosswind, direct headwind, calm winds, variable winds
- **Route geometry**: Short routes, long routes, routes crossing 180° meridian (unlikely but correct)
- **Hazard intersection**: SIGMET polygon that partially intersects corridor, completely contains corridor, doesn't intersect
- **Go/No-Go**: Each check in isolation, combined scenarios, edge cases
- **Briefing assembly**: Full integration test with all sources returning fixture data

---

## 15. Future Possibilities

Things explicitly out of scope for v1 but worth tracking:

- **Paid source adapters**: Notamify (richer NOTAM parsing), CheckWX (pre-decoded METARs), AVWX (error-corrected data)
- **Aircraft performance profiles**: Fuel burn rates, climb/descent performance for more accurate fuel planning
- **Weight & balance integration**: Given current fuel and passengers, compute W&B
- **Graphical briefing**: HTML/web view with embedded map showing route, hazards, stations
- **Slack/SMS integration**: Morning briefing push for planned flights
- **Favorite routes**: Saved route definitions (KCDW→KACK with usual alternates and altitude)
- **Historical briefing archive**: Save briefings for post-flight review / logbook
- **ADSB integration**: Live traffic near route
- **ForeFlight/Garmin Pilot export**: Generate a flight plan file importable into EFBs
- **Multi-leg / round-trip support**: Brief the return leg too
- **International support**: ICAO stations outside the US (AWC has worldwide METARs/TAFs)
- **Instrument approach awareness**: For IFR profiles, check if destination has a usable approach given current equipment (e.g., "ILS RWY 6 LOC U/S" NOTAM + your avionics status)

---

## Dependencies

### Required
- `thor` — CLI framework
- `faraday` — HTTP client
- `faraday-retry` — retry middleware
- `rgeo` — geospatial operations (route corridor, polygon intersection)
- `rgeo-geojson` — parse GeoJSON from AWC API
- `json` — JSON parsing (stdlib)
- `yaml` — YAML config parsing (stdlib)
- `zlib` — decompress bundled station DB (stdlib)
- `time` — UTC/Zulu time handling (stdlib)

### Development
- `rspec` — testing
- `vcr` + `webmock` — HTTP fixture recording
- `rubocop` — style enforcement
- `rake` — task runner
- `bundler` — dependency management

### Optional (loaded if present)
- `redis` — Redis cache backend
- `colorize` or `pastel` — colorized terminal output

---

## References

- [AC 91-92: Pilot's Guide to a Preflight Briefing](https://www.faa.gov/documentLibrary/media/Advisory_Circular/AC_91-92.pdf)
- [AWC Data API](https://aviationweather.gov/data/api/) — OpenAPI spec available
- [AWC Product Info](https://aviationweather.gov/help/data/) — METAR, TAF, PIREP, SIGMET, G-AIRMET documentation
- [FAA TFR Site](https://tfr.faa.gov/tfr3/) — JSON and XML feeds
- [FAA NASR Data](https://www.faa.gov/air_traffic/flight_info/aeronav/aero_data/) — 28-day subscription for airport data
- [FAA NMS (NOTAM Management System)](https://nms.aim.faa.gov/) — transitioning to production April 2026
- [NASA DIP NOTAM Service](https://dip.amesaero.nasa.gov) — structured NOTAM redistribution from FAA SWIM
- [1800wxbrief.com](https://www.1800wxbrief.com) — Leidos Flight Service web portal (the thing we're building an agent-native version of)
- [RGeo Gem](https://github.com/rgeo/rgeo) — Ruby geospatial library
