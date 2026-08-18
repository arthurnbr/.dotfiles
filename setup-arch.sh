#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo "ERROR: do not run this script as root. Run it as your normal user; sudo will be invoked only for pacman." >&2
  exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(zsh tmux ghostty zed git claude hypr starship nvim bin herdr ssh)

# ── Omarchy 4 awareness ───────────────────────────────────────────────
# On Omarchy we drive installs through `omarchy pkg`, which missing-checks
# then wraps pacman (repos) / yay (AUR). On plain Arch we fall back directly.
if command -v omarchy >/dev/null 2>&1; then
  IS_OMARCHY=1
  echo "==> Omarchy detected ($(omarchy version 2>/dev/null | head -1)) — installs via 'omarchy pkg'"
else
  IS_OMARCHY=0
fi

pkg_install() {   # official-repo packages
  if [ "$IS_OMARCHY" = 1 ]; then omarchy pkg add "$@"; else sudo pacman -S --needed --noconfirm "$@"; fi
}

aur_install() {   # AUR packages
  if [ "$IS_OMARCHY" = 1 ]; then omarchy pkg aur add "$@"
  elif command -v yay >/dev/null 2>&1; then yay -S --needed --noconfirm "$@"
  elif command -v paru >/dev/null 2>&1; then paru -S --needed --noconfirm "$@"
  else return 1; fi
}

echo "==> Dotfiles setup (Arch / Omarchy) from $DOTFILES_DIR"

# ──────────────────────────────────────────
# 1. Install pacman packages
# ──────────────────────────────────────────
PACMAN_PKGS=(
  stow
  zsh
  tmux
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  eza
  bat
  fzf
  zoxide
  fnm
  rbenv
  ghostty
  btop
  lazydocker
  starship
  keyd
  jq
  inotify-tools
  pipewire
  neovim
  ripgrep
  fd
  lazygit
  tree-sitter-cli
)

echo "==> Installing packages..."
pkg_install "${PACMAN_PKGS[@]}"

# ──────────────────────────────────────────
# 2. Install Oh My Zsh if missing
# ──────────────────────────────────────────
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ──────────────────────────────────────────
# 3. Install bun if missing
# ──────────────────────────────────────────
if [ ! -d "$HOME/.bun" ]; then
  echo "==> Installing bun..."
  curl -fsSL https://bun.sh/install | bash
fi

# ──────────────────────────────────────────
# 4. Install TPM (tmux plugin manager) if missing
# ──────────────────────────────────────────
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# ──────────────────────────────────────────
# 5. Stow packages (skip karabiner — macOS only)
# ──────────────────────────────────────────
echo "==> Stowing dotfiles..."
cd "$DOTFILES_DIR"
for pkg in "${PACKAGES[@]}"; do
  echo "  - $pkg"
  stow -v --target="$HOME" --restow "$pkg"
done

# Reload Hyprland so freshly-stowed Lua overrides apply immediately (Omarchy 4).
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi

# ──────────────────────────────────────────
# 5b. Skills (OMP) + Seafile drive (secrets lib only; content on demand)
#    Skills travel via git (stow → ~/.claude/skills), exposed to OMP's native
#    provider through ~/.omp/agent/skills.
#    Secrets: a dedicated small `secrets` library holds every token/.env at its
#    root. It is the ONLY library auto-synced (everywhere) and is exposed at
#    ~/.secrets (symlink to its checkout). Content libraries (Ma bibliothèque,
#    Pro, …) are synced on demand into ~/Documents/<lib> — see the seafile skill
#    and claude/.claude/skills/seafile/libraries.md.
#    Fresh-machine bootstrap (the token lives inside the secrets lib, so provide
#    it once via the environment), then re-run — afterwards ~/.secrets resolves:
#      SEAFILE_URL=https://drive.nobrega.fr SEAFILE_TOKEN=<token> ./setup-arch.sh
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

# Token from the environment (bootstrap) or the already-synced secrets file.
if [ -z "${SEAFILE_TOKEN:-}" ] && [ -r "$HOME/.secrets/seafile.env" ]; then
  # shellcheck disable=SC1090
  set -a; . "$HOME/.secrets/seafile.env"; set +a
fi

if [ -n "${SEAFILE_TOKEN:-}" ] && [ -n "${SEAFILE_URL:-}" ]; then
  # seaf-cli lives in the AUR (package `seafile`, provides seaf-cli).
  if ! command -v seaf-cli >/dev/null 2>&1; then
    aur_install seafile || echo "  ! seaf-cli missing and AUR install failed; install 'seafile' manually." >&2
  fi
  if command -v seaf-cli >/dev/null 2>&1 && [ ! -d "$SEAFILE_SECRETS_DIR" ]; then
    mkdir -p "$SEAFILE_CHECKOUT_DIR"
    [ -d "$HOME/.ccnet" ] || seaf-cli init -d "$SEAFILE_CLIENT_DIR" >/dev/null 2>&1 || true
    sudo -n systemctl enable --now "seaf-cli@$(id -un).service" 2>/dev/null || seaf-cli start >/dev/null 2>&1 || true
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
  echo "      SEAFILE_URL=https://drive.nobrega.fr SEAFILE_TOKEN=<token> ./setup-arch.sh"
  echo "      # <token>: curl -d 'username=<you>&password=<pw>' https://drive.nobrega.fr/api2/auth-token/"
fi

# ~/.secrets → the synced secrets checkout (single source, propagated via drive).
# Only when the checkout exists and ~/.secrets is absent or already a symlink
# (never clobber a real ~/.secrets, never create a dangling link).
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
    sudo -n systemctl enable --now "seaf-cli@$(id -un).service" 2>/dev/null || seaf-cli start >/dev/null 2>&1 || true
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

# ──────────────────────────────────────────
# 6. Set ghostty as default terminal
#    Omarchy 4 exports TERMINAL=xdg-terminal-exec (see ~/.config/uwsm/default);
#    xdg-terminal-exec launches the first entry in ~/.config/xdg-terminals.list.
# ──────────────────────────────────────────
mkdir -p "$HOME/.config"
if ! grep -qx "com.mitchellh.ghostty.desktop" "$HOME/.config/xdg-terminals.list" 2>/dev/null; then
  echo "==> Setting ghostty as default terminal..."
  echo "com.mitchellh.ghostty.desktop" > "$HOME/.config/xdg-terminals.list"
fi

# ──────────────────────────────────────────
# 7. Deploy keyd config (Alt+HJKL → arrows) and enable daemon
# ──────────────────────────────────────────
echo "==> Deploying keyd config to /etc/keyd/default.conf..."
sudo install -Dm644 "$DOTFILES_DIR/keyd/default.conf" /etc/keyd/default.conf
sudo systemctl enable --now keyd
sudo keyd reload 2>/dev/null || true

# ──────────────────────────────────────────
# 8. Set zsh as default shell if needed
# ──────────────────────────────────────────
if [ "$SHELL" != "$(command -v zsh)" ]; then
  echo "==> Setting zsh as default shell (you'll be prompted for password)..."
  chsh -s "$(command -v zsh)"
fi

echo ""
echo "==> Done! Restart your shell or run: source ~/.zshrc"
echo "==> For tmux plugins, open tmux and press: prefix + I"
