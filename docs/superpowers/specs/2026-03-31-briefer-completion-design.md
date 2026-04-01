# Briefer Completion — Design Spec

## Goal

Close out all remaining briefer commands so the domain is feature-complete. After this work, `skywatch weather` covers the full range of aviation weather products a pilot or agent would need for situational awareness.

## Scope

### In scope

1. **SIGMET source + CLI** — fetch active SIGMETs (convective + non-convective)
2. **AIRMET source + CLI** — fetch active G-AIRMETs (SIERRA/TANGO/ZULU)
3. **AFD model + source + CLI** — fetch Area Forecast Discussion text from NWS
4. **Winds aloft bug fix** — API returns plain text, not JSON; source must parse text format
5. **Text formatters** for SIGMETs, AIRMETs, and AFD

### Out of scope

- **TFRs** — FAA's tfr.faa.gov is a client-side SPA with no stable public JSON API. The ArcGIS FeatureServer that previously served GeoJSON is no longer responding. Deferring until a reliable data source is identified. The Tfr model stays in the codebase for future use.

## API Endpoints

### SIGMETs — AWC `airsigmet`

- **URL**: `https://aviationweather.gov/api/data/airsigmet?format=json`
- **Returns**: JSON array of SIGMET objects
- **Fields match existing `Sigmet.from_awc`**: `seriesId`, `icaoId`, `airSigmetType`, `hazard`, `severity`, `rawAirSigmet`, `validTimeFrom`, `validTimeTo`, `altitudeHi1`, `altitudeLow1`, `movementDir`, `movementSpd`, `coords`
- **Cache TTL**: 15 minutes (900s) — SIGMETs update roughly every 2 hours but can be issued at any time
- **No parameters needed** — returns all active US SIGMETs

### AIRMETs — AWC `gairmet`

- **URL**: `https://aviationweather.gov/api/data/gairmet?format=json`
- **Returns**: JSON array of G-AIRMET objects
- **Fields match existing `Airmet.from_awc`**: `tag`, `product` (SIERRA/TANGO/ZULU), `hazard`, `due_to`, `severity`, `forecastHour`, `validTime`, `issueTime`, `expireTime`, `top`, `base`, `fzltop`, `fzlbase`, `coords`
- **Cache TTL**: 15 minutes (900s)
- **No parameters needed** — returns all active G-AIRMETs

### AFD — NWS API

- **URL**: `https://api.weather.gov/products/types/AFD/locations/{WFO}`
- **Step 1**: GET the product list, returns JSON with `@graph` array of product references
- **Step 2**: GET the first (most recent) product URL, returns JSON with `productText` field containing the full AFD text
- **Base URL**: `https://api.weather.gov` (different from AWC — needs its own HTTP client instance)
- **Cache TTL**: 60 minutes (3600s) — AFDs are issued ~4x/day
- **Parameter**: WFO identifier (e.g., `OKX` for NY, `SFO` for San Francisco)

### Winds Aloft — Bug Fix

- **Current bug**: Source calls `@client.get` which parses JSON, but the API returns plain text even with `format=json`
- **Fix**: Use `get_raw` to get the text response, then parse the fixed-width text format to extract station data
- **Alternative**: The API may support a different parameter combination that returns JSON. If so, use that. If not, parse the text.

## New Components

### `Skywatch::Briefer::Sources::Sigmet`

Thin source — fetches `/api/data/airsigmet`, maps each entry through `Models::Sigmet.from_awc`. No filtering needed; returns all active SIGMETs.

### `Skywatch::Briefer::Sources::Airmet`

Thin source — fetches `/api/data/gairmet`, maps each entry through `Models::Airmet.from_awc`. No filtering needed; returns all active G-AIRMETs.

### `Skywatch::Briefer::Models::Afd`

Simple model with:
- `wfo` — WFO identifier (e.g., "OKX")
- `product_name` — "Area Forecast Discussion"
- `issued_at` — issuance time
- `text` — full AFD text body
- `to_h` / `to_json` — standard serialization

### `Skywatch::Briefer::Sources::Afd`

Two-step fetch:
1. GET product list from NWS API for the given WFO
2. GET the most recent product to retrieve the full text
3. Return an `Afd` model instance

Needs its own HTTP client instance pointing at `https://api.weather.gov` (not the default AWC base URL).

### Text Formatters

Add to `Skywatch::Briefer::Formatters::Text`:

- `format_sigmet(sigmet)` — hazard, severity, altitude range, validity, raw text
- `format_airmet(airmet)` — product (S/T/Z), hazard, due_to, altitude, validity
- `format_afd(afd)` — WFO header + full text body (AFDs are already human-readable)

### CLI Commands

Add to `Skywatch::Briefer::CLI`:

- `skywatch weather sigmets` — list all active SIGMETs
- `skywatch weather airmets` — list all active AIRMETs, optionally filter by `--product sierra|tango|zulu`
- `skywatch weather afd WFO` — display most recent AFD for a Weather Forecast Office

### Convenience API

Add to `Skywatch` top-level:

- `Skywatch.sigmets` — returns array of Sigmet models
- `Skywatch.airmets` — returns array of Airmet models
- `Skywatch.afd(wfo)` — returns Afd model

### Winds Aloft Fix

Investigate whether the windtemp API supports a parameter that returns JSON. If not, switch to `get_raw` and parse the fixed-width text output. The text format has station IDs in the first column and altitude data in subsequent columns.

## Testing

- Fixture-based tests with WebMock, following existing patterns
- Save representative API responses as fixtures in `spec/fixtures/`
- New fixtures: `spec/fixtures/sigmets/active.json`, `spec/fixtures/airmets/gairmet.json`, `spec/fixtures/afd/okx.json`, `spec/fixtures/afd/okx_product.json`
- Winds aloft: update fixture and source tests to match the actual API response format

## Existing Model Compatibility

The Sigmet and Airmet models were built against the exact API formats confirmed above. No model changes should be needed — just sources to feed them data and formatters to display them.
