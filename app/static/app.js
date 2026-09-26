// 이 파일은 "브라우저"에서 실행됩니다. 서버(백엔드)에 fetch로 요청을 보내고 결과를 화면에 그립니다.

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

  // innerHTML 대신 textContent를 쓰면, 누가 <script>를 적어도 그냥 글자로만 보입니다 (XSS 방지).
  who.textContent = m.name;
  when.textContent = new Date(m.created_at).toLocaleString("ko-KR");
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
    li.textContent = "아직 글이 없어요. 첫 글을 남겨 보세요!";
    list.replaceChildren(li);
  } else {
    list.replaceChildren(...messages.map(renderMessage));
  }
}

// 지금 내 요청에 대답한 서버가 blue인지 green인지 표시합니다.
// 배포 중에 이 색이 바뀌는 순간이 바로 "트래픽이 새 버전으로 넘어간" 순간입니다.
async function loadVersion() {
  try {
    const res = await fetch("/api/version", { cache: "no-store" });
    const { version, color } = await res.json();
    document.documentElement.dataset.color = color;
    document.querySelector("#color-badge").textContent = color;
    document.querySelector("#version").textContent = version;
  } catch {
    document.querySelector("#color-badge").textContent = "연결 끊김";
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault(); // 페이지 새로고침 막기
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
      errorBox.textContent = res.status === 422 ? "이름과 한마디를 모두 적어 주세요." : `서버 오류 (${res.status})`;
      return;
    }
    bodyInput.value = "";
    await loadMessages();
  } catch {
    errorBox.textContent = "서버에 연결할 수 없어요.";
  } finally {
    button.disabled = false;
  }
});

loadMessages();
loadVersion();
setInterval(loadMessages, 3000); // 다른 사람이 쓴 글도 3초마다 새로 가져오기
setInterval(loadVersion, 2000);
