"""YOLOv12 person detector + Ultralytics' built-in ByteTrack tracker.

Loaded once as a module-level singleton (get_model()) so the weights are
read from disk / GPU-resident only once for the lifetime of the backend
process, the same way vlm_client keeps the VLM warm.
"""
from __future__ import annotations

import logging
import threading

from app.config import settings

logger = logging.getLogger("detector")

_model = None
_device = None

# Serializes every call into this module's one YOLO model instance --
# concurrent calls with differently-shaped inputs can corrupt Ultralytics'
# internal anchor-grid cache (the same class of bug app/services/fire_detector.py's
# own lock guards against; see its comment). Person detection now has two
# callers that can run at once -- a video's tracking pass and an image's
# single-frame pass (see services/pipeline.py) -- so this makes them mutually
# exclusive rather than letting them race on the shared model.
_inference_lock = threading.Lock()


def inference_lock() -> threading.Lock:
    """The lock above. track_persons() returns a lazy generator -- actual
    inference happens as the caller iterates it, not at this call -- so
    pipeline.py holds this lock for the whole iteration rather than detector.py
    holding it internally (contrast with detect_persons() below, a single
    call that can lock itself)."""
    return _inference_lock


def _resolve_device() -> str:
    if settings.YOLO_DEVICE != "auto":
        return settings.YOLO_DEVICE
    try:
        import torch

        return "cuda" if torch.cuda.is_available() else "cpu"
    except ImportError:
        return "cpu"


def get_model():
    global _model, _device
    if _model is None:
        from ultralytics import YOLO

        _device = _resolve_device()
        logger.info("Loading YOLO weights=%s device=%s", settings.YOLO_WEIGHTS, _device)
        _model = YOLO(settings.YOLO_WEIGHTS)
    return _model


def get_device() -> str:
    if _device is None:
        get_model()
    return _device


def detect_persons(image_path: str):
    """Runs person detection (no tracking) on a single image and returns its
    ultralytics Results object. Used for image uploads, which are one frame
    with no video to track a person across -- see track_persons() below for
    the video case."""
    model = get_model()
    with _inference_lock:
        results = model.predict(
            source=image_path,
            classes=[0],  # COCO class 0 = person
            imgsz=settings.YOLO_IMGSZ,
            conf=settings.YOLO_CONF,
            iou=settings.YOLO_IOU,
            device=get_device(),
            verbose=False,
        )
    return results[0]


def track_persons(video_path: str):
    """Runs person detection + ByteTrack tracking over the whole video.

    Yields ultralytics Results objects, one per frame, each carrying
    .boxes.id (track ids) for every detected person box -- persist=True
    keeps track identities stable across the call.
    """
    model = get_model()
    return model.track(
        source=video_path,
        classes=[0],  # COCO class 0 = person
        imgsz=settings.YOLO_IMGSZ,
        conf=settings.YOLO_CONF,
        iou=settings.YOLO_IOU,
        device=get_device(),
        tracker="bytetrack.yaml",  # ultralytics built-in tracker config
        persist=True,
        stream=True,
        verbose=False,
    )
