from __future__ import annotations

import json
import shutil
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterator, Optional


@dataclass
class Session:
    id: str
    token: str
    filename: str
    file_type: str
    document_type: str
    mode: str
    created_at: int
    updated_at: int
    status: str = "created"


class SessionStore:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.root.mkdir(parents=True, exist_ok=True)

    def directory(self, session_id: str) -> Path:
        return self.root / session_id

    def original_path(self, session_id: str) -> Path:
        return self.directory(session_id) / "original"

    def result_path(self, session_id: str) -> Path:
        return self.directory(session_id) / "result"

    def save(self, session: Session) -> None:
        directory = self.directory(session.id)
        directory.mkdir(parents=True, exist_ok=True)
        session.updated_at = int(time.time())
        temporary = directory / "metadata.json.tmp"
        temporary.write_text(json.dumps(asdict(session), ensure_ascii=False), encoding="utf-8")
        temporary.replace(directory / "metadata.json")

    def get(self, session_id: str) -> Optional[Session]:
        metadata = self.directory(session_id) / "metadata.json"
        if not metadata.is_file():
            return None
        try:
            return Session(**json.loads(metadata.read_text(encoding="utf-8")))
        except (OSError, ValueError, TypeError):
            return None

    def sessions(self) -> Iterator[Session]:
        for metadata in self.root.glob("*/metadata.json"):
            session = self.get(metadata.parent.name)
            if session:
                yield session

    def delete(self, session_id: str) -> None:
        shutil.rmtree(self.directory(session_id), ignore_errors=True)

    def cleanup(self, ttl_seconds: int) -> int:
        cutoff = int(time.time()) - ttl_seconds
        expired = [session.id for session in self.sessions() if session.updated_at < cutoff]
        for session_id in expired:
            self.delete(session_id)
        return len(expired)
