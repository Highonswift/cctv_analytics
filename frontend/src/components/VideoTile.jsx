import { useEffect, useRef } from "react";

const STATUS_LABEL = {
  pending: "Queued",
  processing: "Processing...",
  done: "Processed",
  error: "Failed",
};

export default function VideoTile({ video, selected, onSelect, playRequest }) {
  const tileRef = useRef(null);
  const videoRef = useRef(null);

  // A clicked timeline (from the chat) for this video: jump to its start,
  // play, and pause once the end of the window is reached.
  useEffect(() => {
    const el = videoRef.current;
    if (!playRequest || playRequest.videoId !== video.id || !el) return undefined;

    const { start, end } = playRequest;
    const stopAtEnd = () => {
      if (el.currentTime >= end) {
        el.pause();
        el.removeEventListener("timeupdate", stopAtEnd);
      }
    };
    tileRef.current?.scrollIntoView({ behavior: "smooth", block: "nearest" });
    el.addEventListener("timeupdate", stopAtEnd);
    el.currentTime = start;
    el.play().catch(() => {
      // autoplay blocked -- the user can press play, the window still applies
    });
    return () => el.removeEventListener("timeupdate", stopAtEnd);
  }, [playRequest, video.id]);

  return (
    <div
      ref={tileRef}
      className={`video-tile${selected ? " video-tile-selected" : ""}`}
      onClick={() => onSelect(video.id)}
    >
      <video ref={videoRef} src={video.video_url} controls muted />
      <div className="video-tile-footer">
        <span className="video-tile-name" title={video.filename}>
          {video.filename}
        </span>
        <span className={`video-tile-status status-${video.status}`}>
          {STATUS_LABEL[video.status] || video.status}
        </span>
      </div>
      {video.status === "done" && <span className="video-tile-tick">✓</span>}
    </div>
  );
}
