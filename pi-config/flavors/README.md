# Flavors (scoped — not yet implemented)

A **flavor** is a higher-level abstraction describing the exact set of
capabilities loaded for a session: which extensions, skills, tools, agents, and
model defaults are active.

Pi has **no native concept of flavors**. This directory is deployed (symlinked)
into `~/.pi/agent/flavors/` so that a future custom extension can discover and
apply flavor files. Until that extension exists, these files do nothing.

## Intended schema (draft)

See `example.flavor.yml`. A flavor is expected to reference resources by name,
where those names resolve to the deployed `~/.pi/agent/{extensions,skills,agents}`
trees.

## Planned activation (future)

- A `flavor` extension reads `~/.pi/agent/flavors/*.yml`.
- Selecting a flavor (CLI flag, `/flavor` command, or env var) enables only the
  listed extensions/skills/tools for that session.
