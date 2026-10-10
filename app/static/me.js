// The user page. Shows the signed-in user's GitHub profile and the messages they wrote.
// renderMessage, loadVersion, loadMe, renderAccount, and logout come from common.js.

function formatDate(value) {
  return value ? new Date(value).toLocaleString("en-US") : "—";
}

function showProfile(user) {
  document.querySelector("#profile-avatar").src = user.avatar_url || "";
  document.querySelector("#profile-name").textContent = user.name || user.login;
  const login = document.querySelector("#profile-login");
  login.textContent = `@${user.login} on GitHub`;
  login.href = user.html_url || `https://github.com/${user.login}`;
  document.querySelector("#profile-joined").textContent = formatDate(user.created_at);
  document.querySelector("#profile-last-login").textContent = formatDate(user.last_login_at);
  document.querySelector("#profile-count").textContent = user.message_count;
  document.querySelector("#profile").hidden = false;
}

async function loadMyMessages() {
  const res = await fetch("/api/me/messages", { cache: "no-store" });
  if (!res.ok) return;
  const messages = await res.json();
  const list = document.querySelector("#messages");
  if (messages.length === 0) {
    const li = document.createElement("li");
    li.className = "empty";
    li.innerHTML = 'You haven\'t written anything yet. <a href="/">Leave a message!</a>';
    list.replaceChildren(li);
  } else {
    list.replaceChildren(...messages.map(renderMessage));
  }
  document.querySelector("#my-messages-title").hidden = false;
}

document.querySelector("#logout").addEventListener("click", logout);

loadVersion();
loadMe().then((user) => {
  renderAccount(user);
  if (!user) {
    document.querySelector("#signin-hint").hidden = false;
    return;
  }
  showProfile(user);
  loadMyMessages();
});
