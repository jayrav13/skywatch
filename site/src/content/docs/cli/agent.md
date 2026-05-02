---
title: agent
description: Install and manage the Skywatch Claude Code subagent.
---

The `skywatch agent` subcommand manages the Claude Code subagent file that enables natural-language aviation weather briefing inside Claude Code.

## Commands

| Command | Description | Example |
|---|---|---|
| `install` | Copy the subagent file to `~/.claude/agents/` | `skywatch agent install` |

## install

```sh
skywatch agent install
```

Copies `skywatch.md` from inside the gem to `~/.claude/agents/skywatch.md`, creating the directory if it does not exist.

### Flags

| Flag | Description |
|---|---|
| `--yes` / `-y` | Overwrite an existing file without prompting |

### Behavior

If `~/.claude/agents/skywatch.md` already exists, the command prompts:

```
~/.claude/agents/skywatch.md exists. Overwrite? [y/N]
```

Enter `y` or `yes` to overwrite, or any other input to skip. Use `--yes` (or `-y`) to bypass the prompt in scripts or CI:

```sh
skywatch agent install --yes
```

After install, the command prints:

```
Installed: /Users/<you>/.claude/agents/skywatch.md
Restart Claude Code (or open a new session) to pick up the agent.
```

### After install

Restart Claude Code or open a new session. The agent activates automatically — no configuration file changes are needed.

See the [Claude Code agent](/skywatch/claude-agent/) page for example interactions, AIM 7-1-5 section coverage, and notes on what the agent does and does not provide.

### Custom agent directory

The install destination can be overridden via the `SKYWATCH_AGENTS_DIR` environment variable:

```sh
SKYWATCH_AGENTS_DIR=/custom/path skywatch agent install
```
