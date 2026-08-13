#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo "ERROR: do not run this script as root. Run it as your normal user; sudo will be invoked only for pacman." >&2
  exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(zsh tmux ghostty zed git claude hypr waybar starship nvim bin herdr ssh)

echo "==> Dotfiles setup (Arch Linux) from $DOTFILES_DIR"

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
  waybar
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

echo "==> Installing pacman packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

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

# ──────────────────────────────────────────
# 5b. Skills (OMP) + Seafile drive (sync client + token)
#    Skills travel via git (stow → ~/.claude/skills), exposed to OMP's native
#    provider through ~/.omp/agent/skills. Tokens never live in git: the Seafile
#    API token sits in ~/.secrets/seafile.env. Given that token, seaf-cli (AUR)
#    is installed and the personal libraries are pulled.
#    ONLY manual step on a fresh machine: drop ~/.secrets/seafile.env once.
# ──────────────────────────────────────────
echo "==> Linking skills for OMP..."
mkdir -p "$HOME/.omp/agent"
ln -sfn "$HOME/.claude/skills" "$HOME/.omp/agent/skills"

echo "==> Seafile drive bootstrap..."
SEAFILE_LIB_DIR="$HOME/seafile-client/seafile"
SEAFILE_SECRETS_DIR="$SEAFILE_LIB_DIR/Ma bibliothèque/secrets"
SEAFILE_ENV="$HOME/.secrets/seafile.env"
SEAFILE_LIBS=("Ma bibliothèque" "Pro" "Arthur")

if [ -r "$SEAFILE_ENV" ]; then
  # shellcheck disable=SC1090
  set -a; . "$SEAFILE_ENV"; set +a
fi

if [ -n "${SEAFILE_TOKEN:-}" ] && [ -n "${SEAFILE_URL:-}" ]; then
  # seaf-cli lives in the AUR; install on demand (token present ⇒ drive wanted).
  if ! command -v seaf-cli >/dev/null 2>&1; then
    if command -v yay >/dev/null 2>&1; then
      yay -S --needed --noconfirm seafile || true
    elif command -v paru >/dev/null 2>&1; then
      paru -S --needed --noconfirm seafile || true
    else
      echo "  ! seaf-cli missing and no AUR helper; install 'seafile' (AUR) manually." >&2
    fi
  fi
  if command -v seaf-cli >/dev/null 2>&1; then
    mkdir -p "$SEAFILE_LIB_DIR"
    [ -d "$HOME/.ccnet" ] || seaf-cli init -d "$HOME/seafile-client" >/dev/null 2>&1 || true
    sudo -n systemctl enable --now "seaf-cli@$USER.service" 2>/dev/null || seaf-cli start >/dev/null 2>&1 || true
    sleep 2
    _sf_hdr="Authorization: Token $SEAFILE_TOKEN"
    _sf_user="$(curl -fsS --max-time 20 -H "$_sf_hdr" "$SEAFILE_URL/api2/account/info/" 2>/dev/null | jq -r '.email // empty' 2>/dev/null || true)"
    _sf_repos="$(curl -fsS --max-time 20 -H "$_sf_hdr" "$SEAFILE_URL/api2/repos/" 2>/dev/null || true)"
    if [ -n "$_sf_user" ] && [ -n "$_sf_repos" ]; then
      for _sf_name in "${SEAFILE_LIBS[@]}"; do
        if [ -d "$SEAFILE_LIB_DIR/$_sf_name" ]; then continue; fi
        _sf_id="$(printf '%s' "$_sf_repos" | jq -r --arg n "$_sf_name" '[.[] | select(.name==$n)][0].id // empty' 2>/dev/null || true)"
        if [ -n "$_sf_id" ]; then
          echo "  - syncing library: $_sf_name"
          seaf-cli download -l "$_sf_id" -s "$SEAFILE_URL" -d "$SEAFILE_LIB_DIR" \
            -u "$_sf_user" -T "$SEAFILE_TOKEN" >/dev/null 2>&1 \
            || echo "    (skipped $_sf_name — encrypted or already syncing)"
        else
          echo "    (library '$_sf_name' not found via API)"
        fi
      done
    else
      echo "  ! Could not reach Seahub with the token; check $SEAFILE_ENV" >&2
    fi
  fi
