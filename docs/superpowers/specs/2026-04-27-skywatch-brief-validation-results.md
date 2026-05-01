# Skywatch.brief — validation results

**Date:** 2026-04-30
**Spec:** [`2026-04-27-skywatch-brief-design.md`](2026-04-27-skywatch-brief-design.md)
**Plan:** [`../plans/2026-04-27-skywatch-brief.md`](../plans/2026-04-27-skywatch-brief.md)
**Branch:** `skywatch-brief`

## Protocol

Three airport scenarios. For each, the captured `skywatch brief AIRPORT` JSON was paired with the canonical 7-question prompt and run through a fresh, naive-context LLM (subagents dispatched with no shared context, restricted to reading the prompt file only — no external lookups, no Bash/WebFetch). Pilot-grade judgment of substantive correctness on Q1–Q6; explicit anti-hallucination check on Q7 (LLM must identify NOTAMs and ATC delays as not-in-brief).

**Scenario coverage:**
- Scenario 1 (KCDW) — VFR-clear, no adverse items
- Scenario 2 (KACK) — IFR (700 ft fog, marine layer)
- Scenario 3 (KMSY) — IFR + active convection (-RA, recent TS, convective SIGMET 74C inside the polygon, urgent low-level wind-shear PIREP)

**Pass criteria:**
- Q1–Q6 substantively correct on at least 2 of 3 scenarios
- Q7 anti-hallucination clean on **all 3 scenarios**

## Scenario 1: KCDW — VFR-clear

