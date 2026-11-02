from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel

VideoStatus = Literal["pending", "processing", "done", "error"]


class AdditionalCategory(BaseModel):
    """The VLM's answer for one user-requested extra category."""

    present: Optional[bool] = None  # None = the model didn't say / answer unreadable
    detail: Optional[str] = None  # short free-text detail, e.g. "black umbrella"


class PersonResult(BaseModel):
    track_id: int  # the track the shown crop came from
    # Every ByteTrack id merged into this person by appearance re-ID. Only
    # more than one id when re-ID is enabled (REID_ENABLED).
    track_ids: list[int] = []
    label: str  # e.g. "ID1"
    # Attributes read from the crop by the VLM. None = the model didn't say /
    # its answer couldn't be read / the check failed. See services/vlm_client.py.
    category: str = "unknown"  # male | female | child | unknown
    dress_color: Optional[str] = None  # colour of the top
    dress_type: Optional[str] = None  # free text: shirt, tshirt, saree, nighty, ...
    holding_bag: Optional[bool] = None
    bags: list[str] = []  # free text, one entry per bag held (suitcase, jute bag, ...)
    face_covered: Optional[bool] = None
    face_cover_type: Optional[str] = None  # free text: balaclava, helmet, mask, kerchief, ...
    # When the best crop was taken, and the stretch of video to play for it
    # (crop moment +/- PLAYBACK_WINDOW_SEC, clamped to the video). None for
    # records processed before timelines existed.
    # One entry per category the user asked for at upload (keyed by the category
    # as typed); empty when none were requested.
    additional_categories: dict[str, AdditionalCategory] = {}
    timestamp_sec: Optional[float] = None
    timeline_start_sec: Optional[float] = None
    timeline_end_sec: Optional[float] = None
    summary: str
    crop_url: str


class VideoRecord(BaseModel):
    id: str
    filename: str
    video_url: str
    status: VideoStatus
    requested_categories: list[str] = []  # extra categories asked for at upload
    created_at: str
    error: Optional[str] = None
    persons: list[PersonResult] = []
