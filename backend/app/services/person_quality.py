"""Whole-person crop quality scoring.

Adapted from face_registering/src/quality.py, which ranks *face* crops. The
structure is kept -- two criteria combined into one final score used to pick
the best crop of a person -- with the face-only pieces swapped for
whole-body equivalents:

Criteria 1 -- image & detection quality (cheap, from the pixels and the box;
computed for every candidate crop while tracking):
    - detection confidence   (YOLO person score)
    - sharpness / blur       (variance of the Laplacian)
    - contrast               (std. dev. of grayscale intensity)
    - brightness             (how far the mean intensity is from too dark / too bright)
    - size                   (person box height in pixels; replaces "face size")
    - pose / completeness    (replaces the landmark-based yaw+roll "angle", which
                              doesn't exist for a body): box aspect ratio, and
                              whether the body is cut off by the frame edge

Criteria 2 -- embedding quality (needs the OSNet embedding, so it is only
computed for the few crops that survive criteria 1):
    - embedding magnitude before L2-normalisation, relative to the largest in
      the same group (the reference used fixed ArcFace-specific bounds, which
      don't transfer to OSNet)
    - cosine similarity of this crop's embedding to the average embedding of
      the whole person ("how typical is this crop of them")

final_score = CRITERIA1_WEIGHT * criteria1 + CRITERIA2_WEIGHT * criteria2

All scores are in [0, 1]. The constants below are starting points, not
calibrated on this project's footage; scores are only used to *rank* crops of
the same person against each other, so exact values matter less than order.
"""
from __future__ import annotations

import cv2
import numpy as np

# --- final combination (same 80/20 split as the reference) -------------------
CRITERIA2_WEIGHT = 0.2
CRITERIA1_WEIGHT = 1.0 - CRITERIA2_WEIGHT

# --- criteria 1 weights (sum to 1.0) ----------------------------------------
DET_SCORE_WEIGHT = 0.25
SHARPNESS_WEIGHT = 0.20
CONTRAST_WEIGHT = 0.10
BRIGHTNESS_WEIGHT = 0.10
SIZE_WEIGHT = 0.20
POSE_WEIGHT = 0.15

# Sharpness/contrast/brightness are measured on the person crop downscaled to
# this fixed size (h, w), so crops of the same person at different distances
# are comparable and the Laplacian stays cheap.
_MEASURE_SIZE = (128, 64)

SHARPNESS_REFERENCE = 500.0  # Laplacian variance (at _MEASURE_SIZE) that counts as fully sharp
CONTRAST_REFERENCE = 60.0    # grayscale std. dev. that counts as full contrast (0..255 scale)

# Brightness: mean grayscale intensity. Full score inside the ideal band,
# falling linearly to 0 at the dark / bright extremes.
BRIGHTNESS_DARK_ZERO = 20.0
BRIGHTNESS_IDEAL_LOW = 90.0
BRIGHTNESS_IDEAL_HIGH = 170.0
BRIGHTNESS_BRIGHT_ZERO = 235.0

# Size: person box height in pixels, scaled 0 at MIN to 1 at MAX.
PERSON_HEIGHT_MIN = 80.0
PERSON_HEIGHT_MAX = 320.0

# Pose: box height / width. A standing person seen from front or back is
# ~2-3; a much wider box means crouching, bending, or merged people.
ASPECT_ZERO = 0.8
ASPECT_FULL = 1.8

# Completeness: penalty for each box side touching the frame edge (body cut
# off there). Cut-off head/feet hurt more than cut-off sides. Sums to 1.0.
EDGE_MARGIN_PX = 2
EDGE_PENALTY_TOP_BOTTOM = 0.35
EDGE_PENALTY_LEFT_RIGHT = 0.15

# --- criteria 2 sub-weights (sum to 1.0) ------------------------------------
EMBED_MAGNITUDE_WEIGHT = 0.5
EMBED_AVG_SIMILARITY_WEIGHT = 0.5


def _clip01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


