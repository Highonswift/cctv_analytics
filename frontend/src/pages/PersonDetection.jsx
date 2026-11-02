import { useCallback, useEffect, useRef, useState } from "react";
import { listVideos } from "../api/persondetection.js";
import UploadPanel from "../components/UploadPanel.jsx";
import VideoGrid from "../components/VideoGrid.jsx";
import ResultsPanel from "../components/ResultsPanel.jsx";

const POLL_INTERVAL_MS = 2000;

export default function PersonDetection() {
  const [videos, setVideos] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  // Set when a timeline is clicked in the chat: { videoId, start, end, nonce }.
  // The nonce makes clicking the same timeline twice replay it.
  const [playRequest, setPlayRequest] = useState(null);
  const pollRef = useRef(null);

  // Videos process in the background, so poll for status and new persons.
  const refresh = useCallback(async () => {
    try {
      const data = await listVideos();
      setVideos(data);
    } catch {
      // transient network hiccup while polling -- next tick will retry
    }
  }, []);

  useEffect(() => {
    refresh();
    pollRef.current = setInterval(refresh, POLL_INTERVAL_MS);
    return () => clearInterval(pollRef.current);
  }, [refresh]);

  function handleUploaded(record) {
    setVideos((prev) => [record, ...prev]);
    setSelectedId(record.id);
  }

  function handlePlay({ videoId, start, end }) {
    setSelectedId(videoId);
    setPlayRequest({ videoId, start, end, nonce: Date.now() });
  }

  return (
    <div className="person-detection-layout">
      <UploadPanel onUploaded={handleUploaded} videos={videos} onPlay={handlePlay} />
      <VideoGrid
        videos={videos}
        selectedId={selectedId}
        onSelect={setSelectedId}
        playRequest={playRequest}
      />
      <ResultsPanel videos={videos} selectedId={selectedId} />
    </div>
  );
}
