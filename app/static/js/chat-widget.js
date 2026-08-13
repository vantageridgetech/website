document.addEventListener("DOMContentLoaded", function () {
  const launcher = document.getElementById("chat-launcher");
  const panel = document.getElementById("chat-panel");
  const closeBtn = document.getElementById("chat-close");
  const form = document.getElementById("chat-form");
  const input = document.getElementById("chat-input");
  const sendBtn = document.getElementById("chat-send");
  const messagesEl = document.getElementById("chat-messages");
  const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

  const GREETING = "Hi, I'm the Vantage Ridge assistant. How can I help you today?";
  const AUTO_OPEN_SESSION_KEY = "vrtChatAutoOpened";
  const AUTO_OPEN_DELAY_MS = 2000;
  const TYPE_SPEED_MS = 22;

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

  // Reveals text character-by-character, like someone typing it live.
  function typeMessage(role, text) {
    const el = document.createElement("div");
    el.className = "chat-msg " + role;
    messagesEl.appendChild(el);

    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReducedMotion) {
      el.textContent = text;
      messagesEl.scrollTop = messagesEl.scrollHeight;
      return el;
    }

    let i = 0;
    (function tick() {
      i += 1;
      el.textContent = text.slice(0, i);
      messagesEl.scrollTop = messagesEl.scrollHeight;
      if (i < text.length) setTimeout(tick, TYPE_SPEED_MS);
    })();
    return el;
  }

  function greet(animated) {
    if (greeted) return;
    greeted = true;
    if (animated) {
      typeMessage("assistant", GREETING);
    } else {
      addMessage("assistant", GREETING);
    }
  }

  function openPanel({ animateGreeting = false, focusInput = true } = {}) {
    panel.classList.add("is-open");
    launcher.setAttribute("aria-expanded", "true");
    greet(animateGreeting);
    if (focusInput) input.focus();
  }

  function closePanel() {
    panel.classList.remove("is-open");
    launcher.setAttribute("aria-expanded", "false");
  }

  launcher.addEventListener("click", function () {
    if (panel.classList.contains("is-open")) {
      closePanel();
    } else {
      openPanel({ animateGreeting: !greeted, focusInput: true });
    }
  });
  closeBtn.addEventListener("click", closePanel);

  // Auto-open once per browser tab/session — not on every page navigation
  // within the same visit, and not instantly on load (a hard pop the moment
  // the page paints reads as spammy rather than helpful).
  if (!sessionStorage.getItem(AUTO_OPEN_SESSION_KEY)) {
    sessionStorage.setItem(AUTO_OPEN_SESSION_KEY, "1");
    setTimeout(function () {
      openPanel({ animateGreeting: true, focusInput: false });
    }, AUTO_OPEN_DELAY_MS);
  }

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
