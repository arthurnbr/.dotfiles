#!/usr/bin/env python3
"""One-time Google OAuth for the Google Workspace MCP (Gmail perso).

Runs the installed-app OAuth flow (opens a browser once), then writes the token
JSON exactly where taylorwilsdon/workspace-mcp reads it
(WORKSPACE_MCP_CREDENTIALS_DIR/<email>.json). Requested scopes == what the server
requests for `--tools gmail calendar` (BASE + GMAIL + CALENDAR), so no agent ever
re-prompts. Env comes from ~/.secrets/google.env (sourced by auth-once.sh).

Refresh token never expires ONLY if the OAuth consent screen is published
"In production" (Testing mode => 7-day expiry = the reconnection pain).
"""
import json
import os
import sys
from pathlib import Path
from urllib.parse import quote

from google_auth_oauthlib.flow import InstalledAppFlow

# BASE + GMAIL + CALENDAR (mirrors auth/scopes.py get_scopes_for_tools(['gmail','calendar']))
SCOPES = [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/userinfo.profile",
    "openid",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.send",
    "https://www.googleapis.com/auth/gmail.compose",
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/gmail.labels",
    "https://www.googleapis.com/auth/gmail.settings.basic",
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/calendar.events",
]

cid = os.environ.get("GOOGLE_OAUTH_CLIENT_ID")
csec = os.environ.get("GOOGLE_OAUTH_CLIENT_SECRET")
email = os.environ.get("USER_GOOGLE_EMAIL") or None
port = int(os.environ.get("WORKSPACE_MCP_PORT", "8000"))
creds_dir = os.path.expanduser(
    os.environ.get("WORKSPACE_MCP_CREDENTIALS_DIR", "~/.secrets/google/credentials")
)

if not cid or not csec:
    sys.exit("GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET manquants dans ~/.secrets/google.env")

client_config = {
    "installed": {
        "client_id": cid,
        "client_secret": csec,
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "redirect_uris": ["http://localhost"],
    }
}

print(f"-> Ouverture du consentement Google (compte {email or 'a determiner'})...", file=sys.stderr)
flow = InstalledAppFlow.from_client_config(client_config, scopes=SCOPES)
creds = flow.run_local_server(
    host="localhost",
    port=port,
    open_browser=True,
    prompt="consent",
    access_type="offline",
    authorization_prompt_message="-> Si le navigateur ne s'ouvre pas, va sur:\n{url}",
    success_message="Authentifie. Tu peux fermer cet onglet et revenir au terminal.",
)

# Resolve the account email (needed for the credential filename).
acct = email
if not acct:
    try:
        from googleapiclient.discovery import build

        oa = build("oauth2", "v2", credentials=creds)
        acct = oa.userinfo().get().execute().get("email")
    except Exception as exc:  # noqa: BLE001
        sys.exit(f"Impossible de determiner l'email; renseigne USER_GOOGLE_EMAIL. ({exc})")

Path(creds_dir).mkdir(parents=True, exist_ok=True)
os.chmod(creds_dir, 0o700)
fname = quote(acct, safe="@._-") + ".json"
path = os.path.join(creds_dir, fname)
data = {
    "token": creds.token,
    "refresh_token": creds.refresh_token,
    "token_uri": creds.token_uri,
    "client_id": creds.client_id,
    "client_secret": creds.client_secret,
    "scopes": list(creds.scopes) if creds.scopes else SCOPES,
    "expiry": creds.expiry.isoformat() if creds.expiry else None,
}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    json.dump(data, f, indent=2)

print(f"OK  token ecrit: {path}")
print(f"    compte        : {acct}")
print(f"    refresh_token : {'present' if creds.refresh_token else 'ABSENT (relance avec prompt=consent / app publiee)'}")
if not creds.refresh_token:
    sys.exit(1)
