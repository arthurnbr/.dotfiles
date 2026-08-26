#!/usr/bin/env bash
# Google Workspace MCP — selfcheck. Run manually: bash selfcheck.sh
set -uo pipefail
ok=0; warn=0; err=0
say(){ printf '%s\n' "$*"; }
ENV_FILE="${HOME}/.secrets/google.env"
export PATH="${HOME}/.local/bin:${PATH}"

if command -v uvx >/dev/null 2>&1; then say "OK   uv present ($(uv --version 2>/dev/null))"; ok=$((ok+1));
else say "ERR  uv/uvx absent -> curl -LsSf https://astral.sh/uv/install.sh | sh"; err=$((err+1)); fi

if [ -f "${ENV_FILE}" ]; then say "OK   ${ENV_FILE} present"; ok=$((ok+1));
  set -a; . "${ENV_FILE}" 2>/dev/null || true; set +a
  for v in GOOGLE_OAUTH_CLIENT_ID GOOGLE_OAUTH_CLIENT_SECRET USER_GOOGLE_EMAIL; do
    if [ -n "${!v:-}" ]; then say "OK   ${v} renseigne"; ok=$((ok+1));
    else say "ERR  ${v} vide dans ${ENV_FILE}"; err=$((err+1)); fi
  done
else say "ERR  ${ENV_FILE} introuvable"; err=$((err+1)); fi

CRED_DIR="${WORKSPACE_MCP_CREDENTIALS_DIR:-${HOME}/.secrets/google/credentials}"
if compgen -G "${CRED_DIR}/*.json" >/dev/null 2>&1; then
  say "OK   token OAuth cache dans ${CRED_DIR} (deja authentifie)"; ok=$((ok+1));
else
  say "WARN token OAuth absent -> lance: bash $(dirname "$0")/auth-once.sh"; warn=$((warn+1)); fi

say ""
say "Resume: ${ok} OK / ${warn} WARN / ${err} ERR"
[ "${err}" -eq 0 ]
