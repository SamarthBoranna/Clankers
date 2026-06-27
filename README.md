# Clankers

A home to projects surrounding AI tooling and harness construction.

## pi-config

Version-controlled configuration for the [pi](https://pi.dev) coding agent.
The repo is the single source of truth — `deploy.sh` symlinks resources into
pi's config dir (`~/.pi/agent/`), so editing files here updates your live agent
while keeping secrets and machine-local state out of git.

### Setup

```bash
./pi-config/deploy.sh              # deploy into ~/.pi/agent/
```

Re-run after any change. `deploy.sh` is idempotent, self-locating, and backs up
pre-existing files before linking.

### What gets deployed

| Source                 | Method   | Notes                                  |
|------------------------|----------|----------------------------------------|
| `skills/` `extensions/` `prompts/` `themes/` | symlink | loaded natively by pi |
| `models.json`          | symlink  | custom providers (Ollama, etc.)        |
| `agents/` `flavors/`   | symlink  | custom; inert until a loader extension |
| `settings.json`        | **copy** | pi rewrites it at runtime; repo wins   |

Never touched: `auth.json`, `bin/`, `sessions/` (secrets / machine-local).

### Local models (Ollama)

`models.json` registers an OpenAI-compatible `ollama` provider. Configured
RAM-safe for 16GB (16K context, no swap):

| Model                  | Size | Thinking | Use for             |
|------------------------|------|----------|---------------------|
| `qwen2.5-coder:7b-16k` | 7B   | no       | coding daily driver |
| `qwen3:8b-16k`         | 8B   | yes      | reasoning / planning|
| `llama3.2:3b-16k`      | 3B   | no       | fast / simple tasks |

`-16k` tags are Ollama Modelfile variants (`num_ctx 16384`) so pi's displayed
window matches what Ollama serves (default ~4K otherwise). Reloads on `/model`.

```bash
pi --provider ollama --model qwen2.5-coder:7b-16k "your task"
```

See [`pi-config/README.md`](pi-config/README.md) for full details.
