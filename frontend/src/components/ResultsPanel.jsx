function Badge({ label, value, cls }) {
  return (
    <span className={`gear-badge ${cls}`}>
      {label}: {value}
    </span>
  );
}

// yes/no attribute with optional detail text (bag kinds, face-cover kind).
// Green = absent, red = present (worth noticing), grey = unknown.
function FlagBadge({ label, flag, detail }) {
  if (flag === true) return <Badge label={label} value={detail || "yes"} cls="gear-missing" />;
  if (flag === false) return <Badge label={label} value="no" cls="gear-ok" />;
  return <Badge label={label} value="?" cls="gear-unknown" />;
}

function PersonBadges({ person }) {
  const known = person.category && person.category !== "unknown";
  const dress = [person.dress_color, person.dress_type].filter(Boolean).join(" ");
  const bags = person.bags || [];
  return (
    <div className="gear-badges">
      <Badge label="Category" value={known ? person.category : "unknown"} cls={known ? "gear-ok" : "gear-unknown"} />
      <Badge label="Dress" value={dress || "?"} cls={dress ? "gear-ok" : "gear-unknown"} />
      <FlagBadge label="Bag" flag={person.holding_bag} detail={bags.join(", ")} />
      <FlagBadge label="Face covered" flag={person.face_covered} detail={person.face_cover_type} />
      {Object.entries(person.additional_categories || {}).map(([name, answer]) => (
        <FlagBadge key={name} label={name} flag={answer.present} detail={answer.detail} />
      ))}
    </div>
  );
}

function VideoResultSection({ video, active }) {
  return (
    <section className={`result-section${active ? " result-section-active" : ""}`}>
      <h3 title={video.filename}>{video.filename}</h3>

      {video.status !== "done" && video.status !== "error" && (
        <p className="result-status">
          {video.status === "processing" ? "Processing..." : "Waiting to process..."}
        </p>
      )}
      {video.status === "error" && (
        <p className="error-text">Processing failed: {video.error}</p>
      )}
      {video.status === "done" && video.persons.length === 0 && (
        <p className="result-status">No persons detected.</p>
      )}

      <ul className="person-list">
        {video.persons.map((person) => (
          <li key={person.track_id} className="person-item">
            <div className="person-line">
              <strong>{person.label}:</strong> {person.summary}
            </div>
            <PersonBadges person={person} />
          </li>
        ))}
      </ul>
    </section>
  );
}

export default function ResultsPanel({ videos, selectedId }) {
  return (
    <aside className="panel right-panel">
      <h2>Results</h2>
      <div className="results-list">
        {videos.length === 0 && <p className="empty-hint">No uploads yet.</p>}
        {videos.map((video) => (
          <VideoResultSection key={video.id} video={video} active={video.id === selectedId} />
        ))}
      </div>
    </aside>
  );
}
