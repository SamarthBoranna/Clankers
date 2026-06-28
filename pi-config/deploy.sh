#!/usr/bin/env bash
#
# deploy.sh — deploy this repo's pi-config to the global pi agent directory.
#
# Strategy:
#   - SYMLINK static resource dirs (skills, extensions, prompts, themes, agents,
#     flavors) so the repo stays the single source of truth and pi reads through
#     the links.
#   - COPY settings.json (symlinking it occasionally causes issues because pi
#     rewrites the file at runtime).
#   - NEVER touch auth.json, bin/, or sessions/ (secrets / machine-local state).
#   - INSTALL external dependencies: extension npm packages, plus Nerd Fonts
#     (downloaded cross-platform from the official release into the OS font dir)
#     — installed machine-locally so no binaries are committed to the repo.
#
# The script is idempotent: re-running only fixes what is wrong and backs up any
# pre-existing real files/dirs before replacing them with symlinks.
#
# Override the target with PI_CODING_AGENT_DIR (defaults to ~/.pi/agent).

set -euo pipefail

# ----------------------------------------------------------------------------
# Resolve paths (works regardless of caller's cwd)
# ----------------------------------------------------------------------------
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
PI_CONFIG_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

if REPO_ROOT="$(git -C "$PI_CONFIG_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_ROOT="$(dirname "$PI_CONFIG_DIR")"
fi

AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

# Resource dirs to symlink into AGENT_DIR.
#   native pi resources : skills extensions prompts themes
#   custom abstractions : agents flavors  (consumed by your own future extensions)
RESOURCE_DIRS=(skills extensions prompts themes agents flavors)

# Nerd Fonts to install (cross-platform, from the official ryanoasis/nerd-fonts
# release). Each name matches a release asset: <Name> -> <Name>.zip.
# Needed by the tui-design footer glyphs (folder / git-branch).
NERD_FONTS_VERSION="3.4.0"
NERD_FONTS=(JetBrainsMono)

# ----------------------------------------------------------------------------
# Pretty logging
# ----------------------------------------------------------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_GREEN=$'\033[32m'; C_BLUE=$'\033[34m'
  C_YELLOW=$'\033[33m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
else
  C_RESET=""; C_GREEN=""; C_BLUE=""; C_YELLOW=""; C_DIM=""; C_BOLD=""
