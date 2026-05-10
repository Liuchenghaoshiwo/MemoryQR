import { createMemoryPayload } from "./memoryPayload.js";

const form = document.querySelector("[data-memory-form]");
const titleInput = document.querySelector("[data-title-input]");
const messageInput = document.querySelector("[data-message-input]");
const payloadOutput = document.querySelector("[data-payload-output]");
const statusText = document.querySelector("[data-status-text]");

function updatePreview() {
  const payload = createMemoryPayload({
    title: titleInput.value,
    message: messageInput.value,
    createdAt: "2026-05-10T00:00:00.000Z",
  });

  payloadOutput.textContent = JSON.stringify(JSON.parse(payload), null, 2);
  statusText.textContent = `${payload.length} characters ready for future QR encoding`;
}

form.addEventListener("input", updatePreview);
form.addEventListener("submit", (event) => {
  event.preventDefault();
  updatePreview();
});

updatePreview();