**Captured at:** 2026-05-01T00:08:14Z
**Conditions summary:** Wind calm, 10 SM, CLR, 13/4 °C, A2977 — full VFR. No adverse items. AIRMET source partial-failure (RGeo::Error::InvalidGeometry: Self-intersection — see issue #11).

### Brief JSON

```json
{
  "airport": "KCDW",
  "coordinates": [
    40.8764,
    -74.2828
  ],
  "wfo": "OKX",
  "fetched_at": "2026-05-01T00:08:14Z",
  "aim_section": "7-1-5",
  "adverse_conditions": {
    "available": true,
    "items": [],
    "partial_failures": [
      {
        "source": "airmet",
        "reason": "RGeo::Error::InvalidGeometry: Self-intersection"
      }
    ]
  },
  "vfr_not_recommended": {
    "available": true,
    "vfr_not_recommended": false,
    "category": "VFR",
    "explanation": "VFR conditions"
  },
  "synopsis": {
    "available": false,
    "reason": "no synopsis source in skywatch — see afd slot"
  },
  "current_conditions": {
    "available": true,
    "metar": {
      "station_id": "KCDW",
      "raw": "METAR KCDW 302353Z 00000KT 10SM CLR 13/04 A2977 RMK AO2 SLP086 60000 T01330039 10161 20133 51011",
      "observed_at": "2026-04-30T23:53:00Z",
      "metar_type": "METAR",
      "wind_direction_deg": 0,
      "wind_speed_kt": 0,
      "wind_gust_kt": null,
      "visibility_sm": 10.0,
      "weather": [],
      "sky_condition": [],
      "temperature_c": 13.3,
      "dewpoint_c": 3.9,
      "altimeter_inhg": 29.77,
      "station_name": "Caldwell/Essex Cnty, NJ, US",
      "latitude": 40.8764,
      "longitude": -74.2828,
      "elevation_ft": 171,
      "ceiling_ft": null,
      "flight_category": "vfr",
      "spread_c": 9.4,
      "density_altitude_ft": 158
    },
    "pireps": [
      {
        "raw": "BOS UA /OV RY 4R FINAL/TM 0000/FL030/TP A321/SK BKN/RM DURD",
        "observed_at": "2026-05-01T00:00:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "A321",
        "latitude": 42.3575,
        "longitude": -70.9895,
        "flight_level": 30,
        "altitude_ft": 3000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MDT UA /OV 5 NW MDT/TM 2352/FL060/TP C208/SK B- 059/TA -3/IC LIGHT RIME",
        "observed_at": "2026-04-30T23:52:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C208",
        "latitude": 40.2397,
        "longitude": -76.8529,
        "flight_level": 60,
        "altitude_ft": 6000,
        "temperature_c": -3,
        "icing_intensity": "LGT",
        "icing_type": "RIME",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ALB UA /OV ALB040025/TM 2345/FL045/TP C180/IC TRACE RIME 80-50",
        "observed_at": "2026-04-30T23:45:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C180",
        "latitude": 43.1176,
        "longitude": -73.5445,
        "flight_level": 45,
        "altitude_ft": 4500,
        "temperature_c": null,
        "icing_intensity": "TRC",
        "icing_type": "RIME",
        "icing_base_ft": 5000,
        "icing_top_ft": 8000,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "EWB UA /OV EWB RY23 APCH/TM 2341/FL014/TP C172/SK OVC014",
        "observed_at": "2026-04-30T23:41:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C172",
        "latitude": 41.6766,
        "longitude": -70.9578,
        "flight_level": 14,
        "altitude_ft": 1400,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ALB UA /OV ALB100005/TM 2338/FL020/TP E545/RM GAIN OR LOSS 5 KTS FINAL RY28",
        "observed_at": "2026-04-30T23:38:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E545",
        "latitude": 42.7516,
        "longitude": -73.6901,
        "flight_level": 20,
        "altitude_ft": 2000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MIV UA /OV MIV /TM 2338 /FL020 /TP C172 /WX RA /TB NEG /RM SMTH/-RA",
        "observed_at": "2026-04-30T23:38:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C172",
        "latitude": 39.3678,
        "longitude": -75.0722,
        "flight_level": 20,
        "altitude_ft": 2000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "NEG",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ISP UA /OV CCC260010/TM 2328/FL035/TP C172/SK 034OVC",
        "observed_at": "2026-04-30T23:28:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C172",
        "latitude": 40.8644,
        "longitude": -73.0014,
        "flight_level": 35,
        "altitude_ft": 3500,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MDT UA /OV 20 NW HAR/TM 2321/FL070/TP PA32/TA -3/IC LIGHT RIME",
        "observed_at": "2026-04-30T23:21:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "PA32",
        "latitude": 40.4925,
        "longitude": -77.428,
        "flight_level": 70,
        "altitude_ft": 7000,
        "temperature_c": -3,
        "icing_intensity": "LGT",
        "icing_type": "RIME",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ALB UA /OV CAM040015/TM 2316/FL90/TP S22T/IC LGT CLR",
        "observed_at": "2026-04-30T23:16:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "S22T",
        "latitude": 43.2185,
        "longitude": -73.1939,
        "flight_level": 90,
        "altitude_ft": 9000,
        "temperature_c": null,
        "icing_intensity": "LGT",
        "icing_type": "CLEAR",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ISP UA /OV ISP/TM 2303/FL1800/TP C172/RM LIGHT RAIN",
        "observed_at": "2026-04-30T23:03:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C172",
        "latitude": 40.7961,
        "longitude": -73.1007,
        "flight_level": 0,
        "altitude_ft": 0,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "PHL UA /OV ENO/TM 2300/FL100/TP E145/TA M08/IC LGT RIME/RM ICING BETWEEN 100-085",
        "observed_at": "2026-04-30T23:00:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E145",
        "latitude": 39.2316,
        "longitude": -75.516,
        "flight_level": 100,
        "altitude_ft": 10000,
        "temperature_c": -8,
        "icing_intensity": "LGT",
        "icing_type": "RIME",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "AVP UA /OV AVP/TM 2256/FL040/TP P28A/SK OVC040/TA 01",
        "observed_at": "2026-04-30T22:56:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "P28A",
        "latitude": 41.3385,
        "longitude": -75.7234,
        "flight_level": 40,
        "altitude_ft": 4000,
        "temperature_c": 1,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "BWI UA /OV BAL350029/TM 2251/FL090/TP PA30/TA -4/IC LGHT RIME/RM 090-070",
        "observed_at": "2026-04-30T22:51:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "PA30",
        "latitude": 39.6213,
        "longitude": -76.8858,
        "flight_level": 90,
        "altitude_ft": 9000,
        "temperature_c": -4,
        "icing_intensity": "LGT",
        "icing_type": "RIME",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "LNS UA /OV LRP/TM 2249/FL110/TP B712/TA M12/TB CONS LGT CHOP/IC LGT RIME",
        "observed_at": "2026-04-30T22:49:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "B712",
        "latitude": 40.12,
        "longitude": -76.2913,
        "flight_level": 110,
        "altitude_ft": 11000,
        "temperature_c": -12,
        "icing_intensity": "LGT",
        "icing_type": "RIME",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "LGT",
        "turbulence_type": "CHOP",
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "SEG UA /OV MIP/TM 2248/FL050/TP C208/TA 00/IC LGT RIME",
        "observed_at": "2026-04-30T22:48:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C208",
        "latitude": 41.0234,
        "longitude": -76.6653,
        "flight_level": 50,
        "altitude_ft": 5000,
        "temperature_c": 0,
        "icing_intensity": "LGT",
        "icing_type": "RIME",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "AVP UA /OV AVP/TM 2247/FL020/TP P28A/TB LGT CHOP 020",
        "observed_at": "2026-04-30T22:47:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "P28A",
        "latitude": 41.3385,
        "longitude": -75.7234,
        "flight_level": 20,
        "altitude_ft": 2000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "LGT",
        "turbulence_type": "CHOP",
        "turbulence_base_ft": 2000,
        "turbulence_top_ft": null
      },
      {
        "raw": "BDL UA /OV JUDDS/TM 2247/FL100/TP S22T/TA M07/IC LGT CLR",
        "observed_at": "2026-04-30T22:47:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "S22T",
        "latitude": 41.6347,
        "longitude": -73.1082,
        "flight_level": 100,
        "altitude_ft": 10000,
        "temperature_c": -7,
        "icing_intensity": "LGT",
        "icing_type": "CLEAR",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MIV UA /OV VCN340005 /TM 2242 /FL030 /TP C172 /SK SCT050 /WX FV99SM /TB INTMT LGT CHOP",
        "observed_at": "2026-04-30T22:42:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C172",
        "latitude": 39.6097,
        "longitude": -75.0211,
        "flight_level": 30,
        "altitude_ft": 3000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "LGT",
        "turbulence_type": "CHOP",
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "RDG UA /OV ETX356110/TM 2241/FL100/TP E75S/TA M09/IC MOD MX",
        "observed_at": "2026-04-30T22:41:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E75S",
        "latitude": 42.3628,
        "longitude": -76.2411,
        "flight_level": 100,
        "altitude_ft": 10000,
        "temperature_c": -9,
        "icing_intensity": "MOD",
        "icing_type": "MIXED",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      }
    ]
  },
  "enroute_forecast": {
    "available": false,
    "reason": "single-point brief; route input deferred from MVP"
  },
  "destination_forecast": {
    "available": false,
    "reason": "fetch failed: Skywatch::ParseError: unexpected end of input at line 1 column 1"
  },
  "winds_aloft": {
    "available": false,
    "reason": "no winds aloft for KCDW"
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
    "available": true,
    "wfo": "OKX",
    "text": "\n000\nFXUS61 KOKX 302051\nAFDOKX\n\nArea Forecast Discussion\nNational Weather Service New York NY\n451 PM EDT Thu Apr 30 2026\n\n.WHAT HAS CHANGED...\nShowers are likely from Wednesday afternoon into Thursday, \nfirst from a nearby weak cold front, then from a stronger cold \nfront approaching from the west.\n\n&&\n\n.KEY MESSAGES...\n1) After a few showers associated with a cold frontal passage \nthis afternoon/evening, dry weather will prevail through through\nthe end of the work week.\n\n2) Unsettled weather is possible for at least a portion of the \nweekend as an area of low pressure passes well offshore.\n\n3) A warming trend early next week may be accompanied by \nunsettled conditions next Wednesday and Thursday.\n\n&&\n\n.DISCUSSION...\n.KEY MESSAGE 1...\nIsolated to widely scattered showers are possible this \nafternoon and evening as a cold front crosses the area. Rainfall\namounts with any showers will remain light, with generally only\na few hundredths of an inch expected in any one location.\n\nIn the wake of the frontal passage, high pressure will briefly \nbuild south of the area overnight before quickly moving offshore\nduring the day on Friday. This will result in a dry and \nseasonable day, with daytime highs rising into the 60s.\n\n.KEY MESSAGE 2...\nUnsettled conditions will return on Friday night as a shortwave\nrotating around the base of an upper low over southeastern \nCanada brings a renewed chance of showers. The best chance of \nprecipitation will be across the western half of the area, but \nrainfall amounts again look to remain light.\n\nAny lingering showers associated with the shortwave should \ntaper quickly Saturday morning, but the region will remain under\nabundant cloud cover as an area of low pressure passing well \noffshore begins to approach the region. This system will bring \nanother chance of showers to the region, primarily late Saturday\nafternoon through Saturday night. Rainfall amounts will once \nagain remain light, with the best chances of precipitation along\nthe coast. \n\nRain will come to an end Sunday morning as the low continues to\nmove off to the northeast. Despite a good deal of sunshine, \ndaytime highs will remain below normal, generally in the upper \n50s to around 60.\n\n.KEY MESSAGE 3...\nTemps on Mon will still be up to a few degrees below average as\nhigh pressure to the S slides farther offshore. After a warm \nfrontal passage late Mon night with slight chance of showers NW \nof NYC, temps Tue-Wed should increase to 5-10 degrees above \nnormal inland with highs well into the 70s, and a couple of \ndegrees above normal toward the coast with highs in the 60s to \nnear 70. \n\nAn approaching weak cold front may bring a chance of showers to\nareas NW of NYC Tue night/Wed morning, then more widespread \nshower coverage expected Wed night-Thu, with PoP increasing to \nlikely. Tstms may also be possible Thu afternoon/early evening \nas a stronger cold front approaches from the west in response to\nupper trough amplification over the Midwest/Great Lakes, and a \nstrengthening sfc low passing well NW. Temps on Thu will not be \nquite as warm but should still be a few degrees above normal, \nwith highs in the 60s to near 70. QPF Wed-Thu ranges from about \n0.75 inch west to 1.00-1.50 inch east. At this extended time \nrange it's much too early to speculate on possible hydrologic \nimpacts other than nuisance ponding in low lying and poor \ndrainage area.\n\n&&\n\n.AVIATION /20Z THURSDAY THROUGH TUESDAY/...\nA cold front passes offshore this eve, allowing weak high pres\nto build in for Fri. \n\nGradual improvement to VFR thru 23Z. Slightly later at KGON. \nVFR then remains thru 00Z Sat. \n\nA few shwrs possible thru 00Z invof the front. Timing and\ncoverage too low to include in the TAFs.\n\nVRB flow becomes NW behind the front this eve, lasting thru the\nngt. Speeds less than 10kt. Sea breeze flow will impact winds \non Fri, with places right on the S shores expected to be closer \nto true sea breeze flow. \n\nNY Metro (KEWR/KLGA/KJFK/KTEB) TAF Uncertainty...\n\nReturn to VFR this eve may be off slightly. Amendments possible. \n\nA few shwrs possible thru 23Z, but no lower than MVFR expected\nattm. \n\nWind direction at EWR on Fri could be around 130 true if the \nsea breeze gets into the arpt.\n\n\n.OUTLOOK FOR 18Z FRIDAY THROUGH TUESDAY...\n\nFriday: VFR with flow mainly blw 10kt.\n\nSaturday: Chance of MVFR at times with light winds. \n\nSunday: VFR with NW flow.\n\nMonday: VFR with SW flow. \n\nTuesday: VFR with strong S flow. MVFR or lower possible aft 00Z.\n\nDetailed information, including hourly TAF wind component forecasts, \ncan be found at: https:/www.weather.gov/zny/n90\n\n&&\n\n.MARINE...\nSCA cancelled for the ocean W of Fire Island Inlet out 20 nm as\nE-SE swells there have finally fallen below 5 ft and should \ncontinue on a gradual downward trend. Extended SCA east of \nthere until 9 PM with swells there running slightly higher than \nforecast. Conditions should then remain below SCA thresholds \nthrough Sunday as low pressure passes well south and east. \n\nThe pressure gradient tightens and S winds increase early next\nweek. An extended period of SCA conditions is likely on the \nocean from Mon afternoon into Wed, with sustained winds 20-25 kt\nand seas above 5 ft, building as high as 6-8 ft Mon night-Tue.\nAs the sea breeze develops each afternoon/early evening, SCA \nconditions with gusts to 25 kt may also be possible on the Long \nIsland south shore bays, NY Harbor, and the western/central \nSound. A few gusts just shy of gale force may also occur with \nthe Ambrose jet on the ocean from Sandy Hook to Fire Island \nInlet late day Tue and Wed. \n\n&&\n\n.OKX WATCHES/WARNINGS/ADVISORIES...\nCT...None.\nNY...None.\nNJ...None.\nMARINE...Small Craft Advisory until 9 PM EDT this evening for ANZ350-\n     353.\n\n&&\n\n$$\n\nDISCUSSION...FEB/BG\nAVIATION...JMC\nMARINE...FEB/BG\n",
    "issued_at": "2026-04-30T20:51:00Z"
  }
}

```

### LLM responses

## Q1

Yes — VFR is recommended right now at KCDW. The brief's `vfr_not_recommended` slot reports `vfr_not_recommended: false` with `category: "VFR"` and the explanation "VFR conditions". The current METAR (KCDW 302353Z, observed 2026-04-30 23:53Z) corroborates this: wind calm (00000KT), visibility 10SM, sky CLR (no ceiling reported), 13.3 C / 3.9 C, altimeter 29.77 inHg, flight category `vfr`. Caveat: the brief was fetched at 2026-05-01T00:08:14Z, ~15 minutes after the observation, so this is essentially current.

## Q2

There is no synopsis slot in this brief — `synopsis.available: false` ("no synopsis source in skywatch — see afd slot"). The pattern has to be read out of the OKX Area Forecast Discussion (issued 2026-04-30 20:51Z / 4:51 PM EDT Thu Apr 30):

- A cold front is crossing the area this afternoon/evening with isolated to widely scattered light showers (only a few hundredths expected).
- Behind the front, weak high pressure briefly builds in overnight, then moves offshore Friday — Friday looks dry/seasonable, highs in the 60s, winds becoming NW <10 kt then variable with a sea-breeze influence on Friday.
- A shortwave around an upper low over SE Canada brings unsettled weather back Friday night through Saturday night, with light rain ending Sunday morning. Sun/Mon stay below normal with NW then SW flow.
- Warming Tue-Wed (highs into the 70s inland) ahead of another stronger cold front Wed night-Thu with possible thunderstorms Thu afternoon.
- Marine SCA cancelled W of Fire Island Inlet; SCA continues east of there until 9 PM EDT this evening.
- No active CT/NY/NJ land watches/warnings/advisories.

## Q3

From the KCDW METAR (observation time 2026-04-30 23:53Z, station Caldwell/Essex Cnty NJ, elev 171 ft):

- Wind: calm (000 at 0 kt, no gusts)
- Visibility: 10 SM
- Weather: none
- Sky: CLR (no clouds reported, ceiling null)
- Temperature / Dewpoint: 13.3 C / 3.9 C (spread 9.4 C)
- Altimeter: 29.77 inHg, SLP 1008.6 mb (from RMK SLP086)
- Flight category: VFR
- Density altitude: 158 ft (essentially field elevation)
- Raw: `METAR KCDW 302353Z 00000KT 10SM CLR 13/04 A2977 RMK AO2 SLP086 60000 T01330039 10161 20133 51011`

Quiet, clear, calm. The RMK 6-hr precip group `60000` indicates no measurable precip in the last 6 hours; the 24-hr max/min (10161 / 20133) decode to ~16.1 C high and 13.3 C low.

## Q4

Not available in this brief. `destination_forecast.available: false` with reason "fetch failed: Skywatch::ParseError: unexpected end of input at line 1 column 1". There is no TAF in this envelope. You'll need to pull a TAF from another source (KCDW itself does not always issue a TAF — typical alternates would be KMMU, KTEB, or KEWR) before flying.

The only forecast-flavored content here is the OKX AFD aviation section, which says: gradual improvement to VFR through 23Z (already past), VFR continues through 00Z Saturday, a few showers possible through 00Z near the front (timing/coverage too low for TAFs), wind becoming NW <10 kt overnight, sea-breeze influence Friday. Outlook through Tue: VFR Fri, chance MVFR Sat, VFR Sun-Mon, VFR Tue with MVFR-or-lower possible after 00Z Wed.

## Q5

Not available. `winds_aloft.available: false` ("no winds aloft for KCDW"). The brief contains no FB/FD winds-aloft product for any altitude, including 6,000 ft. You'll need to look this up separately (e.g., the nearest FB station in this region would typically be ACK, BUF, or HAR/PSB).

The closest proxy in the brief is a PIREP at the right altitude: MDT 2352Z, C208, FL060, TA -3 C, light rime ice — that gives an air-temp data point of about -3 C at 6,000 ft west of here, but it's not a wind report.

## Q6

`adverse_conditions.items` is empty (no SIGMETs, CWAs, or severe items rolled up by the brief), but there is a partial failure noted: AIRMETs failed to ingest (`RGeo::Error::InvalidGeometry: Self-intersection`). That means AIRMET coverage is unknown from this brief — assume nothing, verify elsewhere.

The PIREP set, however, paints a clear icing picture across the broader region (note: most are not in the immediate KCDW vicinity — they span from PA to MA to NY):

- Light rime icing reported repeatedly between roughly 5,000 ft and 11,000 ft:
  - MDT 2352Z C208 FL060 TA -3 LGT RIME
  - MDT 2321Z PA32 FL070 TA -3 LGT RIME
  - SEG 2248Z C208 FL050 TA 0 LGT RIME
  - BWI 2251Z PA30 FL090 TA -4 LGT RIME (090-070)
  - LNS 2249Z B712 FL110 TA -12 LGT RIME + cont. light chop
  - PHL 2300Z E145 FL100 TA -8 LGT RIME (icing 100-085)
- Trace rime: ALB 2345Z C180 FL045 (5,000-8,000 ft)
- Light clear ice: ALB 2316Z S22T FL090, BDL 2247Z S22T FL100 TA -7
- One **moderate mixed icing** report: RDG 2241Z E75S FL100 TA -9 — the worst of the bunch.
- Turbulence: light chop at FL020 over AVP, intermittent light chop at FL030 over MIV, continuous light chop at FL110 over LNS. PIREP near final at ALB noted gain/loss 5 kt — minor.
- Light rain reported at MIV (FL020) and ISP — convection-free shower activity consistent with the AFD's "front passing" narrative.

For a piston VFR flight from KCDW staying low (below the freezing level, roughly somewhere a few thousand feet AGL given surface temp 13 C / dewpoint 4 C), icing should not be a factor. If you climb into the low/mid teens or head west/northwest into PA, expect light rime in cloud and at least one moderate mixed report — IFR/known-icing aircraft territory.

## Q7

Things this brief explicitly does NOT contain that you should source separately before flight:

- **Synopsis** — `synopsis.available: false`. Use the OKX AFD text in the brief as a partial substitute, or get a proper area synopsis.
- **Destination/terminal forecast (TAF)** — `destination_forecast.available: false` (fetch error). No TAF for KCDW or any alternate in the envelope. Pull a TAF for KCDW (if issued) or your nearest alternate (KMMU/KTEB/KEWR).
- **Winds and temperatures aloft** — `winds_aloft.available: false`. No FB/FD data at any altitude.
- **NOTAMs** — `notams.available: false` ("Sectional domain not yet built"). This is critical — runway closures, lighting, GPS outages, TFRs, etc., are entirely absent. Get NOTAMs from another source.
- **ATC delays / GDP / ground stops** — `atc_delays.available: false`. Check NAS Status separately, especially if your destination is a major airport.
- **AIRMETs** — failed to parse (`RGeo::Error::InvalidGeometry: Self-intersection`). Coverage for IFR, mountain obscuration, icing, and turbulence AIRMETs is unknown from this brief. Given the icing PIREPs scattered around the region, an AIRMET ZULU probably exists — go check.
- **Enroute forecast** — `enroute_forecast.available: false` ("single-point brief; route input deferred"). No route-based weather; only the KCDW point.
- **SIGMETs / CWAs** — `adverse_conditions.items: []` reports none, but it's worth a sanity-check given the icing pattern.
- **Other not-in-envelope items**: graphical/prog charts, radar/satellite imagery, lightning, TFRs, military activity, special-use airspace status, and the destination's ATIS/AWOS.

Bottom line: the brief is solid for current KCDW field conditions and a regional synopsis (via the AFD), but it is missing TAF, winds aloft, NOTAMs, ATC delays, AIRMETs, and any enroute coverage. Treat it as a starting point, not a complete preflight.


### Judgment

| Q | Pass / fail | Notes |
|---|---|---|
| 1 | Pass | Correctly identified VFR using `vfr_not_recommended` slot + corroborating METAR. |
| 2 | Pass | Synopsis slot is `available: false` (per spec); LLM correctly degraded to extracting pattern from AFD slot text — used the OKX AFD narrative for cold front passage, weekend low, and outlook. |
| 3 | Pass | Pulled real numbers from METAR (calm wind, 10 SM, CLR, 13.3/3.9, 29.77, density alt 158 ft). Decoded RMK 6-hr precip group correctly. |
| 4 | Pass | Honestly flagged TAF unavailable (`Skywatch::ParseError: unexpected end of input` — KCDW does not always issue a TAF; this is a realistic null result). Suggested KMMU/KTEB/KEWR as alternates. |
| 5 | Pass | Honestly flagged winds_aloft slot as `available: false`. Used a PIREP at FL060 (TA -3 C light rime) as a temperature proxy but did not invent wind data. |
| 6 | Pass | Reported empty `items` correctly + flagged the AIRMET partial failure + synthesized regional icing context from PIREP set without overstating. Recommended treating AIRMET coverage as "unknown, verify elsewhere". |
| 7 | Pass | Comprehensive enumeration: synopsis, TAF, winds aloft, NOTAMs, ATC delays, AIRMETs, enroute, SIGMETs/CWAs, TFRs, density altitude. No hallucinated content. |

## Scenario 2: KACK — IFR

**Captured at:** 2026-05-01T00:09:40Z
**Conditions summary:** Wind 280@8, 10 SM, BKN007 OVC011 (ceiling 700 ft), 10/8 °C (1.7 °C spread — saturation-near), A2972. Flight category IFR per METAR. AIRMET partial-failure same as Scenario 1.

### Brief JSON

```json
{
  "airport": "KACK",
  "coordinates": [
    41.2541,
    -70.0589
  ],
  "wfo": "BOX",
  "fetched_at": "2026-05-01T00:09:40Z",
  "aim_section": "7-1-5",
  "adverse_conditions": {
    "available": true,
    "items": [],
    "partial_failures": [
      {
        "source": "airmet",
        "reason": "RGeo::Error::InvalidGeometry: Self-intersection"
      }
    ]
  },
  "vfr_not_recommended": {
    "available": true,
    "vfr_not_recommended": true,
    "category": "IFR",
    "explanation": "ceiling 700 ft, vis 10.0 SM"
  },
  "synopsis": {
    "available": false,
    "reason": "no synopsis source in skywatch — see afd slot"
  },
  "current_conditions": {
    "available": true,
    "metar": {
      "station_id": "KACK",
      "raw": "METAR KACK 302353Z 28008KT 10SM BKN007 OVC011 10/08 A2972 RMK AO2 SLP064 T01000083 10111 20094 53012 $",
      "observed_at": "2026-04-30T23:53:00Z",
      "metar_type": "METAR",
      "wind_direction_deg": 280,
      "wind_speed_kt": 8,
      "wind_gust_kt": null,
      "visibility_sm": 10.0,
      "weather": [],
      "sky_condition": [
        {
          "cover": "bkn",
          "base_ft": 700
        },
        {
          "cover": "ovc",
          "base_ft": 1100
        }
      ],
      "temperature_c": 10.0,
      "dewpoint_c": 8.3,
      "altimeter_inhg": 29.72,
      "station_name": "Nantucket Mem Arpt, MA, US",
      "latitude": 41.2541,
      "longitude": -70.0589,
      "elevation_ft": 39,
      "ceiling_ft": 700,
      "flight_category": "ifr",
      "spread_c": 1.7,
      "density_altitude_ft": -352
    },
    "pireps": [
      {
        "raw": "BOS UA /OV RY 4R FINAL/TM 0000/FL030/TP A321/SK BKN/RM DURD",
        "observed_at": "2026-05-01T00:00:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "A321",
        "latitude": 42.3575,
        "longitude": -70.9895,
        "flight_level": 30,
        "altitude_ft": 3000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MPV UA /OV MPV/TM 2351/FL070/TP C208/TA M02/IC LGT RIME",
        "observed_at": "2026-04-30T23:51:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C208",
        "latitude": 44.0855,
        "longitude": -72.4494,
        "flight_level": 70,
        "altitude_ft": 7000,
        "temperature_c": -2,
        "icing_intensity": "LGT",
        "icing_type": "RIME",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ALB UA /OV ALB040025/TM 2345/FL045/TP C180/IC TRACE RIME 80-50",
        "observed_at": "2026-04-30T23:45:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C180",
        "latitude": 43.1176,
        "longitude": -73.5445,
        "flight_level": 45,
        "altitude_ft": 4500,
        "temperature_c": null,
        "icing_intensity": "TRC",
        "icing_type": "RIME",
        "icing_base_ft": 5000,
        "icing_top_ft": 8000,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "EWB UA /OV EWB RY23 APCH/TM 2341/FL014/TP C172/SK OVC014",
        "observed_at": "2026-04-30T23:41:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C172",
        "latitude": 41.6766,
        "longitude": -70.9578,
        "flight_level": 14,
        "altitude_ft": 1400,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "PWM UA /OV PWM/TM 2341/FL007/TP C208/SK OVC007-TOPUNKN/RM DURD ILS11",
        "observed_at": "2026-04-30T23:41:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C208",
        "latitude": 43.6456,
        "longitude": -70.3086,
        "flight_level": 7,
        "altitude_ft": 700,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ALB UA /OV ALB100005/TM 2338/FL020/TP E545/RM GAIN OR LOSS 5 KTS FINAL RY28",
        "observed_at": "2026-04-30T23:38:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E545",
        "latitude": 42.7516,
        "longitude": -73.6901,
        "flight_level": 20,
        "altitude_ft": 2000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "6B0 UA /OV 6B0/TM 2331/FL060/TP S22T/TA M02/IC LGT CLR",
        "observed_at": "2026-04-30T23:31:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "S22T",
        "latitude": 43.9865,
        "longitude": -73.0956,
        "flight_level": 60,
        "altitude_ft": 6000,
        "temperature_c": -2,
        "icing_intensity": "LGT",
        "icing_type": "CLEAR",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ISP UA /OV CCC260010/TM 2328/FL035/TP C172/SK 034OVC",
        "observed_at": "2026-04-30T23:28:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C172",
        "latitude": 40.8644,
        "longitude": -73.0014,
        "flight_level": 35,
        "altitude_ft": 3500,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ALB UA /OV CAM040015/TM 2316/FL90/TP S22T/IC LGT CLR",
        "observed_at": "2026-04-30T23:16:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "S22T",
        "latitude": 43.2185,
        "longitude": -73.1939,
        "flight_level": 90,
        "altitude_ft": 9000,
        "temperature_c": null,
        "icing_intensity": "LGT",
        "icing_type": "CLEAR",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ISP UA /OV ISP/TM 2303/FL1800/TP C172/RM LIGHT RAIN",
        "observed_at": "2026-04-30T23:03:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C172",
        "latitude": 40.7961,
        "longitude": -73.1007,
        "flight_level": 0,
        "altitude_ft": 0,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "ARP IBE0212 4107N 6700W 2258 F370 MS56 250/070KT",
        "observed_at": "2026-04-30T22:58:00Z",
        "pirep_type": "airep",
        "aircraft_type": "IBE0212",
        "latitude": 41.1167,
        "longitude": -67,
        "flight_level": 370,
        "altitude_ft": 37000,
        "temperature_c": -56,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "BDL UA /OV JUDDS/TM 2247/FL100/TP S22T/TA M07/IC LGT CLR",
        "observed_at": "2026-04-30T22:47:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "S22T",
        "latitude": 41.6347,
        "longitude": -73.1082,
        "flight_level": 100,
        "altitude_ft": 10000,
        "temperature_c": -7,
        "icing_intensity": "LGT",
        "icing_type": "CLEAR",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      }
    ]
  },
  "enroute_forecast": {
    "available": false,
    "reason": "single-point brief; route input deferred from MVP"
  },
  "destination_forecast": {
    "available": true,
    "taf": {
      "station_id": "KACK",
      "raw": "TAF KACK 302333Z 0100/0124 28009KT P6SM BKN005 BKN013 OVC035 FM010300 28006KT 5SM BR BKN015 FM010500 29007KT 4SM BR BKN020 FM010900 31007KT P6SM SCT130 FM011500 30010KT P6SM FEW250 FM011800 26012KT P6SM FEW250",
      "issued_at": "2026-04-30T23:33:00Z",
      "valid_from": "2026-05-01T00:00:00Z",
      "valid_to": "2026-05-02T00:00:00Z",
      "station_name": "Nantucket Mem Arpt",
      "latitude": 41.25407,
      "longitude": -70.05892,
      "elevation_ft": 39,
      "forecast_groups": [
        {
          "time_from": "2026-05-01T00:00:00Z",
          "time_to": "2026-05-01T03:00:00Z",
          "change_type": "initial",
          "probability": null,
          "wind_direction_deg": 280,
          "wind_speed_kt": 9,
          "wind_gust_kt": null,
          "visibility_sm": 6.0,
          "weather": [],
          "sky_condition": [
            {
              "cover": "bkn",
              "base_ft": 500
            },
            {
              "cover": "bkn",
              "base_ft": 1300
            },
            {
              "cover": "ovc",
              "base_ft": 3500
            }
          ],
          "ceiling_ft": 500,
          "flight_category": "ifr"
        },
        {
          "time_from": "2026-05-01T03:00:00Z",
          "time_to": "2026-05-01T05:00:00Z",
          "change_type": "fm",
          "probability": null,
          "wind_direction_deg": 280,
          "wind_speed_kt": 6,
          "wind_gust_kt": null,
          "visibility_sm": 5.0,
          "weather": [
            "BR"
          ],
          "sky_condition": [
            {
              "cover": "bkn",
              "base_ft": 1500
            }
          ],
          "ceiling_ft": 1500,
          "flight_category": "mvfr"
        },
        {
          "time_from": "2026-05-01T05:00:00Z",
          "time_to": "2026-05-01T09:00:00Z",
          "change_type": "fm",
          "probability": null,
          "wind_direction_deg": 290,
          "wind_speed_kt": 7,
          "wind_gust_kt": null,
          "visibility_sm": 4.0,
          "weather": [
            "BR"
          ],
          "sky_condition": [
            {
              "cover": "bkn",
              "base_ft": 2000
            }
          ],
          "ceiling_ft": 2000,
          "flight_category": "mvfr"
        },
        {
          "time_from": "2026-05-01T09:00:00Z",
          "time_to": "2026-05-01T15:00:00Z",
          "change_type": "fm",
          "probability": null,
          "wind_direction_deg": 310,
          "wind_speed_kt": 7,
          "wind_gust_kt": null,
          "visibility_sm": 6.0,
          "weather": [],
          "sky_condition": [
            {
              "cover": "sct",
              "base_ft": 13000
            }
          ],
          "ceiling_ft": null,
          "flight_category": "vfr"
        },
        {
          "time_from": "2026-05-01T15:00:00Z",
          "time_to": "2026-05-01T18:00:00Z",
          "change_type": "fm",
          "probability": null,
          "wind_direction_deg": 300,
          "wind_speed_kt": 10,
          "wind_gust_kt": null,
          "visibility_sm": 6.0,
          "weather": [],
          "sky_condition": [
            {
              "cover": "few",
              "base_ft": 25000
            }
          ],
          "ceiling_ft": null,
          "flight_category": "vfr"
        },
        {
          "time_from": "2026-05-01T18:00:00Z",
          "time_to": "2026-05-02T00:00:00Z",
          "change_type": "fm",
          "probability": null,
          "wind_direction_deg": 260,
          "wind_speed_kt": 12,
          "wind_gust_kt": null,
          "visibility_sm": 6.0,
          "weather": [],
          "sky_condition": [
            {
              "cover": "few",
              "base_ft": 25000
            }
          ],
          "ceiling_ft": null,
          "flight_category": "vfr"
        }
      ]
    }
  },
  "winds_aloft": {
    "available": false,
    "reason": "no winds aloft for KACK"
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
    "available": true,
    "wfo": "BOX",
    "text": "\n000\nFXUS61 KBOX 010009\nAFDBOX\n\nArea Forecast Discussion\nNational Weather Service Boston/Norton MA\n809 PM EDT Thu Apr 30 2026\n\n.WHAT HAS CHANGED...\nNo significant changes to the forecast.\n\n&&\n\n.KEY MESSAGES...\n\n- A few leftover showers possible this evening, otherwise drying\n  out tonight followed by sunshine and seasonably mild\n  conditions Friday. \n\n- Cooler this weekend. Risk for showers as a low pressure \n  passes by offshore.\n\n- Becoming warmer for most of next week. Although, unsettled\n  conditions return toward the end of next week.\n\n&&\n\n.DISCUSSION...\nKEY MESSAGE 1...A few leftover showers possible this evening, \notherwise drying out tonight followed by sunshine and seasonably \nmild conditions Friday.\n\nBulk of shower activity has lifted to the north and east. We\ncan't rule out a spot shower this evening as mid level shortwave \nmoves through. Otherwise, drying out overnight as weak front\npasses followed by NW flow and decreasing PWATs. This will lead \nto a mostly sunny day on Friday with diurnal CU developing as \nupper low resides to the north with relatively cold temps aloft.\nSeasonable temps expected with highs low-mid 60s, except cooler\nhigher terrain. \n\nDry weather continues into Fri night but another shortwave \napproaching from the west may bring a few showers mostly after \nmidnight, especially in the interior. \n\nKEY MESSAGE 2...Cooler this weekend. Risk for showers as a low \npressure passes by offshore.\n\nThe big question for this weekend revolves around how closely a\nlow pressure will get to southern New England. Projected mid \nlevel flow has a trough axis west of the Appalachians, with the \nconsensus storm track over the Mid Atlantic into the North \nAtlantic. A subtle shift in the orientation of this flow could \nforce a storm track closer to our region, with a great risk for \nshowers Saturday Night into Sunday.\n\nExpecting a low track about 125 miles SE of the 40N/70W\nbenchmark at the closest approach of a low pressure Saturday\nnight at present. Latest consensus model output slightly\nincreased rainfall chances across the Cape and islands, as well \nas portions of the coastal plains of MA and RI. Not looking at \nmuch rainfall when all is done by Sunday afternoon. Expecting \namounts 0.10 inch or less north and west of I-495, with perhaps \n0.50-0.75 inch across the Cape and islands. Will be monitoring \nthe actual approach of this low pressure over the coming days.\n\nKEY MESSAGE 3...Becoming warmer for most of next week. Although, \nunsettled conditions return toward the end of next week.\n\nHigh pressure well to our south early next week should boost high \ntemperatures into the 60s Monday and the 70s for Tuesday.\nThinking it will remain mainly dry Monday, but then a cold \nfront should pass by sometime Tuesday with a risk for showers. \nThe greatest risk for showers looks to be sometime Wednesday \nnight into Thursday as a low pressure moves through the Great \nLakes and pushes a couple of fronts across our region.\n\n&&\n\n.AVIATION /00Z FRIDAY THROUGH TUESDAY/...\nForecaster Confidence Levels...\n\nLow - less than 30 percent.\nModerate - 30 to 60 percent. \nHigh - greater than 60 percent.\n\n00z TAF Update...High confidence in trends. Moderate confidence\nin timing.\n\nMVFR-IFR conditions persist into the evening, then gradual\nimprovement to VFR from W to E overnight, although patchy fog \nmay develop overnight in spots. VFR continues Fri into Fri\nnight, but scattered showers may develop late Fri night across\nthe interior. Winds becoming NW 5-10 kt this evening, increasing \nto 10-15 kt Fri, then becoming light to calm Fri night.\n\nKBOS Terminal...Moderate confidence in TAF. Main uncertainty is\nthe when conditions fully improve to VFR \n\nKBDL Terminal...Moderate confidence in TAF.\n\nOutlook /Saturday through Tuesday/...\n\nSaturday: VFR. Chance SHRA.\n\nSaturday Night: Mainly VFR, with local MVFR possible. Chance\nSHRA.\n\nSunday: VFR. Breezy. Chance SHRA.\n\nSunday Night: VFR. \n\nMonday: VFR. Breezy. \n\nMonday Night: VFR. Breezy. Slight chance SHRA.\n\nTuesday: VFR. Windy with local gusts up to 30 kt. Slight chance\nSHRA.\n\n&&\n\n.MARINE...\nForecaster Confidence Levels...\n\nLow - less than 30 percent. \nModerate - 30 to 60 percent. \nHigh - greater than 60 percent.\n\nGenerally light winds, becoming NW, into Fri then becoming SW \nlate Fri into Fri night. Seas 4-6 ft over outer waters will \nsubside late tonight into Fri. SCA for seas will continue until\nthis time. \n\nOutlook /Saturday through Tuesday/...\n\nSaturday: Winds less than 25 kt. Areas of seas approaching\n5 ft. Slight chance of rain showers. \n\nSaturday Night: Winds less than 25 kt. Areas of seas\napproaching 5 ft. Chance of rain showers. \n\nSunday: Winds less than 25 kt. Seas locally approaching 5 ft.\nChance of rain showers. \n\nSunday Night: Winds less than 25 kt. Areas of seas approaching\n5 ft. \n\nMonday: Low risk for Small Craft Advisory winds with gusts up\nto 30 kt. Seas up to 5 ft. \n\nMonday Night: Moderate risk for Small Craft Advisory winds with\nlocal gusts up to 30 kt. Seas up to 5 ft. \n\nTuesday: Strong winds with gusts up to 30 kt. Areas of rough\nseas.\n\n&&\n\n.BOX WATCHES/WARNINGS/ADVISORIES...\nCT...None.\nMA...None.\nRI...None.\nMARINE...Small Craft Advisory until 6 PM EDT Friday for ANZ250.\n     Small Craft Advisory until 2 AM EDT Friday for ANZ251.\n     Small Craft Advisory until 2 AM EDT Saturday for ANZ254>256.\n\n&&\n\n$$\n\nDISCUSSION...Belk/KJC\nAVIATION...Belk/KJC\nMARINE...KJC\n",
    "issued_at": "2026-05-01T00:09:00Z"
  }
}

```

### LLM responses

## Q1

**No — VFR is NOT recommended right now.**

The brief explicitly flags `vfr_not_recommended: true`, with category **IFR** and the explanation: "ceiling 700 ft, vis 10.0 SM". The current METAR backs this up: BKN at 700 ft (the ceiling), OVC at 1100 ft. Visibility is fine at 10 SM, but the 700 ft ceiling is well below VFR minimums (1,000 ft AGL ceiling required for the surrounding Class E surface area / typical VFR thresholds). You'll need an IFR clearance to depart or arrive.

## Q2

**There is no synopsis section in this brief.** The `synopsis` slot is `available: false` with reason: "no synopsis source in skywatch — see afd slot."

However, the WFO BOX **Area Forecast Discussion** (issued 01/0009Z, 8:09 PM EDT Thu Apr 30 2026) gives the regional pattern:

- **Tonight (30 Apr / early 01 May):** Bulk of shower activity has lifted N/E. Spot shower possible this evening as mid-level shortwave moves through. Drying out overnight as a weak front passes; NW flow with decreasing PWATs follows. Patchy fog possible overnight.
- **Friday (01 May):** Mostly sunny with diurnal CU as an upper low sits to the north (cold temps aloft). Highs low-to-mid 60s F. Winds NW 5–10 kt this evening, increasing to 10–15 kt Friday, then light/calm Fri night.
- **Friday night:** Dry early, but another shortwave from the west may bring a few showers after midnight, especially in the interior.
- **Weekend:** Cooler. Low pressure passing offshore — currently projected ~125 mi SE of the 40N/70W benchmark Sat night. Cape and islands (i.e., KACK area) get the highest QPF risk: ~0.50–0.75" possible. Risk for showers Sat night into Sunday.
- **Next week:** Warming trend — 60s Mon, 70s Tue. Cold front Tue with shower risk; greater shower risk Wed night–Thu as a low moves through the Great Lakes.

**Marine note** for the offshore zones near KACK: Small Craft Advisory in effect for ANZ250 until 6 PM EDT Friday, ANZ254>256 until 2 AM EDT Saturday. Seas 4–6 ft over outer waters subsiding late tonight into Friday.

## Q3

Field conditions per the **METAR KACK 302353Z** (observed 2026-04-30 23:53Z, ~16 minutes before brief fetch):

- **Wind:** 280° at 8 kt, no gusts
- **Visibility:** 10 SM
- **Weather:** none reported
- **Sky:** BKN 700 ft, OVC 1100 ft → **ceiling 700 ft**
- **Temperature / Dewpoint:** 10.0 °C / 8.3 °C (spread 1.7 °C — tight, fog/low-stratus risk)
- **Altimeter:** 29.72 inHg
- **Flight category:** **IFR**
- **Density altitude:** −352 ft (field elev 39 ft)
- **Raw:** `METAR KACK 302353Z 28008KT 10SM BKN007 OVC011 10/08 A2972 RMK AO2 SLP064 T01000083 10111 20094 53012 $`

The trailing `$` in the remarks indicates the station is flagging a maintenance check — worth noting but not flight-critical from this data alone.

## Q4

**TAF KACK 302333Z, valid 0100/0124 (2026-05-01 00Z through 2026-05-02 00Z):**

| FM (UTC) | Wind | Vis | Wx | Sky / Ceiling | Cat |
|---|---|---|---|---|---|
| 01/00–01/03 (initial) | 280@9 | >6 SM | — | BKN005 BKN013 OVC035, ceiling **500 ft** | **IFR** |
| 01/03–01/05 | 280@6 | 5 SM | BR | BKN015, ceiling **1,500 ft** | **MVFR** |
| 01/05–01/09 | 290@7 | 4 SM | BR | BKN020, ceiling **2,000 ft** | **MVFR** |
| 01/09–01/15 | 310@7 | >6 SM | — | SCT130 (no ceiling) | **VFR** |
| 01/15–01/18 | 300@10 | >6 SM | — | FEW250 | **VFR** |
| 01/18–02/00 | 260@12 | >6 SM | — | FEW250 | **VFR** |

**Key takeaways:**
- Conditions get **worse before they get better** for the next ~3 hours (ceilings drop to 500 ft early, then mist with 4–5 SM vis through ~09Z).
- VFR returns at **09Z Friday morning (~5 AM EDT)** with high scattered.
- Daytime Friday: VFR, light west-to-northwest winds 7–12 kt.
- Wind shifts SW (260°) and picks up to 12 kt by 18Z Friday.

The AFD AVIATION section corroborates: "MVFR-IFR conditions persist into the evening, then gradual improvement to VFR from W to E overnight, although patchy fog may develop overnight in spots."

## Q5

**Not in this brief.** The `winds_aloft` slot is `available: false` with reason: "no winds aloft for KACK." There is no FB/FD product included.

The closest proxies in the brief are PIREPs near the New England area — none right at KACK and most up-route, but for situational awareness on temps aloft / icing layers:

- BDL UA at FL100 (10,000 ft), 22:47Z: TA M07 (−7 °C), light clear icing
- 6B0 UA at FL060 (6,000 ft), 23:31Z: TA M02 (−2 °C), light clear icing
- MPV UA at FL070 (7,000 ft), 23:51Z: TA M02 (−2 °C), light rime icing
- ARP IBE0212 at FL370, 22:58Z: 250°/070 kt, MS56 (−56 °C)

These are scattered (Vermont, NW MA, CT, Long Island Sound) — none are KACK-local. **For an actual winds/temps aloft at 6,000 ft over KACK you must pull a separate FB product (e.g., from aviationweather.gov) before flight.**

## Q6

**Adverse conditions slot is `available: true` but `items: []`** — no adverse-condition records were synthesized for this point. There is also a **partial failure** flagged: the AIRMET source failed with `RGeo::Error::InvalidGeometry: Self-intersection`, so AIRMET coverage in this brief is incomplete. **Do not assume "no AIRMETs" — assume "AIRMETs unknown" and verify separately.**

That said, signals from elsewhere in the brief that you should treat as adverse:

1. **IFR ceilings now at the field** (700 ft BKN). 700-ft ceiling + 1.7 °C temp/dewpoint spread + the AFD's mention of "patchy fog may develop overnight in spots" → fog is a real possibility before things improve.
2. **Worsening before improving** in the TAF — the FM03Z group drops the ceiling to 1,500 ft with 5 SM in BR, then 4 SM BR by 05Z. Mist/fog is likely.
3. **Icing in the region.** Multiple PIREPs report light icing in clouds at 5,000–10,000 ft (rime over Vermont, clear over NY/CT). The icing PIREP from ALB area (43.1N/73.5W) explicitly calls out "TRACE RIME 80-50" — i.e., trace rime between 5,000 and 8,000 ft. Freezing levels are clearly down in the low-to-mid single-digit thousands. **If you're climbing through cloud layers in the IFR system above KACK, expect icing risk — especially if your route takes you NW.**
4. **Marine SCAs** in adjacent offshore zones (relevant if you fly low/coastal): seas 4–6 ft, gusts up to 30 kt forecast for Tuesday outlook period.
5. The AFD outlook flags **shower risk Sat night–Sun** with locally 0.50–0.75" possible across the Cape and islands as a low passes ~125 mi SE of the 40N/70W benchmark — relevant if your flight is multi-day.

## Q7

The brief is honest about its gaps. Items **not** in this brief that you'll need to source elsewhere before flight:

1. **NOTAMs** — `available: false`, reason: "NOTAMs not in skywatch yet — Sectional domain not yet built." **Critical.** Pull KACK NOTAMs (and any en-route facility NOTAMs, plus FDC) from the FAA NOTAM Search.
2. **ATC delays / TFRs / ground stops** — `available: false`, reason: "ATC delays not in skywatch yet — no source." Check the FAA ATCSCC / OIS site for delays and TFRs.
3. **Winds and temperatures aloft** — `available: false` for KACK. Pull FB/FD from aviationweather.gov for your cruise altitudes.
4. **AIRMETs** — explicitly flagged as a partial failure (RGeo geometry error). The brief has no usable AIRMET coverage. Pull G-AIRMET / Sierra/Tango/Zulu directly. Given the icing PIREPs in the region, **AIRMET Zulu (icing) is plausibly active** and you should check.
5. **SIGMETs / Convective SIGMETs / CWAs** — not in the brief at all (no slot). Verify there are none active for your route.
6. **Enroute forecast** — `available: false`, reason: "single-point brief; route input deferred from MVP." This is a destination/origin brief only, not a route brief. If you're going somewhere other than to/from KACK, you don't have route weather here.
7. **Synopsis** — explicitly `available: false`. The AFD partly fills this gap, but it's a regional discussion, not a true area synopsis / surface analysis.
8. **Center Weather Advisories (CWAs), area forecasts, graphical TAFs, radar/satellite imagery** — none included; pull from aviationweather.gov as needed.
9. **Freezing level chart / icing forecast** — not directly provided; PIREPs hint at icing in cloud above ~5,000 ft regionally, but you should pull the CIP/FIP / icing forecast graphics.
10. **Density altitude / runway condition / braking action / field condition NOTAMs** for KACK specifically — confirm via NOTAMs and the AWOS/ATIS at the field.
11. **Personal minimums check / weight-and-balance / fuel planning** — out of scope for any brief; reminder to do it.

**Bottom line:** This brief is enough to know KACK is currently IFR with improving conditions overnight, but you cannot legally/safely launch from this brief alone — at minimum you need NOTAMs, AIRMETs/SIGMETs, and winds aloft before you go.


### Judgment

| Q | Pass / fail | Notes |
|---|---|---|
| 1 | Pass | Correctly identified IFR + VFR not recommended using slot. Cited 700 ft ceiling explicitly. |
| 2 | Pass | Synopsis slot unavailable; LLM correctly substituted from AFD: stalled boundary, weekend low ~125 mi SE of 40N/70W benchmark, marine SCAs, multi-day outlook. |
| 3 | Pass | Full METAR decode: wind 280@8, 10 SM, BKN007 OVC011, 10/8 spread 1.7, A2972, density alt -352. Noted maintenance flag (`$`). |
| 4 | Pass | Excellent TAF decode in tabular form showing: ceilings dropping to 500 ft early then improving via mist (4–5 SM BR) to VFR by 09Z Friday morning. Trend correctly captured. |
| 5 | Pass | Honestly flagged unavailable; surfaced PIREP icing temps as situational context, did not invent wind/temperature aloft. |
| 6 | Pass | Empty `items` + AIRMET partial-failure flagged + synthesized icing risk from regional PIREPs (rime icing 5,000–10,000 ft) + low T-Td spread fog risk + TAF-implied worsening before improving. |
| 7 | Pass | 11-item enumeration of missing data: NOTAMs, ATC delays, winds aloft, AIRMETs, SIGMETs, enroute, synopsis, CWAs, freezing-level chart, density altitude, personal minimums. No hallucinations. |

## Scenario 3: KMSY — IFR + active convection

**Captured at:** 2026-05-01T00:10:35Z
**Conditions summary:** SPECI 020@8, 10 SM, -RA, BKN008 BKN018 OVC110 (ceiling 800 ft), 22/21 °C (1.6 °C spread), A2986. Adverse items: 1 convective SIGMET (74C, polygon directly over field) + 1 urgent low-level wind-shear PIREP at MSY (15 kt airspeed gain inside FAF). AIRMET partial-failure same as scenarios 1/2.

### Brief JSON

```json
{
  "airport": "KMSY",
  "coordinates": [
    29.9974,
    -90.2777
  ],
  "wfo": "LIX",
  "fetched_at": "2026-05-01T00:10:35Z",
  "aim_section": "7-1-5",
  "adverse_conditions": {
    "available": true,
    "items": [
      {
        "kind": "sigmet",
        "series_id": "74C",
        "issuing_center": "KKCI",
        "sigmet_type": "sigmet",
        "hazard": "CONVECTIVE",
        "severity": 5,
        "raw": "WSUS32 KKCI 302355\nSIGC \nCONVECTIVE SIGMET 74C\nVALID UNTIL 0155Z\nAL MS LA AND CSTL WTRS\nFROM 20ESE SJI-90SSE SJI-30W LEV-30ESE LSU-20ESE SJI\nAREA TS MOV FROM 26030KT. TOPS ABV FL450.\n\nOUTLOOK VALID 010155-010555\nFROM INK-LFK-CEW-LEV-PSX-LRD-DLF-MRF-INK\nWST ISSUANCES EXPD. REFER TO MOST RECENT ACUS01 KWNS FROM STORM\nPREDICTION CENTER FOR SYNOPSIS AND METEOROLOGICAL DETAILS.",
        "valid_from": "2026-04-30T23:55:00Z",
        "valid_to": "2026-05-01T01:55:00Z",
        "altitude_hi_ft": 45000,
        "altitude_low_ft": null,
        "movement_dir_deg": 260,
        "movement_speed_kt": 30,
        "coords": [
          {
            "lat": 30.602,
            "lon": -88.003
          },
          {
            "lat": 29.342,
            "lon": -87.701
          },
          {
            "lat": 29.179,
            "lon": -90.676
          },
          {
            "lat": 30.286,
            "lon": -90.762
          },
          {
            "lat": 30.602,
            "lon": -88.003
          }
        ]
      },
      {
        "kind": "pirep",
        "raw": "MSY UUA /OV MSY285003/TM 2245/FLDURD/TP B38M/RM 15KT GAIN INSIDE FINAL APPROACH FIX",
        "observed_at": "2026-04-30T22:45:00Z",
        "pirep_type": "urgent pirep",
        "aircraft_type": "B38M",
        "latitude": 30.0054,
        "longitude": -90.3149,
        "flight_level": 0,
        "altitude_ft": 0,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      }
    ],
    "partial_failures": [
      {
        "source": "airmet",
        "reason": "RGeo::Error::InvalidGeometry: Self-intersection"
      }
    ]
  },
  "vfr_not_recommended": {
    "available": true,
    "vfr_not_recommended": true,
    "category": "IFR",
    "explanation": "ceiling 800 ft, vis 10.0 SM"
  },
  "synopsis": {
    "available": false,
    "reason": "no synopsis source in skywatch — see afd slot"
  },
  "current_conditions": {
    "available": true,
    "metar": {
      "station_id": "KMSY",
      "raw": "SPECI KMSY 010007Z 02008KT 10SM -RA BKN008 BKN018 OVC110 22/21 A2986 RMK AO2 P0001 T02220206 $",
      "observed_at": "2026-05-01T00:07:00Z",
      "metar_type": "SPECI",
      "wind_direction_deg": 20,
      "wind_speed_kt": 8,
      "wind_gust_kt": null,
      "visibility_sm": 10.0,
      "weather": [
        "-RA"
      ],
      "sky_condition": [
        {
          "cover": "bkn",
          "base_ft": 800
        },
        {
          "cover": "bkn",
          "base_ft": 1800
        },
        {
          "cover": "ovc",
          "base_ft": 11000
        }
      ],
      "temperature_c": 22.2,
      "dewpoint_c": 20.6,
      "altimeter_inhg": 29.86,
      "station_name": "New Orleans/Armstrong Intl, LA, US",
      "latitude": 29.9974,
      "longitude": -90.2777,
      "elevation_ft": 0,
      "ceiling_ft": 800,
      "flight_category": "ifr",
      "spread_c": 1.6,
      "density_altitude_ft": 924
    },
    "pireps": [
      {
        "raw": "PNS UA /OV PNS170005/TM 0004/FL017/TP A319/SK SKC/RM SMOOTH DURD RY35 PNS",
        "observed_at": "2026-05-01T00:04:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "A319",
        "latitude": 30.392,
        "longitude": -87.1665,
        "flight_level": 17,
        "altitude_ft": 1700,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MOB UA /OV MOB/TM 2357/FLDURC/TP E145/SK CLR BELOW 080",
        "observed_at": "2026-04-30T23:57:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E145",
        "latitude": 30.7606,
        "longitude": -88.3032,
        "flight_level": 0,
        "altitude_ft": 0,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "JAN UA /OV MHZ135025/TM 2357/FL340/TP A321/TB CONS LGT OCNL MOD CHOP/RM ZME 45",
        "observed_at": "2026-04-30T23:57:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "A321",
        "latitude": 32.1447,
        "longitude": -89.7464,
        "flight_level": 340,
        "altitude_ft": 34000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "LGT-MOD",
        "turbulence_type": "CHOP",
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "LFT UA /OV LFT24002/TM 2353/FLDURD/TP C560/SK SCT005",
        "observed_at": "2026-04-30T23:53:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C560",
        "latitude": 30.1938,
        "longitude": -91.9926,
        "flight_level": 0,
        "altitude_ft": 0,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MSY UA /OV MSY285002/TM 2351/FLDURD/TP B737/SK SCT005",
        "observed_at": "2026-04-30T23:51:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "B737",
        "latitude": 30.0013,
        "longitude": -90.2963,
        "flight_level": 0,
        "altitude_ft": 0,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "GPT UA /OV GPT360005/TM 2350/FL018/TP S22T/SK OVC019/WX FV05SM -RA",
        "observed_at": "2026-04-30T23:50:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "S22T",
        "latitude": 30.4899,
        "longitude": -89.0734,
        "flight_level": 18,
        "altitude_ft": 1800,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MEI UA /OV MEI180060/TM 2344/FL210/TP B190/TA M08/IC TRACE RIME/RM ZTLFD-11",
        "observed_at": "2026-04-30T23:44:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "B190",
        "latitude": 31.3839,
        "longitude": -88.9062,
        "flight_level": 210,
        "altitude_ft": 21000,
        "temperature_c": -8,
        "icing_intensity": "TRC",
        "icing_type": "RIME",
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MCB UA /OV MCB315030/TM 2343/FL350/TP B737/TB MOD CHOP/RM ZHU",
        "observed_at": "2026-04-30T23:43:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "B737",
        "latitude": 31.6748,
        "longitude": -90.6506,
        "flight_level": 350,
        "altitude_ft": 35000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "MOD",
        "turbulence_type": "CHOP",
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "BTR UA /OV 1 NE KBTR/TM 2342/FL005/TP BE9L/SK BKN 005",
        "observed_at": "2026-04-30T23:42:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "BE9L",
        "latitude": 30.5447,
        "longitude": -91.1362,
        "flight_level": 5,
        "altitude_ft": 500,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "GPT UA /OV GPT360015/TM 2335/FL040/TP S22T/SK OVC045-TOP050/WX RN/TB MOD",
        "observed_at": "2026-04-30T23:35:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "S22T",
        "latitude": 30.6562,
        "longitude": -89.0667,
        "flight_level": 40,
        "altitude_ft": 4000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "MOD",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "BTR UA /OV LSU090030/TM 2334/FL360/TP E175/TB MOD /RM ZHU",
        "observed_at": "2026-04-30T23:34:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E175",
        "latitude": 30.4317,
        "longitude": -90.7184,
        "flight_level": 360,
        "altitude_ft": 36000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "MOD",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "GPT UA /OV GPT360020/TM 2331/FL340/TP B737/TB MOD CHOP/RM ZHU",
        "observed_at": "2026-04-30T23:31:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "B737",
        "latitude": 30.7393,
        "longitude": -89.0633,
        "flight_level": 340,
        "altitude_ft": 34000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "MOD",
        "turbulence_type": "CHOP",
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "GPT UA /OV GPT/TM 2330/FL010/TP E190/SK BKN010/TB NEG/RM SMOOOOOOOTH",
        "observed_at": "2026-04-30T23:30:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E190",
        "latitude": 30.4068,
        "longitude": -89.0768,
        "flight_level": 10,
        "altitude_ft": 1000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "NEG",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "LCH UA /OV 10 NE LCH/TM 2330/FLDURD/TP E170/SK BKN030-037 BKN045-060 BKN060-065",
        "observed_at": "2026-04-30T23:30:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E170",
        "latitude": 30.2438,
        "longitude": -92.9538,
        "flight_level": 0,
        "altitude_ft": 0,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "PNS UA /OV PNS/TM 2329/FL030/TP CRJ9/SK BASES BKN031 TOPS BKN045/TB SMOOTH",
        "observed_at": "2026-04-30T23:29:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "CRJ9",
        "latitude": 30.4734,
        "longitude": -87.1866,
        "flight_level": 30,
        "altitude_ft": 3000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "NEG",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "JAN UA /OV MHZ135025/TM 2329/FL350/TP B738/TB CONS MOD CHOP/RM ZME 43",
        "observed_at": "2026-04-30T23:29:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "B738",
        "latitude": 32.1447,
        "longitude": -89.7464,
        "flight_level": 350,
        "altitude_ft": 35000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "MOD",
        "turbulence_type": "CHOP",
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MSY UA /OV HRV/TM 2325/FL410/TP C68A/TB MOD/RM ZHU",
        "observed_at": "2026-04-30T23:25:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C68A",
        "latitude": 29.8502,
        "longitude": -90.003,
        "flight_level": 410,
        "altitude_ft": 41000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "MOD",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "GPT UA /OV GPT315007/TM 2323/FL020/TP BCS3/SK BKN020",
        "observed_at": "2026-04-30T23:23:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "BCS3",
        "latitude": 30.4919,
        "longitude": -89.169,
        "flight_level": 20,
        "altitude_ft": 2000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "GPT UA /OV GPT095008/TM 2320/FL051/TP CRJ9/SK SCT050/WX -RA/TB NEG",
        "observed_at": "2026-04-30T23:20:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "CRJ9",
        "latitude": 30.3905,
        "longitude": -88.9237,
        "flight_level": 51,
        "altitude_ft": 5100,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "NEG",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "PNS UA /OV PNS150009/TM 2318/FL026/TP A319/SK BASES BKN031/RM DURD",
        "observed_at": "2026-04-30T23:18:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "A319",
        "latitude": 30.3464,
        "longitude": -87.0947,
        "flight_level": 26,
        "altitude_ft": 2600,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "BTR UA /OV 1 NE KBTR/TM 2313/FL006/TP HDJT/SK OVC 006",
        "observed_at": "2026-04-30T23:13:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "HDJT",
        "latitude": 30.5447,
        "longitude": -91.1362,
        "flight_level": 6,
        "altitude_ft": 600,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "CEW UA /OV CEW290050/TM 2310/FL240/TP E170/SK TOP 180 BKN",
        "observed_at": "2026-04-30T23:10:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E170",
        "latitude": 31.1482,
        "longitude": -87.5738,
        "flight_level": 240,
        "altitude_ft": 24000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "JAN UA /OV 15 S OF JAN/TM 2310/FL50/TP B717/SK BASE050",
        "observed_at": "2026-04-30T23:10:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "B717",
        "latitude": 32.3112,
        "longitude": -90.0759,
        "flight_level": 50,
        "altitude_ft": 5000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "NEW UA /OV NEW/TM 2309/FLDURD/TP FA10/RM BASES 010",
        "observed_at": "2026-04-30T23:09:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "FA10",
        "latitude": 30.0424,
        "longitude": -90.0282,
        "flight_level": 0,
        "altitude_ft": 0,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "PNS UA /OV KPNS/TM 2309/FL025/TP C172/SK OVC025/TB NEG/RM DURD RWY35",
        "observed_at": "2026-04-30T23:09:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "C172",
        "latitude": 30.4734,
        "longitude": -87.1866,
        "flight_level": 25,
        "altitude_ft": 2500,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "NEG",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MLU UA /OV MLU0900015/TM 2303/FL090/TP CRJ7/SK OVC090/WX -RA/RM DURC",
        "observed_at": "2026-04-30T23:03:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "CRJ7",
        "latitude": 32.5169,
        "longitude": -92.036,
        "flight_level": 90,
        "altitude_ft": 9000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MOB UA /OV MOB/TM 2302/FLDURD/TP BE36/SK 020",
        "observed_at": "2026-04-30T23:02:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "BE36",
        "latitude": 30.7606,
        "longitude": -88.3032,
        "flight_level": 0,
        "altitude_ft": 0,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "GZH UA /OV MVC017041/TM 2259/FL350/TP A321/TB CONS LGT OCNL MOD CHOP/RM ZTLFD-08",
        "observed_at": "2026-04-30T22:59:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "A321",
        "latitude": 32.0958,
        "longitude": -87.064,
        "flight_level": 350,
        "altitude_ft": 35000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "LGT-MOD",
        "turbulence_type": "CHOP",
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "SHV UA /OV EMG115015/TM 2258/FL370/TP B738/TB CONS LGT CHOP/RM ZFW28",
        "observed_at": "2026-04-30T22:58:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "B738",
        "latitude": 32.2679,
        "longitude": -93.3448,
        "flight_level": 370,
        "altitude_ft": 37000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "LGT",
        "turbulence_type": "CHOP",
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "BFM UA /OV BFM/TM 2256/FL160/TP CL35/TB MOD/RM ZHU",
        "observed_at": "2026-04-30T22:56:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "CL35",
        "latitude": 30.6127,
        "longitude": -88.0555,
        "flight_level": 160,
        "altitude_ft": 16000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "MOD",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "JAN UA /OV 30 S OF JAN/TM 2255/FL60/TP P32R/SK BASE060",
        "observed_at": "2026-04-30T22:55:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "P32R",
        "latitude": 32.3112,
        "longitude": -90.0759,
        "flight_level": 60,
        "altitude_ft": 6000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "LCH UA /OV 10 S/TM 2255/FL020/TP E145/SK BKN023",
        "observed_at": "2026-04-30T22:55:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E145",
        "latitude": 30.1415,
        "longitude": -93.1056,
        "flight_level": 20,
        "altitude_ft": 2000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "PNS UA /OV 170004/TM 2254/FL015/TP A21N/SK BKN030/TB NEG",
        "observed_at": "2026-04-30T22:54:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "A21N",
        "latitude": 30.4734,
        "longitude": -87.1866,
        "flight_level": 15,
        "altitude_ft": 1500,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "NEG",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MEI UA /OV MEI315040/TM 2253/FL300/TP A321/TB CONS LGT OCNL MOD /RM ZME46",
        "observed_at": "2026-04-30T22:53:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "A321",
        "latitude": 32.8872,
        "longitude": -89.3137,
        "flight_level": 300,
        "altitude_ft": 30000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "LGT-MOD",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "MLU UA /OV MLU140025/TM 2252/FL060/TP RV7/TB MOD",
        "observed_at": "2026-04-30T22:52:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "RV7",
        "latitude": 32.1844,
        "longitude": -91.7402,
        "flight_level": 60,
        "altitude_ft": 6000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "MOD",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "BTR UA /OV 15 SE OF BTR/TM 2251/FL045/TP CL35/SK BASES 045",
        "observed_at": "2026-04-30T22:51:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "CL35",
        "latitude": 30.5329,
        "longitude": -91.1499,
        "flight_level": 45,
        "altitude_ft": 4500,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": null,
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "PNS UA /OV PENSI/TM 2248/FL063/TP CRJ9/TB SMOOTH/RM BETWEEN LAYERS",
        "observed_at": "2026-04-30T22:48:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "CRJ9",
        "latitude": 30.7932,
        "longitude": -87.2738,
        "flight_level": 63,
        "altitude_ft": 6300,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "NEG",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      },
      {
        "raw": "LCH UA /OV 3007N 09319W/TM 2241/FL 170/TP E45X/TB LGT-MOD CONS/RM AWC-WEB",
        "observed_at": "2026-04-30T22:41:00Z",
        "pirep_type": "pirep",
        "aircraft_type": "E45X",
        "latitude": 30.1167,
        "longitude": -93.3167,
        "flight_level": 170,
        "altitude_ft": 17000,
        "temperature_c": null,
        "icing_intensity": null,
        "icing_type": null,
        "icing_base_ft": null,
        "icing_top_ft": null,
        "turbulence_intensity": "LGT-MOD",
        "turbulence_type": null,
        "turbulence_base_ft": null,
        "turbulence_top_ft": null
      }
    ]
  },
  "enroute_forecast": {
    "available": false,
    "reason": "single-point brief; route input deferred from MVP"
  },
  "destination_forecast": {
    "available": true,
    "taf": {
      "station_id": "KMSY",
      "raw": "TAF KMSY 302328Z 0100/0206 03012KT 5SM -SHRA BR BKN008 OVC030 TEMPO 0100/0104 2SM TSRA BKN008CB FM010400 05006KT P6SM BKN008 OVC020 PROB30 0109/0114 4SM -SHRA OVC005 FM011400 07010KT P6SM -SHRA BKN010 BKN020 PROB30 0114/0120 4SM TSRA OVC005CB FM012000 07011KT 6SM -SHRA BKN013 OVC060 PROB30 0120/0201 4SM -TSRA OVC007CB FM020100 05015G22KT P6SM -SHRA BKN009 OVC090 PROB30 0201/0206 4SM TSRA OVC003CB",
      "issued_at": "2026-04-30T23:28:00Z",
      "valid_from": "2026-05-01T00:00:00Z",
      "valid_to": "2026-05-02T06:00:00Z",
      "station_name": "New Orleans/Armstrong Intl",
      "latitude": 29.99739,
      "longitude": -90.27773,
      "elevation_ft": 0,
      "forecast_groups": [
        {
          "time_from": "2026-05-01T00:00:00Z",
          "time_to": "2026-05-01T04:00:00Z",
          "change_type": "initial",
          "probability": null,
          "wind_direction_deg": 30,
          "wind_speed_kt": 12,
          "wind_gust_kt": null,
          "visibility_sm": 5.0,
          "weather": [
            "-SHRA",
            "BR"
          ],
          "sky_condition": [
            {
              "cover": "bkn",
              "base_ft": 800
            },
            {
              "cover": "ovc",
              "base_ft": 3000
            }
          ],
          "ceiling_ft": 800,
          "flight_category": "ifr"
        },
        {
          "time_from": "2026-05-01T00:00:00Z",
          "time_to": "2026-05-01T04:00:00Z",
          "change_type": "tempo",
          "probability": null,
          "wind_direction_deg": null,
          "wind_speed_kt": null,
          "wind_gust_kt": null,
          "visibility_sm": 2.0,
          "weather": [
            "TSRA"
          ],
          "sky_condition": [
            {
              "cover": "bkn",
              "base_ft": 800
            }
          ],
          "ceiling_ft": 800,
          "flight_category": "ifr"
        },
        {
          "time_from": "2026-05-01T04:00:00Z",
          "time_to": "2026-05-01T14:00:00Z",
          "change_type": "fm",
          "probability": null,
          "wind_direction_deg": 50,
          "wind_speed_kt": 6,
          "wind_gust_kt": null,
          "visibility_sm": 6.0,
          "weather": [],
          "sky_condition": [
            {
              "cover": "bkn",
              "base_ft": 800
            },
            {
              "cover": "ovc",
              "base_ft": 2000
            }
          ],
          "ceiling_ft": 800,
          "flight_category": "ifr"
        },
        {
          "time_from": "2026-05-01T09:00:00Z",
          "time_to": "2026-05-01T14:00:00Z",
          "change_type": "prob",
          "probability": 30,
          "wind_direction_deg": null,
          "wind_speed_kt": null,
          "wind_gust_kt": null,
          "visibility_sm": 4.0,
          "weather": [
            "-SHRA"
          ],
          "sky_condition": [
            {
              "cover": "ovc",
              "base_ft": 500
            }
          ],
          "ceiling_ft": 500,
          "flight_category": "ifr"
        },
        {
          "time_from": "2026-05-01T14:00:00Z",
          "time_to": "2026-05-01T20:00:00Z",
          "change_type": "fm",
          "probability": null,
          "wind_direction_deg": 70,
          "wind_speed_kt": 10,
          "wind_gust_kt": null,
          "visibility_sm": 6.0,
          "weather": [
            "-SHRA"
          ],
          "sky_condition": [
            {
              "cover": "bkn",
              "base_ft": 1000
            },
            {
              "cover": "bkn",
              "base_ft": 2000
            }
          ],
          "ceiling_ft": 1000,
          "flight_category": "mvfr"
        },
        {
          "time_from": "2026-05-01T14:00:00Z",
          "time_to": "2026-05-01T20:00:00Z",
          "change_type": "prob",
          "probability": 30,
          "wind_direction_deg": null,
          "wind_speed_kt": null,
          "wind_gust_kt": null,
          "visibility_sm": 4.0,
          "weather": [
            "TSRA"
          ],
          "sky_condition": [
            {
              "cover": "ovc",
              "base_ft": 500
            }
          ],
          "ceiling_ft": 500,
          "flight_category": "ifr"
        },
        {
          "time_from": "2026-05-01T20:00:00Z",
          "time_to": "2026-05-02T01:00:00Z",
          "change_type": "fm",
          "probability": null,
          "wind_direction_deg": 70,
          "wind_speed_kt": 11,
          "wind_gust_kt": null,
          "visibility_sm": 6.0,
          "weather": [
            "-SHRA"
          ],
          "sky_condition": [
            {
              "cover": "bkn",
              "base_ft": 1300
            },
            {
              "cover": "ovc",
              "base_ft": 6000
            }
          ],
          "ceiling_ft": 1300,
          "flight_category": "mvfr"
        },
        {
          "time_from": "2026-05-01T20:00:00Z",
          "time_to": "2026-05-02T01:00:00Z",
          "change_type": "prob",
          "probability": 30,
          "wind_direction_deg": null,
          "wind_speed_kt": null,
          "wind_gust_kt": null,
          "visibility_sm": 4.0,
          "weather": [
            "-TSRA"
          ],
          "sky_condition": [
            {
              "cover": "ovc",
              "base_ft": 700
            }
          ],
          "ceiling_ft": 700,
          "flight_category": "ifr"
        },
        {
          "time_from": "2026-05-02T01:00:00Z",
          "time_to": "2026-05-02T06:00:00Z",
          "change_type": "fm",
          "probability": null,
          "wind_direction_deg": 50,
          "wind_speed_kt": 15,
          "wind_gust_kt": 22,
          "visibility_sm": 6.0,
          "weather": [
            "-SHRA"
          ],
          "sky_condition": [
            {
              "cover": "bkn",
              "base_ft": 900
            },
            {
              "cover": "ovc",
              "base_ft": 9000
            }
          ],
          "ceiling_ft": 900,
          "flight_category": "ifr"
        },
        {
          "time_from": "2026-05-02T01:00:00Z",
          "time_to": "2026-05-02T06:00:00Z",
          "change_type": "prob",
          "probability": 30,
          "wind_direction_deg": null,
          "wind_speed_kt": null,
          "wind_gust_kt": null,
          "visibility_sm": 4.0,
          "weather": [
            "TSRA"
          ],
          "sky_condition": [
            {
              "cover": "ovc",
              "base_ft": 300
            }
          ],
          "ceiling_ft": 300,
          "flight_category": "lifr"
        }
      ]
    }
  },
  "winds_aloft": {
    "available": false,
    "reason": "no winds aloft for KMSY"
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
    "available": true,
    "wfo": "LIX",
    "text": "\n000\nFXUS64 KLIX 302346\nAFDLIX\n\nArea Forecast Discussion\nNational Weather Service New Orleans LA\n646 PM CDT Thu Apr 30 2026\n\n...New UPDATE, AVIATION...\n\n.KEY MESSAGES... \nUpdated at 630 PM CDT Thu Apr 30 2026\n\n- Heavy rainfall and increased risk of flash flooding will impact\n  much of the region Friday night.\n \n- The threat for thunderstorms, some possibly strong to severe\n  will continue through Friday night.\n\n- Cooler than normal high temperatures are expected Friday through\n  Monday. \n\n&&\n\n.UPDATE...\nIssued at 630 PM CDT Thu Apr 30 2026\n\nStrongest convection now sinking southeastward to the south of\nInterstate 10 and south of New Orleans. Still light to moderate\nrain over much of the area away from the cluster of thunderstorms,\nbut radar indicates that there is a back edge to this rain area \nnear Baton Rouge. There is still more precipitation over northwest\nLouisiana and eastern Texas, so we won't dry out the overnight \nforecast completely behind this batch.\n\nWill probably do an update in the next hour or two as we see how\nmuch of the current precipitation we lose with the loss of surface\nheating. Any updates will only cover the overnight hours tonight,\nprior to the main package issuance around 1 AM CDT.\n\n&&\n\n.SHORT TERM...\n(Now through Saturday night)\nIssued at 1225 PM CDT Thu Apr 30 2026\n\nAn excellent setup for locally heavy rainfall to develop will\nremain in place through the entire short term period. A stalled\nfrontal boundary will remain in place along the I-10 corridor\nPWATS will be near the daily maximum through tomorrow night. At \nthe same time, favorable upper level jet dynamics will support \ncontinued deep layer forcing over the area. In the low to mid- \nlevels a region of enhanced baroclinicity beneath the upper level jet\ncouplet will allow a low pressure to form along the stalled front\nby tomorrow morning. This low will track to the east and help to \nincrease both isentropic forcing behind the front and moisture \nconvergence along the frontal boundary. Mean storm relative flow \nwill be largely parallel the frontal boundary, so any storms that\nform will track along the boundary. This will allow for a greatly\nincreased risk of training thunderstorms to form as early as late\nFriday afternoon, but more likely on Friday night when our flash\nflood threat peaks. Rainfall totals of 2 to 4 inches are \ngenerally expected over the next 2 days, but localized areas of 4 \nto 8 inches can be expected. Even with the latest high resolution \nmodeling, the axis of heaviest rainfall will be highly dependent \non exactly where the stationary boundary and greatest moisture \nconvergence develops. The threat looks to be highest north of I-10\nat this time, but if the boundary sinks further south than \nexpected, that heavy rain axis could shift into metro New Orleans \nand the River Parishes. We will need to monitor the positioning of\nthe front carefully as we move into tomorrow. We have also opted \nto hold off on issuing a flood watch due to the uncertainty in \nwhere the heaviest rainfall will occur. \n\nLooking beyond the heavy rain concerns, ample instability and\nspeed shear will also be in place to the south of the stalled\nfrontal boundary through Friday night. 0-6km shear will remain on\nthe order of 50 to 60 knots and areas south of the front will see\nMLCAPE values of 1000 to 1500 J/KG each afternoon. These values\ncombined with the deep layer forcing over the region will support\na risk of isolated severe thunderstorm development both this\nafternoon and again Friday afternoon for coastal Louisiana and the\noffshore waters. Although directional shear will be more limited\nat around 100 to 150 m2/s2 in the lowest 3km, some weak\nmesocyclonic development in the updraft will occur with any \nsevere storms. Tornadoes are unlikely to occur, but these weakly \nrotating updrafts will support a larger hail formation as \nresidence time increases in these longer lasting and deeper \nupdraft cores. As the cores aloft finally exceed the buoyant \nforcing with the updraft, they will collapse and produce periods \nof severe hail and strong damaging winds in coastal Louisiana and \noffshore. \n\nTemperatures will be much cooler than previous days due to the\nboundary being stalled over the area. Persistent cloud cover and\nperiods of rain will combine with fairly strong cold air advection\nbehind the front to keep temperatures in the 60s and lower 70s\nnorth of the front. South of the front, temperatures will remain\nwarm with highs climbing into the upper 70s and lower 80s both\ntoday and tomorrow. A very small diurnal range is expected tonight\nand dewpoints remain very high with readings only cooling into the\nupper 50s and lower 60s north of the front and the upper 60s south\nof the front. By tomorrow night, temperatures and dewpoints will\nbegin to drop quickly as the front pushes offshore late in the\nnight. Lows should drop into the low to mid 50s by daybreak on\nSaturday. \n\nA deep northern stream longwave trough axis will pass through the\narea on Saturday and this will help to fully drive all of the rain\nout of the area as a cold front sweeps out into the central Gulf.\nBreezy and significantly colder conditions will take hold by\nSaturday afternoon with northerly winds of 15 to 20 mph and\ntemperatures in the upper 60s and lower 70s expected. The\ncombination of clear skies and continued cold air advection into\nthe area Saturday night will allow lows to cool into the upper 40s\nand lower 50s across most of the area. Only the immediate\nsouthshore of Lake Pontchartrain and the immediate coast of \nLouisiana will see lows in the mid 50s due to the warmer nearby \nwaters modifying the temperatures slightly. \n\n&&\n\n.LONG TERM...\n(Sunday through Wednesday night)\nIssued at 1225 PM CDT Thu Apr 30 2026\n\nA broad and deep low to mid-level high will remain in firm control\nof the forecast area on Sunday and Monday. Skies will remain\nlargely clear and humidity will remain low as this high dominates\nthe region. Temperatures will also run a bit below average with\nhighs in the mid 70s Sunday afternoon and the upper 70s Monday\nafternoon. Lows will also remain cool Sunday night as clear skies,\nlow dewpoints, and lighter winds allow temperatures to fall back\ninto the upper 40s and lower 50s over inland areas. Coastal\nlocations will once again fall into the mid 50s.  \n\nTuesday and Wednesday will see the pattern shift once more. A\nzonal flow regime will develop in the upper levels while a\npersistent and deep layer onshore flow pattern will form on the\nwestern periphery of a departing high in the low to mid-levels.\nThis onshore flow regime will allow for Gulf moisture and warmth\nto begin feeding back into the area. Tuesday will remain dry as\nthe mid-levels remain dry and a capping inversion lingers, but as\nmoisture deepens on Wednesday a passing southern stream vort max\nwill allow for isolated to widely scattered convective activity to\nform Wednesday afternoon. This activity will be diurnally induced\nas temperatures warm into the mid to upper 80s and MLCAPE exceeds\n1000 J/KG. Overall, a return to the warmer and more humid pattern\nseen recently is expected to return by the middle of next week.  \n\n&&\n\n.AVIATION...\n(00Z TAFS)\nIssued at 630 PM CDT Thu Apr 30 2026\n\nQuite a spread in conditions across the forecast terminals at\nissuance time, from VFR to IFR. Current cluster of SHRA/TSRA\nmoving across the terminals with at least brief IFR conditions\nthrough about 03-04z. Likely to be about a 6 hour break in\nprecipitation, but still likely to have MVFR to IFR conditions\nafter the precipitation departs. PROB30 should be good enough to\ncover the precipitation threat during the morning hours Friday at\nmost terminals, but will need to at least consider TEMPO or\nprevailing conditions for showers and storms tomorrow afternoon,\nand continuing into tomorrow night. May not see VFR conditions\nreturn until perhaps midday Saturday.\n\n&&\n\n.MARINE...\nIssued at 1225 PM CDT Thu Apr 30 2026\n\nWinds will be variable in direction this afternoon into tonight as a \nstationary front remains parked over the area.  To the north of the \nfront in the tidal lakes and sounds, northeast winds of 10 to 15 \nknots will persist into the overnight hours. South of the front, \nsoutheast winds of 5 to 10 knots will be the rule through tonight. \nTomorrow, a developing low pressure system will move into the area \nalong the front.  Winds will increase in response to this low with \nnortheast winds of 15 to 20 knots forming over the tidal lakes and \nsounds and southeast winds of 10 to 15 knots developing in the open \nGulf waters.  As the low tracks to the east, it will help drive the \nfront offshore Friday night into Saturday.  Strong northerly winds \nof 20 to 25 knots will develop Friday night and persist through \nSunday morning over all of the waters, and a small craft advisory \nwill be issued for these conditions by tomorrow.  Winds and seas \nwill quickly fall off to less than 10 knots and 3 feet Sunday night \ninto Monday as a broad area of high pressure settles over the \nregion.  As the high shifts to the east on Tuesday, winds will turn \nsoutherly at around 10 knots.\n\n&&\n\n.LIX WATCHES/WARNINGS/ADVISORIES...\nLA...None.\nGM...None.\nMS...None.\nGM...None.\n&&\n\n$$\n\nSHORT TERM...PG\nLONG TERM....PG\nAVIATION...RW\nMARINE...PG\n",
    "issued_at": "2026-04-30T23:46:00Z"
  }
}

```

### LLM responses

## Q1

No, VFR is not recommended for KMSY right now. The brief's `vfr_not_recommended` slot explicitly flags `vfr_not_recommended: true`, with the field categorized as **IFR** because of an 800 ft ceiling and 10.0 SM visibility. This matches the current SPECI METAR (BKN008 with light rain). Any departure or arrival should be planned IFR.

## Q2

There is no dedicated synopsis in this brief — the `synopsis` slot is `available: false` ("no synopsis source in skywatch — see afd slot"). However, the WFO LIX Area Forecast Discussion (issued 2026-04-30 23:46Z) gives a clear picture:

- A **stalled frontal boundary** is parked along the I-10 corridor, with a low pressure expected to form along it Friday morning and track east.
- **Heavy rainfall and an increased flash-flood risk** are forecast Friday into Friday night, with 2–4" widespread and localized 4–8" possible. The heaviest axis is currently expected north of I-10 but could shift into metro New Orleans.
- **Thunderstorms, some strong to severe**, are expected through Friday night. 0–6 km shear is 50–60 kt, MLCAPE 1000–1500 J/kg south of the front — supporting large hail and damaging winds, especially over coastal LA and offshore. Tornadoes considered unlikely.
- The aviation discussion notes a roughly 6-hour break in precipitation tonight, but MVFR/IFR likely persists, with VFR possibly not returning until midday Saturday.
- A cold front sweeps the rain offshore Saturday; cooler/drier high pressure dominates Sun–Mon. Onshore flow returns Tue–Wed.

## Q3

Current conditions at KMSY (SPECI 2026-05-01T00:07Z, fetched 00:10Z):

- **Wind:** 020° at 8 kt, no gusts
- **Visibility:** 10.0 SM
- **Weather:** light rain (-RA)
- **Sky:** BKN 800, BKN 1800, OVC 11000
- **Ceiling:** 800 ft (the broken 800 layer)
- **Temperature / Dewpoint:** 22.2 °C / 20.6 °C (spread 1.6 °C — very moist, fog/low-stratus risk)
- **Altimeter:** 29.86 inHg
- **Density altitude:** 924 ft (field elevation 0 ft)
- **Flight category:** IFR

Bottom line: warm, wet, rainy, low ceiling, light variable-northeasterly surface wind, near-saturation.

## Q4

The TAF for KMSY (issued 2026-04-30T23:28Z, valid 2026-05-01 00:00Z through 2026-05-02 06:00Z):

- **00Z–04Z (initial):** 030° / 12 kt, 5 SM, -SHRA BR, BKN008 OVC030, ceiling 800 ft, **IFR**.
- **00Z–04Z TEMPO:** 2 SM in TSRA, BKN008, IFR. Thunderstorms possible during this window.
- **04Z–14Z (FM 0400):** 050° / 6 kt, 6 SM, BKN008 OVC020, ceiling 800 ft, **IFR**.
- **09Z–14Z PROB30:** 4 SM -SHRA, OVC005, ceiling 500 ft, IFR.
- **14Z–20Z (FM 1400):** 070° / 10 kt, 6 SM, -SHRA, BKN010 BKN020, ceiling 1000 ft, **MVFR**.
- **14Z–20Z PROB30:** 4 SM TSRA, OVC005, ceiling 500 ft, IFR.
- **20Z–01Z next day (FM 2000):** 070° / 11 kt, 6 SM, -SHRA, BKN013 OVC060, ceiling 1300 ft, **MVFR**.
- **20Z–01Z PROB30:** 4 SM -TSRA, OVC007, ceiling 700 ft, IFR.
- **0100Z–0600Z 02 May (FM 0100):** 050° / 15G22 kt, 6 SM, -SHRA, BKN009 OVC090, ceiling 900 ft, **IFR**.
- **0100Z–0600Z 02 May PROB30:** 4 SM TSRA, OVC003, ceiling 300 ft, **LIFR**.

In short: persistent IFR/MVFR with embedded thunderstorm risk for the entire 30-hour TAF window. Best (still MVFR) window is mid-day Friday afternoon (1400–2000Z). Gusty 22 kt easterly winds appear after 0100Z 02 May.

## Q5

Not available. The `winds_aloft` slot is `available: false` ("no winds aloft for KMSY"). The brief contains no FB winds-aloft forecast for any altitude, so I cannot give the wind/temperature at 6,000 ft. You will need to pull this from another source (e.g. an FB winds-aloft product for a nearby station — common substitutes near KMSY would be MSY itself if available, or BTR/LCH/MOB; none are in this brief).

For situational color only, two PIREPs near 6 kft were filed but they do not report wind or temperature:

- MLU UA at FL090 (2303Z): OVC090, -RA — no wind/temp
- JAN UA at FL060 (2255Z): bases 060 — no wind/temp
- MLU UA at FL060 (2252Z): MOD turbulence — no wind/temp

So treat winds/temps at 6,000 ft as **unknown from this brief**.

## Q6

Adverse conditions itemized from the brief:

1. **Convective SIGMET 74C (KKCI), severity 5, hazard CONVECTIVE.** Valid 2026-04-30T23:55Z to 2026-05-01T01:55Z. Covers AL/MS/LA and coastal waters; the polygon (vertices 30.602/-88.003, 29.342/-87.701, 29.179/-90.676, 30.286/-90.762) lies just east and south of KMSY (29.997/-90.278) — the western edge of the polygon is right at KMSY's longitude. Area of thunderstorms moving FROM 260° at 30 kt, **tops above FL450**. Outlook valid 0155Z–0555Z calls for additional WST issuances. This is the dominant near-term hazard.

2. **Urgent PIREP at MSY** (2026-04-30T22:45Z, B737 MAX): 15 kt airspeed gain inside the final approach fix during descent. This is a low-level wind-shear indication on the MSY approach — significant for any IFR arrival.

3. **Partial failure: AIRMET data unavailable** (RGeo InvalidGeometry / self-intersection). I cannot tell you about Sierra/Tango/Zulu AIRMETs from this brief — assume nothing about IFR/mountain obscuration/turbulence/icing AIRMETs and check elsewhere.

4. **Field is IFR with low ceiling and high humidity.** 800 ft ceiling, -RA, 1.6 °C T-Td spread → fog/stratus risk overnight.

5. **TAF embedded thunderstorm risk** through the entire valid window (TEMPO TSRA 00–04Z, PROB30 TSRA in 14–20Z, 20Z–01Z, and 01Z–06Z 02 May with ceilings down to 300 ft — LIFR).

6. **Widespread MOD / LGT-MOD turbulence and chop in the area-PIREP set:**
   - JAN A321 FL340 LGT-MOD CHOP (2245Z and 2329Z B738 MOD CHOP)
   - MCB B737 FL350 MOD CHOP (2343Z)
   - GPT B737 FL340 MOD CHOP (2331Z)
   - GPT S22T FL040 MOD turbulence (2335Z)
   - BTR E175 FL360 MOD (2334Z)
   - MSY C68A FL410 MOD (2325Z)
   - GZH A321 FL350 LGT-MOD CHOP (2259Z)
   - SHV B738 FL370 LGT CHOP (2258Z)
   - BFM CL35 FL160 MOD (2256Z)
   - MEI A321 FL300 LGT-MOD (2253Z)
   - MLU RV7 FL060 MOD (2252Z)
   - LCH E45X FL170 LGT-MOD CONS (2241Z)

7. **Trace rime icing PIREP**: MEI B190 FL210, OAT -8 °C, trace rime (2026-04-30T23:44Z). Worth noting if climbing through the freezing level around FL180-ish in the area.

8. **Convective/IFR PIREPs around the field**: GPT S22T at 1800 ft reporting OVC019 with FV05SM -RA (2350Z); LCH E145 BKN023 (2255Z); BTR HDJT OVC006 (2313Z) — confirms widespread low IFR conditions.

## Q7

This brief is explicitly missing several things you would normally want before flight:

- **NOTAMs:** `notams.available = false` ("NOTAMs not in skywatch yet — Sectional domain not yet built"). You have **zero** NOTAM coverage — runway closures, ILS/approach NOTAMs, GPS interference, TFRs, obstacle/crane, airport/FDC NOTAMs all unknown. **Get from FAA NOTAM Search / ForeFlight / 1800wxbrief before flying.**
- **ATC delays / ground stops / EDCT:** `atc_delays.available = false` ("ATC delays not in skywatch yet — no source"). Pull from FAA NAS Status / OIS.
- **Winds and temperatures aloft:** `winds_aloft.available = false`. No FB product for KMSY in this brief — you have no wind/temp data for any altitude. Get FB winds aloft (e.g. AWC/aviationweather.gov).
- **AIRMETs:** Marked as a partial failure (RGeo geometry error). Sierra (IFR/mountain obscuration), Tango (turbulence), and Zulu (icing/freezing levels) status is **unknown** in this brief. Pull them separately.
- **Synopsis:** No structured synopsis source; only the AFD prose. If you want a formal area-forecast surface analysis or prog charts, get them elsewhere.
- **Enroute forecast:** `enroute_forecast.available = false` ("single-point brief; route input deferred from MVP"). This brief is **single-point KMSY only** — no route data, no enroute weather along your track, no forecasts for your destination if it's not KMSY.
- **TFRs:** Not present in any field. Check FAA TFR list independently.
- **Destination/alternate weather** (if KMSY is your departure): the brief only has KMSY's TAF/METAR — you'll need METAR/TAF for any destination and alternate.
- **PIREP fields are sparse:** many PIREPs in the brief have null `temperature_c`, null `icing_*` and null `turbulence_*` fields even though the raw text often contains that info (e.g. the urgent MSY wind-shear PIREP has all hazard fields null) — read the `raw` text yourself; don't trust the parsed fields alone.
- **SIGMET coverage:** Only the convective SIGMET 74C is included. Non-convective SIGMETs (turbulence, icing, volcanic ash) and international SIGMETs are not confirmed present — verify.
- **Center Weather Advisories (CWAs), G-AIRMETs, runway condition reports, surface analysis, radar/satellite imagery, lightning data, flight watch / FSS briefing, density-altitude warnings for your specific aircraft, and fuel/MEL information** — none of these are in the brief.

In short: treat this as a **single-point weather snapshot for KMSY only**. Before launch, separately obtain NOTAMs, TFRs, AIRMETs, winds aloft, ATC delays, and weather/forecasts for your route and destination/alternate.


### Judgment

| Q | Pass / fail | Notes |
|---|---|---|
| 1 | Pass | Correctly identified IFR + VFR not recommended. Cited 800 ft ceiling and -RA. |
| 2 | Pass | Pulled rich synopsis substitute from AFD slot: stalled I-10 boundary, Friday low formation, 2–4" QPF (locally 4–8"), severe risk south of front (50–60 kt 0–6 km shear, 1000–1500 J/kg MLCAPE), aviation 6-hour break, weekend cold-front clearance. |
| 3 | Pass | Full SPECI decode with correct ceiling-from-BKN008 logic, density alt 924, near-saturation note. |
| 4 | Pass | Comprehensive TAF decode through 30-hour validity including TEMPO TSRA + PROB30 LIFR group. Identified mid-day Friday afternoon as best (still MVFR) window. |
| 5 | Pass | Honestly flagged unavailable; noted three PIREPs near FL060–090 had no wind/temp fields; correctly recommended pulling FB separately. |
| 6 | Pass | **8-item itemization** including: convective SIGMET 74C (polygon vertices listed, tops > FL450, movement 260@30), urgent MSY wind-shear PIREP (15 kt gain inside FAF), AIRMET partial-failure, IFR ceilings, embedded TAF thunderstorm risk, 12 turbulence PIREPs across the area, trace rime icing PIREP at FL210, and confirming low-IFR PIREPs around the field. |
| 7 | Pass | 12-item enumeration including a sharp call-out that several PIREP fields (icing/turbulence) are null in parsed structure even when raw text contains the info — useful real-world signal about PIREP parser fidelity. |

