#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(zsh tmux ghostty zed git karabiner)

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
brew install stow eza bat fzf zoxide fnm rbenv zsh-syntax-highlighting zsh-autosuggestions

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

echo ""
echo "==> Done! Restart your shell or run: source ~/.zshrc"
echo "==> For tmux plugins, open tmux and press: prefix + I"
