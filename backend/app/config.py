from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=str(BASE_DIR / ".env"), extra="ignore")

    HOST: str = "0.0.0.0"
    PORT: int = 8010
    CORS_ORIGINS: str = "http://localhost:5174"

    OLLAMA_URL: str = "http://127.0.0.1:11434"
    OLLAMA_MODEL: str = "qwen2.5vl:latest"
    OLLAMA_KEEP_ALIVE: str = "-1"

    YOLO_WEIGHTS: str = "yolo12n.pt"
    YOLO_DEVICE: str = "auto"
    YOLO_CONF: float = 0.35
    YOLO_IOU: float = 0.5
    YOLO_IMGSZ: int = 640

    # Fractional padding added on every side of a detected person box before
    # cropping for the VLM. Larger than the helmet project (0.08) so bags and
    # carried objects near the box edge stay visible.
    CROP_PADDING_RATIO: float = 0.15
    # Person boxes smaller than this (pixels^2) are too small to judge.
    MIN_CROP_AREA_PX: int = 3000
    # Seconds of video played before and after a person's crop moment when its
    # timeline is clicked in the UI (stored in the result JSON at processing time).
    PLAYBACK_WINDOW_SEC: float = 3.0

    # Person re-identification (services/reid.py + track_dedup.py). ByteTrack
    # gives a person a NEW track id whenever they leave view and come back, so
    # one real person can appear as several tracks -- and each track costs a
    # VLM call. After tracking, tracks are compared by whole-body appearance
    # (OSNet embeddings), tracks that look like the same person are merged, and
    # only the single best-quality crop of each merged person goes to the VLM.
    # Needs the optional `torchreid` package; without it (or with
    # REID_ENABLED=false) the pipeline silently falls back to one crop per track.
    REID_ENABLED: bool = True
    REID_MODEL_NAME: str = "osnet_x1_0"  # torchreid model name
    # Path (relative to backend/ unless absolute) to a re-ID-TRAINED checkpoint
    # for that model, e.g. an OSNet trained on Market1501/MSMT17 from the
    # torchreid model zoo. Empty -> torchreid falls back to ImageNet weights,
    # which are not trained for telling people apart (matching is much weaker).
    REID_MODEL_PATH: str = ""
    # cpu by default: OSNet is tiny, and the GPU's VRAM is better left to the
    # Qwen VLM (see the GPU notes in howtosetup.md). auto | cpu | cuda.
    REID_DEVICE: str = "cpu"
    # Cosine similarity two tracks must reach to be merged. 0.72 is
    # persontraking_project's "reid_confirm" (conservative -- some duplicates
    # may remain); 0.55 is its "reid_match" (aggressive -- more merging, more
    # risk of wrongly merging two different people).
    REID_MERGE_THRESHOLD: float = 0.72
    # Best-quality crops kept per track for comparison; their mean embedding
    # represents the track. One final crop per person still goes to the VLM.
    REID_CROPS_PER_TRACK: int = 3
    # Two tracks that appear together in more than this many frames are
    # different people (one person can't be in two places) and never merge.
    REID_MAX_CO_FRAMES: int = 0

    # Gemini chat assistant (answers questions over every saved video/image
    # result). GEMINI_API_KEY has no default -- get one from
    # https://aistudio.google.com/apikey and set it in backend/.env; the
    # /api/chat endpoint returns a clear error until it's set.
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-3.6-flash"
    GEMINI_URL: str = "https://generativelanguage.googleapis.com"

    STORAGE_DIR: str = "./storage"

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

    @property
    def storage_path(self) -> Path:
        p = (BASE_DIR / self.STORAGE_DIR).resolve() if not Path(self.STORAGE_DIR).is_absolute() else Path(self.STORAGE_DIR)
        p.mkdir(parents=True, exist_ok=True)
        return p

    @property
    def videos_path(self) -> Path:
        p = self.storage_path / "videos"
        p.mkdir(parents=True, exist_ok=True)
        return p

    @property
    def crops_path(self) -> Path:
        p = self.storage_path / "crops"
        p.mkdir(parents=True, exist_ok=True)
        return p

    @property
    def results_path(self) -> Path:
        p = self.storage_path / "results"
        p.mkdir(parents=True, exist_ok=True)
        return p

    def resolve_backend_path(self, value: str) -> Path:
        """Resolves a weights path from .env: absolute as-is, else relative to backend/."""
        p = Path(value)
        return p if p.is_absolute() else (BASE_DIR / p).resolve()


settings = Settings()
