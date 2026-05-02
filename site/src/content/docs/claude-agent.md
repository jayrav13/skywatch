---
title: Claude Code agent
description: Install and use the Skywatch Claude Code subagent for natural-language AIM 7-1-5 aviation weather briefings.
---

## What the subagent does

The Skywatch Claude Code subagent is a briefer, not a commander. It is modeled on FAA AIM section 7-1-5. When you ask for a weather brief, it:

1. Calls `skywatch brief` with the airport, coordinates, or route you specify
2. Parses the JSON output
3. Presents the result in formal AIM 7-1-5 section order

It surfaces objective data — including the formal **VFR FLIGHT NOT RECOMMENDED** advisory when the METAR warrants it — but never tells you whether to fly. The pilot makes that decision.

All data comes exclusively from the `skywatch` CLI. The agent does not fabricate weather data and does not consult any other source.

## Install

```sh
skywatch agent install
```

The command copies `agents/skywatch.md` from the gem to `~/.claude/agents/skywatch.md`. Claude Code picks up agents from that directory automatically.

If a file already exists at that path, the command prompts before overwriting:

```
~/.claude/agents/skywatch.md exists. Overwrite? [y/N]
```

To skip the prompt:

```sh
skywatch agent install --yes
```

After install, restart Claude Code (or open a new session) to activate the agent.

## Example interactions

Ask in plain English — the agent resolves the intent and calls the CLI:

```
Give me a weather brief for KCDW.
```

```
What are VFR conditions from KCDW to KACY departing at 1pm tomorrow?
```

```
Weather for 40.688, -74.174 — I'm departing in two hours.
```

```
Preflight weather for JFK.
```

## AIM 7-1-5 sections the agent presents

The agent presents all ten AIM 7-1-5 slots in order, noting availability for each:

| Section | Status |
|---|---|
| Adverse conditions | Live (SIGMETs, AIRMETs, PIREPs, storm reports, smoke) |
| VFR flight not recommended | Live (derived from active METAR) |
| Synopsis | Unavailable — see Area Forecast Discussion |
| Current conditions | Live (METAR) |
| En-route forecast | Live for route briefs; not applicable for single-point |
| Destination forecast | Live (TAF) |
| Winds aloft | Live |
| NOTAMs | Unavailable — check 1800wxbrief.com |
| ATC delays | Unavailable — check fly.faa.gov/ois |
| Area Forecast Discussion | Live (WFO narrative) |

## What is NOT in the agent yet

The following are not yet available in Skywatch and the agent notes them explicitly rather than omitting them silently:

- **NOTAMs** — the Sectional domain is not yet built
- **ATC delays** — no public structured source integrated yet
- **Structured synopsis** — the AIM synopsis slot is filled by the Area Forecast Discussion

These are tracked as open issues in the [GitHub repository](https://github.com/jayrav13/skywatch).
