import { useRef, useState } from "react";
import { uploadVideo } from "../api/persondetection.js";
import ChatPanel from "./ChatPanel.jsx";

export default function UploadPanel({ onUploaded, videos, onPlay }) {
  const inputRef = useRef(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState(null);
  const [categories, setCategories] = useState("");

  async function handleFiles(files) {
    if (!files || files.length === 0) return;
    setError(null);
    setUploading(true);
    try {
      for (const file of files) {
        onUploaded(await uploadVideo(file, categories));
      }
    } catch (err) {
      setError(err.message || "Upload failed");
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  return (
    <aside className="panel left-panel">
      <h2>Upload Video</h2>
      <label className="model-picker">
        <span>Additional categories (optional)</span>
        <input
          type="text"
          value={categories}
          placeholder="e.g. holding an umbrella, wearing glasses"
          onChange={(e) => setCategories(e.target.value)}
        />
        <small>Comma-separated. Applies to the next uploads; leave empty for the default check.</small>
      </label>
      <div
        className="dropzone"
        onDragOver={(e) => e.preventDefault()}
        onDrop={(e) => {
          e.preventDefault();
          handleFiles(e.dataTransfer.files);
        }}
        onClick={() => inputRef.current?.click()}
      >
        <p>{uploading ? "Uploading..." : "Drop a video here or click to browse"}</p>
        <input
          ref={inputRef}
          type="file"
          accept="video/*"
          multiple
          hidden
          onChange={(e) => handleFiles(e.target.files)}
        />
      </div>
      {error && <p className="error-text">{error}</p>}

      <ChatPanel videos={videos} onPlay={onPlay} />
    </aside>
  );
}