else
  echo "  - No token in $SEAFILE_ENV — Seafile drive & token-based skills inactive."
  echo "    Enable once (out-of-band):"
  echo "      mkdir -p ~/.secrets"
  echo "      printf 'SEAFILE_URL=https://drive.nobrega.fr\\nSEAFILE_TOKEN=<token>\\n' > ~/.secrets/seafile.env"
  echo "      # <token>: curl -d 'username=<you>&password=<pw>' https://drive.nobrega.fr/api2/auth-token/"
  echo "    then re-run ./setup-arch.sh"
fi

# Secrets alias into the drive: only when nothing is there yet AND the target
# exists (never clobber a real ~/.secrets, never create a dangling symlink).
if [ ! -e "$HOME/.secrets" ] && [ -d "$SEAFILE_SECRETS_DIR" ]; then
  ln -sfn "$SEAFILE_SECRETS_DIR" "$HOME/.secrets"
fi

# ──────────────────────────────────────────
# 6. agent-island (Claude Code session overlay for Hyprland + Waybar)
#    Clones the repo to ~/Documents/agent-island and runs its installer
#    (idempotent merge into ~/.claude/settings.json).
# ──────────────────────────────────────────
AGENT_ISLAND_DIR="$HOME/Documents/agent-island"
if [ ! -d "$AGENT_ISLAND_DIR/.git" ]; then
  echo "==> Cloning agent-island..."
  mkdir -p "$(dirname "$AGENT_ISLAND_DIR")"
  git clone https://github.com/arthurnbr/agent-island.git "$AGENT_ISLAND_DIR"
else
  echo "==> Updating agent-island..."
  git -C "$AGENT_ISLAND_DIR" pull --ff-only || true
fi
# Walker is in the AUR — try yay/paru, otherwise warn.
if ! command -v walker >/dev/null 2>&1; then
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm walker-bin || yay -S --needed --noconfirm walker || true
  elif command -v paru >/dev/null 2>&1; then
    paru -S --needed --noconfirm walker-bin || paru -S --needed --noconfirm walker || true
  else
    echo "  ! walker not installed and no AUR helper found." >&2
    echo "    Install manually: https://github.com/abenz1267/walker" >&2
  fi
fi
"$AGENT_ISLAND_DIR/install.sh" || true

# ──────────────────────────────────────────
# 7. Set ghostty as default terminal (xdg-terminal-exec)
# ──────────────────────────────────────────
mkdir -p "$HOME/.config"
if ! grep -qx "com.mitchellh.ghostty.desktop" "$HOME/.config/xdg-terminals.list" 2>/dev/null; then
  echo "==> Setting ghostty as default terminal..."
  echo "com.mitchellh.ghostty.desktop" > "$HOME/.config/xdg-terminals.list"
fi

# ──────────────────────────────────────────
# 8. Deploy keyd config (Alt+HJKL → arrows) and enable daemon
# ──────────────────────────────────────────
echo "==> Deploying keyd config to /etc/keyd/default.conf..."
sudo install -Dm644 "$DOTFILES_DIR/keyd/default.conf" /etc/keyd/default.conf
sudo systemctl enable --now keyd
sudo keyd reload 2>/dev/null || true

# ──────────────────────────────────────────
# 9. Set zsh as default shell if needed
# ──────────────────────────────────────────
if [ "$SHELL" != "$(command -v zsh)" ]; then
  echo "==> Setting zsh as default shell (you'll be prompted for password)..."
  chsh -s "$(command -v zsh)"
fi

echo ""
echo "==> Done! Restart your shell or run: source ~/.zshrc"
echo "==> For tmux plugins, open tmux and press: prefix + I"
