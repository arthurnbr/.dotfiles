#!/usr/bin/env bash
# One-time Google OAuth for the Google Workspace MCP. Run once on a machine with a
# browser: bash ~/.claude/mcp-servers/google/auth-once.sh
# Writes the token to ~/.secrets/google/credentials/<email>.json (Seafile-synced).
set -euo pipefail

ENV_FILE="${HOME}/.secrets/google.env"
if [ ! -f "${ENV_FILE}" ]; then
  echo "auth-once: ${ENV_FILE} introuvable. Cree-le d'abord (cf. runbook)." >&2
  exit 1
fi
set -a; . "${ENV_FILE}"; set +a
export PATH="${HOME}/.local/bin:${PATH}"
export OAUTHLIB_INSECURE_TRANSPORT="${OAUTHLIB_INSECURE_TRANSPORT:-1}"

DIR="$(cd "$(dirname "$0")" && pwd)"
exec uv run --quiet \
  --with google-auth-oauthlib \
  --with google-api-python-client \
  python "${DIR}/auth-once.py"
