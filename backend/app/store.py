"""Thread-safe registry of uploaded videos and their YOLO+VLM results.

Persisted as one JSON file per video under storage/results/ so the list
survives a backend restart. This is intentionally file-based rather than a
database -- phase 1 only needs to display saved results, and a later phase
(the "future use" LLM chat over this data) can read the same JSON files.
"""
from __future__ import annotations

import json
import logging
import threading
from datetime import datetime, timezone

from app.config import settings
from app.models import PersonResult, VideoRecord

logger = logging.getLogger("store")


class VideoStore:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._records: dict[str, VideoRecord] = {}
        self._load_from_disk()

    def _load_from_disk(self) -> None:
        for path in settings.results_path.glob("*.json"):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                record = VideoRecord.model_validate(data)
                self._records[record.id] = record
            except Exception:
                logger.exception("Failed to load saved result %s", path)

    def _persist(self, record: VideoRecord) -> None:
        path = settings.results_path / f"{record.id}.json"
        path.write_text(record.model_dump_json(indent=2), encoding="utf-8")

    def create(
        self, video_id: str, filename: str, video_url: str, requested_categories: list[str] | None = None
    ) -> VideoRecord:
        record = VideoRecord(
            id=video_id,
            filename=filename,
            video_url=video_url,
            status="pending",
            requested_categories=requested_categories or [],
            created_at=datetime.now(timezone.utc).isoformat(),
        )
        with self._lock:
            self._records[video_id] = record
            self._persist(record)
        return record

    def get(self, video_id: str) -> VideoRecord | None:
        with self._lock:
            return self._records.get(video_id)

    def list_all(self) -> list[VideoRecord]:
        with self._lock:
            return sorted(self._records.values(), key=lambda r: r.created_at, reverse=True)

    def set_status(self, video_id: str, status: str, error: str | None = None) -> None:
        with self._lock:
            record = self._records.get(video_id)
            if record is None:
                return
            record.status = status
            record.error = error
            self._persist(record)

    def add_person(self, video_id: str, person: PersonResult) -> None:
        with self._lock:
            record = self._records.get(video_id)
            if record is None:
                return
            record.persons.append(person)
            self._persist(record)


video_store = VideoStore()
