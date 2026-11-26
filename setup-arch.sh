#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo "ERROR: do not run this script as root. Run it as your normal user; sudo will be invoked only for pacman." >&2
  exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(zsh tmux ghostty zed git claude omp hypr starship nvim bin herdr ssh omarchy)

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
  tea
  tree-sitter-cli
)

echo "==> Installing packages..."
pkg_install "${PACMAN_PKGS[@]}"

# AUR GUI apps
AUR_PKGS=(
  insomnia-bin   # REST/GraphQL client (offline Scratch Pad, no account needed)
)
aur_install "${AUR_PKGS[@]}" || echo "  ! AUR install failed for: ${AUR_PKGS[*]}" >&2

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
# herdr-app writes its state (shared.json, view.json, data/) next to its config: real folders,
# so stow links only the files and mods/<name>/, never the whole herdr-app folder into the repo.
mkdir -p "$HOME/.config/herdr-app/mods" "$HOME/.config/herdr-app/layouts"
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
# 5c. Gitea (tea) login for project management (Eduvia)
#    `tea` (installed above) is wired to git.eduvia.dev from ~/.secrets/gitea.env
#    — no-op until that secret is synced. Plane uses the stowed `plane` wrapper,
#    which reads ~/.secrets/plane.env directly, so there is nothing to configure.
# ──────────────────────────────────────────
if [ -x "$DOTFILES_DIR/bin/.local/bin/gitea-login" ]; then
  echo "==> Configuring Gitea (tea) login..."
  "$DOTFILES_DIR/bin/.local/bin/gitea-login" || true
fi

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

# ──────────────────────────────────────────
# 9. Omdrop — AirDrop for Omarchy (PCs with non-Apple Wi-Fi)
#    Needs a radio backend giving an `awdl0` interface. On a PC that is
#    omdrop-owl (software AWDL via OWL); on an Apple Silicon Mac it is the
#    brcmfmac driver, which the plugin installs itself — so we skip the OWL
#    backend there. OWL only runs a validated profile for cards in its table;
#    cards it hasn't tested (e.g. Realtek RTL8822CE / rtw88) need an explicit
#    opt-in via /etc/omdrop/allow-untested, which we set when the detected
#    driver has no packaged profile. Install OWL BEFORE the plugin.
# ──────────────────────────────────────────
OMDROP_PLUGIN_URL="https://github.com/netmojo-systems/omdrop-plugin.git"
# Drivers with a validated omdrop-owl profile (shared or exclusive mode works).
OMDROP_TESTED_DRIVERS="iwlwifi mt7925e rtw88_8822be rtw89_8852ae rtw89_8852ce"

WIFI_IFACE="$(ls /sys/class/net 2>/dev/null | while read -r i; do [ -d "/sys/class/net/$i/wireless" ] && echo "$i" && break; done)"
IS_APPLE_SILICON=0
grep -qi 'Apple' /proc/device-tree/model 2>/dev/null && IS_APPLE_SILICON=1

if [ "$IS_APPLE_SILICON" = 1 ]; then
  echo "==> Omdrop: Apple Silicon Mac — the plugin installs its own brcmfmac backend on first use; skipping omdrop-owl."
  aur_install omdrop-plugin 2>/dev/null || omarchy plugin add "$OMDROP_PLUGIN_URL" 2>/dev/null || true
elif [ -z "$WIFI_IFACE" ]; then
  echo "==> Omdrop: no Wi-Fi interface detected — skipping (needs AWDL-capable Wi-Fi)."
elif [ "$IS_OMARCHY" != 1 ]; then
  echo "==> Omdrop: Omarchy not detected — the bar plugin is Omarchy-only; skipping."
else
  WIFI_DRIVER="$(basename "$(readlink -f "/sys/class/net/$WIFI_IFACE/device/driver" 2>/dev/null)" 2>/dev/null)"
  echo "==> Omdrop: Wi-Fi $WIFI_IFACE driver '$WIFI_DRIVER' — installing omdrop-owl backend..."
  aur_install omdrop-owl || echo "==> Omdrop: omdrop-owl install failed — skipping plugin." 
  if command -v omdrop-discoverable >/dev/null 2>&1 || pacman -Qq omdrop-owl >/dev/null 2>&1; then
    # Opt in to untested profile when this driver isn't in OWL's validated table.
    case " $OMDROP_TESTED_DRIVERS " in
      *" $WIFI_DRIVER "*) : ;;  # validated — no opt-in needed
      *)
        echo "==> Omdrop: driver '$WIFI_DRIVER' is untested by omdrop-owl — enabling /etc/omdrop/allow-untested (may fail to discover, or drop Wi-Fi while visible)."
        sudo mkdir -p /etc/omdrop
        echo 1 | sudo tee /etc/omdrop/allow-untested >/dev/null
        # The fallback "*" profile is shared mode, which needs the AP on
        # channel 6/44/149 and a connected Wi-Fi passing traffic — impossible
        # on managed networks (eduroam: channel 52). The RTL8822CE shares the
        # rtw88 driver and generation of the validated RTL8822BE, which works
        # in EXCLUSIVE mode, so pin that here (Wi-Fi drops during the window).
        if [ "$WIFI_DRIVER" = "rtw88_8822ce" ] && [ ! -f /etc/omdrop/owl-profiles ]; then
          echo "==> Omdrop: pinning RTL8822CE to exclusive mode (/etc/omdrop/owl-profiles)."
          sudo tee /etc/omdrop/owl-profiles >/dev/null <<'OWLPROF'
