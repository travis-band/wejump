// This file runs in the browser. It sends requests to the server (backend) with fetch and draws the results on the page.

const form = document.querySelector("#form");
const nameInput = document.querySelector("#name");
const bodyInput = document.querySelector("#body");
const errorBox = document.querySelector("#error");
const list = document.querySelector("#messages");

function renderMessage(m) {
  const li = document.createElement("li");
  const meta = document.createElement("div");
  meta.className = "meta";
  const who = document.createElement("strong");
  const when = document.createElement("span");
  const text = document.createElement("p");

  // Using textContent instead of innerHTML means that even if someone types <script>, it shows up as plain text (prevents XSS).
  who.textContent = m.name;
  when.textContent = new Date(m.created_at).toLocaleString("en-US");
  text.textContent = m.body;

  meta.append(who, when);
  li.append(meta, text);
  return li;
}

async function loadMessages() {
  const res = await fetch("/api/messages");
  if (!res.ok) return;
  const messages = await res.json();
  if (messages.length === 0) {
    const li = document.createElement("li");
    li.className = "empty";
    li.textContent = "No messages yet. Be the first to leave one!";
    list.replaceChildren(li);
  } else {
    list.replaceChildren(...messages.map(renderMessage));
  }
}

// Show whether the server that answered my request is blue or green.
// During a deploy, the moment this color changes is the moment traffic moved to the new version.
async function loadVersion() {
  try {
    const res = await fetch("/api/version", { cache: "no-store" });
    const { version, color } = await res.json();
    document.documentElement.dataset.color = color;
    document.querySelector("#color-badge").textContent = color;
    document.querySelector("#version").textContent = version;
  } catch {
    document.querySelector("#color-badge").textContent = "disconnected";
  }
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
      body: JSON.stringify({ name: nameInput.value, body: bodyInput.value }),
    });
    if (!res.ok) {
      errorBox.textContent = res.status === 422 ? "Please fill in both your name and a message." : `Server error (${res.status})`;
      return;
    }
    bodyInput.value = "";
    await loadMessages();
  } catch {
    errorBox.textContent = "Can't reach the server.";
  } finally {
    button.disabled = false;
  }
});

loadMessages();
loadVersion();
setInterval(loadMessages, 3000); // Fetch new messages, including other people's, every 3 seconds
setInterval(loadVersion, 2000);
