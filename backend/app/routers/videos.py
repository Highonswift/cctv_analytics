from __future__ import annotations

import shutil
import threading
import uuid
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.config import settings
from app.models import VideoRecord
from app.services.pipeline import process_video
from app.store import video_store

router = APIRouter(prefix="/api/videos", tags=["videos"])

ALLOWED_SUFFIXES = {".mp4", ".mov", ".avi", ".mkv", ".webm"}
MAX_CATEGORIES = 10
MAX_CATEGORY_LENGTH = 80


def parse_categories(raw: str | None) -> list[str]:
    """Comma-separated extra categories from the upload form -> a clean,
    de-duplicated list (case-insensitive), capped in count and length."""
    seen: set[str] = set()
    out: list[str] = []
    for item in (raw or "").split(","):
        item = " ".join(item.split())[:MAX_CATEGORY_LENGTH]
        if item and item.lower() not in seen:
            seen.add(item.lower())
            out.append(item)
    return out[:MAX_CATEGORIES]


@router.get("")
def list_videos() -> list[VideoRecord]:
    return video_store.list_all()


@router.get("/{video_id}")
def get_video(video_id: str) -> VideoRecord:
    record = video_store.get(video_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Video not found")
    return record


@router.post("")
async def upload_video(
    file: UploadFile = File(...), categories: str | None = Form(None)
) -> VideoRecord:
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in ALLOWED_SUFFIXES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type {suffix!r}. Allowed: {sorted(ALLOWED_SUFFIXES)}",
        )

    requested = parse_categories(categories)

    video_id = uuid.uuid4().hex
    dest_path = settings.videos_path / f"{video_id}{suffix}"
    with dest_path.open("wb") as out_file:
        shutil.copyfileobj(file.file, out_file)

    record = video_store.create(
        video_id=video_id,
        filename=file.filename or dest_path.name,
        video_url=f"/media/videos/{dest_path.name}",
        requested_categories=requested,
    )

    thread = threading.Thread(
        target=process_video, args=(video_id, str(dest_path), requested), daemon=True
    )
    thread.start()

    return record
