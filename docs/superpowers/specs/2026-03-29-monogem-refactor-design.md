# Skywatch Monogem Refactor Design

## Overview

Consolidate skywatch from a multi-gem architecture (briefer, radar, mayday, etc. as separate gems) into a single `skywatch` gem with internal domain modules. All existing briefer code and the radar scaffold are re-namespaced under `Skywatch::Briefer` and `Skywatch::Radar`. Shared infrastructure (HTTP client, cache, geometry, errors, station DB) moves to `Skywatch::Shared`.

## Motivation

The multi-gem approach duplicates infrastructure (HTTP client, cache, station data), requires CLI-to-JSON shelling between components, and creates operational overhead (8 gemspecs, 8 test suites) for a single-developer project. A single gem with clean internal modules gives the same separation of concerns without the boilerplate.

## Module Structure

```
Skywatch (top-level module + convenience API)
├── Skywatch::Shared       # HTTP client, cache, station DB, geometry, errors, Position
├── Skywatch::Briefer      # pilot weather briefings (was the briefer gem)
├── Skywatch::Radar        # flight tracking via OpenSky (was the radar gem)
├── Skywatch::Mayday       # emergency detection (future)
├── Skywatch::Nimbus       # deep weather analysis (future)
├── Skywatch::Livewire     # ATC audio (future)
├── Skywatch::Sectional    # airspace & NOTAMs (future)
├── Skywatch::Blackbox     # NTSB historical (future)
└── Skywatch::Tracon       # orchestrator (future)
```

## File Layout

```
skywatch/
├── exe/skywatch
├── lib/
│   ├── skywatch.rb
│   └── skywatch/
│       ├── version.rb
│       ├── shared/
│       │   ├── errors.rb
│       │   ├── http.rb
│       │   ├── cache.rb
│       │   ├── geometry.rb
│       │   └── position.rb
│       ├── briefer/
│       │   ├── cli.rb
│       │   ├── sources/
│       │   │   ├── metar.rb
│       │   │   ├── taf.rb
│       │   │   ├── pirep.rb
│       │   │   ├── winds_aloft.rb
│       │   │   ├── air_sigmet.rb
│       │   │   ├── gairmet.rb
│       │   │   ├── tfr.rb
│       │   │   └── forecast_discussion.rb
│       │   ├── models/
│       │   │   ├── metar.rb
│       │   │   ├── taf.rb
│       │   │   ├── taf_group.rb
│       │   │   ├── pirep.rb
│       │   │   ├── winds_aloft.rb
│       │   │   ├── sigmet.rb
│       │   │   ├── airmet.rb
│       │   │   ├── tfr.rb
│       │   │   └── forecast_discussion.rb
│       │   ├── analysis/
│       │   │   ├── flight_category.rb
│       │   │   └── crosswind_calculator.rb
│       │   └── formatters/
│       │       └── text.rb
│       ├── radar/
│       │   ├── cli.rb
│       │   ├── sources/
│       │   │   └── opensky.rb
│       │   ├── models/
│       │   │   └── state_vector.rb
│       │   ├── analysis/
│       │   │   └── proximity.rb
│       │   └── formatters/
│       │       └── text.rb
│       └── cli.rb              # top-level Thor with subcommands
├── spec/
│   ├── spec_helper.rb
│   ├── shared/
│   │   ├── http_spec.rb
│   │   ├── cache_spec.rb
│   │   └── geometry_spec.rb
│   ├── briefer/
│   │   ├── sources/
│   │   │   ├── metar_spec.rb
│   │   │   ├── taf_spec.rb
│   │   │   ├── pirep_spec.rb
│   │   │   └── winds_aloft_spec.rb
│   │   ├── models/
│   │   │   ├── metar_spec.rb
│   │   │   ├── taf_spec.rb
│   │   │   ├── taf_group_spec.rb
│   │   │   ├── pirep_spec.rb
│   │   │   ├── winds_aloft_spec.rb
│   │   │   ├── sigmet_spec.rb
│   │   │   ├── airmet_spec.rb
│   │   │   └── tfr_spec.rb
│   │   ├── analysis/
│   │   │   ├── flight_category_spec.rb
│   │   │   └── crosswind_calculator_spec.rb
│   │   └── formatters/
│   │       └── text_spec.rb
│   ├── radar/
│   │   ├── sources/
│   │   │   └── opensky_spec.rb
│   │   ├── models/
│   │   │   └── state_vector_spec.rb
│   │   └── analysis/
│   │       └── proximity_spec.rb
│   ├── fixtures/
│   │   ├── metars/
│   │   ├── tafs/
│   │   ├── pireps/
│   │   ├── winds_aloft/
│   │   ├── sigmets/
│   │   ├── airmets/
│   │   ├── tfrs/
│   │   ├── afd/
│   │   └── opensky/
│   ├── briefer_spec.rb         # integration tests for Skywatch.metar, etc.
│   └── cli_spec.rb
├── skywatch.gemspec
├── Gemfile
├── Rakefile
├── .rubocop.yml
├── .rspec
├── .gitignore
├── LICENSE.txt
└── CLAUDE.md
```

## Namespace Mapping

### Shared (extracted from briefer)

