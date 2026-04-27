# Skywatch.brief — design

**Status:** draft
**Date:** 2026-04-27
**Owner:** Jay Ravaliya

## Goal

Build a single composition layer, `Skywatch::Brief` + `Skywatch.brief`, that produces an [AIM 7-1-5](https://www.faa.gov/air_traffic/publications/atpubs/aim_html/chap7_section_1.html)-shaped weather brief for a single airport, composed from existing Briefer and Nimbus primitives.

The shipping bar is **validation success**, not feature completeness. The thesis we are testing is:

> *Can an LLM produce a useful 1-800-WX-BRIEF-quality answer from the Skywatch primitives we have built today?*

If yes, we expand (route input, coord input, ETD-aware briefs, NOTAMs via Sectional, etc.). If no, we have a concrete signal about whether the gap is data quality, data shape, or both — and we re-rank the post-Nimbus roadmap accordingly.

## Non-goals (deferred to filed GitHub issues)

| Deferred | Reason |
|---|---|
| Route input (`from:`/`to:`) | Validate concept first; route geometry is a confounding variable. |
| Coordinate input (`at: [lat, lon]`) | Same. Adds nearest-station-lookup logic we don't need to validate the thesis. |
| ETD-aware briefs (`departing_at:`) | Same. Adds TAF-group selection and winds-aloft interpolation logic. |
| AFD synopsis sub-paragraph extraction | Brittle parsing; full AFD text is already useful in a supplementary slot. |
| Mayday and Radar inclusion | Outside AIM 7-1-5 scope; intentionally excluded. |
| Text formatter for human consumption | LLM is the validation consumer; JSON only suffices. |
| Automated Claude API validation runner | Human judgment is the validation; automating it doesn't make the judgment more reliable. |

## Anchor — AIM 7-1-5 Standard Briefing elements

The brief envelope mirrors the canonical 9-element sequence defined in [AIM § 7-1-5](https://faraim.org/faa/aim/chapter-7/section-7-1-5.html):

1. Adverse Conditions
2. VFR Flight Not Recommended
3. Synopsis
4. Current Conditions
5. En Route Forecast
6. Destination Forecast
7. Winds Aloft
8. NOTAMs
9. ATC Delays

Coverage of these elements with current Skywatch primitives:

| # | Element | Coverage |
|---|---|---|
| 1 | Adverse Conditions | ✅ SIGMETs, AIRMETs, urgent PIREPs (Briefer); convective alerts, storm reports (Nimbus). ⚠️ TFRs missing. |
| 2 | VFR Flight Not Recommended | ✅ Derivable from `Briefer::Analysis::FlightCategory`. |
| 3 | Synopsis | ⚠️ No direct primitive. AFD is the closest analogue; exposed as supplementary slot. |
| 4 | Current Conditions | ✅ METAR + non-urgent PIREPs. |
| 5 | En Route Forecast | ⚠️ Single-point brief — no route to forecast across. |
| 6 | Destination Forecast | ✅ TAF. |
| 7 | Winds Aloft | ✅ Winds aloft. |
| 8 | NOTAMs | ❌ Sectional domain not yet built. |
| 9 | ATC Delays | ❌ No source in Skywatch. |

Six slots fillable, one supplementary, three statically unavailable in MVP. This coverage profile is *exactly the validation signal we want*: the LLM must use the six, lean on the supplementary, and explicitly disclaim the three.

## Architecture

`Skywatch::Brief` is a pure composition layer over existing primitives. No new data sources.

```
Skywatch.brief(airport: "KCDW")
   │
   ├─→ Briefer::Sources::Metar.fetch("KCDW")           ─┐
   ├─→ Briefer::Sources::Taf.fetch("KCDW")              │
   ├─→ Briefer::Sources::Pirep.fetch("KCDW")            │
   ├─→ Briefer::Sources::WindsAloft.fetch("KCDW")       │ existing primitives,
   ├─→ Briefer::Sources::Sigmet.fetch                   │ no changes
   ├─→ Briefer::Sources::Airmet.fetch                   │
   ├─→ Briefer::Sources::Afd.fetch(<wfo>)               │
   ├─→ Nimbus::Sources::Alerts.fetch(at: [lat, lon])    │
   └─→ Nimbus::Sources::StormReport.fetch               ─┘
   │
   └─→ Brief.new(...) → Brief#to_h (AIM-9 envelope)
```

### File layout

```
lib/skywatch/brief/
├── models/brief.rb                # the envelope; #to_h produces the AIM-9 hash
├── analysis/composer.rb           # orchestrates fetches, builds slots, handles per-slot errors
├── analysis/airport_locator.rb    # airport → [lat, lon] (METAR-derived) and airport → wfo
├── analysis/adverse_filter.rb     # SIGMET/AIRMET polygon-intersect + PIREP/storm-report distance filtering
└── cli.rb                         # Thor subcommand: skywatch brief AIRPORT
spec/skywatch/brief/...
docs/superpowers/specs/2026-04-27-skywatch-brief-design.md
docs/superpowers/specs/2026-04-27-skywatch-brief-validation-results.md  # filled during validation
```

`Brief` is a top-level domain alongside Briefer/Nimbus/Mayday/Radar — but unlike them, it has no `sources/` subdirectory. That is the structural signal that it is a composition layer, not a new data domain.

### Two pieces of new infrastructure (small, justified)

1. **Airport → `[lat, lon]`** — read directly from the METAR result the composer already fetched. Zero extra I/O.
2. **Airport → WFO** — derived from `api.weather.gov/points/{lat,lon}` → `properties.cwa`. Same endpoint already used implicitly by the AFD source. Cached via existing `Shared::Cache` (1-day TTL — WFO assignments don't change).

## Data model

### Top-level shape

Every AIM slot follows a uniform contract: `{ available: bool, ... }`. That predictability is for the LLM — its only branching logic per slot is `if slot[:available]`.

```ruby
{
  airport: "KCDW",
  coordinates: [40.875, -74.282],
  wfo: "OKX",
  fetched_at: "2026-04-27T18:32:14Z",
  aim_section: "7-1-5",                    # anchor for downstream agents

  # AIM 7-1-5 elements, in canonical order:
  adverse_conditions:    { available: ..., ... },
  vfr_not_recommended:   { available: ..., ... },
  synopsis:              { available: ..., ... },
  current_conditions:    { available: ..., ... },
  enroute_forecast:      { available: ..., ... },
  destination_forecast:  { available: ..., ... },
  winds_aloft:           { available: ..., ... },
  notams:                { available: ..., ... },
  atc_delays:            { available: ..., ... },

  # Supplementary, outside AIM-9:
  afd:                   { available: ..., ... }
}
```

### Slot specifications

| Slot | When `available: true` | When `available: false` |
|---|---|---|
| `adverse_conditions` | `{ available: true, items: [{ kind: "sigmet"\|"airmet"\|"pirep"\|"convective_alert"\|"storm_report", ...existing to_h... }, ...], partial_failures: [{source:, reason:}, ...] }`. Items merged from Briefer (SIGMETs/AIRMETs filtered by polygon intersect with airport coord; urgent PIREPs within 100 nm) and Nimbus (convective alerts at coord; storm reports within 100 nm, last 6 hr). Empty `items` list still means `available: true, items: []` — diagnostic ("we looked, nothing adverse"). `partial_failures` is always present, empty array when no failures. | Only if every adverse source failed. `reason: "all adverse sources failed: ..."` |
| `vfr_not_recommended` | `{ available: true, vfr_not_recommended: bool, category: "VFR"\|"MVFR"\|"IFR"\|"LIFR", explanation: "ceiling 800 ft, vis 2 SM" }`. Derived from `Briefer::Analysis::FlightCategory`. Rule: IFR or LIFR → `vfr_not_recommended: true`; MVFR → `false` with "marginal" explanation; VFR → `false`. | Never. METAR-fail is a hard-fail of the whole brief, so this slot is always available when the brief is returned at all. |
| `synopsis` | (never `true` in MVP) | `{ available: false, reason: "no synopsis source in skywatch — see afd slot" }`. Hardcoded. |
| `current_conditions` | `{ available: true, metar: {...}, pireps: [{...}, ...] }`. PIREPs filtered to within 100 nm, non-urgent only (urgent PIREPs go to `adverse_conditions`). PIREP fetch failure leaves `pireps: []`, slot stays available. | Never. METAR-fail is a hard-fail of the whole brief, so this slot is always available when the brief is returned at all. |
| `enroute_forecast` | (never `true` in MVP) | `{ available: false, reason: "single-point brief; route input deferred from MVP" }`. Hardcoded. |
| `destination_forecast` | `{ available: true, taf: {...} }`. TAF for the airport, full `to_h`. | TAF fetch failed or no TAF available. |
| `winds_aloft` | `{ available: true, station: "...", forecasts: [...] }`. Winds aloft for the nearest winds-aloft station. | Lookup or fetch failed. |
| `notams` | (never `true` in MVP) | `{ available: false, reason: "NOTAMs not in skywatch yet — Sectional domain not yet built" }`. Hardcoded. |
| `atc_delays` | (never `true` in MVP) | `{ available: false, reason: "ATC delays not in skywatch yet — no source" }`. Hardcoded. |
| `afd` (supplementary) | `{ available: true, wfo: "OKX", text: "...", issued_at: "..." }`. Full AFD text. | WFO lookup failed or AFD fetch failed. |

### Design notes

- **Pass-through on existing models.** Every fetched primitive renders via its existing `to_h`. No new normalization. The brief's job is composition, not reshaping. The `kind:` discriminator on `adverse_conditions.items` is the only addition.
- **Four slots are statically `available: false`.** Synopsis, en-route forecast, NOTAMs, ATC delays — these aren't even attempted; they have hardcoded reasons. This is *also* how the validation report will read: "the LLM correctly identified these gaps and didn't hallucinate."
- **`aim_section: "7-1-5"`** is a literal field. A downstream agent (or future Claude API caller) sees exactly which canonical structure they're looking at, and lets us version-bump the envelope cleanly if AIM 7-1-5 ever gets renumbered.

## Composition logic

`Skywatch::Brief::Analysis::Composer` orchestrates the fetches, derives the slots, and wraps each slot's outcome. Sequential, not parallel — Ruby threading + Faraday is workable but premature for a validation MVP. (If brief execution exceeds ~5s in practice, parallelization becomes a follow-up.)

### Fetch order

1. **METAR fetch.** Required first — yields the airport's `latitude`/`longitude`. If METAR returns empty or 404, the whole brief raises `Skywatch::Error("no METAR for #{airport}")`. This is the only hard-fail; everything else degrades to `available: false`.
2. **WFO lookup.** `api.weather.gov/points/{lat,lon}` → `properties.cwa`. Wrapped — failure makes `afd: { available: false }`.
3. **Independent fetches** (each wrapped in a per-slot try/rescue):
   - `Briefer::Sources::Taf.fetch(airport)` → `destination_forecast`
   - `Briefer::Sources::Pirep.fetch(airport, radius_nm: 100)` → split across `current_conditions` (informational PIREPs) and `adverse_conditions` (urgent PIREPs)
   - `Briefer::Sources::WindsAloft.fetch(airport)` → `winds_aloft`
   - `Briefer::Sources::Sigmet.fetch` + filter → `adverse_conditions`
   - `Briefer::Sources::Airmet.fetch` + filter → `adverse_conditions`
   - `Briefer::Sources::Afd.fetch(wfo)` → `afd`
   - `Nimbus::Sources::Alerts.fetch(at: [lat, lon])` → `adverse_conditions` (warnings/watches)
   - `Nimbus::Sources::StormReport.fetch` + filter → `adverse_conditions`
4. **Derivations** (in-memory, no I/O):
   - `vfr_not_recommended` from METAR via `Briefer::Analysis::FlightCategory`
   - `current_conditions` assembled from METAR + non-urgent PIREPs
   - `adverse_conditions.items` assembled from urgent PIREPs + filtered SIGMETs + filtered AIRMETs + convective alerts + recent storm reports

### Locators and filters

| Concern | Approach |
|---|---|
| airport → `[lat, lon]` | Read from the METAR result already fetched. Zero extra I/O. |
| airport → `wfo` | `api.weather.gov/points/{lat,lon}` → `properties.cwa`. Cached. |
| SIGMET/AIRMET filtering | rgeo polygon-intersect: does the airport coord fall inside the product's geometry? Each model already exposes its geometry. |
| PIREP / storm-report filtering | `Radar::Analysis::Proximity.distance_nm(...)` ≤ 100 nm. Reuse the existing helper — no new geometry code. |
| PIREP urgency partition | Existing `Briefer::Models::Pirep` exposes type/severity. Urgent → `adverse_conditions`; informational → `current_conditions`. |

### VFR-not-recommended rule

```
if FlightCategory.from(metar) in [:lifr, :ifr]
  vfr_not_recommended: true,  category: <upcased>,  explanation: "<ceil>, <vis>"
elsif :mvfr
  vfr_not_recommended: false, category: "MVFR",     explanation: "marginal — <ceil>, <vis>"
else
  vfr_not_recommended: false, category: "VFR",      explanation: "VFR conditions"
end
```

### Per-slot error wrapping

```ruby
def wrap(slot_name)
  yield
rescue StandardError => e
  { available: false, reason: "fetch failed: #{e.class}: #{e.message}" }
end
```

Applied uniformly. The composer never raises (except METAR hard-fail).

### Caching

Every fetch already runs through `Shared::Cache` (configured per-source TTL). The composer adds nothing — calling the brief twice within the existing TTLs is automatically cheap.

## CLI

```bash
skywatch brief KCDW              # JSON to stdout (canonical, agent-first)
skywatch brief KCDW --format json   # explicit, same as default
```

Wired as a top-level Thor subcommand alongside `weather`, `mayday`, `nimbus`, `radar`. No `--format text` for MVP — the LLM is the consumer of the validation, not a human terminal user. A text formatter is a follow-up.

## Error handling

| Failure | Behavior |
|---|---|
| Invalid airport / METAR returns empty | `Skywatch::Error("no METAR for #{airport}")` raised at the Ruby API; CLI prints to stderr and exits non-zero. Only hard-fail. |
| Any other source fetch fails | Slot becomes `{ available: false, reason: "fetch failed: <ClassName>: <message>" }`. Brief still returns. |
| WFO lookup fails | `afd: { available: false }`. Everything else continues. |
| Adverse-source partial failure | `adverse_conditions.items` includes what succeeded; the slot stays `available: true`; the failed sources are noted in `adverse_conditions.partial_failures: [{ source:, reason: }, ...]` (empty array when no failures). |

The `partial_failures` convention on adverse is the only place the uniform `available: bool` contract bends, and it bends to preserve the *meaning* of `available: true` — it must mean "we got a real read on adverse conditions," which it doesn't if half the sources silently failed. A non-empty `partial_failures` is the LLM's signal "this brief is incomplete on adverse."

## Testing strategy

Three layers, scaling cheap to expensive:

### 1. Unit specs (RSpec, fixture-backed via WebMock)

- `Composer` orchestration: each slot's success path, each slot's failure path, the METAR-hard-fail, the partial-failures aggregation.
- `AirportLocator`: METAR-derived lat/lon, NWS points → WFO (cached), failure modes.
- VFR-not-recommended derivation: VFR / MVFR / IFR / LIFR + missing-METAR.
- Adverse filtering: SIGMET polygon-intersect (in-region vs out-of-region), PIREP partitioning (urgent vs informational), distance-based filtering, empty-list case.
- Brief envelope: shape contract — every slot is `{ available: bool, ... }`, every hardcoded-unavailable slot has the right reason string.

### 2. Integration spec

One spec: full `Skywatch.brief(airport: "KCDW")` end-to-end with all sources stubbed via WebMock, asserting the full JSON envelope against a frozen fixture. Catches shape regressions cheaply.

### 3. Validation report (committed markdown, not RSpec)

- File: `docs/superpowers/specs/2026-04-27-skywatch-brief-validation-results.md`
- Three airport scenarios picked to stress different parts of the rubric:
  1. **A VFR-clear airport** (e.g., KCDW on a clear day) — easy case; brief should read cleanly.
  2. **An IFR airport** (picked at validation time based on real conditions) — tests `vfr_not_recommended: true` path and IFR-relevant adverse handling.
  3. **An airport with active convective alerts** (picked at validation time) — tests Nimbus integration and the most safety-critical adverse path.
- For each scenario: timestamp of capture, the captured JSON brief, the canonical 7-question prompt, the LLM's response, a pass/fail call.

### Canonical 7-question protocol (frozen for reproducibility)

1. *Is VFR flight recommended for this airport right now?*
2. *What's the synopsis / weather pattern in the area?*
3. *What are the current conditions on the field?*
4. *What's the destination/terminal forecast?*
5. *What are the winds and temperature at 6000 ft?*
6. *What adverse conditions should I worry about?*
7. *What's NOT in this brief that I'd need to get from elsewhere before I fly?*

### Validation acceptance criteria

**Pass** if, across the three scenarios:
- Q1–Q6: LLM answers are substantively correct (pilot-grade judgment) on at least 2 of 3 scenarios.
- Q7 (anti-hallucination): LLM correctly identifies NOTAMs and ATC delays as not-in-brief on **all 3 scenarios**. This is the load-bearing test — if the LLM hallucinates NOTAMs, the whole envelope shape was for nothing.

**Fail** if:
- Any Q7 hallucination — the `available: false, reason: ...` contract isn't doing its job; we'd need to revisit the contract or the prompt before expanding.
- Multiple Q1–Q6 substantive errors across scenarios — the data we have isn't sufficient regardless of shape; that's a "go research more sources before expanding" signal, and the lightning/smoke/sectional priorities re-rank accordingly.

Either outcome is informative — that is the point of running this MVP at all.

## Follow-up GitHub issues to file

(File after spec is approved, before implementation begins.)

1. Route-input briefs (`from:`/`to:`) — option B from input-scope question.
2. Coordinate-input briefs (`at: [lat, lon]`) — option B from input-identifier question.
3. ETD-aware briefs (`departing_at:`) — option B from time-scope question.
4. AFD synopsis sub-paragraph extraction — option C from synopsis question.
5. Text formatter for `skywatch brief --format text`.
6. Parallelize composer fetches if `Skywatch.brief` exceeds ~5s in practice.

(One issue or several — decide at filing time based on what overlaps.)
