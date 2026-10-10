// Code shared by both pages (index.html and me.html). Loaded before app.js / me.js.

// Draw one guestbook message. Using textContent instead of innerHTML means that even if someone
// types <script>, it shows up as plain text (prevents XSS).
function renderMessage(m) {
  const li = document.createElement("li");
  const meta = document.createElement("div");
  meta.className = "meta";
  const who = document.createElement("span");
  who.className = "who";
  const when = document.createElement("span");
  const text = document.createElement("p");

  if (m.avatar_url) {
    const avatar = document.createElement("img");
    avatar.className = "avatar";
    avatar.src = m.avatar_url;
    avatar.alt = "";
    who.append(avatar);
  }
  const name = document.createElement("strong");
  // Messages from before login existed belong to the guest user. Their typed-in name is still shown.
  name.textContent = m.login === "guest" ? `${m.name} (guest)` : `@${m.login}`;
  who.append(name);

  when.textContent = new Date(m.created_at).toLocaleString("en-US");
  text.textContent = m.body;

  meta.append(who, when);
  li.append(meta, text);
  return li;
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

// Who is signed in? Returns the profile, or null if nobody is (or the server can't be reached).
// The browser sends the session cookie along automatically; JavaScript never touches it.
async function loadMe() {
  try {
    const res = await fetch("/api/me", { cache: "no-store" });
    return res.ok ? await res.json() : null;
  } catch {
    return null;
  }
}

async function logout() {
  await fetch("/auth/logout", { method: "POST" });
  location.href = "/";
}

// The account area at the top right: "Sign in with GitHub", or the signed-in user with a Logout button.
function renderAccount(user) {
  const box = document.querySelector("#account");
  if (!user) {
    const signIn = document.createElement("a");
    signIn.className = "signin";
    signIn.href = "/auth/login";
    signIn.textContent = "Sign in with GitHub";
    box.replaceChildren(signIn);
    return;
  }
  const profile = document.createElement("a");
  profile.className = "who";
  profile.href = "/me.html";
  const avatar = document.createElement("img");
  avatar.className = "avatar";
  avatar.src = user.avatar_url || "";
  avatar.alt = "";
  const name = document.createElement("span");
  name.textContent = `@${user.login}`;
  profile.append(avatar, name);

  const out = document.createElement("button");
  out.type = "button";
  out.className = "link-button";
  out.textContent = "Logout";
  out.addEventListener("click", logout);
  box.replaceChildren(profile, out);
}
