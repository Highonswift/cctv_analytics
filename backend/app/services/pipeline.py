"""End-to-end per-video pipeline: YOLOv12+ByteTrack -> best crop per track ->
(optional, off by default) merge tracks that are the same person by
appearance (services/track_dedup.py, OSNet re-ID) -> one Qwen2.5VL attribute
check per person (category, dress, bags, face cover) -> saved results.

Runs in a background thread kicked off right after upload (see
routers/videos.py); the video's status field is what the frontend polls to
know when to show the green "processed" tick.
"""
from __future__ import annotations

import logging

import cv2

from app.config import settings
from app.models import PersonResult
from app.services import track_dedup, vlm_client
from app.services.detector import inference_lock, track_persons
from app.services.track_dedup import TrackSamples
from app.store import video_store

logger = logging.getLogger("pipeline")


def _pad_and_clip_bbox(bbox, frame_shape) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = bbox
    h, w = frame_shape[:2]
    box_w, box_h = x2 - x1, y2 - y1
    pad_x, pad_y = box_w * settings.CROP_PADDING_RATIO, box_h * settings.CROP_PADDING_RATIO
    x1 = max(0, int(x1 - pad_x))
    y1 = max(0, int(y1 - pad_y))
    x2 = min(w, int(x2 + pad_x))
    y2 = min(h, int(y2 + pad_y))
    return x1, y1, x2, y2


def _collect_track_samples(video_path: str) -> dict[int, TrackSamples]:
    """Track everyone through the whole video. For each track keep the frames
    it appeared in (needed to tell that two tracks were on screen together,
    hence different people) and its few best-quality crops. Only the padded
    crops are kept in memory, not whole frames."""
    keep = max(1, settings.REID_CROPS_PER_TRACK) if settings.REID_ENABLED else 1
    tracks: dict[int, TrackSamples] = {}
    # Held for the whole tracking pass, not just one call -- see
    # detector.inference_lock()'s docstring for why.
    with inference_lock():
        for frame_index, result in enumerate(track_persons(video_path)):
            boxes = result.boxes
            if boxes is None or boxes.id is None:
                continue
            frame = result.orig_img
            ids = boxes.id.int().tolist()
            confs = boxes.conf.tolist()
            xyxy = boxes.xyxy.tolist()
            for track_id, conf, box in zip(ids, confs, xyxy):
                track = tracks.setdefault(track_id, TrackSamples(track_id))
                track.frames.add(frame_index)  # counts even if the box is too small to crop
                x1, y1, x2, y2 = box
                area = max(0.0, x2 - x1) * max(0.0, y2 - y1)
                if area < settings.MIN_CROP_AREA_PX:
                    continue
                track.consider(frame, frame_index, box, _pad_and_clip_bbox(box, frame.shape), conf, keep)
    return tracks


def _video_timing(video_path: str) -> tuple[float, float | None]:
    """(fps, duration in seconds) of the video; fps 0 if it can't be read.
    The tracker yields every frame, so frame_index / fps is the crop's time."""
    capture = cv2.VideoCapture(video_path)
    try:
        fps = capture.get(cv2.CAP_PROP_FPS) or 0.0
        frames = capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0.0
    finally:
        capture.release()
    return fps, (frames / fps if fps and frames > 0 else None)


def _playback_window(timestamp: float | None, duration: float | None) -> tuple[float | None, float | None]:
    """The stretch of video to play for a crop taken at `timestamp`:
    +/- PLAYBACK_WINDOW_SEC, clamped to the video."""
    if timestamp is None:
        return None, None
    start = max(0.0, timestamp - settings.PLAYBACK_WINDOW_SEC)
    end = timestamp + settings.PLAYBACK_WINDOW_SEC
    if duration is not None:
        end = min(end, duration)
    return round(start, 2), round(end, 2)


def _process_persons(video_id: str, video_path: str, categories: list[str]) -> None:
    """Person tracking, merging of tracks that are the same person, then one
    VLM attribute check per person, saving each as it's found. A real failure
    here (not a single person's VLM call -- that's caught below) propagates to
    the caller, which marks the whole video "error"."""
    tracks = _collect_track_samples(video_path)
    # ByteTrack can give one real person several track ids (they leave view,
    # come back); this merges those by appearance so each person is checked
    # once. Falls back to one crop per track if re-ID is off/unavailable.
    people = track_dedup.select_people(tracks)
    if not people:
        return

    fps, duration = _video_timing(video_path)

    crop_dir = settings.crops_path / video_id
    crop_dir.mkdir(parents=True, exist_ok=True)

    for label_index, selected in enumerate(people, start=1):
        crop = selected.crop
        if crop.size == 0:
            continue

        crop_filename = f"track_{selected.track_id}.jpg"
        cv2.imwrite(str(crop_dir / crop_filename), crop)

        try:
            attrs = vlm_client.analyse_person(crop, categories)
        except Exception as error:
            logger.exception("VLM check failed for track %s in video %s", selected.track_id, video_id)
            attrs = {"summary": f"Person analysis failed: {error}"}

        timestamp = selected.frame_index / fps if fps else None
        start, end = _playback_window(timestamp, duration)

        person = PersonResult(
            timestamp_sec=timestamp,
            timeline_start_sec=start,
            timeline_end_sec=end,
            track_id=selected.track_id,
            track_ids=selected.track_ids,
            label=f"ID{label_index}",
            crop_url=f"/media/crops/{video_id}/{crop_filename}",
            **attrs,
        )
        video_store.add_person(video_id, person)


def process_video(video_id: str, video_path: str, categories: list[str] | None = None) -> None:
    """Tracks people through the video and runs the VLM attribute check on each,
    updating the stored record as it goes. A real failure (tracker crash, not a
    single person's VLM call) marks the whole video "error"."""
    video_store.set_status(video_id, "processing")
    try:
        _process_persons(video_id, video_path, categories or [])
    except Exception as error:  # noqa: BLE001
        logger.exception("Person processing failed for video %s", video_id)
        video_store.set_status(video_id, "error", error=str(error))
        return
    video_store.set_status(video_id, "done")
