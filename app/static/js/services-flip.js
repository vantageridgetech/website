const SERVICES = [
  {
    title: "Cloud Infrastructure Setup & Migration",
    hook: "New environments, or migrating off legacy systems — on AWS, Google Cloud, or Azure.",
    bullets: [
      "Multi-cloud network & environment design",
      "Migration planning with minimal downtime",
      "Infrastructure as code from day one",
    ],
  },
  {
    title: "Cloud Cost Optimization",
    hook: "Cut cloud spend without cutting capability.",
    bullets: [
      "Right-sizing & reserved-capacity review",
      "Idle and orphaned resource cleanup",
      "Cost visibility dashboards & alerts",
    ],
  },
  {
    title: "Cloud Security & Compliance",
    hook: "Find what an attacker or an auditor would find first — before they do.",
    bullets: [
      "Account security reviews & IAM hardening",
      "CIS benchmark alignment",
      "WAF / threat-detection setup",
    ],
  },
  {
    title: "CI/CD & DevSecOps Pipelines",
    hook: "Security scanning built into the path to production, not bolted on after.",
    bullets: [
      "GitHub Actions / Jenkins pipeline design",
      "SAST, dependency & container scanning",
      "Policy-as-code guardrails",
    ],
  },
  {
    title: "Custom Web & Application Development",
    hook: "Real applications — auth, databases, payments — not just static pages.",
    bullets: [
      "Full-stack apps built to run in production",
      "Secure by default: CSRF, hashed auth, tested",
      "Deployed on the cloud platform of your choice",
    ],
  },
  {
    title: "Secure Website Design & Hosting",
    hook: "A website for your business, hosted the way we'd host our own.",
    bullets: [
      "TLS, WAF, and CDN by default",
      "IaC-managed, no manual console changes",
      "Right-sized for a small-business budget",
    ],
  },
  {
    title: "Applied AI Automation & Agents",
    hook: "Practical AI integrations for real workflows — including this chat widget.",
    bullets: [
      "Agent-based workflow automation",
      "Meeting transcription & summarization",
      "Internal tooling to cut manual ops work",
    ],
  },
  {
    title: "Ongoing Cloud & IT Support",
    hook: "A fractional cloud engineer for teams that don't have one yet.",
    bullets: [
      "Monitoring, alerting & incident response",
      "Recurring cloud cost review",
      "Ad-hoc advisory for small in-house teams",
    ],
  },
];

document.addEventListener("DOMContentLoaded", function () {
  const card = document.getElementById("services-flip-card");
  if (!card) return;

  const inner = card.querySelector(".flip-card__inner");
  const frontFace = card.querySelector(".flip-card__face--front");
  const backFace = card.querySelector(".flip-card__face--back");
  const dotsEl = document.getElementById("flip-dots");
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  let currentIndex = 0;
  let frontIsActive = true; // which physical face is currently facing the viewer
  let timer = null;

  function renderFace(face, index) {
    const s = SERVICES[index];
    face.innerHTML =
      '<div class="flip-card__index">' + String(index + 1).padStart(2, "0") + " / " + SERVICES.length + "</div>" +
      "<h3>" + s.title + "</h3>" +
      "<p>" + s.hook + "</p>" +
      "<ul>" + s.bullets.map((b) => "<li>" + b + "</li>").join("") + "</ul>";
  }

  function renderDots() {
    dotsEl.innerHTML = "";
    SERVICES.forEach((s, i) => {
      const dot = document.createElement("button");
      dot.setAttribute("aria-label", "Show " + s.title);
      if (i === currentIndex) dot.classList.add("is-active");
      dot.addEventListener("click", () => goTo(i));
      dotsEl.appendChild(dot);
    });
  }

  function goTo(index) {
    if (index === currentIndex) return;
    currentIndex = index;
    const hiddenFace = frontIsActive ? backFace : frontFace;
    renderFace(hiddenFace, currentIndex);
    frontIsActive = !frontIsActive;
    card.classList.toggle("is-flipped");
    renderDots();
    resetTimer();
  }

  function advance() {
    goTo((currentIndex + 1) % SERVICES.length);
  }

  function resetTimer() {
    if (timer) clearInterval(timer);
    if (!prefersReducedMotion) {
      timer = setInterval(advance, 4800);
    }
  }

  renderFace(frontFace, 0);
  renderDots();
  resetTimer();

  card.addEventListener("mouseenter", () => timer && clearInterval(timer));
  card.addEventListener("mouseleave", resetTimer);
});
