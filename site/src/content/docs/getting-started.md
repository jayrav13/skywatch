---
title: Getting started
description: Install the Skywatch Ruby gem and run your first aviation weather brief in under a minute.
---

## Requirements

- Ruby 3.2 or newer
- No API keys needed for core functionality — all data comes from public FAA, NWS, and ADS-B endpoints

## Install

```sh
gem install skywatch
```

## First commands

Confirm the install:

```sh
skywatch --help
```

Fetch an AIM 7-1-5 weather brief for Caldwell (KCDW):

```sh
skywatch brief KCDW
```

The brief is printed as JSON. Fields follow AIM section 7-1-5 order: adverse conditions, VFR-not-recommended flag, current conditions, destination forecast, winds aloft, area forecast discussion, and placeholder slots for NOTAMs and ATC delays (not yet available).

## Optional: install the Claude Code subagent

If you use Claude Code, you can install the Skywatch subagent so you can ask for briefs in plain English:

```sh
skywatch agent install
```

Then open (or restart) Claude Code and try:

```
Give me a weather brief for KCDW
```

The agent invokes the CLI, parses the JSON, and presents the brief in AIM 7-1-5 order. See the [Claude Code agent](/skywatch/claude-agent/) page for details.

## Next steps

- [CLI reference — brief](/skywatch/cli/brief/) — all brief flags and examples
- [CLI reference — weather](/skywatch/cli/weather/) — METARs, TAFs, SIGMETs, AIRMETs, and more
- [Claude Code agent](/skywatch/claude-agent/) — natural-language briefing via the subagent
