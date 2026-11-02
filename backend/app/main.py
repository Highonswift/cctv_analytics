from __future__ import annotations

import logging
import threading

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import chat, videos
from app.services import reid, vlm_client
from app.services.detector import get_model

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("main")

app = FastAPI(title="Apartment CCTV Analysis API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(videos.router)
app.include_router(chat.router)

app.mount("/media/videos", StaticFiles(directory=str(settings.videos_path)), name="videos")
app.mount("/media/crops", StaticFiles(directory=str(settings.crops_path)), name="crops")


@app.get("/api/health")
def health() -> dict:
    return {"status": "ok"}


@app.on_event("startup")
def on_startup() -> None:
    # Both the VLM (Ollama) and YOLO weights load in background threads so
    # they stay warm/resident for the life of this process without blocking
    # server startup on a slow first model load / download.
    threading.Thread(target=vlm_client.warm_up, daemon=True).start()
    threading.Thread(target=get_model, daemon=True).start()
    # Person re-ID model (OSNet). Returns None if re-ID is disabled (the default
    # here) or torchreid isn't installed -- the pipeline then uses one crop per track.
    threading.Thread(target=reid.get_embedder, daemon=True).start()
