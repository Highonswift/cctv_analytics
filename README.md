# Apartment CCTV Analysis

Upload a CCTV video; every person in it is detected, tracked, cropped and
described by a vision-language model. Results are saved as JSON and can be
queried in plain English through a chat box.

This project is a reuse of the safety-helmet detection project with the fire/smoke
detection and image upload removed, and the VLM prompt changed.

| | |
|---|---|
| Person detection + tracking | YOLO12n + ByteTrack (Ultralytics) |
| Person description | Qwen2.5-VL, run locally through Ollama |
| Chat over the results | Google Gemini API |
| Backend | Python 3.13, FastAPI (port 8010) |
| Frontend | React 18 + Vite (port 5174) |
| Storage | JSON + media files on disk (`backend/storage/`) |

## What is detected per person

The VLM gets one crop per person and returns one JSON object:

```json
{
  "category": "male | female | child | unknown",
  "dress_color": "colour of the top",
  "dress_type": "free text: shirt, tshirt, saree, nighty, ...",
  "holding_bag": true,
  "bags": ["free text, one per bag: suitcase, jute bag, carry bag, backpack, ..."],
  "face_covered": true,
  "face_cover_type": "free text: balaclava, helmet, mask, kerchief, ... (null if not covered)",
  "summary": "one short description"
}
```

Anything the model omits or gets wrong-shaped becomes `null` / `unknown` rather
than failing the person (`_normalise` in `backend/app/services/vlm_client.py`).
Each video is saved as `backend/storage/results/{video_id}.json`; the person
crops are in `backend/storage/crops/{video_id}/`.

## Pipeline

```
upload -> YOLO12n + ByteTrack over every frame -> best crop per track
       -> Qwen2.5-VL (one call per person) -> PersonResult saved to JSON
```

- The crop is the person box plus `CROP_PADDING_RATIO` on every side (default
  0.15, up from 0.08 in the helmet project) so bags and carried items stay in view.
- Person re-ID merging (OSNet, `REID_ENABLED=true`) combines tracks that look like the same person and never appear in the same frame, so each person is described once. Merge strictness is `REID_MERGE_THRESHOLD` (0.72 conservative; 0.55 aggressive).
- Chat (`POST /api/chat`) sends all saved JSON plus your question to Gemini;
  it is stateless.

## Setup

Full step-by-step instructions (including re-ID and troubleshooting): [how_to_setup.md](how_to_setup.md). Short version:

```powershell
# 1. Ollama running, then once:
ollama pull qwen2.5vl

# 2. Backend
cd backend
python -m venv venv
venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env      # set GEMINI_API_KEY for chat
uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload

# 3. Frontend (second terminal)
cd frontend
npm install
npm run dev
```

Open http://localhost:5174/persondetection. Health check:
http://localhost:8010/api/health.

## Configuration (`backend/.env`)

Same as the helmet project, minus all `FIRE_*` settings, plus:

| Variable | Default | Meaning |
|---|---|---|
| `CROP_PADDING_RATIO` | `0.15` | fraction of the person box added on every side of the crop |
| `MIN_CROP_AREA_PX` | `3000` | person boxes smaller than this (px²) are skipped |
| `REID_ENABLED` | `true` | merge tracks of the same person by appearance (needs `torchreid`; falls back to one crop per track if missing) |

See `backend/.env.example` for the rest (Ollama, YOLO, Gemini, re-ID).

## API

| Method & path | Purpose |
|---|---|
| `GET /api/health` | liveness |
| `POST /api/videos` | multipart upload (`file`); returns a `pending` record, processing continues in the background |
| `GET /api/videos`, `GET /api/videos/{id}` | records with status and persons |
| `POST /api/chat` | `{"question": "..."}` -> `{"answer": "..."}` |
| `GET /media/videos/{file}`, `GET /media/crops/{id}/{file}` | media |

## Limitations (inherited)

No authentication, no job queue (a restart mid-processing leaves a video at
"processing"), one VLM call per person is the main cost, and very large crops
can exceed Qwen's 4096-token context (the client shrinks and retries once).
