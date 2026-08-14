from __future__ import annotations

import asyncio
import html
import json
import os
import re
import secrets
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncIterator, Dict
from urllib.parse import urlparse, urlunparse

import httpx
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse, HTMLResponse

from .config import Settings
from .security import encode_jwt, secure_equal
from .store import Session, SessionStore

SUPPORTED_TYPES: Dict[str, str] = {
    "doc": "word", "docx": "word", "odt": "word", "rtf": "word",
    "txt": "word", "pdf": "word", "md": "word", "markdown": "word",
    "html": "word", "htm": "word",
    "xls": "cell", "xlsx": "cell", "ods": "cell", "csv": "cell",
    "ppt": "slide", "pptx": "slide", "odp": "slide",
}
SAFE_ID = re.compile(r"^[a-f0-9]{32}$")


def create_app(settings: Settings | None = None) -> FastAPI:
    config = settings or Settings.from_env()
    store = SessionStore(config.storage_dir)

    async def cleanup_loop() -> None:
        while True:
            await asyncio.sleep(min(900, max(60, config.session_ttl_seconds // 4)))
            store.cleanup(config.session_ttl_seconds)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        task = asyncio.create_task(cleanup_loop())
        try:
            yield
        finally:
            task.cancel()

    app = FastAPI(title="ONLYOFFICE Bridge", version="1.0.0", lifespan=lifespan)
    app.state.settings = config
    app.state.store = store

    def require_api_key(x_api_key: str = Header(default="")) -> None:
        if not secure_equal(x_api_key, config.bridge_api_key):
            raise HTTPException(status_code=401, detail="Invalid API key")

    def get_session(session_id: str) -> Session:
        if not SAFE_ID.fullmatch(session_id):
            raise HTTPException(status_code=404, detail="Session not found")
        session = store.get(session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        if session.updated_at < int(time.time()) - config.session_ttl_seconds:
            store.delete(session_id)
            raise HTTPException(status_code=410, detail="Session expired")
        return session

    def validate_session_token(session: Session, token: str) -> None:
        if not secure_equal(token, session.token):
            raise HTTPException(status_code=403, detail="Invalid session token")

    def document_key(session: Session) -> str:
        return f"{session.id}-{session.updated_at}"

    @app.get("/health")
    async def health() -> dict:
        return {"ok": True}

    @app.post("/api/office/sessions", dependencies=[Depends(require_api_key)])
    async def create_session(
        file: UploadFile = File(...), mode: str = Form(default="edit")
    ) -> dict:
        filename = Path(file.filename or "document").name
        suffix = Path(filename).suffix.lower().lstrip(".")
        document_type = SUPPORTED_TYPES.get(suffix)
        if not document_type:
            raise HTTPException(status_code=415, detail="Unsupported document type")
        normalized_mode = "view" if mode.lower() == "view" else "edit"
        session = Session(
            id=secrets.token_hex(16), token=secrets.token_urlsafe(32), filename=filename,
            file_type="txt" if suffix in {"md", "markdown"} else suffix,
            document_type=document_type, mode=normalized_mode,
            created_at=int(time.time()), updated_at=int(time.time()),
        )
        destination = store.original_path(session.id)
        destination.parent.mkdir(parents=True, exist_ok=False)
        size = 0
        try:
            with destination.open("wb") as output:
                while chunk := await file.read(1024 * 1024):
                    size += len(chunk)
                    if size > config.max_upload_bytes:
                        raise HTTPException(status_code=413, detail="File is too large")
                    output.write(chunk)
            if size == 0:
                raise HTTPException(status_code=400, detail="File is empty")
            store.save(session)
        except Exception:
            store.delete(session.id)
            raise
        editor_url = f"{config.public_base_url}/office/editor/{session.id}?token={session.token}"
        return {"sessionId": session.id, "editorUrl": editor_url, "expiresIn": config.session_ttl_seconds}

    @app.get("/office/editor/{session_id}", response_class=HTMLResponse)
    async def editor(session_id: str, token: str = Query(...)) -> str:
        session = get_session(session_id)
        validate_session_token(session, token)
        document_url = f"{config.bridge_internal_url}/office/file/{session.id}?token={session.token}"
        callback_url = f"{config.bridge_internal_url}/office/callback/{session.id}?token={session.token}"
        editor_config = {
            "documentType": session.document_type,
            "document": {
                "fileType": session.file_type,
                "key": document_key(session),
                "title": session.filename,
                "url": document_url,
                "permissions": {"edit": session.mode == "edit", "download": True, "print": True},
            },
            "editorConfig": {"mode": session.mode, "lang": "zh-CN", "callbackUrl": callback_url},
            "type": "desktop" if session.mode == "edit" else "embedded",
            "height": "100%", "width": "100%",
        }
        editor_config["token"] = encode_jwt(editor_config, config.onlyoffice_jwt_secret)
        api_url = f"{config.onlyoffice_public_url}/web-apps/apps/api/documents/api.js"
        return f"""<!doctype html><html><head><meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
<style>html,body,#editor{{height:100%;margin:0;overflow:hidden}}</style></head>
<body><div id=\"editor\"></div><script src=\"{html.escape(api_url, quote=True)}\"></script>
<script>new DocsAPI.DocEditor('editor',{json.dumps(editor_config, ensure_ascii=False, separators=(',', ':'))});</script>
</body></html>"""

    @app.get("/office/file/{session_id}")
    async def office_file(session_id: str, token: str = Query(...)) -> FileResponse:
        session = get_session(session_id)
        validate_session_token(session, token)
        source = store.result_path(session.id) if store.result_path(session.id).is_file() else store.original_path(session.id)
        return FileResponse(source, filename=session.filename, media_type="application/octet-stream")

    def safe_onlyoffice_download_url(raw_url: str) -> str:
        candidate = urlparse(raw_url)
        public = urlparse(config.onlyoffice_public_url)
        internal = urlparse(config.onlyoffice_internal_url)
        if candidate.scheme not in {"http", "https"} or candidate.hostname != public.hostname:
            if candidate.scheme != internal.scheme or candidate.netloc != internal.netloc:
                raise HTTPException(status_code=400, detail="Unexpected download host")
            return raw_url
        return urlunparse((internal.scheme, internal.netloc, candidate.path, candidate.params, candidate.query, ""))

    @app.post("/office/callback/{session_id}")
    async def callback(session_id: str, payload: dict, token: str = Query(...)) -> dict:
        session = get_session(session_id)
        validate_session_token(session, token)
        status = int(payload.get("status", 0))
        if status in {2, 6}:
            download_url = safe_onlyoffice_download_url(str(payload.get("url", "")))
            temporary = store.directory(session.id) / "result.tmp"
            async with httpx.AsyncClient(timeout=120, follow_redirects=False) as client:
                async with client.stream("GET", download_url) as response:
                    response.raise_for_status()
                    size = 0
                    with temporary.open("wb") as output:
                        async for chunk in response.aiter_bytes(1024 * 1024):
                            size += len(chunk)
                            if size > config.max_upload_bytes:
                                raise HTTPException(status_code=413, detail="Edited result is too large")
                            output.write(chunk)
            temporary.replace(store.result_path(session.id))
            session.status = "saved"
            store.save(session)
        elif status == 4:
            session.status = "closed"
            store.save(session)
        return {"error": 0}

    @app.get("/api/office/sessions/{session_id}", dependencies=[Depends(require_api_key)])
    async def session_status(session_id: str) -> dict:
        session = get_session(session_id)
        return {"sessionId": session.id, "status": session.status, "resultReady": store.result_path(session.id).is_file()}

    @app.post("/api/office/sessions/{session_id}/force-save", dependencies=[Depends(require_api_key)])
    async def force_save(session_id: str) -> dict:
        session = get_session(session_id)
        if session.mode != "edit":
            raise HTTPException(status_code=409, detail="Session is not editable")

        # Move the previous result aside so it cannot satisfy the next poll.
        # It is restored when ONLYOFFICE reports that there were no new edits.
        previous_result = store.result_path(session.id)
        saved_result = store.directory(session.id) / "result.previous"
        if saved_result.is_file():
            saved_result.unlink()
        if previous_result.is_file():
            previous_result.replace(saved_result)

        command = {"c": "forcesave", "key": document_key(session)}
        headers = {"Authorization": f"Bearer {encode_jwt(command, config.onlyoffice_jwt_secret)}"}
        command_url = f"{config.onlyoffice_internal_url}/coauthoring/CommandService.ashx"
        try:
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.post(command_url, json=command, headers=headers)
                response.raise_for_status()
                result = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            if saved_result.is_file() and not previous_result.is_file():
                saved_result.replace(previous_result)
            raise HTTPException(status_code=502, detail="ONLYOFFICE force-save request failed") from exc

        error = int(result.get("error", -1))
        if error == 4:
            if saved_result.is_file() and not previous_result.is_file():
                saved_result.replace(previous_result)
            return {"accepted": False, "unchanged": True}
        if error != 0:
            if saved_result.is_file() and not previous_result.is_file():
                saved_result.replace(previous_result)
            raise HTTPException(status_code=502, detail=f"ONLYOFFICE force-save error: {error}")
        if saved_result.is_file():
            saved_result.unlink()
        return {"accepted": True}

    @app.get("/api/office/sessions/{session_id}/result", dependencies=[Depends(require_api_key)])
    async def result(session_id: str) -> FileResponse:
        session = get_session(session_id)
        path = store.result_path(session.id)
        if not path.is_file():
            raise HTTPException(status_code=409, detail="Edited result is not ready")
        return FileResponse(path, filename=session.filename, media_type="application/octet-stream")

    @app.delete("/api/office/sessions/{session_id}", dependencies=[Depends(require_api_key)])
    async def delete_session(session_id: str) -> dict:
        session = get_session(session_id)
        store.delete(session.id)
        return {"deleted": True}

    return app


app = create_app() if os.getenv("PUBLIC_BASE_URL") else FastAPI(title="ONLYOFFICE Bridge (not configured)")
