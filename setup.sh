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
brew install stow eza bat fzf zoxide fnm rbenv zsh-syntax-highlighting zsh-autosuggestions starship neovim ripgrep fd lazygit tree-sitter jq

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
# 6. Skills (OMP) + Seafile drive (sync client + token)
#    Skills travel via git (stow → ~/.claude/skills), exposed to OMP's native
#    provider through ~/.omp/agent/skills. Tokens never live in git: the Seafile
#    API token sits in ~/.secrets/seafile.env. Given that token, seaf-cli (if
#    installed) pulls the personal libraries; the API access works regardless.
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
  if ! command -v seaf-cli >/dev/null 2>&1; then
    echo "  ! seaf-cli not found — for local sync install it manually:" >&2
    echo "    brew install --cask seafile-client   # or the Seafile-cli AppImage" >&2
    echo "    (drive API access via the token works without it.)" >&2
  fi
  if command -v seaf-cli >/dev/null 2>&1; then
    mkdir -p "$SEAFILE_LIB_DIR"
    [ -d "$HOME/.ccnet" ] || seaf-cli init -d "$HOME/seafile-client" >/dev/null 2>&1 || true
    seaf-cli start >/dev/null 2>&1 || true
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
  echo "    then re-run ./setup.sh"
fi

# Secrets alias into the drive: only when nothing is there yet AND the target
# exists (never clobber a real ~/.secrets, never create a dangling symlink).
if [ ! -e "$HOME/.secrets" ] && [ -d "$SEAFILE_SECRETS_DIR" ]; then
  ln -sfn "$SEAFILE_SECRETS_DIR" "$HOME/.secrets"
fi

echo ""
echo "==> Done! Restart your shell or run: source ~/.zshrc"
echo "==> For tmux plugins, open tmux and press: prefix + I"
