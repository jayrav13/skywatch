---
title: Overview
description: Aviation situational awareness toolkit — real-time weather, flight tracking, and AIM 7-1-5 brief composition from public FAA/NWS/ADS-B data.
---

import { Card, CardGrid, LinkButton } from '@astrojs/starlight/components';

Skywatch is an aviation situational awareness toolkit built as a Ruby gem. It pulls real-time weather and traffic data from public FAA, NWS, and ADS-B sources — no API keys, no subscriptions. Use it from the command line, from a Ruby script, or let a Claude Code subagent compose a full AIM 7-1-5 preflight brief in natural language.

## What's possible

<CardGrid>
  <Card title="Get a weather brief" icon="document">
    Compose a full AIM 7-1-5 preflight briefing for any airport — adverse conditions, current METAR, TAF, winds aloft, Area Forecast Discussion, and more.

    ```sh
    skywatch brief KCDW
    ```
  </Card>
  <Card title="Plan a flight" icon="rocket">
    Add a destination and a departure time for a corridor-aware route brief. Skywatch checks adverse conditions along the entire route.

    ```sh
    skywatch brief KCDW --to KACY \
      --departing-at "2026-05-02T13:00:00-04:00"
    ```
  </Card>
  <Card title="Ask Claude" icon="seti:ai">
    Install the Skywatch Claude Code subagent and ask in plain English. The agent calls the CLI, parses the JSON, and presents the brief in AIM 7-1-5 order.

    ```
    "Give me a weather brief for KCDW"
    "What are conditions from KCDW to KACY at 1pm tomorrow?"
    ```
  </Card>
</CardGrid>

<LinkButton href="/skywatch/getting-started/" variant="primary">Get started</LinkButton>
<LinkButton href="/skywatch/cli/brief/" variant="secondary">CLI reference</LinkButton>
