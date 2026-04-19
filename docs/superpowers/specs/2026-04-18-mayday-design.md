# Mayday — Design Spec

**Date:** 2026-04-18
**Status:** Draft, pending review
**Author:** Jay (with Claude)

## Goal

Give an agent (or developer, or pilot) a one-shot way to ask:

> *"Is anything squawking an emergency code (7500/7600/7700) within X nm of this point right now?"*

and get back a small, classified, actionable list.

## Design Principles (applied from north star)

- **Agent-first.** Caller invokes one tool, gets a deterministic JSON list, decides what to do. No watch loops in the gem; cadence belongs to the caller.
- **Developer-friendly underneath.** Library API mirrors `Skywatch.flights`: keyword args, returns model objects, no globals.
- **Encapsulate domain knowledge.** The agent shouldn't have to know that `7600` means radio failure. Mayday wraps each emergency state vector in a model that exposes `emergency_type` (`:hijack` / `:radio_failure` / `:general`) and a human label.
- **Compose, don't duplicate.** Radar already has the OpenSky source, the bbox math, and the `emergency?` predicate. Mayday is a thin filter + classifier + presenter on top.

## Scope

### In scope

1. **`Mayday::Models::Emergency`** — wraps a `Radar::Models::StateVector`, classifies by squawk, exposes derived `emergency_type` and `label`.
2. **`Mayday::Sources::Emergency`** — `near(lat:, lon:, radius_nm:)` returns `[Emergency, ...]` by composing radar's bbox + proximity + emergency filter.
3. **`Mayday::Formatters::Text.format_emergency(emergency)`** — single-emergency text rendering.
4. **CLI:** `skywatch mayday near LAT LON [--radius N]` — text or JSON output, same TTY auto-detection as the rest of the gem.
5. **Convenience API:** `Skywatch.mayday(lat:, lon:, radius_nm: 100)` — returns `[Emergency, ...]`.

### Out of scope (deliberately)

- **Watch / loop modes.** Callers (agent, scheduler, developer) handle cadence.
- **Global / unscoped scans.** Add only when a real use case appears; `near` covers the agent's typical question.
- **Station code → lat/lon resolution.** No station DB in the gem; `near` takes literal lat/lon to mirror `radar flights`.
- **Anomaly detection** (rapid descent, transponder dropout, off-course). Different problem; if ever, separate domain.
- **Historical / past emergencies.** OpenSky free tier is current-state only.
- **Alerting / notification side effects.** Caller's job.

## Architecture

```
lib/skywatch/mayday/
├── models/emergency.rb       # wraps StateVector + classification
├── sources/emergency.rb      # near(lat:, lon:, radius_nm:) composition
└── formatters/text.rb        # format_emergency
```

**Data flow:**

```
Skywatch.mayday(lat:, lon:, radius_nm:)
  → Mayday::Sources::Emergency.new.near(...)
    → Radar::Analysis::Proximity.bbox(lat, lon, radius_nm: …)
    → Radar::Sources::Opensky.new.states_bbox(**bbox)        # cached 15s
    → Radar::Analysis::Proximity.within_radius(vectors, …)
    → vectors.select(&:emergency?)                           # already-existing predicate
    → vectors.map { |sv| Mayday::Models::Emergency.new(sv) }
```

No new HTTP client, no new cache, no new bbox math.

## API Endpoints

None. Mayday is pure composition over existing radar primitives. The OpenSky endpoint (`/api/states/all`) is unchanged.

## New Components

### `Skywatch::Mayday::Models::Emergency`

Wraps a single emergency `StateVector`.

```ruby
emergency = Skywatch::Mayday::Models::Emergency.new(state_vector)

emergency.state_vector       # the underlying StateVector (developer escape hatch)
emergency.squawk             # "7700"
emergency.emergency_type     # :general
emergency.label              # "GENERAL EMERGENCY"

# Convenience delegations to the underlying state vector:
emergency.callsign           # "UAL1234"
emergency.icao24             # "abc123"
emergency.latitude           # 40.6892
emergency.longitude          # -74.1745
emergency.altitude_ft        # 32000
emergency.velocity_kt        # 420
emergency.heading_deg        # 270  (delegates to true_track_deg)
emergency.on_ground          # false

emergency.to_h
# {
#   callsign: "UAL1234", icao24: "abc123", squawk: "7700",
#   emergency_type: :general, label: "GENERAL EMERGENCY",
#   latitude: 40.6892, longitude: -74.1745,
#   altitude_ft: 32000, velocity_kt: 420, heading_deg: 270,
#   on_ground: false
# }

emergency.to_json
```

**Classification table (lives as a constant on the model):**

| squawk | emergency_type | label |
|---|---|---|
| `"7500"` | `:hijack` | `HIJACK` |
| `"7600"` | `:radio_failure` | `RADIO FAILURE` |
| `"7700"` | `:general` | `GENERAL EMERGENCY` |

