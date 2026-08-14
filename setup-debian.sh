#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo "ERROR: do not run this script as root. Run it as your normal user; sudo will be invoked only for apt." >&2
  exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
# Headless server subset — GUI packages (ghostty, zed, hypr, waybar, keyd, karabiner) are intentionally excluded.
PACKAGES=(zsh tmux git claude starship nvim bin herdr ssh)

echo "==> Dotfiles setup (Debian) from $DOTFILES_DIR"

# ──────────────────────────────────────────
# 1. Install apt packages
#    CORE must succeed; EXTRAS are best-effort (name/availability varies by release).
# ──────────────────────────────────────────
CORE_PKGS=(stow zsh tmux git curl ca-certificates unzip jq neovim)
EXTRA_PKGS=(zsh-syntax-highlighting zsh-autosuggestions eza bat fzf zoxide ripgrep fd-find btop inotify-tools direnv rbenv)

echo "==> Installing apt packages (core)..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${CORE_PKGS[@]}"

echo "==> Installing apt packages (extras, best-effort)..."
for p in "${EXTRA_PKGS[@]}"; do
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$p" \
    || echo "   (skip: $p not available)"
done

# Debian ships bat as `batcat` and fd as `fdfind` — expose the canonical names on PATH.
mkdir -p "$HOME/.local/bin"
if command -v batcat >/dev/null 2>&1 && [ ! -e "$HOME/.local/bin/bat" ]; then ln -s "$(command -v batcat)" "$HOME/.local/bin/bat"; fi
if command -v fdfind >/dev/null 2>&1 && [ ! -e "$HOME/.local/bin/fd" ]; then ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"; fi

# ──────────────────────────────────────────
# 2. Install Oh My Zsh if missing (KEEP_ZSHRC so it never clobbers the stowed ~/.zshrc)
# ──────────────────────────────────────────
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> Installing Oh My Zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ──────────────────────────────────────────
# 3. Install bun if missing
# ──────────────────────────────────────────
if [ ! -d "$HOME/.bun" ]; then
  echo "==> Installing bun..."
  curl -fsSL https://bun.sh/install | bash || echo "   (bun install skipped)"
fi

# ──────────────────────────────────────────
# 4. Install TPM (tmux plugin manager) if missing
# ──────────────────────────────────────────
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# ──────────────────────────────────────────
# 5. Stow packages (headless subset)
#    Free the ~/.zshrc slot if a non-symlink template snuck in.
# ──────────────────────────────────────────
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.pre-stow.bak"
fi
echo "==> Stowing dotfiles..."
cd "$DOTFILES_DIR"
for pkg in "${PACKAGES[@]}"; do
  echo "  - $pkg"
  stow -v --target="$HOME" --restow "$pkg"
done

# ──────────────────────────────────────────
# 5b. Skills (OMP) + Seafile drive (secrets lib only; content on demand)
#    Skills travel via git (stow → ~/.claude/skills), exposed to OMP's native
#    provider through ~/.omp/agent/skills. Secrets: the dedicated `secrets`
#    library holds every token/.env at its root; it is exposed at ~/.secrets.
#    Fresh-machine bootstrap (token lives inside the secrets lib, provide once):
#      SEAFILE_URL=https://drive.nobrega.fr SEAFILE_TOKEN=<token> ./setup-debian.sh
# ──────────────────────────────────────────
echo "==> Linking skills for OMP..."
mkdir -p "$HOME/.omp/agent"
ln -sfn "$HOME/.claude/skills" "$HOME/.omp/agent/skills"

echo "==> Registering local MCP servers for OMP..."
OMP_MCP="$HOME/.omp/agent/mcp.json"
if command -v jq >/dev/null 2>&1; then
  [ -f "$OMP_MCP" ] || echo '{"mcpServers":{}}' >"$OMP_MCP"
  for srv in dolibarr vikunja; do
    script="$HOME/.claude/mcp-servers/$srv/server.mjs"   # resolved absolute (OMP does not reliably expand ${HOME} in args)
    tmp="$(mktemp)"
    if jq --arg name "$srv" --arg s "$script" \
         '.mcpServers[$name] = {type:"stdio", command:"node", args:[$s]}' \
         "$OMP_MCP" >"$tmp"; then mv "$tmp" "$OMP_MCP"; else rm -f "$tmp"; fi
  done
