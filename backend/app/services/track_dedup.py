"""Merge ByteTrack tracks that are really the same person, then pick ONE crop
per person for the VLM.

Why: ByteTrack has no appearance memory. When a person leaves view (camera
pans away, occlusion) and comes back, they get a brand-new track id, so one
real person becomes several tracks -- and every track costs a VLM call.

How (adapted from the face_search_v1 / face_registering projects, but on
whole-body crops instead of faces):

  1. While tracking, each track keeps its few best-quality crops
     (TrackSamples.consider; quality from person_quality.criteria1) and the
     set of frames it appeared in.
  2. After tracking, every kept crop is embedded with OSNet (reid.py); a
     track's embedding is the mean of its crops' embeddings.
  3. Tracks are merged agglomerative-style: repeatedly join the two most
     similar groups (cosine similarity, as in matcher.py) while that
     similarity >= REID_MERGE_THRESHOLD -- but NEVER join two groups that
     appeared together in the same frame. One person can't be in two places
     at once, so tracks that co-occur are different people. This rule is what
     makes conservative merging safe: a wrong merge would silently drop a real
     person from the safety check.
  4. Per merged person, all their crops are ranked by the final quality score
     (criteria 1 + criteria 2 relative to that person's average embedding,
     as in face_registering/src/quality.py) and only the best one is kept.

If re-ID is off or unavailable, or anything in steps 2-4 fails, this falls
back to one (best-quality) crop per track -- the previous behaviour.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

import numpy as np

from app.config import settings
from app.services import person_quality, reid

logger = logging.getLogger("track_dedup")

# Two crops kept for the same track must be at least this many frames apart,
# so the few kept crops show different poses instead of near-identical
# neighbouring frames.
SAMPLE_MIN_FRAME_GAP = 8

_EMBED_BATCH = 32


@dataclass
class CropSample:
    track_id: int
    frame_index: int
    crop: np.ndarray  # padded crop -- what the VLM sees (padding keeps e.g. a helmet brim in view)
    person_box: tuple[int, int, int, int]  # y1, y2, x1, x2 of the tight person box inside `crop`
    quality1: float  # person_quality.criteria1

    def person_crop(self) -> np.ndarray:
        """The tight person box (no padding) -- what the re-ID model embeds."""
        y1, y2, x1, x2 = self.person_box
        return self.crop[y1:y2, x1:x2]


@dataclass
class TrackSamples:
    track_id: int
    frames: set[int] = field(default_factory=set)  # every frame this track was detected in
    samples: list[CropSample] = field(default_factory=list)  # best quality first, at most `keep`

    def consider(self, frame: np.ndarray, frame_index: int, box, padded_box, det_conf: float, keep: int) -> None:
        """Offer this frame's detection of the track as a candidate crop.
        The (comparatively costly) crop copy is only made if it makes the cut."""
        frame_h, frame_w = frame.shape[:2]
        x1, y1 = max(0, int(round(box[0]))), max(0, int(round(box[1])))
        x2, y2 = min(frame_w, int(round(box[2]))), min(frame_h, int(round(box[3])))
        if x2 <= x1 or y2 <= y1:
            return

        quality = person_quality.criteria1(frame[y1:y2, x1:x2], det_conf, box, frame.shape)

        near = next(
            (i for i, s in enumerate(self.samples) if abs(s.frame_index - frame_index) < SAMPLE_MIN_FRAME_GAP),
            None,
        )
        if near is not None:
            if quality <= self.samples[near].quality1:
                return  # a better crop from almost the same moment is already kept
        elif len(self.samples) >= keep and quality <= self.samples[-1].quality1:
            return

        px1, py1, px2, py2 = padded_box
        crop = frame[py1:py2, px1:px2].copy()
        crop_h, crop_w = crop.shape[:2]
        person_box = (
            max(0, y1 - py1), min(crop_h, y2 - py1),
            max(0, x1 - px1), min(crop_w, x2 - px1),
        )
        sample = CropSample(self.track_id, frame_index, crop, person_box, quality)
        if near is not None:
            self.samples[near] = sample
        else:
            self.samples.append(sample)
        self.samples.sort(key=lambda s: s.quality1, reverse=True)
        del self.samples[keep:]


@dataclass
class SelectedPerson:
    crop: np.ndarray  # the single best crop of this person -> the VLM
    track_id: int  # the track that crop came from (used in the crop's file name)
    track_ids: list[int]  # every ByteTrack id merged into this person, ascending
    frame_index: int  # frame the crop was taken from (0-based, in the tracked video)


def select_people(tracks: dict[int, TrackSamples]) -> list[SelectedPerson]:
    """One SelectedPerson per real person, ordered by their earliest track id."""
    usable = {tid: t for tid, t in sorted(tracks.items()) if t.samples}
    if not usable:
        return []

    embedder = reid.get_embedder() if settings.REID_ENABLED else None
    if embedder is not None and len(usable) > 1:
        try:
            return _merge_by_appearance(usable, embedder)
        except Exception:  # noqa: BLE001 -- re-ID is an optimisation; never fail the video over it
            logger.exception("Person re-ID merging failed; falling back to one crop per track")
    return [_one_per_track(track) for track in usable.values()]


def _one_per_track(track: TrackSamples) -> SelectedPerson:
    best = track.samples[0]
    return SelectedPerson(
        crop=best.crop, track_id=track.track_id, track_ids=[track.track_id], frame_index=best.frame_index
    )


def _embed_all(embedder, samples: list[CropSample]) -> np.ndarray:
    crops = [sample.person_crop() for sample in samples]
    batches = [embedder.embed(crops[i : i + _EMBED_BATCH]) for i in range(0, len(crops), _EMBED_BATCH)]
    return np.concatenate(batches, axis=0)


def _merge_by_appearance(tracks: dict[int, TrackSamples], embedder) -> list[SelectedPerson]:
    track_ids = list(tracks)
    n = len(track_ids)

    # One row per kept crop, grouped by track.
    samples: list[CropSample] = []
    rows_of: list[list[int]] = []
    for tid in track_ids:
        rows_of.append(list(range(len(samples), len(samples) + len(tracks[tid].samples))))
        samples.extend(tracks[tid].samples)

    raw = _embed_all(embedder, samples)  # (rows, D) raw features
    norms = np.linalg.norm(raw, axis=1)
    unit = raw / np.maximum(norms, 1e-12)[:, None]  # L2-normalised, for cosine similarity

    # Frames two tracks share. Groups that share more than REID_MAX_CO_FRAMES
    # can never merge. Updated by summing on merge -- an upper bound, i.e. it
    # can only make merging *more* cautious.
    co = np.zeros((n, n), dtype=np.int64)
    for i in range(n):
        for j in range(i + 1, n):
            co[i, j] = co[j, i] = len(tracks[track_ids[i]].frames & tracks[track_ids[j]].frames)

    members: list[list[int]] = [[i] for i in range(n)]  # track indices per group
    sums = [unit[rows].sum(axis=0) for rows in rows_of]  # unnormalised centroid per group
    alive = list(range(n))
    max_co = settings.REID_MAX_CO_FRAMES
    threshold = settings.REID_MERGE_THRESHOLD

    def centroids() -> dict[int, np.ndarray]:
        out = {}
        for g in alive:
            norm = np.linalg.norm(sums[g])
            out[g] = sums[g] / norm if norm > 0 else sums[g]
        return out

    while True:
        cents = centroids()
        best: tuple[float, int, int] | None = None
        for pos, a in enumerate(alive):
            for b in alive[pos + 1 :]:
                if co[a, b] > max_co:
                    continue  # they appeared together -> different people
                similarity = float(cents[a] @ cents[b])
                if similarity >= threshold and (best is None or similarity > best[0]):
                    best = (similarity, a, b)
        if best is None:
            break

        similarity, a, b = best
        logger.info(
            "Re-ID: merging tracks %s into person with tracks %s (similarity %.2f >= %.2f)",
            sorted(track_ids[m] for m in members[b]),
            sorted(track_ids[m] for m in members[a]),
            similarity,
            threshold,
        )
        members[a].extend(members[b])
        sums[a] = sums[a] + sums[b]
        for k in alive:
            if k != a and k != b:
                co[a, k] = co[k, a] = co[a, k] + co[b, k]
        alive.remove(b)

    _log_closest_remaining(alive, centroids(), co, members, track_ids, threshold)

    # One best crop per merged person.
    cents = centroids()
    people: list[SelectedPerson] = []
    for g in alive:
        rows = [r for m in members[g] for r in rows_of[m]]
        max_norm = float(norms[rows].max())

        def score(row: int) -> float:
            criteria2 = person_quality.criteria2(float(norms[row]), max_norm, float(unit[row] @ cents[g]))
            return person_quality.final_score(samples[row].quality1, criteria2)

        best_row = max(rows, key=score)
        people.append(
            SelectedPerson(
                crop=samples[best_row].crop,
                track_id=samples[best_row].track_id,
                track_ids=sorted(track_ids[m] for m in members[g]),
                frame_index=samples[best_row].frame_index,
            )
        )

    people.sort(key=lambda p: p.track_ids[0])
    logger.info(
        "Re-ID: %d tracks -> %d people (%d duplicate tracks merged, threshold %.2f)",
        n, len(people), n - len(people), threshold,
    )
    return people


def _log_closest_remaining(alive, cents, co, members, track_ids, threshold) -> None:
    """Report the most similar pair that was NOT merged, and why -- the number
    to look at when tuning REID_MERGE_THRESHOLD."""
    closest: tuple[float, int, int] | None = None
    for pos, a in enumerate(alive):
        for b in alive[pos + 1 :]:
            similarity = float(cents[a] @ cents[b])
            if closest is None or similarity > closest[0]:
                closest = (similarity, a, b)
    if closest is None:
        return
    similarity, a, b = closest
    reason = (
        f"appeared together in {int(co[a, b])} frame(s)"
        if co[a, b] > settings.REID_MAX_CO_FRAMES
        else f"below threshold {threshold:.2f}"
    )
    logger.info(
        "Re-ID: most similar pair left unmerged: tracks %s vs %s, similarity %.2f (%s)",
        sorted(track_ids[m] for m in members[a]),
        sorted(track_ids[m] for m in members[b]),
        similarity,
        reason,
    )
