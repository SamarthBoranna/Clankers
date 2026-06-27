# pi-config

Personal, version-controlled configuration for [pi](https://pi.dev) that deploys
to the global pi agent directory via symlinks. This repo is the **single source
of truth**; `~/.pi/agent/` reads through symlinks back into here.

## How it works

`deploy.sh` links this directory's resources into `~/.pi/agent/`
(overridable with `PI_CODING_AGENT_DIR`):

| Source (here)     | Target (`~/.pi/agent/`) | Method   | Native to pi? |
|-------------------|-------------------------|----------|---------------|
| `skills/`         | `skills/`               | symlink  | ✅ yes        |
| `extensions/`     | `extensions/`           | symlink  | ✅ yes        |
| `prompts/`        | `prompts/`              | symlink  | ✅ yes        |
| `themes/`         | `themes/`               | symlink  | ✅ yes        |
| `agents/`         | `agents/`               | symlink  | ❌ custom     |
| `flavors/`        | `flavors/`              | symlink  | ❌ custom     |
| `settings.json`   | `settings.json`         | **copy** | ✅ yes        |
| `AGENTS.md` (opt) | `AGENTS.md`             | symlink  | ✅ yes        |

`settings.json` is **copied, not symlinked**, because pi rewrites it at runtime
(e.g. `lastChangelogVersion`); symlinking it back into the repo causes churn.
This repo is the source of truth — edit `settings.json` here and re-deploy.

**Never touched by deploy:** `auth.json` (your API token), `bin/` (fd/rg
binaries), and `sessions/` (your history) all stay machine-local in
`~/.pi/agent/`.

## Why `~/.pi/agent/` and not `~/.pi/`

Pi's source (`getAgentDir()`) resolves the config dir to
`~/.pi/<CONFIG_DIR_NAME>/agent` → `~/.pi/agent`. All resources load from there.
Linking into `~/.pi/` directly would be silently ignored.

## Usage

```bash
# Deploy (idempotent — safe to re-run anytime)
./pi-config/deploy.sh

# Deploy to a custom location
PI_CODING_AGENT_DIR=~/some/other/agent ./pi-config/deploy.sh
```

After editing anything here, re-run `deploy.sh`. For settings/extension changes,
restart pi (or use `/reload` for resources).

## Directory guide

- **skills/** — [Agent Skills](https://agentskills.io) (`SKILL.md` packages). Loaded natively.
- **extensions/** — TypeScript modules (token optimization, custom footers, tools, sub-agents...). Loaded natively.
- **prompts/** — Reusable prompt templates (`/name` to expand). Loaded natively.
- **themes/** — Theme JSON files. Loaded natively.
- **agents/** — Markdown agent specs + `agent-chain.yml`. **Custom**; needs an extension to act on them. See `agents/README.md`.
- **flavors/** — Session capability bundles. **Custom / scoped**; not yet implemented. See `flavors/README.md`.

## Idempotency & safety

`deploy.sh`:
- skips already-correct symlinks,
- relinks incorrect ones,
- backs up any pre-existing real file/dir to `*.bak.<timestamp>` before linking,
- copies `settings.json` (backing up a differing existing copy first),
- runs `npm install` for any `extensions/**/package.json`.
