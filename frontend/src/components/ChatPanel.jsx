import { useState } from "react";
import { askChat } from "../api/persondetection.js";

const MARKER = /\[\[([^\]|]+)\|([^\]]+)\]\]/g;

function formatTime(sec) {
  const total = Math.max(0, Math.round(sec));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

// Turns Gemini's [[video_id|ID3]] markers into buttons that play that
// person's timeline; text, and markers that match nothing, stay as text.
function AnswerText({ text, videos, onPlay }) {
  const parts = [];
  let last = 0;
  for (const match of text.matchAll(MARKER)) {
    parts.push(text.slice(last, match.index));
    const [raw, videoId, label] = match;
    const video = videos.find((v) => v.id === videoId.trim());
    const person = video?.persons.find((p) => p.label === label.trim());
    if (person && person.timeline_start_sec != null && person.timeline_end_sec != null) {
      parts.push(
        <button
          key={match.index}
          type="button"
          className="timeline-chip"
          title={`Play ${video.filename}`}
          onClick={() =>
            onPlay({ videoId: video.id, start: person.timeline_start_sec, end: person.timeline_end_sec })
          }
        >
          ▶ {person.label} · {formatTime(person.timestamp_sec ?? person.timeline_start_sec)}
        </button>
      );
    } else {
      parts.push(person ? `${person.label}` : raw);
    }
    last = match.index + raw.length;
  }
  parts.push(text.slice(last));
  return <>{parts}</>;
}

// Answers questions over every saved video result (per-person attributes),
// via the backend's Gemini-backed /api/chat. Stateless server-side -- each
// question re-sends the full current results snapshot, no history; the
// exchange list below is purely local (for display), not sent back on the
// next question.
export default function ChatPanel({ videos = [], onPlay }) {
  const [question, setQuestion] = useState("");
  const [exchanges, setExchanges] = useState([]); // [{ question, answer, error }]
  const [asking, setAsking] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    const q = question.trim();
    if (!q || asking) return;

    setAsking(true);
    setQuestion("");
    const entry = { question: q, answer: null, error: null };
    setExchanges((prev) => [...prev, entry]);

    try {
      const { answer } = await askChat(q);
      setExchanges((prev) => prev.map((ex) => (ex === entry ? { ...ex, answer } : ex)));
    } catch (err) {
      const message = err.message || "Failed to reach the chat assistant";
      setExchanges((prev) => prev.map((ex) => (ex === entry ? { ...ex, error: message } : ex)));
    } finally {
      setAsking(false);
    }
  }

  return (
    <div className="chat-panel">
      <div className="chat-panel-label">Chat</div>
      <p className="chat-panel-hint">Ask about people, clothing, bags or covered faces across every processed video.</p>

      {exchanges.length > 0 && (
        <div className="chat-log">
          {exchanges.map((ex, i) => (
            <div key={i} className="chat-exchange">
              <div className="chat-question">{ex.question}</div>
              {ex.error ? (
                <div className="chat-answer chat-answer-error">{ex.error}</div>
              ) : ex.answer ? (
                <div className="chat-answer">
                  <AnswerText text={ex.answer} videos={videos} onPlay={onPlay} />
                </div>
              ) : (
                <div className="chat-answer chat-answer-pending">Thinking...</div>
              )}
            </div>
          ))}
        </div>
      )}

      <form className="chat-panel-box" onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="e.g. Who is carrying a suitcase?"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          disabled={asking}
        />
        <button type="submit" disabled={asking || !question.trim()}>
          {asking ? "..." : "Send"}
        </button>
      </form>
    </div>
  );
}
