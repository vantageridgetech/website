document.addEventListener("DOMContentLoaded", function () {
  const launcher = document.getElementById("chat-launcher");
  const panel = document.getElementById("chat-panel");
  const closeBtn = document.getElementById("chat-close");
  const form = document.getElementById("chat-form");
  const input = document.getElementById("chat-input");
  const sendBtn = document.getElementById("chat-send");
  const messagesEl = document.getElementById("chat-messages");
  const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

  let history = [];
  let greeted = false;

  function addMessage(role, text) {
    const el = document.createElement("div");
    el.className = "chat-msg " + role;
    el.textContent = text;
    messagesEl.appendChild(el);
    messagesEl.scrollTop = messagesEl.scrollHeight;
    return el;
  }

  function openPanel() {
    panel.classList.add("is-open");
    launcher.setAttribute("aria-expanded", "true");
    if (!greeted) {
      addMessage(
        "assistant",
        "Hi, I'm the Vantage Ridge assistant. Tell me a bit about what you're working on, and I'll point you to the right service — or just ask what we do."
      );
      greeted = true;
    }
    input.focus();
  }

  function closePanel() {
    panel.classList.remove("is-open");
    launcher.setAttribute("aria-expanded", "false");
  }

  launcher.addEventListener("click", function () {
    panel.classList.contains("is-open") ? closePanel() : openPanel();
  });
  closeBtn.addEventListener("click", closePanel);

  form.addEventListener("submit", async function (e) {
    e.preventDefault();
    const text = input.value.trim();
    if (!text) return;

    addMessage("user", text);
    history.push({ role: "user", content: text });
    input.value = "";
    input.disabled = true;
    sendBtn.disabled = true;

    const pending = addMessage("pending", "Thinking…");

    try {
      const resp = await fetch("/api/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRFToken": csrfToken,
        },
        body: JSON.stringify({ messages: history }),
      });
      const data = await resp.json();
      pending.remove();

      if (!resp.ok) {
        addMessage("assistant", data.error || "Something went wrong — please try again or email hello@vantageridgetech.com.");
        return;
      }

      addMessage("assistant", data.reply);
      history.push({ role: "assistant", content: data.reply });
    } catch (err) {
      pending.remove();
      addMessage("assistant", "Couldn't reach the assistant right now — please email hello@vantageridgetech.com.");
    } finally {
      input.disabled = false;
      sendBtn.disabled = false;
      input.focus();
    }
  });
});
