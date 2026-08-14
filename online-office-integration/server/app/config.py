from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} is required")
    return value.rstrip("/")


@dataclass(frozen=True)
class Settings:
    public_base_url: str
    bridge_internal_url: str
    onlyoffice_public_url: str
    onlyoffice_internal_url: str
    onlyoffice_jwt_secret: str
    bridge_api_key: str
    storage_dir: Path
    session_ttl_seconds: int
    max_upload_bytes: int

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            public_base_url=_required("PUBLIC_BASE_URL"),
            bridge_internal_url=_required("BRIDGE_INTERNAL_URL"),
            onlyoffice_public_url=_required("ONLYOFFICE_PUBLIC_URL"),
            onlyoffice_internal_url=_required("ONLYOFFICE_INTERNAL_URL"),
            onlyoffice_jwt_secret=_required("ONLYOFFICE_JWT_SECRET"),
            bridge_api_key=_required("BRIDGE_API_KEY"),
            storage_dir=Path(os.getenv("STORAGE_DIR", "/app/storage")),
            session_ttl_seconds=int(os.getenv("SESSION_TTL_SECONDS", "86400")),
            max_upload_bytes=int(os.getenv("MAX_UPLOAD_BYTES", str(200 * 1024 * 1024))),
        )
