# Radar

A Ruby gem for real-time flight tracking via the OpenSky Network API. Part of the skywatch aviation awareness system.

## Project Overview

- **Type**: Ruby gem (single gem, internal modules)
- **CLI framework**: Thor
- **HTTP client**: Faraday (with faraday-retry)
- **Testing**: RSpec with WebMock fixtures
- **Style**: RuboCop

## Commands

```bash
bundle exec rspec              # Run tests
bundle exec rubocop            # Lint
bundle exec rake               # Default task
bin/radar                      # CLI entry point
```

## Architecture

```
Radar (top-level convenience methods)
  -> CLI (Thor)
  -> Data Layer (Sources module)
  -> HTTP Client (Faraday wrapper with caching)
```

Key modules: `Sources::Opensky` (data fetching), `Models::StateVector` (aircraft state), `Analysis::Proximity` (bounding box, distance), `Formatters::Text` (human-readable output).

## Conventions

- Data source is OpenSky Network (free, no key)
- Cache TTL: 15 seconds for state vectors
- Custom User-Agent header on all requests
- Test against saved fixtures, never live APIs in tests
- All CLI commands support --format json|text (auto-detect TTY)
