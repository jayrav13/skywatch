# Skywatch

Aviation situational awareness toolkit — real-time weather, flight tracking, and more from public FAA/NWS/ADS-B data.

## Project Overview

- **Type**: Ruby gem (single gem, internal domain modules)
- **CLI framework**: Thor (subcommands per domain)
- **HTTP client**: Faraday (with faraday-retry)
- **Geospatial**: rgeo + rgeo-geojson
- **Testing**: RSpec with WebMock fixtures
- **Style**: RuboCop

## Commands

```bash
bundle exec rspec              # Run tests
bundle exec rubocop            # Lint
bundle exec rake               # Default task (spec + rubocop)
exe/skywatch                   # CLI entry point
```

## Architecture

```
Skywatch (top-level module + convenience API)
├── Shared    # HTTP client, cache, geometry, errors, Position
├── Briefer   # aviation weather briefings
├── Radar     # flight tracking via OpenSky
└── CLI       # Thor with subcommands
```

## CLI Usage

```bash
skywatch weather metar KCDW
skywatch weather taf KACK
skywatch weather pireps KCDW --radius 100
skywatch weather winds JFK
skywatch weather sigmets
skywatch weather airmets --product sierra
skywatch weather afd OKX
skywatch weather categories KCDW KEWR
skywatch weather crosswind KCDW --runway 220
skywatch mayday near 40.875 -74.282 --radius 100
skywatch nimbus outlook 1 --at 40.688,-74.174
skywatch nimbus storms --type tornado --near 40.688,-74.174 --radius 100
skywatch nimbus convection 40.688 -74.174
skywatch brief KCDW
skywatch radar track UAL1234
skywatch radar flights 37.62 -122.38
```

## Conventions

- All data sources under `Skywatch::<Domain>::Sources`
- All models under `Skywatch::<Domain>::Models`
- Shared infrastructure under `Skywatch::Shared`
- No API keys required for core functionality
- Cache TTLs: METARs 5min, TAFs 30min, state vectors 15s
- Test against saved fixtures, never live APIs
- All CLI commands support --format json|text (auto-detect TTY)
