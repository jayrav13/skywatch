# Skywatch

Aviation situational awareness toolkit. Real-time aviation weather, flight tracking, and situational awareness from public FAA/NWS/ADS-B data. For end-user documentation, visit https://jayravaliya.com/skywatch.

## Requirements

- Ruby 3.2 or later (see `.ruby-version`)
- Bundler

## Setup

```bash
git clone git@github.com:jayrav13/skywatch.git
cd skywatch
bundle install
```

## Running Tests

All tests use WebMock fixtures and never hit live APIs.

```bash
bundle exec rspec        # full test suite
bundle exec rubocop      # lint
bundle exec rake         # run both
```

## Running the CLI Locally

```bash
bundle exec exe/skywatch --help
bundle exec exe/skywatch brief KCDW
```

Once installed via `gem install`, use `skywatch` directly without `bundle exec exe/`.

## Project Structure

- `lib/skywatch/` — source code root
- `lib/skywatch/shared/` — HTTP client, cache, geometry, errors, Position utilities
- `lib/skywatch/briefer/` — METAR, TAF, PIREP, winds, SIGMET, AIRMET, AFD sources and models
- `lib/skywatch/brief/` — Skywatch.brief composition layer (AIM 7-1-5 weather brief)
- `lib/skywatch/radar/` — flight tracking via OpenSky Network
- `lib/skywatch/mayday/` — emergency squawk detection and alerting
- `lib/skywatch/nimbus/` — convective outlooks, storm reports, smoke plumes, NEXRAD
- `lib/skywatch/agent/` — Claude Code subagent install command
- `agents/` — bundled subagent file (installed via `skywatch agent install`)
- `spec/` — RSpec tests (mirrors `lib/` layout)
- `spec/fixtures/` — WebMock JSON and XML fixtures
- `exe/` — CLI binary entry point

## Architecture

Skywatch is organized into domain modules (briefer, brief, radar, mayday, nimbus, agent) with shared infrastructure under `Skywatch::Shared`. Each domain exports sources (data fetching) and models (data representation).

For the full architecture overview, see `CLAUDE.md` in the repo root.

## Contributing

1. Run tests and lint before pushing:
   ```bash
   bundle exec rake
   ```
2. Push to a branch and open a PR against `main`.
3. Ensure CI is green.
4. Test against fixtures only — never commit changes that hit live APIs.

## License

MIT. See LICENSE.txt in the repo root.
