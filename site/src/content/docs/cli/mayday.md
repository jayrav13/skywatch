---
title: mayday
description: Detect aircraft squawking emergency transponder codes (7500, 7600, 7700) near a coordinate.
---

The `skywatch mayday` subcommand queries live ADS-B state vectors for aircraft broadcasting emergency squawk codes.

## Commands

| Command | Description | Example |
|---|---|---|
| `near` | Aircraft squawking 7500/7600/7700 within a radius | `skywatch mayday near 40.875 -74.282 --radius 100` |

## near

Find aircraft squawking an emergency code near a coordinate:

```sh
skywatch mayday near 40.875 -74.282 --radius 100
```

Arguments:
- `LAT` — latitude in decimal degrees
- `LON` — longitude in decimal degrees
- `--radius N` — search radius in NM (default: 100)

### Squawk codes

| Code | Meaning |
|---|---|
| 7500 | Hijack |
| 7600 | Loss of communications |
| 7700 | General emergency |

### Output

Returns a list of aircraft state vectors matching any of the three emergency codes. Each entry includes callsign, ICAO24 hex, position, altitude, ground speed, and squawk code.

```sh
# JSON output
skywatch mayday near 40.875 -74.282 --radius 100 --format json

# Text output
skywatch mayday near 40.875 -74.282 --radius 100 --format text
```

When no emergencies are detected, the command outputs `No emergencies within Nnm of LAT, LON` (text) or `[]` (JSON).