else
  echo "   (jq absent — add servers by hand, cf. ~/.claude/mcp-servers/*/mcp.example.json)"
fi

echo "==> Seafile secrets bootstrap..."
SEAFILE_CLIENT_DIR="$HOME/seafile-client"
SEAFILE_CHECKOUT_DIR="$SEAFILE_CLIENT_DIR/seafile"
SEAFILE_SECRETS_DIR="$SEAFILE_CHECKOUT_DIR/secrets"   # local checkout of the `secrets` lib

if [ -z "${SEAFILE_TOKEN:-}" ] && [ -r "$HOME/.secrets/seafile.env" ]; then
  # shellcheck disable=SC1090
  set -a; . "$HOME/.secrets/seafile.env"; set +a
fi

if [ -n "${SEAFILE_TOKEN:-}" ] && [ -n "${SEAFILE_URL:-}" ]; then
  if ! command -v seaf-cli >/dev/null 2>&1; then
    echo "  ! seaf-cli not found — for local sync: sudo apt-get install -y seafile-cli" >&2
    echo "    (drive API access via the token works without it.)" >&2
  fi
  if command -v seaf-cli >/dev/null 2>&1 && [ ! -d "$SEAFILE_SECRETS_DIR" ]; then
    mkdir -p "$SEAFILE_CHECKOUT_DIR"
    [ -d "$HOME/.ccnet" ] || seaf-cli init -d "$SEAFILE_CLIENT_DIR" >/dev/null 2>&1 || true
    seaf-cli start >/dev/null 2>&1 || true
    sleep 2
    _sf_hdr="Authorization: Token $SEAFILE_TOKEN"
    _sf_user="$(curl -fsS --max-time 20 -H "$_sf_hdr" "$SEAFILE_URL/api2/account/info/" 2>/dev/null | jq -r '.email // empty' 2>/dev/null || true)"
    _sf_id="$(curl -fsS --max-time 20 -H "$_sf_hdr" "$SEAFILE_URL/api2/repos/" 2>/dev/null | jq -r '[.[]|select(.name=="secrets")][0].id // empty' 2>/dev/null || true)"
    if [ -n "$_sf_user" ] && [ -n "$_sf_id" ]; then
      echo "  - syncing secrets library"
      seaf-cli download -l "$_sf_id" -s "$SEAFILE_URL" -d "$SEAFILE_CHECKOUT_DIR" -u "$_sf_user" -T "$SEAFILE_TOKEN" >/dev/null 2>&1 || true
      for _ in $(seq 1 15); do if [ -d "$SEAFILE_SECRETS_DIR" ]; then break; fi; sleep 1; done
    else
      echo "  ! Could not resolve the secrets lib via Seahub; check token/URL." >&2
    fi
  fi
else
  echo "  - No Seafile token — drive & token-based skills inactive."
  echo "    Bootstrap once (out-of-band), then re-run:"
  echo "      SEAFILE_URL=https://drive.nobrega.fr SEAFILE_TOKEN=<token> ./setup-debian.sh"
fi

# ~/.secrets → the synced secrets checkout (single source, propagated via drive).
if [ -d "$SEAFILE_SECRETS_DIR" ]; then
  if [ ! -e "$HOME/.secrets" ] || [ -L "$HOME/.secrets" ]; then
    ln -sfn "$SEAFILE_SECRETS_DIR" "$HOME/.secrets"
  else
    echo "  ! ~/.secrets is a real dir; move its files into the 'secrets' lib, then:" >&2
    echo "      rm -rf ~/.secrets && ln -sfn '$SEAFILE_SECRETS_DIR' ~/.secrets" >&2
  fi
fi

# ──────────────────────────────────────────
# 6. Set zsh as default shell if needed
# ──────────────────────────────────────────
if [ "$SHELL" != "$(command -v zsh)" ]; then
  echo "==> Setting zsh as default shell..."
  sudo chsh -s "$(command -v zsh)" "$USER"
fi

echo ""
echo "==> Done! Restart your shell or run: exec zsh"
echo "==> For tmux plugins, open tmux and press: prefix + I"
