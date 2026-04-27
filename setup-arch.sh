#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(zsh tmux ghostty zed git claude)

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
# 6. Set ghostty as default terminal (xdg-terminal-exec)
# ──────────────────────────────────────────
mkdir -p "$HOME/.config"
if ! grep -qx "ghostty.desktop" "$HOME/.config/xdg-terminals.list" 2>/dev/null; then
  echo "==> Setting ghostty as default terminal..."
  echo "ghostty.desktop" > "$HOME/.config/xdg-terminals.list"
fi

# ──────────────────────────────────────────
# 7. Set zsh as default shell if needed
# ──────────────────────────────────────────
if [ "$SHELL" != "$(command -v zsh)" ]; then
  echo "==> Setting zsh as default shell (you'll be prompted for password)..."
  chsh -s "$(command -v zsh)"
fi

echo ""
echo "==> Done! Restart your shell or run: source ~/.zshrc"
echo "==> For tmux plugins, open tmux and press: prefix + I"
