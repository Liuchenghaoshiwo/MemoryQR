const MEMORY_SCHEMA = "memoryqr.memory.v1";

export function createMemoryPayload({ title, message, createdAt = new Date().toISOString() }) {
  const memory = {
    schema: MEMORY_SCHEMA,
    title: normalizeText(title, "Untitled memory"),
    message: normalizeText(message, ""),
    createdAt,
  };

  return JSON.stringify(memory);
}

export function parseMemoryPayload(payload) {
  let memory;

  try {
    memory = JSON.parse(payload);
  } catch {
    throw new Error("Expected valid MemoryQR JSON.");
  }

  if (!memory || memory.schema !== MEMORY_SCHEMA) {
    throw new Error("Unsupported MemoryQR schema.");
  }

  return {
    schema: memory.schema,
    title: normalizeText(memory.title, "Untitled memory"),
    message: normalizeText(memory.message, ""),
    createdAt: normalizeText(memory.createdAt, new Date().toISOString()),
  };
}

function normalizeText(value, fallback) {
  const normalized = String(value ?? "").trim();
  return normalized.length > 0 ? normalized : fallback;
}
