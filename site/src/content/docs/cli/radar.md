---
title: radar
description: Flight tracking via OpenSky Network ADS-B data — track by callsign or list flights near a coordinate.
---

The `skywatch radar` subcommand pulls live ADS-B state vectors from the OpenSky Network. All commands support `--format json|text`.

## Commands

| Command | Description | Example |
|---|---|---|
| `track` | Track a flight by callsign | `skywatch radar track UAL1234` |
| `flights` | List active flights near a coordinate | `skywatch radar flights 37.62 -122.38` |

## track

Look up a flight by its callsign (ICAO flight number):

```sh
skywatch radar track UAL1234
```

Returns one or more state vectors matching the callsign. Each vector includes:
- ICAO24 hex address
- Callsign
- Origin country
- Position (latitude, longitude, baro altitude, geo altitude)
- Ground speed and track
- Vertical rate
- Squawk code
- On-ground flag

If no aircraft is found with the given callsign:

```sh
# Text: "No aircraft found with callsign UAL1234"
# JSON: []
```

## flights

List all active flights within a radius of a coordinate (useful for pattern traffic, approach sequencing, or density awareness):

```sh
skywatch radar flights 37.62 -122.38
skywatch radar flights 37.62 -122.38 --radius 25
```

Default radius is 50 NM. The `--radius` flag takes a value in NM.

Arguments:
- `LAT` — latitude in decimal degrees
- `LON` — longitude in decimal degrees

### Data source

All radar data comes from the [OpenSky Network](https://opensky-network.org/) public REST API using ADS-B state vectors. State vector data is cached for 15 seconds to avoid hammering the endpoint on repeated calls.

Note: OpenSky anonymous API access may rate-limit requests. Results reflect ADS-B equipage — not all aircraft broadcast ADS-B.