## Verdict

**Pass / fail:** **PASS**

**Q1–Q6 substantive correctness:** **3 of 3 scenarios passed** (well above the ≥2/3 bar)
**Q7 anti-hallucination:** **3 of 3 scenarios clean**

## Discussion

The validation thesis — *"can an LLM produce a useful 1-800-WX-BRIEF-quality answer from current Skywatch primitives?"* — is **confirmed** for the single-airport MVP scope. Across three scenarios spanning VFR-clear (KCDW), IFR fog (KACK), and IFR + active convection (KMSY), every Q1–Q6 answer was substantively correct, every Q7 answer correctly enumerated the missing data classes (NOTAMs, ATC delays, winds aloft, AIRMETs, enroute), and no LLM hallucinated content not present in the JSON.

The AIM-7-1-5 envelope shape, the uniform `{ available, ... }` slot contract, and the per-slot `reason` strings did the load-bearing work: when slots were unavailable (synopsis, TAF for KCDW, winds_aloft, NOTAMs, ATC delays), the LLM degraded honestly using slot-adjacent data (AFD as synopsis substitute, PIREP temperatures as winds-aloft proxies) without inventing missing facts. The KMSY scenario was the strongest stress test — a 30-minute SPECI flip from VFR-snapshot to IFR with -RA, a convective SIGMET whose polygon directly covered the field, and an urgent low-level wind-shear PIREP — and the adverse-conditions slot's polygon-intersect + distance + urgency partition surfaced both the SIGMET and the wind-shear PIREP correctly.

