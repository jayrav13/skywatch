---
title: weather
description: Aviation weather data commands — METARs, TAFs, PIREPs, winds aloft, SIGMETs, AIRMETs, Area Forecast Discussions, flight categories, and crosswind components.
---

The `skywatch weather` subcommand exposes individual data sources. All commands support `--format json|text`. When output is a TTY the default is `text`; when piped the default is `json`.

## Commands

| Command | Description | Example |
|---|---|---|
| `metar` | Current METAR(s) for one or more stations | `skywatch weather metar KCDW` |
| `taf` | Current TAF(s) for one or more stations | `skywatch weather taf KACK` |
| `pireps` | Recent PIREPs near a station | `skywatch weather pireps KCDW --radius 100` |
| `winds` | Winds aloft forecast for a station | `skywatch weather winds JFK` |
| `sigmets` | All active SIGMETs | `skywatch weather sigmets` |
| `airmets` | All active AIRMETs | `skywatch weather airmets --product sierra` |
| `afd` | Area Forecast Discussion for a WFO | `skywatch weather afd OKX` |
| `categories` | Flight categories for one or more stations | `skywatch weather categories KCDW KEWR` |
| `crosswind` | Crosswind component for a runway | `skywatch weather crosswind KCDW --runway 220` |

## metar

Fetch the current METAR for one or more stations:

```sh
skywatch weather metar KCDW
skywatch weather metar KCDW KEWR KJFK
```

Add `--raw` to print only the raw METAR string without decoding:

```sh
skywatch weather metar KCDW --raw
```

## taf

Fetch the current TAF:

```sh
skywatch weather taf KACK
skywatch weather taf KCDW KACY
```

## pireps

Fetch recent PIREPs within a radius of a station:

```sh
skywatch weather pireps KCDW --radius 100
```

Default radius is 100 NM.

## winds

Fetch winds aloft forecast:

```sh
skywatch weather winds JFK
skywatch weather winds JFK --altitude 9000
```

`--altitude` filters to a specific altitude in feet.

## sigmets

List all currently active SIGMETs (no arguments required):

```sh
skywatch weather sigmets
```

## airmets

List all active AIRMETs. Optionally filter by product:

```sh
skywatch weather airmets
skywatch weather airmets --product sierra
skywatch weather airmets --product tango
skywatch weather airmets --product zulu
```

Products: `sierra` (IFR/mountain obscuration), `tango` (turbulence), `zulu` (icing/freezing level).

## afd

Fetch the Area Forecast Discussion for a Weather Forecast Office (WFO):

```sh
skywatch weather afd OKX
```

WFO codes follow standard NWS three-letter identifiers (e.g., `OKX` for New York, `BOS` for Boston, `PHI` for Philadelphia).

## categories

Report flight categories (VFR/MVFR/IFR/LIFR) for one or more stations:

```sh
skywatch weather categories KCDW KEWR
```

## crosswind

Calculate the crosswind component given the current METAR wind and a runway heading:

```sh
skywatch weather crosswind KCDW --runway 220
```

`--runway` is required and takes a runway heading in degrees magnetic (e.g., runway 22 = 220 degrees).
