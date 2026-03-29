---
name: Briefer Status
description: Briefer gem build progress — Phases 1-2 done, mid-Phase 3 (Sigmet model + Geometry done, needs Airmet/TFR/NOTAM sources + CLIs)
type: project
---

**Completed:** Phases 1 (Foundation) and 2 (Core Weather) — 31 commits, 164 passing specs.
- Sources: Metar, Taf, Pirep, WindsAloft
- Models: Metar, Taf, TafGroup, Pirep, WindsAloft, Position, Sigmet, Airmet
- Analysis: FlightCategory, CrosswindCalculator
- Geometry module (rgeo integration)
- CLI commands: metar, taf, pireps, winds, crosswind, categories
- Cache layer (memory-based with TTLs)

**In progress — Phase 3 (Hazards & NOTAMs):**
- Done: Sigmet model, Airmet model, Geometry module (rgeo)
- Remaining: Sigmet source, Airmet source, TFR source+model, NOTAM source+model, AreaForecast source, CLI commands for all hazard types

**Why:** Briefer is the first and most mature subagent. Finishing it unblocks radar and the rest of the skywatch build order.

**How to apply:** Continue Phase 3 TDD — sources and CLI commands for hazards. Then Phases 4-6 per BRIEFER_PLAN.md §13.
