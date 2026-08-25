#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(zsh tmux ghostty zed git karabiner claude starship nvim bin herdr ssh)

echo "==> Dotfiles setup from $DOTFILES_DIR"

# ──────────────────────────────────────────
# 1. Install Homebrew if missing
# ──────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi

# ──────────────────────────────────────────
# 2. Install stow + common tools
# ──────────────────────────────────────────
echo "==> Installing packages..."
brew install stow eza bat fzf zoxide fnm rbenv zsh-syntax-highlighting zsh-autosuggestions starship neovim ripgrep fd lazygit tree-sitter jq tea

# ──────────────────────────────────────────
# 3. Install Oh My Zsh if missing
# ──────────────────────────────────────────
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ──────────────────────────────────────────
# 4. Install TPM (tmux plugin manager) if missing
# ──────────────────────────────────────────
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# ──────────────────────────────────────────
# 5. Stow all packages
# ──────────────────────────────────────────
echo "==> Stowing dotfiles..."
cd "$DOTFILES_DIR"
for pkg in "${PACKAGES[@]}"; do
  echo "  - $pkg"
  stow -v --target="$HOME" --restow "$pkg"
done

# ──────────────────────────────────────────
# 6. Skills (OMP) + Seafile drive (secrets lib only; content on demand)
#    Skills travel via git (stow → ~/.claude/skills), exposed to OMP's native
#    provider through ~/.omp/agent/skills.
#    Secrets: a dedicated small `secrets` library holds every token/.env at its
#    root. It is the ONLY library auto-synced (everywhere) and is exposed at
#    ~/.secrets (symlink to its checkout). Content libraries (Ma bibliothèque,
#    Pro, …) are synced on demand into ~/Documents/<lib> — see the seafile skill
#    and claude/.claude/skills/seafile/libraries.md.
#    Fresh-machine bootstrap (the token lives inside the secrets lib, so provide
#    it once via the environment), then re-run — afterwards ~/.secrets resolves:
#      SEAFILE_URL=https://drive.nobrega.fr SEAFILE_TOKEN=<token> ./setup.sh
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
  echo "   (jq absent — ajoute les serveurs à la main, cf. ~/.claude/mcp-servers/*/mcp.example.json)"
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
    echo "  ! seaf-cli not found — for local sync install it manually:" >&2
    echo "    brew install --cask seafile-client   # or the Seafile-cli AppImage" >&2
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
  echo "      SEAFILE_URL=https://drive.nobrega.fr SEAFILE_TOKEN=<token> ./setup.sh"
  echo "      # <token>: curl -d 'username=<you>&password=<pw>' https://drive.nobrega.fr/api2/auth-token/"
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

# ── 2brain: mémoire persistante multi-agents (synchronisée partout, comme secrets) ──
SEAFILE_2BRAIN_DIR="$SEAFILE_CHECKOUT_DIR/2brain"
if [ -n "${SEAFILE_TOKEN:-}" ] && [ -n "${SEAFILE_URL:-}" ] && command -v seaf-cli >/dev/null 2>&1; then
  if [ ! -d "$SEAFILE_2BRAIN_DIR" ]; then
    echo "==> Syncing 2brain memory library..."
    seaf-cli start >/dev/null 2>&1 || true
    _b_hdr="Authorization: Token $SEAFILE_TOKEN"
    _b_user="$(curl -fsS --max-time 20 -H "$_b_hdr" "$SEAFILE_URL/api2/account/info/" 2>/dev/null | jq -r '.email // empty' 2>/dev/null || true)"
    _b_id="$(curl -fsS --max-time 20 -H "$_b_hdr" "$SEAFILE_URL/api2/repos/" 2>/dev/null | jq -r '[.[]|select(.name=="2brain")][0].id // empty' 2>/dev/null || true)"
    if [ -n "$_b_user" ] && [ -n "$_b_id" ]; then
      seaf-cli download -l "$_b_id" -s "$SEAFILE_URL" -d "$SEAFILE_CHECKOUT_DIR" -u "$_b_user" -T "$SEAFILE_TOKEN" >/dev/null 2>&1 || true
      for _ in $(seq 1 15); do [ -d "$SEAFILE_2BRAIN_DIR" ] && break; sleep 1; done
    else
      echo "  ! Could not resolve the 2brain lib via Seahub; check token/URL." >&2
    fi
  fi
fi
# ~/2brain → the synced 2brain checkout (never clobber a real dir, never dangle).
if [ -d "$SEAFILE_2BRAIN_DIR" ]; then
  if [ ! -e "$HOME/2brain" ] || [ -L "$HOME/2brain" ]; then
    ln -sfn "$SEAFILE_2BRAIN_DIR" "$HOME/2brain"
  else
    echo "  ! ~/2brain is a real dir; move its files into the '2brain' lib, then symlink it." >&2
  fi
fi
mkdir -p "$HOME/2brain-scratch"   # local, jamais synchronisé (travail jetable des agents)

# ── Gitea (tea) login for project management (Eduvia) ──────────────────
# Wire `tea` to git.eduvia.dev from ~/.secrets/gitea.env (no-op until synced).
# Plane uses the stowed `plane` wrapper, which reads ~/.secrets/plane.env.
if [ -x "$DOTFILES_DIR/bin/.local/bin/gitea-login" ]; then
  echo "==> Configuring Gitea (tea) login..."
  "$DOTFILES_DIR/bin/.local/bin/gitea-login" || true
fi

echo ""
echo "==> Done! Restart your shell or run: source ~/.zshrc"
echo "==> For tmux plugins, open tmux and press: prefix + I"
