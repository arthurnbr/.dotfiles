#!/usr/bin/env bash
# Google Workspace MCP — launcher (stdio). Loads its own secret, execs workspace-mcp via uvx.
#
# WHAT: exposes Arthur's Google (Gmail + Calendar) as MCP tools to any MCP client
#       (Claude Code, OMP, Codex, OpenClaw). Server = taylorwilsdon/workspace-mcp (uvx).
# SECRET: ~/.secrets/google.env (GOOGLE_OAUTH_CLIENT_ID/SECRET, USER_GOOGLE_EMAIL),
#       synced via Seafile. OAuth token cached in ~/.secrets/google/credentials/
#       (plain JSON per user) -> syncs to every machine = connect once, everywhere.
# WIRE: { "command": "bash", "args": ["<ABS>/launch.sh"] }  (see mcp.example.json)
# AUTH: one-time -> bash ~/.claude/mcp-servers/google/auth-once.sh
# NOTE: all diagnostics go to stderr; stdout stays pure JSON-RPC for MCP.
set -euo pipefail

ENV_FILE="${HOME}/.secrets/google.env"
if [ ! -f "${ENV_FILE}" ]; then
  echo "google MCP: ${ENV_FILE} introuvable. Synchronise ~/.secrets (Seafile) ou cree-le (cf. runbook)." >&2
  exit 1
fi
set -a; . "${ENV_FILE}"; set +a

if [ -z "${GOOGLE_OAUTH_CLIENT_ID:-}" ]; then
  echo "google MCP: GOOGLE_OAUTH_CLIENT_ID manquant dans ${ENV_FILE} (cree l'OAuth client Desktop dans Google Cloud Console)." >&2
  exit 1
fi

export WORKSPACE_MCP_CREDENTIALS_DIR="${WORKSPACE_MCP_CREDENTIALS_DIR:-${HOME}/.secrets/google/credentials}"
export WORKSPACE_MCP_PORT="${WORKSPACE_MCP_PORT:-8000}"
export GOOGLE_OAUTH_REDIRECT_URI="${GOOGLE_OAUTH_REDIRECT_URI:-http://localhost:${WORKSPACE_MCP_PORT}/oauth2callback}"
export OAUTHLIB_INSECURE_TRANSPORT="${OAUTHLIB_INSECURE_TRANSPORT:-1}"
export PATH="${HOME}/.local/bin:${PATH}"

exec uvx workspace-mcp --single-user --tools gmail calendar --transport stdio