Initializer accepts a `StateVector` and raises `ArgumentError` if the vector is not emergency-squawking. Construction is the only enforcement point — once an `Emergency` exists, callers can trust its squawk is one of the three.

### `Skywatch::Mayday::Sources::Emergency`

```ruby
class Emergency
  def near(lat:, lon:, radius_nm: 100)
    bbox = Radar::Analysis::Proximity.bbox(lat, lon, radius_nm: radius_nm)
    vectors = Radar::Sources::Opensky.new.states_bbox(**bbox)
    in_radius = Radar::Analysis::Proximity.within_radius(vectors, lat: lat, lon: lon, radius_nm: radius_nm)
    in_radius.select(&:emergency?).map { |sv| Models::Emergency.new(sv) }
  end
end
```

No `initialize` arg needed — opensky source is constructed inline because it owns its own cached HTTP client.

### `Skywatch::Mayday::Formatters::Text`

```ruby
def self.format_emergency(emergency)
  # Multi-line block similar to format_sigmet:
  #   MAYDAY: GENERAL EMERGENCY (squawk 7700)
  #     Callsign: UAL1234   ICAO24: abc123
  #     Position: 40.6892, -74.1745   Alt: FL320   Spd: 420kt   Hdg: 270°
end
```

### CLI: `skywatch mayday near LAT LON`

Lives in a new `Skywatch::Mayday::CLI` Thor class, registered alongside `weather` and `radar` in `Skywatch::CLI`.

```bash
skywatch mayday near 40.6892 -74.1745                # default radius 100nm
skywatch mayday near 40.6892 -74.1745 --radius 250
skywatch mayday near 40.6892 -74.1745 --format json
```

Empty result → `"No emergencies within 100nm of 40.6892, -74.1745"` (text mode) or `[]` (JSON mode).

### Convenience API

Add to `Skywatch` top-level:

```ruby
def self.mayday(lat:, lon:, radius_nm: 100)
  Mayday::Sources::Emergency.new.near(lat: lat, lon: lon, radius_nm: radius_nm)
end
```

## Edge Cases

| Case | Behavior |
|---|---|
| State vector with `nil` squawk | Skipped — `emergency?` returns false. |
| State vector with `nil` lat or lon | Skipped — fails `within_radius`. |
| OpenSky returns `{"states": null}` | Empty list returned (existing radar source already handles this). |
| OpenSky 5xx / network error | Propagates as `Skywatch::ApiError` (existing shared HTTP behavior); CLI catches and prints `Error: …`. |
| Radius ≤ 0 | Returns empty list (bbox collapses; nothing matches). No special validation needed. |
| Lat/lon out of valid range | OpenSky returns no states; we return empty. No client-side validation. |

## Testing

Fixture-based, following the existing pattern.

**New fixture:**
- `spec/fixtures/opensky/states_bbox_emergencies.json` — a small bbox response containing:
  - 1 normal aircraft (squawk `"1200"`)
  - 1 hijack (`"7500"`)
  - 1 radio failure (`"7600"`)
  - 1 general emergency (`"7700"`)
  - 1 emergency aircraft *outside* the radius circle (inside bbox but >radius distance) — must be filtered out by proximity
  - 1 emergency aircraft with `nil` position — must be filtered out

**New spec files:**
- `spec/mayday/models/emergency_spec.rb` — classification, label, delegations, `to_h`/`to_json`, ArgumentError on non-emergency vector
- `spec/mayday/sources/emergency_spec.rb` — webmocks the OpenSky bbox call, asserts filtering and wrapping
- `spec/mayday/formatters/text_spec.rb` — formatter output snapshot
- `spec/mayday_spec.rb` — `Skywatch.mayday(...)` end-to-end through fixtures

**Modified:**
- `spec/cli_spec.rb` — `mayday near` text + JSON modes, empty-result message

**Live smoke (optional, post-merge):**
```bash
bundle exec exe/skywatch mayday near 40.6892 -74.1745 --radius 250 --format json
```

## Existing-code Reuse Confirmation

Already in `lib/skywatch/radar/models/state_vector.rb`:
- `EMERGENCY_SQUAWKS = %w[7500 7600 7700].freeze`
- `def emergency?` predicate

Mayday uses both. The `EMERGENCY_SQUAWKS` constant stays where it is (radar owns the raw vector schema). Mayday introduces only the type classification (`:hijack` / `:radio_failure` / `:general`) and the human label.

## Naming

- Module: `Skywatch::Mayday`
- Convenience: `Skywatch.mayday(lat:, lon:, radius_nm:)`
- CLI: `skywatch mayday near LAT LON`

"Mayday" is the radio distress call and matches the project's aviation-call-sign convention (Briefer, Radar, Nimbus, Sectional, Livewire, Blackbox). Internally, the model is `Emergency` rather than `Mayday` to keep the noun grammatical (`emergency.label`, not `mayday.label`).
