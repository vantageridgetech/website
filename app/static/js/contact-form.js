document.addEventListener("DOMContentLoaded", function () {
  const form = document.getElementById("contact-form");
  if (!form) return;

  form.addEventListener("submit", async function (e) {
    e.preventDefault();
    const submitBtn = document.getElementById("cf-submit");
    const status = document.getElementById("cf-status");
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    const payload = {
      name: document.getElementById("cf-name").value.trim(),
      email: document.getElementById("cf-email").value.trim(),
      message: document.getElementById("cf-message").value.trim(),
    };

    submitBtn.disabled = true;
    status.textContent = "";
    status.className = "form-status";

    try {
      const resp = await fetch("/api/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRFToken": csrfToken },
        body: JSON.stringify(payload),
      });
      const data = await resp.json();

      if (!resp.ok) {
        status.textContent = data.error || "Something went wrong — please try again.";
        status.classList.add("error");
        return;
      }

      status.textContent = "Sent — we'll get back to you soon.";
      status.classList.add("success");
      form.reset();
    } catch (err) {
      status.textContent = "Couldn't send — please email hello@vantageridgetech.com directly.";
      status.classList.add("error");
    } finally {
      submitBtn.disabled = false;
    }
  });
});