# driver      status    mode       mon_mac  reconnect  mt76_pm  notes
rtw88_8822ce  untested  exclusive  station  no         no       RTL8822CE (rtw88), exclusive like its 8822BE cousin. Wi-Fi off during the window.
OWLPROF
        fi
        ;;
    esac
    echo "==> Omdrop: adding the Omarchy plugin..."
    omarchy plugin add "$OMDROP_PLUGIN_URL" 2>/dev/null || true
  fi
fi

# ──────────────────────────────────────────
# 10. Tormarchy — Tor toggle in the Omarchy bar (tripleu.tor)
#     `--enable` places the widget in the bar (right section). `setup` is the
#     root side (tor, nftables helper in /usr/local/bin, polkit rule, tor group);
#     it is idempotent and must be re-run after `omarchy plugin update`.
# ──────────────────────────────────────────
TORMARCHY_PLUGIN_URL="https://github.com/TripleU613/tormarchy.git"
TORMARCHY_DIR="$HOME/.config/omarchy/plugins/tripleu.tor"
if [ "$IS_OMARCHY" = 1 ]; then
  if [ ! -d "$TORMARCHY_DIR" ]; then
    echo "==> Tormarchy: adding the Omarchy plugin..."
    omarchy plugin add "$TORMARCHY_PLUGIN_URL" --enable --yes || true
  fi
  if [ -x "$TORMARCHY_DIR/tormarchy" ]; then
    echo "==> Tormarchy: installing the system side (sudo)..."
    sudo "$TORMARCHY_DIR/tormarchy" setup || echo "==> Tormarchy: setup failed — re-run: sudo $TORMARCHY_DIR/tormarchy setup"
  fi
else
  echo "==> Tormarchy: Omarchy not detected — the bar plugin is Omarchy-only; skipping."
fi

# ──────────────────────────────────────────
# 11. Wallpaper Engine — live wallpapers on Omarchy (io.github.dkgamer02ai.wallpaper-engine)
#     Renders Steam Wallpaper Engine scene/video wallpapers on the Hyprland
#     background layer. `linux-wallpaperengine-git` (AUR) is the renderer; the
#     plugin ships the omarchy-we CLI, the Omatrix dial, a theme-set hook and the
#     menu > Style entry (its install.sh wires all that up, incl. the autostart
#     `omarchy-we launch` line). Steam + subscribed wallpapers stay manual.
#     Rebind SUPER+CTRL+SPACE -> Omatrix lives in hypr/bindings.lua (stowed).
#     The power-profile FPS watcher (omarchy-we-fps-watch) is stowed in bin/.
# ──────────────────────────────────────────
WE_PLUGIN_URL="https://github.com/dkgamer02ai/omarchy-wallpaper-engine.git"
WE_PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.dkgamer02ai.wallpaper-engine"
WE_AUTOSTART="$HOME/.config/hypr/autostart.lua"
WE_FPS_LINE='o.launch_on_start("omarchy-we-fps-watch")'
if [ "$IS_OMARCHY" = 1 ]; then
  aur_install linux-wallpaperengine-git || echo "==> Wallpaper Engine: renderer install failed — live wallpapers will not render until: yay -S linux-wallpaperengine-git"
  if [ ! -d "$WE_PLUGIN_DIR" ]; then
    echo "==> Wallpaper Engine: adding the Omarchy plugin..."
    omarchy plugin add "$WE_PLUGIN_URL" --enable --yes || true
  fi
  # install.sh links the CLI, drops the transparent bg, installs the theme-set
  # hook, the menu row and the `omarchy-we launch` autostart line. --no-deps
  # because the AUR renderer is handled above. Idempotent; safe to re-run.
  if [ -x "$WE_PLUGIN_DIR/install.sh" ]; then
    "$WE_PLUGIN_DIR/install.sh" --no-deps || echo "==> Wallpaper Engine: install.sh failed — re-run: $WE_PLUGIN_DIR/install.sh --no-deps"
  fi
  omarchy plugin enable io.github.dkgamer02ai.wallpaper-engine >/dev/null 2>&1 || true
  # Add the power-profile FPS watcher to autostart (install.sh only adds the
  # `omarchy-we launch` line). autostart.lua is omarchy-managed, so append in
  # place rather than stow; guard against duplicates.
  if [ -f "$WE_AUTOSTART" ] && ! grep -qF 'omarchy-we-fps-watch' "$WE_AUTOSTART"; then
    printf '\n-- Switch Wallpaper Engine FPS cap with the power profile (power-saver -> 30 fps).\n%s\n' "$WE_FPS_LINE" >> "$WE_AUTOSTART"
  fi
else
  echo "==> Wallpaper Engine: Omarchy not detected — the live-wallpaper plugin is Omarchy-only; skipping."
fi

echo ""
echo "==> Done! Restart your shell or run: source ~/.zshrc"
echo "==> For tmux plugins, open tmux and press: prefix + I"
