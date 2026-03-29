---
name: Skywatch Architecture
description: Multi-agent aviation system — tracon orchestrator + 7 subagent gems (briefer, radar, mayday, nimbus, livewire, sectional, blackbox)
type: project
---

Skywatch is a multi-agent system for US aviation situational awareness. Design spec at `docs/superpowers/specs/2026-03-29-skywatch-design.md`.

**Architecture:** tracon (orchestrator) + 7 subagent gems, each with its own CLI. No cross-gem Ruby dependencies — coordination via CLI invocations and JSON output. Dual-mode: standalone agent (Claude API) or Claude Code skill (/skywatch).

**Build order:** briefer → radar → mayday → tracon → nimbus → sectional → livewire → blackbox

**Why:** Hobbyist aviation awareness — real-time weather, traffic, emergencies, ATC. All public/free data sources (most need no API key).

**How to apply:** Follow the gem contract in the design spec. Each gem follows identical structure (exe/, lib/, sources/, models/, analysis/, formatters/, spec/).
