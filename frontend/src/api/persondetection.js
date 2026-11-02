const JSON_HEADERS = { Accept: "application/json" };

async function handle(response) {
  if (!response.ok) {
    let detail = response.statusText;
    try {
      const body = await response.json();
      detail = body.detail || detail;
    } catch {
      // ignore non-JSON error bodies
    }
    throw new Error(detail);
  }
  return response.json();
}

export function listVideos() {
  return fetch("/api/videos", { headers: JSON_HEADERS }).then(handle);
}

export function getVideo(videoId) {
  return fetch(`/api/videos/${videoId}`, { headers: JSON_HEADERS }).then(handle);
}

// `categories`: optional comma-separated extra things to look for in each person.
export function uploadVideo(file, categories) {
  const formData = new FormData();
  formData.append("file", file);
  if (categories && categories.trim()) formData.append("categories", categories.trim());
  return fetch("/api/videos", {
    method: "POST",
    body: formData,
  }).then(handle);
}

// Stateless: each call answers `question` from the current saved results,
// with no conversation history sent or kept on the server.
export function askChat(question) {
  return fetch("/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...JSON_HEADERS },
    body: JSON.stringify({ question }),
  }).then(handle);
}