| Old | New |
|---|---|
| `Briefer::Error` | `Skywatch::Error` |
| `Briefer::ConnectionError` | `Skywatch::ConnectionError` |
| `Briefer::ApiError` | `Skywatch::ApiError` |
| `Briefer::ParseError` | `Skywatch::ParseError` |
| `Briefer::Client::Http` | `Skywatch::Shared::Http` |
| `Briefer::Client::Cache` | `Skywatch::Shared::Cache` |
| `Briefer::Geometry` | `Skywatch::Shared::Geometry` |
| `Briefer::Models::Position` | `Skywatch::Shared::Position` |

### Briefer domain

| Old | New |
|---|---|
| `Briefer::Models::Metar` | `Skywatch::Briefer::Models::Metar` |
| `Briefer::Models::Taf` | `Skywatch::Briefer::Models::Taf` |
| `Briefer::Models::TafGroup` | `Skywatch::Briefer::Models::TafGroup` |
| `Briefer::Models::Pirep` | `Skywatch::Briefer::Models::Pirep` |
| `Briefer::Models::WindsAloft` | `Skywatch::Briefer::Models::WindsAloft` |
| `Briefer::Models::Sigmet` | `Skywatch::Briefer::Models::Sigmet` |
| `Briefer::Models::Airmet` | `Skywatch::Briefer::Models::Airmet` |
| `Briefer::Models::Tfr` | `Skywatch::Briefer::Models::Tfr` |
| `Briefer::Sources::Metar` | `Skywatch::Briefer::Sources::Metar` |
| `Briefer::Sources::Taf` | `Skywatch::Briefer::Sources::Taf` |
| `Briefer::Sources::Pirep` | `Skywatch::Briefer::Sources::Pirep` |
| `Briefer::Sources::WindsAloft` | `Skywatch::Briefer::Sources::WindsAloft` |
| `Briefer::Analysis::FlightCategory` | `Skywatch::Briefer::Analysis::FlightCategory` |
| `Briefer::Analysis::CrosswindCalculator` | `Skywatch::Briefer::Analysis::CrosswindCalculator` |
| `Briefer::Formatters::Text` | `Skywatch::Briefer::Formatters::Text` |
| `Briefer::CLI` | `Skywatch::Briefer::CLI` |

### Radar domain

| Old | New |
|---|---|
| `Radar::Models::StateVector` | `Skywatch::Radar::Models::StateVector` |
| `Radar::Sources::Opensky` | `Skywatch::Radar::Sources::Opensky` |
| `Radar::Analysis::Proximity` | `Skywatch::Radar::Analysis::Proximity` |
| `Radar::Formatters::Text` | `Skywatch::Radar::Formatters::Text` |
| `Radar::CLI` | `Skywatch::Radar::CLI` |

## HTTP Client

The shared HTTP client takes a configurable `base_url`:

```ruby
module Skywatch
  module Shared
    class Http
      def initialize(base_url: "https://aviationweather.gov")
        @connection = build_connection(base_url)
      end
    end
  end
end
```

The default client (`Skywatch.client`) uses `aviationweather.gov`. Sources that need a different host create their own:

```ruby
# Briefer sources use default
Skywatch.client.get("/api/data/metar", ...)

# TFR source creates its own connection (tfr.faa.gov)
Skywatch::Shared::Http.new(base_url: "https://tfr.faa.gov")

# Radar sources create their own connection (opensky-network.org)
Skywatch::Shared::Http.new(base_url: "https://opensky-network.org")
```

The cache wraps any Http instance, same as before.

## CLI Structure

Top-level Thor CLI with subcommands per domain:

```ruby
module Skywatch
  class CLI < Thor
    desc "weather SUBCOMMAND", "Aviation weather briefings"
    subcommand "weather", Skywatch::Briefer::CLI

    desc "radar SUBCOMMAND", "Flight tracking"
    subcommand "radar", Skywatch::Radar::CLI

    desc "version", "Print version"
    def version
      puts "skywatch #{Skywatch::VERSION}"
    end
  end
end
```

Usage:
```bash
skywatch weather metar KCDW KTEB
skywatch weather taf KACK
skywatch weather pireps KCDW --radius 100
skywatch weather categories KCDW
skywatch weather crosswind KCDW --runway 280
skywatch radar track UAL1234
skywatch radar flights 37.62 -122.38 --radius 50
skywatch version
```

All commands support `--format json|text` (auto-detect TTY).

## Convenience API

```ruby
# Weather shortcuts
Skywatch.metar("KCDW")
Skywatch.taf("KACK")
Skywatch.pireps("KCDW", radius_nm: 100)
Skywatch.winds_aloft("KCDW")
Skywatch.crosswind("KCDW", runway_heading: 280)

# Radar shortcuts
Skywatch.flights(lat: 37.62, lon: -122.38, radius_nm: 50)
Skywatch.track("UAL1234")
Skywatch.aircraft("a12345")
```

## Gemspec

```ruby
Gem::Specification.new do |spec|
  spec.name = "skywatch"
  spec.summary = "Aviation situational awareness toolkit"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "rgeo", "~> 3.0"
  spec.add_dependency "rgeo-geojson", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"
end
```

One gemspec, all dependencies declared once.

## What This Refactor Does NOT Change

- All model logic, parsing, and field decomposition stay identical
- All source fetch logic stays identical
- All analysis logic stays identical
- All formatter output stays identical
- All test assertions stay identical (just re-namespaced)
- All fixture files reused as-is

This is a mechanical namespace + file-move refactor. No behavior changes.

## Scope

This spec covers only the refactor itself — moving existing code into the new structure. Continuing Phase 3 (new sources/CLIs) and building out radar happen after this refactor lands.