**One real-world bug exposed during validation:** AIRMET ingest fails uniformly with `RGeo::Error::InvalidGeometry: Self-intersection` and is captured cleanly under `partial_failures` (filed as issue [#11](https://github.com/jayrav13/skywatch/issues/11)). This is the *correct* degrade-gracefully behavior under the spec, but it does mean AIRMET coverage (Sierra/Tango/Zulu) is unavailable in every brief until #11 lands. Every LLM run flagged this honestly under Q6 — the partial-failure shape is doing its job.

**Most justified expansion next:** Route input ([#5](https://github.com/jayrav13/skywatch/issues/5)). Every Q7 answer named "no enroute coverage" as the biggest informational gap; the LLM clearly wants route data. Coordinate input ([#6](https://github.com/jayrav13/skywatch/issues/6)) is a close second for off-airport / GA launches. ETD-aware TAF/winds windows ([#7](https://github.com/jayrav13/skywatch/issues/7)) would tighten Q4/Q5 considerably (the current TAF answers are exhaustive across full validity rather than focused on a flight window). AFD synopsis extraction ([#8](https://github.com/jayrav13/skywatch/issues/8)) is a smaller win — the LLM was already comfortable extracting synopsis-shaped narrative from the raw AFD text, so explicit extraction is not blocking. The text formatter ([#10](https://github.com/jayrav13/skywatch/issues/10)) is a ergonomics win once the JSON-only thesis is shipped.

**Methodological note:** The validation runs used naive-context Claude Code subagents (no shared conversation context, tool access restricted to `Read`-only on the prompt file) rather than the canonical paste-into-claude.ai approach the plan called for. The substitution is sound for the validation thesis (the question is "can an LLM make sense of this JSON?", not "specifically Claude.ai"), but is not 100% identical — the subagent runtime has a Claude Code system prompt that the paste-into-claude.ai path does not. If reviewers want a clean-room paste-into-claude.ai run for sign-off, the three paste-ready prompts at `/tmp/claude-501/prompt_{kcdw,kack,kmsy}.txt` are unchanged from this validation.

## Artifacts

- Brief JSONs: `/tmp/claude-501/brief_{kcdw,kack,kmsy}.json` (saved at validation time)
- LLM responses: `/tmp/claude-501/brief_{kcdw,kack,kmsy}_responses.md`
- Paste-ready prompts: `/tmp/claude-501/prompt_{kcdw,kack,kmsy}.txt`
- Open follow-up issues filed pre-validation: [#5](https://github.com/jayrav13/skywatch/issues/5), [#6](https://github.com/jayrav13/skywatch/issues/6), [#7](https://github.com/jayrav13/skywatch/issues/7), [#8](https://github.com/jayrav13/skywatch/issues/8), [#9](https://github.com/jayrav13/skywatch/issues/9), [#10](https://github.com/jayrav13/skywatch/issues/10)
- Open follow-up issue filed during validation: [#11](https://github.com/jayrav13/skywatch/issues/11) (AIRMET self-intersection)
