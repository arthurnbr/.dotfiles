#!/usr/bin/env bash
# Serveurs Eduvia for herdr-app. Travels in ~/.dotfiles (stow package `herdr`):
#   mods/eduvia-servers/   this mod
#   layouts/eduvia.json    Herdr's main layout + the Serveurs Eduvia button next to the tabs
#
# On a new machine, `stow herdr` (setup*.sh does it) puts both in place. This script checks
# what the mod needs and shows the layout:
#
#   ~/.config/herdr-app/mods/eduvia-servers/install.sh
#
# HERDR_APP_HOME: another herdr-app home (default ~/.config/herdr-app).
# Off: ctrl-shift-l back to "main", or `herdr-app do layout.toggle --id eduvia-servers`.
set -euo pipefail
home=${HERDR_APP_HOME:-$HOME/.config/herdr-app}

missing=()
for tool in herdr-app hc jq ss bash; do command -v "$tool" >/dev/null || missing+=("$tool"); done
[ ${#missing[@]} -eq 0 ] || { echo "manquant : ${missing[*]}" >&2; exit 1; }
[ -f "$home/mods/eduvia-servers/main.js" ] && [ -f "$home/layouts/eduvia.json" ] \
  || { echo "mod ou layout absent de $home : lance \`stow herdr\` depuis ~/.dotfiles" >&2; exit 1; }

herdr-app check "$home/mods/eduvia-servers"
if herdr-app status >/dev/null 2>&1; then
  herdr-app do layout.switch '{"name":"eduvia"}' >/dev/null
  echo "Layout « eduvia » affiché (ctrl-shift-l pour changer de layout)."
else
  echo "herdr-app n’est pas ouvert : choisis le layout « Eduvia » dans Réglages > Look, ou relance ce script."
fi
