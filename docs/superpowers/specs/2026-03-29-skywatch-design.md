# Skywatch — Aviation Situational Awareness Agent System

## Overview

Skywatch is a multi-agent system for answering questions about the current state of the skies over the United States. It consists of an orchestrator agent (`tracon`) and 7 specialized subagent gems, each with its own CLI. The system is designed for hobbyist aviation enthusiasts who want real-time awareness of weather, traffic, emergencies, and ATC activity.

## Architecture

### Project Structure

```
skywatch/
├── tracon/            # Orchestrator agent gem
├── briefer/           # Weather briefings (existing, moved from ../briefer)
├── radar/             # Flight tracking
├── mayday/            # Emergency detection
├── nimbus/            # Deep weather analysis
├── livewire/          # ATC audio feeds
├── sectional/         # Airspace & NOTAMs
└── blackbox/          # NTSB historical safety
```

All gems are peer directories within `skywatch/`. No gem depends on another gem as a Ruby dependency. Coordination happens exclusively through CLI invocations and JSON output.

### Dual-Mode Orchestration

Tracon operates in two modes:

**Standalone Agent Mode** — `tracon ask "emergency at SFO?"`
- Tracon invokes the Claude API directly using the Anthropic SDK
- Subagent CLIs are registered as tools
- Claude decides which tools to call, tracon executes them, Claude synthesizes
- Works anywhere: terminal, scripts, automation

**Claude Code Skill Mode** — `/skywatch emergency at SFO?`
- Tracon installs a skill.md into `~/.claude/commands/skywatch.md`
- Claude Code loads the skill and uses Bash to call subagent CLIs
- Same subagent layer, different caller

Both modes consume the same CLI + JSON interface from subagents.

## Gem Contract

Every subagent gem follows the same structure and conventions.

### Directory Layout

```
<agent>/
├── exe/<agent>              # CLI entry point
├── lib/
│   ├── <agent>.rb           # Top-level module + convenience API
│   └── <agent>/
│       ├── version.rb       # VERSION constant
│       ├── skill.md         # Claude Code skill definition
│       ├── errors.rb        # Error hierarchy
│       ├── client/
│       │   ├── http.rb      # Faraday wrapper
│       │   └── cache.rb     # TTL-based in-memory cache
│       ├── sources/         # API endpoint wrappers (fetch + parse)
│       ├── models/          # Typed data objects (.from_api, .to_h, .to_json)
│       ├── analysis/        # Business logic (pure functions)
│       └── formatters/
│           └── text.rb      # Human-readable output
├── spec/                    # RSpec + VCR cassettes
├── <agent>.gemspec
├── CLAUDE.md
└── .rubocop.yml
```

### CLI Contract

- `<agent> <command> [args] --format json|text` — every command supports both output formats
- `<agent> install-skill` — copies skill.md to `~/.claude/commands/<agent>.md`
- `<agent> uninstall-skill` — removes it
- `<agent> version` — prints version
- Exit code 0 on success, 1 on error
- JSON to stdout, errors to stderr
- Auto-detect format: text when TTY, JSON when piped

### Shared Dependencies

- `faraday` + `faraday-retry` for HTTP
- `thor` for CLI
- Dev: `rspec`, `vcr`, `webmock`, `rubocop`
- No cross-gem Ruby dependencies

## Tracon — Orchestrator Agent

### Gem Contents

```
tracon/
├── exe/tracon
├── lib/tracon/
│   ├── version.rb      # VERSION constant
│   ├── skill.md        # Claude Code skill (for /skywatch command)
│   ├── agent.rb        # Claude API orchestration loop
│   ├── tools.rb        # Tool definitions from installed subagents
│   └── registry.rb     # Discovers which subagents are on $PATH
└── tracon.gemspec      # Depends on: anthropic SDK, thor
```

### Components

**registry.rb** — Discovers installed subagents by checking `$PATH` for known CLI names (`briefer`, `radar`, `mayday`, etc.). Returns available subagents and their versions. Used by both modes.

