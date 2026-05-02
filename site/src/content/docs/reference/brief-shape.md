---
title: Brief response shape
description: Complete JSON schema for the skywatch brief command output, including all AIM 7-1-5 slots.
---

`skywatch brief` outputs a single JSON object. Every field maps to an AIM section 7-1-5 slot.

## Top-level fields

| Field | Type | Description |
|---|---|---|
| `airport` | string \| null | ICAO identifier of the departure (or single) airport |
| `coordinates` | `[float, float]` | `[lat, lon]` of the airport or supplied coordinate |
| `wfo` | string | NWS Weather Forecast Office code responsible for the location |
| `fetched_at` | ISO8601 string | UTC timestamp when the brief was assembled |
| `departing_at` | ISO8601 string \| null | Supplied ETD, or null if not provided |
| `aim_section` | string | Always `"7-1-5"` |
| `note` | string \| null | Present for coordinate briefs; explains the nearest airport used |
| `destination` | string \| null | Present for route briefs; the `--to` airport ICAO ID |
| `adverse_conditions` | object | AIM 7-1-5 slot 1 |
| `vfr_not_recommended` | object | AIM 7-1-5 slot 2 |
| `synopsis` | object | AIM 7-1-5 slot 3 (currently unavailable) |
| `current_conditions` | object | AIM 7-1-5 slot 4 |
| `enroute_forecast` | object | AIM 7-1-5 slot 5 (only populated for route briefs) |
| `destination_forecast` | object | AIM 7-1-5 slot 6 |
| `winds_aloft` | object | AIM 7-1-5 slot 7 |
| `notams` | object | AIM 7-1-5 slot 8 (currently unavailable) |
| `atc_delays` | object | AIM 7-1-5 slot 9 (currently unavailable) |
| `afd` | object | AIM 7-1-5 slot 10 — Area Forecast Discussion |

## Slot details

### adverse_conditions

```json
{
  "items": [...],
  "partial_failures": []
}
```

`items` is an array of hazard objects. Each item has a `kind` field (`sigmet`, `airmet`, `pirep`, `convective_alert`, `storm_report`, `smoke`) and source-specific fields.

### vfr_not_recommended

```json
{
  "vfr_not_recommended": false,
  "reason": null
}
```

`vfr_not_recommended` is `true` when the current METAR reports IFR or LIFR conditions. `reason` is a plain-English string when true (e.g., `"ceiling 200 ft, vis 0.5 SM, IFR conditions reported"`).

### synopsis

Currently unavailable:

```json
{
  "available": false,
  "reason": "no synopsis source in skywatch — see afd slot"
}
```

### current_conditions

```json
{
  "metar": { ... },
  "pireps": [ ... ]
}
```

`metar` is a decoded METAR object with fields: `station_id`, `raw`, `time`, `wind_direction_deg`, `wind_speed_kt`, `wind_gust_kt`, `visibility_sm`, `sky_conditions`, `temperature_c`, `dewpoint_c`, `altimeter_inhg`, `flight_category`.

`pireps` is an array of informational PIREPs near the airport (not already in adverse_conditions).

### enroute_forecast

For single-airport briefs:

```json
{
  "available": false,
  "reason": "single-point brief; route input deferred from MVP"
}
```

For route briefs:

```json
{
  "available": true,
  "corridor": {
    "from": "KCDW",
    "to": "KACY",
    "distance_nm": 52.3,
    "bearing_deg": 132,
    "waypoint_count": 4
  },
  "items": [...],
  "partial_failures": []
}
```

### destination_forecast

```json
{
  "taf": { ... },
  "note": null
}
```

`taf` contains the decoded TAF with `station_id`, `raw`, `issue_time`, and a `groups` array. Each group has `from_time`, `to_time`, `wind_direction_deg`, `wind_speed_kt`, `wind_gust_kt`, `visibility_sm`, `sky_conditions`, and `weather`.

`note` is non-null when the ETD falls outside the available TAF window.

### winds_aloft

```json
{
  "station_id": "JFK",
  "forecasts": [
    {
      "altitude_ft": 3000,
      "direction_deg": 270,
      "speed_kt": 15,
      "temperature_c": 8
    }
  ]
}
```

### notams

Currently unavailable:

```json
{
  "available": false,
  "reason": "NOTAMs not in skywatch yet — Sectional domain not yet built"
}
```

### atc_delays

Currently unavailable:

```json
{
  "available": false,
  "reason": "ATC delays not in skywatch yet — no source"
}
```

### afd

```json
{
  "wfo": "OKX",
  "issue_time": "2026-05-01T12:35:00Z",
  "text": "..."
}
```

`text` is the full raw AFD text from the NWS. The SYNOPSIS and SHORT TERM sections are most relevant for preflight planning.

## Trimmed example

```json
{
  "airport": "KCDW",
  "coordinates": [40.875, -74.282],
  "wfo": "OKX",
  "fetched_at": "2026-05-01T18:00:00Z",
  "departing_at": null,
  "aim_section": "7-1-5",
  "note": null,
  "adverse_conditions": {
    "items": [],
    "partial_failures": []
  },
  "vfr_not_recommended": {
    "vfr_not_recommended": false,
    "reason": null
  },
  "synopsis": {
    "available": false,
    "reason": "no synopsis source in skywatch — see afd slot"
  },
  "current_conditions": {
    "metar": {
      "station_id": "KCDW",
      "raw": "KCDW 011753Z 27012KT 10SM FEW060 22/10 A2992",
      "wind_direction_deg": 270,
      "wind_speed_kt": 12,
      "wind_gust_kt": null,
      "visibility_sm": 10.0,
      "flight_category": "VFR"
    },
    "pireps": []
  },
  "enroute_forecast": {
    "available": false,
    "reason": "single-point brief; route input deferred from MVP"
  },
  "destination_forecast": {
    "taf": { "station_id": "KCDW", "groups": [...] },
    "note": null
  },
  "winds_aloft": {
    "station_id": "JFK",
    "forecasts": [
      { "altitude_ft": 3000, "direction_deg": 270, "speed_kt": 14, "temperature_c": 10 }
    ]
  },
  "notams": {
    "available": false,
    "reason": "NOTAMs not in skywatch yet — Sectional domain not yet built"
  },
  "atc_delays": {
    "available": false,
    "reason": "ATC delays not in skywatch yet — no source"
  },
  "afd": {
    "wfo": "OKX",
    "issue_time": "2026-05-01T12:35:00Z",
    "text": "..."
  }
}
```
