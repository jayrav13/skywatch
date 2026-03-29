# Briefer

A Ruby gem delivering FAA-standard preflight weather briefings for pilots and AI agents. Consolidates aviation weather data from free, public FAA/NWS sources.

## Project Overview

- **Type**: Ruby gem (single gem, many internal modules)
- **CLI framework**: Thor
- **HTTP client**: Faraday (with faraday-retry)
- **Geospatial**: rgeo + rgeo-geojson
- **Testing**: RSpec with VCR/webmock fixtures
- **Style**: RuboCop

See `BRIEFER_PLAN.md` for full architecture, data sources, module structure, data models, and build phases.

## Commands

```bash
bundle exec rspec              # Run tests
bundle exec rubocop            # Lint
bundle exec rake               # Default task
bin/briefer                    # CLI entry point
```

## Architecture

```
Briefer (top-level convenience methods)
  -> CLI (Thor)
  -> Briefing Orchestrator
  -> Intelligence Layer (Analysis module)
  -> Data Layer (Sources module)
  -> HTTP Client (Faraday wrapper with rate limiting + caching)
```

Key modules: `Sources::*` (data fetching), `Models::*` (typed data objects), `Analysis::*` (route geometry, flight categories, hazard filtering), `GoNoGo::*` (decision engine), `Formatters::*` (text/json/summary output).

## Conventions

- All data sources are under `Briefer::Sources`, models under `Briefer::Models`
- Every CLI command maps 1:1 to a Ruby API method
- No API keys required for core functionality (AWC, FAA feeds are public)
- Station/airport data is bundled with the gem (offline lookup)
- Cache TTLs follow aviation data freshness: METARs 5min, TAFs 30min, SIGMETs 15min, NOTAMs 60min
- Custom `User-Agent` header on all requests per AWC guidelines
- Test against saved fixtures (VCR cassettes / static JSON), never live APIs in tests

## Build Phases

Currently building in phases — see `BRIEFER_PLAN.md` section 13 for the full checklist:

1. **Foundation** - Gem scaffold, HTTP client, METAR source/model, flight categories, CLI basics
2. **Core Weather** - TAF, PIREP, winds aloft, crosswind calculator, caching
3. **Hazards & NOTAMs** - SIGMETs, AIRMETs, TFRs, NOTAMs, rgeo integration
4. **Route Intelligence** - Route builder, station selector, hazard filter, full briefing assembly
5. **Go/No-Go Engine** - Profiles, evaluator, all check classes
6. **Polish & Distribution** - Config system, colorized output, publish to RubyGems