**tools.rb** — Maps each subagent's CLI commands to Claude API tool schemas. Only generates tool definitions for subagents that are actually installed.

**agent.rb** — Standalone agent mode. Calls Claude API with system prompt (aviation identity, routing logic, response style), registers tools from `tools.rb`, executes tool calls by shelling out to subagent CLIs, handles the conversation loop.

**skill.md** — Claude Code mode. Same routing knowledge as the system prompt but formatted as a Claude Code skill. Installed to `~/.claude/commands/skywatch.md`.

### CLI Commands

```
tracon ask "what's happening at SFO?"    # Standalone agent mode
tracon tools                              # List available subagent tools
tracon install-skill                      # Install /skywatch into Claude Code
tracon uninstall-skill                    # Remove it
tracon version
```

### Routing Logic

| User intent | Subagents dispatched |
|---|---|
| Weather at an airport | briefer (primary), nimbus (if severe/complex) |
| Active emergencies | mayday, radar (enrich), briefer (wx context) |
| Track a specific flight | radar |
| Is it safe to fly into X? | briefer, nimbus, sectional (NOTAMs/TFRs), mayday |
| What happened at X? | blackbox (if historical), mayday (if current) |
| Listen to ATC | livewire |
| Full picture at airport | all available subagents |

### Availability Awareness

Tracon only dispatches to installed subagents. If a subagent isn't available, it acknowledges the gap: "I'd check NOTAMs but sectional isn't installed." Graceful degradation — answer with whatever is present.

## Subagent Specifications

### briefer — Weather Briefings

**Status:** Existing, in progress (Phase 3 of 6). Will be moved from `../briefer` to `skywatch/briefer` after current phase completes.

**Data Sources:**
- Aviation Weather Center API (aviationweather.gov) — free, no key

**CLI Commands:**
```
briefer metar KSFO [KJFK ...]           # METAR observations
briefer taf KSFO [KJFK ...]            # Terminal forecasts
briefer pireps KSFO --radius 100        # Pilot reports
briefer winds KSFO --altitude 6000      # Winds aloft
briefer crosswind KSFO --runway 280     # Crosswind calculation
briefer categories KSFO [KJFK ...]      # Flight categories
briefer sigmets                          # Active SIGMETs (Phase 3)
briefer airmets                          # Active AIRMETs (Phase 3)
briefer tfrs KSFO                        # TFRs (Phase 3)
briefer afd WFO                          # Area Forecast Discussion (Phase 3)
```

**Cache TTLs:** METARs 5min, TAFs 30min, PIREPs 10min, SIGMETs 15min.

### radar — Flight Tracking

**Data Sources:**
- OpenSky Network (free, no key) — real-time state vectors, positions, tracks
- FlightAware AeroAPI (free tier, key required) — flight plans, ETAs, gate info, aircraft details
- OpenSky is default; FlightAware enriches when configured

**CLI Commands:**
```
radar flights KSFO                       # Active flights near airport
radar track UAL1234                      # Track by callsign
radar aircraft N12345                    # Lookup by tail number
radar history UAL1234                    # Recent flight history
```

**Environment Variables:** `FLIGHTAWARE_API_KEY` (optional, for enrichment)

### mayday — Emergency Detection

**Data Sources:**
- OpenSky Network / ADSB.lol — squawk code filters on ADS-B data
- Enriches with flight context by calling `radar track <callsign> --format json` when radar is installed

**CLI Commands:**
```
mayday active                            # All current emergencies nationwide
mayday active KSFO                       # Emergencies near specific airport
mayday watch KSFO                        # Monitoring snapshot
```

**Emergency Classification:**
- Squawk 7700: General emergency
- Squawk 7600: Communications failure
- Squawk 7500: Hijack/unlawful interference

### nimbus — Deep Weather Analysis

