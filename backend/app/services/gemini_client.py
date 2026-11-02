"""Thin client for the Gemini API, used by the chat assistant to answer
questions over every saved video result (per-person attributes).
Talks to the REST endpoint directly via urllib, same
request-building pattern as vlm_client.py's Ollama client, so no extra
package (e.g. google-genai) needs to be installed.

Stateless by design: every call re-sends the full current JSON snapshot of
stored results plus that one question, no conversation history is kept
server-side. Simple, and avoids the prompt growing across a session as more
videos/images pile up (each question already re-sends every stored result).
"""
from __future__ import annotations

import json
import logging
import urllib.error
import urllib.request

from app.config import settings
from app.store import video_store

logger = logging.getLogger("gemini_client")

SYSTEM_PREAMBLE = (
    "You are an assistant for an apartment CCTV analysis system. You are given "
    "JSON describing every video processed so far and, for each, the people "
    "detected in it. Each person has: `category` (male, female, child, or "
    "unknown), `dress_color` (colour of the top), `dress_type`, `holding_bag` "
    "with `bags` (a list of the bags or carried items), `face_covered` with "
    "`face_cover_type` (balaclava, helmet, mask, kerchief, ...), and a short "
    "`summary`, `additional_categories`, plus `label` (e.g. ID3) and `timestamp_sec` (the moment in the video "
    "the person was captured, in seconds). Whenever your answer names a person, "
    "cite them with exactly this marker: [[VIDEO_ID|LABEL]] using the video's "
    "`video_id` and the person's `label`, e.g. [[3f9c...|ID3]]. The app turns the "
    "marker into a clickable timeline that plays the video at that moment, so do "
    "not write the time yourself and do not alter the marker; mention the video's "
    "filename in plain text as well. List each matching person with its own "
    "marker. A video's `requested_categories` are extra things the user asked to "
    "look for when uploading it; each person's `additional_categories` holds, per "
    "requested category, `present` (true/false/null) and a short `detail`. For "
    "questions about those categories, answer from them (e.g. people whose "
    "\"holding an umbrella\" is present) and say so if a video was not processed "
    "with that category. `null` or `unknown` means it could not be determined, not that "
    "the attribute is absent. The same real person may appear more than once in "
    "a video, because the tracker can give a person a new ID when they leave and "
    "re-enter view. Answer the question using ONLY this data -- if it isn't "
    "enough to answer, say so plainly instead of guessing. Be concise, and refer "
    "to videos by their filename."
)


def build_context() -> dict:
    """Every stored video result, trimmed to what a text answer needs (crop
    URLs and track ids are dropped)."""
    videos = [
        {
            "video_id": v.id,
            "filename": v.filename,
            "status": v.status,
            "created_at": v.created_at,
            "error": v.error,
            "requested_categories": v.requested_categories,
            "persons": [
                p.model_dump(exclude={"crop_url", "track_ids", "timeline_start_sec", "timeline_end_sec"})
                for p in v.persons
            ],
        }
        for v in video_store.list_all()
    ]
    return {"videos": videos}


def ask(question: str) -> str:
    """Sends one question, with the current results snapshot as context, to
    Gemini and returns its answer text."""
    if not settings.GEMINI_API_KEY:
        raise RuntimeError(
            "GEMINI_API_KEY is not set. Add your Gemini API key to backend/.env "
            "(get one at https://aistudio.google.com/apikey) and restart the backend."
        )

    context = build_context()
    prompt = f"{SYSTEM_PREAMBLE}\n\nJSON data:\n{json.dumps(context, indent=2)}\n\nQuestion: {question}"

    body = json.dumps({"contents": [{"parts": [{"text": prompt}]}]}).encode("utf-8")
    url = f"{settings.GEMINI_URL}/v1beta/models/{settings.GEMINI_MODEL}:generateContent?key={settings.GEMINI_API_KEY}"
    request = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        try:
            detail = json.loads(detail).get("error", {}).get("message", detail)
        except json.JSONDecodeError:
            pass
        raise RuntimeError(f"Gemini returned {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"Could not reach Gemini API ({settings.GEMINI_URL}): {error}") from error

    try:
        parts = payload["candidates"][0]["content"]["parts"]
        text = "".join(part.get("text", "") for part in parts).strip()
    except (KeyError, IndexError, TypeError):
        text = ""

    if not text:
        finish_reason = None
        if payload.get("candidates"):
            finish_reason = payload["candidates"][0].get("finishReason")
        raise RuntimeError(f"Gemini returned no answer text (finishReason={finish_reason}).")

    return text
