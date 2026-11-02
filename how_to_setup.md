# How to Set Up

Step-by-step installation of the Apartment CCTV Analysis app on a Windows PC.
For what the app does and how it works, see [README.md](README.md).

The app has three parts that must all be running:

| Part | What it is | Port |
|---|---|---|
| Ollama | serves the Qwen2.5-VL model that describes each person | 11434 |
| Backend | FastAPI app (person detection, tracking, re-ID, storage, chat) | 8010 |
| Frontend | React app you open in the browser | 5174 |

## 1. Prerequisites

Install these first.

| Tool | Version used | Check with |
|---|---|---|
| Python | 3.13 | `python --version` |
| Node.js + npm | 22.x / 10.x | `node --version` |
| Git | any | `git --version` (only needed for step 4) |
| [Ollama](https://ollama.com/download) | recent | `ollama --version` |
| Gemini API key | | free key at https://aistudio.google.com/apikey (only needed for the chat box) |

About 10 GB of free disk space is needed (Qwen model about 6 GB, Python packages
about 2 GB).

If the old helmet detection project is still running, stop it: it uses the same
ports (8010 and 5174).

## 2. Get the VLM (Ollama)

Make sure Ollama is running (it starts with Windows; otherwise run `ollama serve`),
then download the model once:

```powershell
ollama pull qwen2.5vl
ollama list          # should show qwen2.5vl:latest
```

The model runs on your GPU through Ollama. The rest of the app (YOLO person
detection and re-ID) runs on the CPU by default in this setup, which leaves the
GPU memory to Qwen.

## 3. Backend: virtual environment and packages

Open PowerShell in the project folder:

```powershell
cd backend
python -m venv venv
venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

If PowerShell blocks the activate script, run
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once and try again.

`requirements.txt` pulls in `ultralytics`, which installs PyTorch. On Windows
that is the **CPU** build, which is what this setup uses. (For a GPU build, install
the CUDA PyTorch from https://pytorch.org *before* the line above, and make sure
the GPU has room for Qwen as well.)

## 4. Backend: person re-identification (torchreid)

Re-ID merges the several track IDs one person gets when they leave and re-enter
the camera view, so each person appears once. It is on by default
(`REID_ENABLED=true`).

**Do not run `pip install torchreid`.** That is a different package on PyPI and
does not have the API this project uses. Install the original from GitHub. With the
venv still active, in the `backend` folder:

```powershell
# 1. libraries torchreid imports
pip install scipy gdown h5py imageio tensorboard

# 2. get the source and copy its pure-Python package into the venv
git clone --depth 1 https://github.com/KaiyangZhou/deep-person-reid.git
Copy-Item -Recurse deep-person-reid\torchreid venv\Lib\site-packages\torchreid

# 3. clean up the clone (no longer needed)
Remove-Item -Recurse -Force deep-person-reid
```

(`git clone` may print a Windows checkout warning about a few unrelated files; the
`torchreid` folder is complete.) Check it imports:

```powershell
python -c "from torchreid.utils import FeatureExtractor; print('torchreid ok')"
```

A "Cython evaluation ... is unavailable" warning is harmless.

### Re-ID weights

Re-ID needs a checkpoint trained on a person re-ID dataset. The project ships it at
`backend/models/osnet_x1_0_msmt17.pth` (OSNet x1.0 trained on MSMT17), and `.env`
points to it. If the file is missing, download the `osnet_x1_0` MSMT17 checkpoint
from the torchreid model zoo
(https://github.com/KaiyangZhou/deep-person-reid/blob/master/docs/MODEL_ZOO.md)
and save it under that name in `backend/models/`.

### Skipping re-ID

If you do not want it, set `REID_ENABLED=false` in `backend/.env`. The app still
works, but one person who leaves and returns will be described several times.

## 5. Backend: configuration

Create your settings file from the template:

```powershell
Copy-Item .env.example .env
```

Open `backend/.env` and set at least:

```ini
GEMINI_API_KEY=your-key-here
```

Leave it empty to run without chat; everything else still works. **Never commit or
share `.env`.** The other settings can stay as they are:

| Variable | Default | Meaning |
|---|---|---|
| `OLLAMA_URL` / `OLLAMA_MODEL` | `http://127.0.0.1:11434` / `qwen2.5vl:latest` | where Ollama is and which model to use |
| `YOLO_DEVICE` | `auto` | `auto` picks the GPU if the installed PyTorch can see one, otherwise CPU |
| `CROP_PADDING_RATIO` | `0.15` | extra margin around each person in the crop sent to Qwen, so bags stay visible |
| `PLAYBACK_WINDOW_SEC` | `3.0` | seconds before and after a person's moment that play when a timeline is clicked |
| `REID_ENABLED` | `true` | merge tracks of the same person |
| `REID_MODEL_PATH` | `models/osnet_x1_0_msmt17.pth` | re-ID weights, relative to `backend/` |
| `REID_DEVICE` | `cpu` | where the re-ID model runs |
| `REID_MERGE_THRESHOLD` | `0.72` | how similar two tracks must look to be merged (lower merges more; about 0.55 is aggressive) |
| `GEMINI_MODEL` | see `.env.example` | any Gemini model your key can use; whatever is in `.env` wins |
| `STORAGE_DIR` | `./storage` | where videos, crops and result JSON are saved |

Restart the backend after editing `.env`.

## 6. Run the backend

With the venv active, in the `backend` folder:

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload
```

On startup it loads YOLO and the re-ID model and asks Ollama to load Qwen, which can
take a minute the first time. The log should include lines like:

```
Loading YOLO weights=yolo12n.pt device=cpu
Successfully loaded pretrained weights from ...osnet_x1_0_msmt17.pth
qwen2.5vl:latest is warm.
```

Check it is up: http://localhost:8010/api/health should return `{"status":"ok"}`.
Interactive API docs are at http://localhost:8010/docs.

## 7. Frontend

In a second terminal:

```powershell
cd frontend
npm install
npm run dev
```

Open **http://localhost:5174/persondetection**.

`frontend/.env` holds `BACKEND_URL` (default `http://localhost:8010`) and
`FRONTEND_DEV_PORT` (default `5174`). Restart `npm run dev` after changing it.

## 8. Try it

1. In the left panel, optionally type **additional categories** (comma-separated,
   for example `holding an umbrella, wearing glasses`). Leave it empty for the
   default check.
2. Drop a video onto the upload box (`.mp4 .mov .avi .mkv .webm`).
3. The video appears in the centre, and persons appear in the right panel one by
   one as Qwen finishes each. A green tick means all are done.
4. Ask the chat something such as "who is wearing a black tshirt?". Each person in
   the answer is a clickable chip (for example `▶ ID3 · 0:07`) that plays that
   moment in the video.

Results are saved as `backend/storage/results/{video_id}.json`, with person crops
in `backend/storage/crops/{video_id}/` and the videos in `backend/storage/videos/`.
This folder is ignored by git because it can contain footage of people.

## 9. Everyday start-up

Each time, start these three (the first usually already runs):

```powershell
# Ollama: running in the background already, check with: ollama ps

# Terminal 1
cd backend
venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload

# Terminal 2
cd frontend
npm run dev
```

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `Could not connect to Ollama` | Ollama is not running. Start it, check `ollama list`, then restart the backend. |
| Persons show `Person analysis failed: ... exceeds the available context size` | The crop was too large for Qwen's context window. The client already shrinks it once and retries; if it still fails, that person is saved with the error. |
| Log says `torchreid is not installed` or `Could not load osnet_x1_0` | Re-ID is off and each track is described separately. Redo step 4, and check `REID_MODEL_PATH` points to an existing file. |
| Same person appears more than once | Lower `REID_MERGE_THRESHOLD` (for example to `0.60`), restart, and re-upload. Too low can merge different people in similar clothes. |
| Different people merged into one | Raise `REID_MERGE_THRESHOLD`. |
| Chat shows an error (502) | `GEMINI_API_KEY` is empty or invalid, `GEMINI_MODEL` is wrong, or there is no internet. |
| Clicking a chip does nothing | That video was uploaded before timelines existed (no stored time), or the chip's video is not in the list. Re-upload the video. |
| Additional categories are missing | They only apply to videos uploaded after you typed them. Re-upload. |
| A video stays on "Processing..." after a restart | Processing runs in a background thread and is lost on restart. Re-upload it. |
| Videos are slow | Each person is one Qwen call (roughly 5 to 10 s). Check `ollama ps`: if it shows mostly `CPU`, the GPU does not have enough free memory for the model. |
| Frontend loads but nothing works | Backend is not running or `BACKEND_URL` is wrong. |
| `ModuleNotFoundError` when starting the backend | The venv is not active, or step 3 or 4 was skipped. |
| Port 8010 or 5174 already in use | Stop the old helmet project, or change the port in the `uvicorn` command and `frontend/.env` (and `CORS_ORIGINS` in `backend/.env`). |