**Data Sources:**
- Aviation Weather Center API (free) — SIGMETs, AIRMETs, convective outlooks, turbulence forecasts
- NOAA MRMS (free) — radar composites

**CLI Commands:**
```
nimbus radar KSFO                        # Radar summary near airport
nimbus convective                        # Convective outlook (national)
nimbus sigmets                           # Active SIGMETs
nimbus airmets                           # Active AIRMETs
nimbus turbulence KSFO                   # Turbulence forecasts
```

**Relationship to briefer:** Briefer handles pilot-briefing-format weather (route-based, regulatory). Nimbus goes deeper — regional analysis, trend interpretation, hazard correlation across data sources.

### livewire — ATC Audio

**Data Sources:**
- LiveATC stream URL discovery — returns playable stream URLs
- FAA airport data (free) — frequency database

**CLI Commands:**
```
livewire feed KSFO                       # Available feeds + stream URLs
livewire frequencies KSFO                # Known frequencies (tower, ground, approach)
```

**Scope:** MVP returns links to the right feed. Future: whisper/speech-to-text transcription integration.

### sectional — Airspace & NOTAMs

**Data Sources:**
- FAA NOTAM API (notams.aim.faa.gov) — free, requires registration
- FAA NASR (free) — airspace boundary data, airport info
- FAA TFR feed (tfr.faa.gov) — temporary flight restrictions

**CLI Commands:**
```
sectional airspace KSFO                  # Airspace class, boundaries
sectional notams KSFO                    # Active NOTAMs
sectional tfrs                           # Active TFRs (national)
sectional tfrs KSFO                      # TFRs near airport
```

**Environment Variables:** `FAA_NOTAM_API_KEY` (required for NOTAM access)

### blackbox — Historical Safety

**Data Sources:**
- NTSB Aviation Database (free, no key) — accidents, incidents, probable cause
- FAA SDR / Service Difficulty Reports (free) — mechanical issues by aircraft type

**CLI Commands:**
```
blackbox search N12345                   # Incidents by tail number
blackbox search --airport KSFO           # Incidents at airport
blackbox search --airline UAL            # Incidents by operator
blackbox recent                          # Recent NTSB reports
```

## Example Scenario

User: "I hear there's an emergency going into SFO, can you take a look?"

Tracon dispatches:
1. `mayday active KSFO --format json` → Finds UAL1234, 737-900, squawking 7700, FL180 descending
2. `radar track UAL1234 --format json` → Origin JFK, destination SFO, aircraft N12345, 6 years old
3. `briefer metar KSFO --format json` → IFR conditions, ceiling 800 broken, vis 3SM mist, winds 280@15G25
4. `livewire feed KSFO --format json` → NorCal Approach feed URL, tower 120.5

Tracon synthesizes: "Yes, UAL1234 — a 737-900 out of JFK — is squawking 7700 on approach to SFO. Currently descending through FL180. SFO is IFR right now with ceilings at 800 broken and 3 miles visibility in mist, winds from the west at 15 gusting 25. Here's the NorCal Approach feed if you want to listen in: [stream URL]."

## Build Order

1. **briefer** — already in progress, finish Phase 3-6
2. **radar** — foundation for mayday (provides flight context)
3. **mayday** — depends on ADS-B data patterns established by radar
4. **tracon** — once briefer + radar + mayday exist, the orchestrator has enough to be useful
5. **nimbus** — extends weather capability beyond briefer
6. **sectional** — NOTAMs and airspace
7. **livewire** — ATC audio (hardest integration, lowest priority for MVP)
8. **blackbox** — historical data (standalone, can be built anytime)

## Credentials Summary

| Gem | Required | Optional |
|---|---|---|
| briefer | none | — |
| radar | none (OpenSky) | `FLIGHTAWARE_API_KEY` |
| mayday | none | — |
| nimbus | none | — |
| livewire | none | — |
| sectional | `FAA_NOTAM_API_KEY` | — |
| blackbox | none | — |
| tracon | `ANTHROPIC_API_KEY` | — |