def _linear_scale(x: float, lo: float, hi: float) -> float:
    """Map x in [lo, hi] linearly to [0, 1], clipped outside that range."""
    if hi <= lo:
        return 1.0 if x >= hi else 0.0
    return _clip01((x - lo) / (hi - lo))


def _brightness_score(mean_intensity: float) -> float:
    if mean_intensity < BRIGHTNESS_IDEAL_LOW:
        return _linear_scale(mean_intensity, BRIGHTNESS_DARK_ZERO, BRIGHTNESS_IDEAL_LOW)
    if mean_intensity > BRIGHTNESS_IDEAL_HIGH:
        return 1.0 - _linear_scale(mean_intensity, BRIGHTNESS_IDEAL_HIGH, BRIGHTNESS_BRIGHT_ZERO)
    return 1.0


def _pose_score(box: tuple[float, float, float, float], frame_shape) -> float:
    x1, y1, x2, y2 = box
    width, height = max(x2 - x1, 1.0), max(y2 - y1, 1.0)
    aspect_score = _linear_scale(height / width, ASPECT_ZERO, ASPECT_FULL)

    frame_h, frame_w = frame_shape[:2]
    penalty = 0.0
    if y1 <= EDGE_MARGIN_PX:
        penalty += EDGE_PENALTY_TOP_BOTTOM
    if y2 >= frame_h - EDGE_MARGIN_PX:
        penalty += EDGE_PENALTY_TOP_BOTTOM
    if x1 <= EDGE_MARGIN_PX:
        penalty += EDGE_PENALTY_LEFT_RIGHT
    if x2 >= frame_w - EDGE_MARGIN_PX:
        penalty += EDGE_PENALTY_LEFT_RIGHT
    completeness_score = _clip01(1.0 - penalty)

    return (aspect_score + completeness_score) / 2.0


def criteria1(person_bgr: np.ndarray, det_conf: float, box: tuple[float, float, float, float], frame_shape) -> float:
    """Image/detection quality of one person crop.

    `person_bgr` is the tight person box cut out of the frame, `box` its
    (x1, y1, x2, y2) in frame pixels, `frame_shape` the frame's shape.
    """
    gray = cv2.cvtColor(person_bgr, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (_MEASURE_SIZE[1], _MEASURE_SIZE[0]), interpolation=cv2.INTER_AREA)

    sharpness = _linear_scale(float(cv2.Laplacian(gray, cv2.CV_64F).var()), 0.0, SHARPNESS_REFERENCE)
    contrast = _linear_scale(float(gray.std()), 0.0, CONTRAST_REFERENCE)
    brightness = _brightness_score(float(gray.mean()))
    size = _linear_scale(box[3] - box[1], PERSON_HEIGHT_MIN, PERSON_HEIGHT_MAX)
    pose = _pose_score(box, frame_shape)

    return _clip01(
        DET_SCORE_WEIGHT * _clip01(det_conf)
        + SHARPNESS_WEIGHT * sharpness
        + CONTRAST_WEIGHT * contrast
        + BRIGHTNESS_WEIGHT * brightness
        + SIZE_WEIGHT * size
        + POSE_WEIGHT * pose
    )


def criteria2(raw_norm: float, max_norm_in_group: float, similarity_to_avg: float) -> float:
    """Embedding quality of one crop: its raw embedding magnitude relative to
    the largest in its group (low magnitude tends to go with blur/occlusion),
    and how close it is to the person's average embedding."""
    magnitude_score = _clip01(raw_norm / max_norm_in_group) if max_norm_in_group > 0 else 0.0
    similarity_score = _clip01(similarity_to_avg)
    return _clip01(
        EMBED_MAGNITUDE_WEIGHT * magnitude_score + EMBED_AVG_SIMILARITY_WEIGHT * similarity_score
    )


def final_score(criteria1_score: float, criteria2_score: float) -> float:
    return _clip01(CRITERIA1_WEIGHT * criteria1_score + CRITERIA2_WEIGHT * criteria2_score)
