# Agents (custom abstraction)

Markdown definitions of custom agents plus `agent-chain.yml` describing agent
teams / chains.

> **Note:** Pi has no native "agents" resource type. Pi natively loads
> `skills/`, `extensions/`, `prompts/`, and `themes/`. This directory is
> deployed (symlinked) into `~/.pi/agent/agents/` purely so a future custom
> **extension** can read these files and implement sub-agents / chains. Until
> that extension exists, these definitions are inert documentation.

## Agent definition (`<name>.md`) — suggested front matter

```markdown
---
name: planner
description: Breaks a task into an ordered plan.
model: claude-opus-4-8
thinking: high
skills:
  - code-review
tools:
  - read
  - grep
---

## Purpose
...

## Behavior
...
```

## Chains / teams (`agent-chain.yml`)

Describes how agents compose. See the placeholder in this directory.
