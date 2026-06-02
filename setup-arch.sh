#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo "ERROR: do not run this script as root. Run it as your normal user; sudo will be invoked only for pacman." >&2
  exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(zsh tmux ghostty zed git claude hypr waybar starship nvim bin herdr)

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
