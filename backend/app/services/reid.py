"""Whole-body person re-identification embeddings (OSNet via torchreid).

Turns a full-body person crop into an appearance vector; two crops of the
same person land close together (high cosine similarity), crops of different
people further apart. Used by track_dedup.py to recognise that a person who
left view and came back under a new ByteTrack id is the same person.

Adapted from persontraking_project/ai/reid/osnet_reid.py (same torchreid
FeatureExtractor usage). This is a body-appearance space -- never compare
these vectors with the ArcFace *face* embeddings of the face_search /
face_registering projects, they are unrelated vector spaces.

torchreid is an optional dependency. If it is missing, disabled, or the
weights can't be loaded, get_embedder() returns None (and logs why once) and
the pipeline falls back to one crop per track instead of failing.
"""
from __future__ import annotations

import logging
import threading

import cv2
import numpy as np

from app.config import settings

logger = logging.getLogger("reid")


class ReIDUnavailable(RuntimeError):
    """torchreid missing, or the configured weights can't be loaded."""


def _resolve_device() -> str:
    if settings.REID_DEVICE != "auto":
        return settings.REID_DEVICE
    try:
        import torch

        return "cuda" if torch.cuda.is_available() else "cpu"
    except ImportError:
        return "cpu"


class OSNetEmbedder:
    def __init__(self) -> None:
        try:
            from torchreid.utils import FeatureExtractor
        except ImportError as error:
            raise ReIDUnavailable(
                "torchreid is not installed, so person re-ID is off (one VLM call per "
                "track, as before). Install it from the deep-person-reid GitHub repo -- NOT `pip install "
                "torchreid`, which is a different package (see howtosetup.md A3.3) -- or set REID_ENABLED=false."
            ) from error

        model_path = ""
        if settings.REID_MODEL_PATH:
            path = settings.resolve_backend_path(settings.REID_MODEL_PATH)
            if not path.is_file():
                raise ReIDUnavailable(f"REID_MODEL_PATH does not exist: {path}")
            model_path = str(path)
        else:
            logger.warning(
                "REID_MODEL_PATH is empty: %s will use ImageNet weights, which are not trained "
                "for re-identification -- set REID_MODEL_PATH to a Market1501/MSMT17 checkpoint "
                "for reliable matching.",
                settings.REID_MODEL_NAME,
            )

        device = _resolve_device()
        logger.info("Loading %s weights=%s device=%s", settings.REID_MODEL_NAME, model_path or "<imagenet>", device)
        try:
            # model_path "" makes torchreid download/use its pretrained weights;
            # a real path loads that checkpoint. Resizing to 256x128 and
            # normalisation happen inside the extractor.
            self._extractor = FeatureExtractor(
                model_name=settings.REID_MODEL_NAME, model_path=model_path, device=device
            )
        except Exception as error:  # noqa: BLE001 -- surface as "unavailable", never crash the pipeline
            raise ReIDUnavailable(f"Could not load {settings.REID_MODEL_NAME}: {error}") from error
        self._lock = threading.Lock()

    def embed(self, crops_bgr: list[np.ndarray]) -> np.ndarray:
        """One row per crop, shape (N, D), RAW (not L2-normalised) features.

        The magnitude is kept on purpose -- it feeds the embedding-quality part
        of the crop score (see person_quality.criteria2). Callers L2-normalise
        the rows themselves before cosine comparison.
        """
        rgb = [cv2.cvtColor(np.ascontiguousarray(crop), cv2.COLOR_BGR2RGB) for crop in crops_bgr]
        with self._lock:  # one extractor shared by every video's processing thread
            features = self._extractor(rgb)
        return features.detach().cpu().numpy().astype(np.float32)


_embedder: OSNetEmbedder | None = None
_load_attempted = False
_load_lock = threading.Lock()


def get_embedder() -> OSNetEmbedder | None:
    """The shared embedder, loaded on first use, or None when re-ID is turned
    off / unavailable (the reason is logged once)."""
    global _embedder, _load_attempted
    if not settings.REID_ENABLED:
        return None
    if _load_attempted:
        return _embedder
    with _load_lock:
        if not _load_attempted:
            try:
                _embedder = OSNetEmbedder()
            except ReIDUnavailable as error:
                logger.warning("%s", error)
            _load_attempted = True
    return _embedder
