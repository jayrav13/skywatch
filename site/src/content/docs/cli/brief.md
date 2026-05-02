---
title: brief
description: Compose an AIM 7-1-5 aviation weather brief for an airport, coordinate, or route.
---

`skywatch brief` is the core command. It assembles a full AIM 7-1-5 preflight brief from multiple real-time FAA and NWS data sources and outputs JSON.

## Synopsis

```sh
skywatch brief TARGET [--to DEST] [--departing-at TIME]
```

`TARGET` is one of:
- An ICAO airport identifier: `KCDW`
- A coordinate pair: `40.688,-74.174`

## Single-airport brief

```sh
skywatch brief KCDW
```

Fetches adverse conditions within 100 NM of KCDW, the current METAR, active TAF, winds aloft, and the Area Forecast Discussion for the responsible WFO.

## Coordinate brief

```sh
skywatch brief 40.688,-74.174
```

When no airport is within 25 NM of the supplied coordinates, the response includes a `note` field explaining the nearest airport used. If the nearest airport is more than 25 NM away, a warning appears in the note.

## Route brief

```sh
skywatch brief KCDW --to KACY
```

Adds an `enroute_forecast` slot to the response. Skywatch builds a corridor between the two airports (25 NM spacing waypoints), checks adverse conditions along the full route, and reports `distance_nm`, `bearing_deg`, and `waypoint_count` in the corridor metadata.

The destination forecast (`destination_forecast`) reflects the `to` airport's TAF, not the departure airport.

## Departure time

```sh
skywatch brief KCDW --departing-at "2026-05-02T13:00:00-04:00"
```

Accepts any format that Ruby's `Time.parse` understands: ISO8601, natural strings like `"tomorrow at 8am"` (with a timezone-aware shell), or epoch integers. When supplied:

- The `departing_at` field is included in the JSON response (ISO8601)
- TAF groups are filtered or annotated to the window around the ETD
- If the ETD falls outside the available TAF window, `destination_forecast.note` explains this

## Combined route + ETD

```sh
skywatch brief KCDW --to KACY --departing-at "2026-05-02T13:00:00-04:00"
```

Full brief: corridor adverse conditions + departure-airport current conditions + destination TAF around ETD + winds aloft.

## Output

All output is JSON. Pipe it to `jq` for filtering:

```sh
skywatch brief KCDW | jq '.adverse_conditions'
skywatch brief KCDW | jq '.vfr_not_recommended'
skywatch brief KCDW | jq '.winds_aloft.forecasts'
```

See [Brief response shape](/skywatch/reference/brief-shape/) for the complete JSON schema.

## Partial failures

If one data source is unavailable (network timeout, empty response from a WFO), the affected slot may include a `partial_failures` array. The brief is still returned — slots that did succeed contain real data. The agent surfaces partial failures explicitly rather than silently omitting sections.

## Flags

| Flag | Type | Description |
|---|---|---|
| `--to DEST` | string | Destination airport ID for a route brief |
| `--departing-at TIME` | string | ETD in any `Time.parse`-able format |