fi
log_link() { printf '  %slink%s   %s\n' "$C_GREEN" "$C_RESET" "$1"; }
log_copy() { printf '  %scopy%s   %s\n' "$C_BLUE"  "$C_RESET" "$1"; }
log_skip() { printf '  %sskip%s   %s\n' "$C_DIM"   "$C_RESET" "$1"; }
log_warn() { printf '  %swarn%s   %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
log_step() { printf '%s==>%s %s\n' "$C_BOLD" "$C_RESET" "$1"; }

TIMESTAMP="$(date +%Y%m%d%H%M%S)"

# ----------------------------------------------------------------------------
# Symlink a single resource dir: AGENT_DIR/<name> -> PI_CONFIG_DIR/<name>
# ----------------------------------------------------------------------------
link_resource() {
  local name="$1"
  local src="$PI_CONFIG_DIR/$name"
  local dst="$AGENT_DIR/$name"

  mkdir -p "$src"   # ensure the repo side exists (keeps deploy robust)

  if [ -L "$dst" ]; then
    local cur; cur="$(readlink "$dst")"
    if [ "$cur" = "$src" ]; then
      log_skip "$name/ (symlink already correct)"
      return
    fi
    rm "$dst"
    ln -s "$src" "$dst"
    log_link "$name/ (relinked from $cur)"
    return
  fi

  if [ -e "$dst" ]; then
    local backup="$dst.bak.$TIMESTAMP"
    mv "$dst" "$backup"
    ln -s "$src" "$dst"
    log_link "$name/ (backed up existing -> $(basename "$backup"))"
    return
  fi

  ln -s "$src" "$dst"
  log_link "$name/"
}

# ----------------------------------------------------------------------------
# Symlink an optional single file (e.g. AGENTS.md), only if it exists in repo.
# ----------------------------------------------------------------------------
link_optional_file() {
  local name="$1"
  local src="$PI_CONFIG_DIR/$name"
  local dst="$AGENT_DIR/$name"

  [ -f "$src" ] || return 0

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    log_skip "$name (symlink already correct)"
    return
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$TIMESTAMP"
  elif [ -L "$dst" ]; then
    rm "$dst"
  fi
  ln -s "$src" "$dst"
  log_link "$name"
}

# ----------------------------------------------------------------------------
# Copy (not symlink) settings.json.
# ----------------------------------------------------------------------------
copy_settings() {
  local src="$PI_CONFIG_DIR/settings.json"
  local dst="$AGENT_DIR/settings.json"

  if [ ! -f "$src" ]; then
    log_warn "settings.json missing in pi-config; skipping"
    return
  fi
  # settings.json must be a real file, never a symlink.
  if [ -L "$dst" ]; then
    rm "$dst"
  fi
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    log_skip "settings.json (identical)"
    return
  fi
  if [ -f "$dst" ]; then
    cp "$dst" "$dst.bak.$TIMESTAMP"
    log_warn "settings.json differed; backed up -> settings.json.bak.$TIMESTAMP"
  fi
  cp "$src" "$dst"
  log_copy "settings.json"
}

# ----------------------------------------------------------------------------
# Install dependencies for any extension that ships a package.json.
# ----------------------------------------------------------------------------
install_extension_deps() {
  local ext_root="$PI_CONFIG_DIR/extensions"
  [ -d "$ext_root" ] || return 0

  if ! command -v npm >/dev/null 2>&1; then
    log_warn "npm not found; skipping extension dependency install"
    return
  fi

  local found=0 pkg dir
  # depth 2 catches extensions/package.json and extensions/<name>/package.json
  while IFS= read -r pkg; do
    found=1
    dir="$(dirname "$pkg")"
    log_step "npm install in ${dir#$REPO_ROOT/}"
    (cd "$dir" && npm install --no-fund --no-audit)
  done < <(find "$ext_root" -maxdepth 2 -name package.json -not -path '*/node_modules/*' 2>/dev/null)

  [ "$found" -eq 0 ] && log_skip "no extension package.json files found"
}

# ----------------------------------------------------------------------------
# Install Nerd Fonts cross-platform, straight from the official release.
#
# npm/package.json can't do this: packages land in node_modules/, which the
# terminal never reads — fonts must be registered with the OS. So we download
# the official release zip and drop the glyph files into the OS user font dir:
#   macOS : ~/Library/Fonts/nerd-fonts/<Name>/
#   Linux : ~/.local/share/fonts/nerd-fonts/<Name>/  (+ fc-cache refresh)
# Idempotent via a per-font .version stamp; bump NERD_FONTS_VERSION to upgrade.
# ----------------------------------------------------------------------------
install_nerd_fonts() {
  [ "${#NERD_FONTS[@]}" -gt 0 ] || { log_skip "no Nerd Fonts configured"; return 0; }

  if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    log_warn "curl/unzip not found; skipping Nerd Font install"
    return 0
  fi

  local font_dir
  case "$(uname -s)" in
    Darwin) font_dir="$HOME/Library/Fonts" ;;
    *)      font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts" ;;
  esac

  local refreshed=0 name dest stamp url tmp
  for name in "${NERD_FONTS[@]}"; do
    dest="$font_dir/nerd-fonts/$name"
    stamp="$dest/.version"

    if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$NERD_FONTS_VERSION" ]; then
      log_skip "$name Nerd Font (v$NERD_FONTS_VERSION already installed)"
      continue
    fi

    url="https://github.com/ryanoasis/nerd-fonts/releases/download/v$NERD_FONTS_VERSION/$name.zip"
    tmp="$(mktemp -d)"
    log_step "Downloading $name Nerd Font v$NERD_FONTS_VERSION"
    if ! curl -fsSL "$url" -o "$tmp/$name.zip"; then
      log_warn "$name: download failed ($url); skipping"
      rm -rf "$tmp"
      continue
    fi

    rm -rf "$dest"
    mkdir -p "$dest"
    # Extract glyph files only (skip licenses/readmes). unzip exits 11 when one
    # of the patterns matches nothing (e.g. a font ships only .ttf and no .otf),
    # which is harmless — so we ignore its exit code and instead confirm success
    # by checking what actually landed in $dest.
    unzip -qo "$tmp/$name.zip" '*.ttf' '*.otf' -d "$dest" >/dev/null 2>&1 || true
    shopt -s nullglob
    local got=("$dest"/*.ttf "$dest"/*.otf)
    shopt -u nullglob
    if [ "${#got[@]}" -eq 0 ]; then
      log_warn "$name: no .ttf/.otf found in archive; skipping"
      rm -rf "$tmp" "$dest"
      continue
    fi
    printf '%s\n' "$NERD_FONTS_VERSION" > "$stamp"
    rm -rf "$tmp"
    refreshed=1
    log_link "$name Nerd Font -> ${dest/#$HOME/~}"
  done

  if [ "$refreshed" -eq 1 ]; then
    # Refresh the fontconfig cache on Linux so new fonts are picked up.
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
    log_warn "Set your terminal's font to the installed Nerd Font to see TUI glyphs."
  fi
}

# ----------------------------------------------------------------------------
# Run
# ----------------------------------------------------------------------------
log_step "pi-config deploy"
printf '    repo root : %s\n' "$REPO_ROOT"
printf '    source    : %s\n' "$PI_CONFIG_DIR"
printf '    target    : %s\n' "$AGENT_DIR"
echo

mkdir -p "$AGENT_DIR"

log_step "Symlinking resources"
for d in "${RESOURCE_DIRS[@]}"; do
  link_resource "$d"
done
link_optional_file "AGENTS.md"
link_optional_file "models.json"   # custom providers (Ollama, etc.); pi does not rewrite it
echo

log_step "Copying settings"
copy_settings
echo

log_step "Installing dependencies"
install_extension_deps
install_nerd_fonts
echo

log_step "Done."
printf '%sNote:%s auth.json, bin/, and sessions/ in %s were left untouched.\n' \
  "$C_DIM" "$C_RESET" "$AGENT_DIR"
