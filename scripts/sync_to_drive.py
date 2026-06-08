#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "google-api-python-client>=2.0",
#   "google-auth-oauthlib>=1.0",
# ]
# ///
"""Upload a Markdown file to Google Drive as a Google Doc and print a shareable
(commenter) link.

One-way only: md -> Google Doc. Re-running on the same file UPDATES the same
Doc (so the link is stable and existing comments survive) instead of creating a
new one.

First run does a browser OAuth dance and caches a token; run it once from a
terminal before wiring it into nvim.

Stdout is *only* the final URL (so editors can capture it cleanly). All logs go
to stderr.
"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# drive.file = the app can only touch files it created. Minimal, least-scary
# consent screen, and enough to create/update our docs + set their sharing.
SCOPES = ["https://www.googleapis.com/auth/drive.file"]

CONFIG_DIR = Path(
    os.environ.get("SYNC_TO_DRIVE_DIR", Path.home() / ".config" / "sync-to-drive")
)
CLIENT_SECRET = CONFIG_DIR / "client_secret.json"
TOKEN = CONFIG_DIR / "token.json"
FILE_MAP = CONFIG_DIR / "file_map.json"  # local md path -> drive file id

DOCX_MIME = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
GDOC_MIME = "application/vnd.google-apps.document"

# Drop docs into this top-level Drive folder (created on first use). Override
# with SYNC_TO_DRIVE_FOLDER, or set it empty to use the "My Drive" root.
FOLDER_NAME = os.environ.get("SYNC_TO_DRIVE_FOLDER", "nvim-uploads")


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def die(msg, code=1):
    log(f"error: {msg}")
    sys.exit(code)


def get_credentials() -> Credentials:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    creds = None
    if TOKEN.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN), SCOPES)
    if creds and creds.valid:
        return creds
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
        TOKEN.write_text(creds.to_json())
        return creds
    if not CLIENT_SECRET.exists():
        die(
            f"missing OAuth client at {CLIENT_SECRET}\n"
            "  Create one in Google Cloud Console (Desktop app) and save the\n"
            "  downloaded JSON to that path. See the setup guide."
        )
    flow = InstalledAppFlow.from_client_secrets_file(str(CLIENT_SECRET), SCOPES)
    creds = flow.run_local_server(port=0)
    TOKEN.write_text(creds.to_json())
    log(f"saved token to {TOKEN}")
    return creds


def md_to_docx(md_path: Path) -> Path:
    out = Path(tempfile.mkdtemp()) / (md_path.stem + ".docx")
    subprocess.run(
        ["pandoc", str(md_path), "-o", str(out)],
        check=True,
        capture_output=True,
        text=True,
    )
    return out


def load_map() -> dict:
    if FILE_MAP.exists():
        try:
            return json.loads(FILE_MAP.read_text())
        except json.JSONDecodeError:
            return {}
    return {}


def save_map(m: dict):
    FILE_MAP.write_text(json.dumps(m, indent=2))


def ensure_folder(service, name: str) -> str:
    q = (
        f"name = '{name}' and mimeType = 'application/vnd.google-apps.folder' "
        "and trashed = false"
    )
    res = service.files().list(q=q, fields="files(id)", pageSize=1).execute()
    files = res.get("files", [])
    if files:
        return files[0]["id"]
    meta = {"name": name, "mimeType": "application/vnd.google-apps.folder"}
    folder = service.files().create(body=meta, fields="id").execute()
    return folder["id"]


def main():
    if len(sys.argv) != 2:
        die("usage: sync_to_drive.py <file.md>")
    md_path = Path(sys.argv[1]).expanduser().resolve()
    if not md_path.exists():
        die(f"no such file: {md_path}")

    creds = get_credentials()
    service = build("drive", "v3", credentials=creds, cache_discovery=False)

    log("converting markdown -> docx via pandoc…")
    docx = md_to_docx(md_path)
    media = MediaFileUpload(str(docx), mimetype=DOCX_MIME, resumable=True)

    fmap = load_map()
    key = str(md_path)
    existing_id = fmap.get(key)

    if existing_id:
        try:
            log(f"updating existing Doc {existing_id}…")
            file = (
                service.files()
                .update(fileId=existing_id, media_body=media, fields="id, webViewLink")
                .execute()
            )
        except Exception as e:  # doc was deleted/trashed -> fall back to create
            log(f"update failed ({e}); creating a new Doc")
            existing_id = None

    if not existing_id:
        body = {"name": md_path.stem, "mimeType": GDOC_MIME}
        if FOLDER_NAME:
            body["parents"] = [ensure_folder(service, FOLDER_NAME)]
        log("creating new Google Doc…")
        file = (
            service.files()
            .create(body=body, media_body=media, fields="id, webViewLink")
            .execute()
        )
        # anyone with the link can COMMENT (not just view)
        service.permissions().create(
            fileId=file["id"],
            body={"type": "anyone", "role": "commenter"},
        ).execute()
        fmap[key] = file["id"]
        save_map(fmap)

    print(file["webViewLink"])


if __name__ == "__main__":
    main()
