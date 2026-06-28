# pi-config

Personal, version-controlled configuration for [pi](https://pi.dev) that deploys
to the global pi agent directory via symlinks. This repo is the **single source
of truth**; `~/.pi/agent/` reads through symlinks back into here.

## How it works

`deploy.sh` links this directory's resources into `~/.pi/agent/`
(overridable with `PI_CODING_AGENT_DIR`):

| Source (here)     | Target (`~/.pi/agent/`) | Method   | Native to pi? |
| ----------------- | ----------------------- | -------- | ------------- |
| `skills/`         | `skills/`               | symlink  | ✅ yes        |
| `extensions/`     | `extensions/`           | symlink  | ✅ yes        |
| `prompts/`        | `prompts/`              | symlink  | ✅ yes        |
| `themes/`         | `themes/`               | symlink  | ✅ yes        |
| `agents/`         | `agents/`               | symlink  | ❌ custom     |
| `flavors/`        | `flavors/`              | symlink  | ❌ custom     |
| `settings.json`   | `settings.json`         | **copy** | ✅ yes        |
| `AGENTS.md` (opt) | `AGENTS.md`             | symlink  | ✅ yes        |

Beyond linking resources, `deploy.sh` also installs external **dependencies**
(see [Dependencies](#dependencies)) — these are downloaded machine-locally, never
committed to the repo.

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

## Dependencies

External deps that don't fit the symlink/copy model (and shouldn't be committed
to git) are installed by `deploy.sh`:

- **Extension packages** — `npm install` runs automatically for any
  `extensions/**/package.json`.
- **Nerd Fonts** — the `tui-design` footer needs a [Nerd Font](https://github.com/ryanoasis/nerd-fonts)
  for its folder / git-branch glyphs. `deploy.sh` downloads the fonts
  listed in its `NERD_FONTS` array (pinned by `NERD_FONTS_VERSION`) straight from
  the official release into the OS font dir — cross-platform, no package manager
  required:
  - macOS: `~/Library/Fonts/nerd-fonts/<Name>/`
  - Linux: `~/.local/share/fonts/nerd-fonts/<Name>/` (then `fc-cache`)

  Idempotent via a per-font `.version` stamp; bump `NERD_FONTS_VERSION` to
  upgrade. Needs `curl` + `unzip`. (A font _can't_ live in `package.json` —
  npm installs into `node_modules/`, which the terminal never reads.)

> **⚠️ Required manual step — set your terminal font.** `deploy.sh` installs the
> Nerd Font files but **cannot select the font for you** (that's a per-app
> setting). After deploying, set your terminal emulator's font family to the
> installed **JetBrainsMono Nerd Font**, or the `tui-design` footer's `󰝰`
> folder / `` git-branch glyphs render as tofu boxes:
>
> - **macOS Terminal.app:** Settings → Profiles → Text → Font → **JetBrainsMono Nerd Font**.
> - **iTerm2:** Settings → Profiles → Text → Font → **JetBrainsMono Nerd Font**.

## Idempotency & safety

`deploy.sh`:

- skips already-correct symlinks,
- relinks incorrect ones,
- backs up any pre-existing real file/dir to `*.bak.<timestamp>` before linking,
- copies `settings.json` (backing up a differing existing copy first),
- installs [dependencies](#dependencies) (extension `npm install` + Nerd Fonts),
  skipping anything already at the pinned version.
