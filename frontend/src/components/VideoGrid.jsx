import VideoTile from "./VideoTile.jsx";

export default function VideoGrid({ videos, selectedId, onSelect, playRequest }) {
  if (videos.length === 0) {
    return (
      <main className="panel center-panel">
        <p className="empty-hint">Upload a video from the left panel to get started.</p>
      </main>
    );
  }

  return (
    <main className="panel center-panel">
      <div className="video-grid">
        {videos.map((video) => (
          <VideoTile
            key={video.id}
            video={video}
            selected={video.id === selectedId}
            onSelect={onSelect}
            playRequest={playRequest}
          />
        ))}
      </div>
    </main>
  );
}
