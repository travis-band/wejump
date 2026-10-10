// This file runs in the browser. It sends requests to the server (backend) with fetch and draws the results on the page.
// renderMessage, loadVersion, loadMe, and renderAccount come from common.js.

const form = document.querySelector("#form");
const bodyInput = document.querySelector("#body");
const errorBox = document.querySelector("#error");
const list = document.querySelector("#messages");
const signInHint = document.querySelector("#signin-hint");

// Anyone can read, but only signed-in users can post. Show the form or a sign-in hint to match.
function showForm(user) {
  form.hidden = !user;
  signInHint.hidden = Boolean(user);
}

// Returns true if the list was loaded, false if the server answered with an error.
async function loadMessages() {
  const res = await fetch("/api/messages");
  if (!res.ok) return false;
  const messages = await res.json();
  if (messages.length === 0) {
    const li = document.createElement("li");
    li.className = "empty";
    li.textContent = "No messages yet. Be the first to leave one!";
    list.replaceChildren(li);
  } else {
    list.replaceChildren(...messages.map(renderMessage));
  }
  return true;
}

form.addEventListener("submit", async (event) => {
  event.preventDefault(); // Stop the page from reloading
  errorBox.textContent = "";
  const button = form.querySelector("button");
  button.disabled = true;
  try {
    const res = await fetch("/api/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ body: bodyInput.value }),
    });
    if (res.status === 401) {
      // The login cookie expired, or SESSION_SECRET changed on the server. Show the sign-in hint again.
      renderAccount(null);
      showForm(null);
      return;
    }
    if (!res.ok) {
      errorBox.textContent = res.status === 422 ? "Please write a message." : `Server error (${res.status})`;
      return;
    }
    bodyInput.value = "";
    await refreshAll();
  } catch {
    errorBox.textContent = "Can't reach the server.";
  } finally {
    button.disabled = false;
  }
});

// ── Auto-refresh ─────────────────────────────────────────────────────────────
// Off by default. Every request wakes the server, and while the server is awake its
// health checks keep the database awake too. Both use up a free monthly allowance
// (see docs/appendix-free-tier-limits.md). So the page refreshes on its own only when
// you turn it on, and even then it pauses when nobody is looking.

const REFRESH_EVERY_MS = 10 * 1000; // refresh every 10 seconds while it's on
const IDLE_LIMIT_MS = 10 * 60 * 1000; // pause after 10 minutes with no activity

const autoRefreshToggle = document.querySelector("#auto-refresh");
const refreshStatus = document.querySelector("#refresh-status");
let lastUpdated = null;
let lastActivity = Date.now();
let timer = null;

// Load the messages and the version badge together.
async function refreshAll() {
  try {
    const [loaded] = await Promise.all([loadMessages(), loadVersion()]);
    if (loaded) lastUpdated = new Date();
  } catch {
    // Network error: keep the old "Last updated" time so it's clear the list may be stale.
  }
  showStatus();
}

// Why auto-refresh is not running right now, or null if it is running.
function pauseReason() {
  if (!autoRefreshToggle.checked) return "off";
  if (document.hidden) return "hidden";
  if (Date.now() - lastActivity > IDLE_LIMIT_MS) return "idle";
  return null;
}

function showStatus() {
  if (pauseReason() === "idle") {
    refreshStatus.textContent = "Paused after 10 min with no activity. Tap to resume.";
    return;
  }
  // toLocaleTimeString shows the time in the browser's own time zone.
  const time = lastUpdated ? lastUpdated.toLocaleTimeString("en-US") : "…";
  refreshStatus.textContent = `Last updated ${time}`;
}

function tick() {
  if (pauseReason() === null) refreshAll();
  else showStatus();
}

autoRefreshToggle.addEventListener("change", () => {
  clearInterval(timer);
  timer = null;
  if (autoRefreshToggle.checked) {
    lastActivity = Date.now();
    refreshAll(); // refresh right away, then every 10 seconds
    timer = setInterval(tick, REFRESH_EVERY_MS);
  }
  showStatus();
});

// Pause 1: while the tab is hidden (another tab, a minimized window, a phone screen turned off).
// Coming back to the tab counts as activity, so it catches up right away.
document.addEventListener("visibilitychange", () => {
  if (!document.hidden) lastActivity = Date.now();
  tick();
});

// Pause 2: after 10 minutes with no activity, e.g. a tab left open on a classroom screen.
// Any click, tap, key press, scroll, or mouse move counts as activity and resumes it.
for (const type of ["pointerdown", "pointermove", "keydown", "scroll", "touchstart"]) {
  window.addEventListener(
    type,
    () => {
      const wasIdle = pauseReason() === "idle";
      lastActivity = Date.now();
      if (wasIdle) refreshAll();
    },
    { passive: true },
  );
}

// Load once when the page opens
loadMe().then((user) => {
  renderAccount(user);
  showForm(user);
});
if (new URLSearchParams(location.search).get("login") === "failed") {
  signInHint.prepend("Sign-in was canceled or failed. ");
}
refreshAll();
