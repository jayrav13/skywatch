---
title: nimbus
description: SPC convective outlooks, storm reports, active convective warnings, and HMS satellite smoke plumes.
---

The `skywatch nimbus` subcommand pulls convective hazard data from the Storm Prediction Center (SPC) and NOAA Hazard Mapping System (HMS). All commands support `--format json|text`.

## Commands

| Command | Description | Example |
|---|---|---|
| `outlook` | SPC categorical convective outlook for day 1, 2, or 3 | `skywatch nimbus outlook 1 --at 40.688,-74.174` |
| `storms` | Recent SPC storm reports (tornado / wind / hail) | `skywatch nimbus storms --type tornado --near 40.688,-74.174 --radius 100` |
| `convection` | Active NWS convective warnings and watches at a point | `skywatch nimbus convection 40.688 -74.174` |
| `smoke` | HMS satellite-detected smoke plumes covering a point | `skywatch nimbus smoke 40.688 -74.174` |

## outlook

Fetch the SPC categorical outlook (Marginal / Slight / Enhanced / Moderate / High) for day 1, 2, or 3:

```sh
# All outlook polygons for day 1
skywatch nimbus outlook 1

# Covering outlook for a specific point (highest risk level)
skywatch nimbus outlook 1 --at 40.688,-74.174

# Day 2 and day 3 outlooks
skywatch nimbus outlook 2
skywatch nimbus outlook 3
```

`--at LAT,LON` returns only the polygon covering the point, choosing the highest risk level when multiple polygons overlap.

## storms

Fetch recent SPC storm reports:

```sh
# All storm reports for today
skywatch nimbus storms

# Filter by type
skywatch nimbus storms --type tornado
skywatch nimbus storms --type wind
skywatch nimbus storms --type hail

# Filter by proximity
skywatch nimbus storms --near 40.688,-74.174 --radius 100

# Specific date and type
skywatch nimbus storms --date 20260430 --type tornado
```

`--date` format is `YYYYMMDD`. Default is today. `--radius` defaults to 100 NM when `--near` is specified.

## convection

Check active NWS radar-driven warnings and watches at a coordinate:

```sh
skywatch nimbus convection 40.688 -74.174
```

Default events checked: Tornado Warning, Severe Thunderstorm Warning, Flash Flood Warning, Tornado Watch, Severe Thunderstorm Watch.

To check specific event types:

```sh
skywatch nimbus convection 40.688 -74.174 --events "Tornado Warning,Severe Thunderstorm Warning"
```

## smoke

Check for HMS satellite-detected smoke plumes at a coordinate:

```sh
skywatch nimbus smoke 40.688 -74.174
```

Reports any smoke plumes detected by NOAA's Hazard Mapping System that cover the given point, including density classification (light / medium / heavy) where available.
