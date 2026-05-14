const MEMORY_SCHEMA = "memoryqr.memory.v1";
const AUTHORIZATION_MODE_LOCAL_READER = "local-reader";
const AUTHORIZATION_POLICY_LOCAL_READER_ALLOWLIST = "local-reader-allowlist";
const ATTACHMENT_STORAGE_KIND_LOCAL_ENCRYPTED_BUNDLE = "local-encrypted-bundle";
const MAX_ATTACHMENTS = 8;
const MAX_ATTACHMENT_REFERENCES_BYTES = 2048;
const MAX_ENCRYPTED_BUNDLE_REF_LENGTH = 512;
const READER_ID_PATTERN = /^[a-z0-9][a-z0-9._:-]{0,63}$/u;
const ENCRYPTED_BUNDLE_REF_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:/?#@!$&'()*+,;=%~-]{0,511}$/u;
const ATTACHMENT_TYPES = new Set(["image", "audio", "video"]);
const SHA256_PATTERN = /^[a-f0-9]{64}$/u;
const textEncoder = new TextEncoder();

export function createMemoryPayload({
  title,
  message,
  createdAt = new Date().toISOString(),
  authorization,
  attachments = [],
}) {
  const memory = {
    schema: MEMORY_SCHEMA,
    title: normalizeText(title, "Untitled memory"),
    message: normalizeText(message, ""),
    createdAt,
  };
  const normalizedAuthorization = normalizeMemoryAuthorization(authorization);
  const normalizedAttachments = normalizeAttachmentReferences(attachments);

  if (normalizedAuthorization) {
    memory.authorization = normalizedAuthorization;
  }
  if (normalizedAttachments.length > 0) {
    memory.attachments = normalizedAttachments;
  }

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

  const parsedMemory = {
    schema: memory.schema,
    title: normalizeText(memory.title, "Untitled memory"),
    message: normalizeText(memory.message, ""),
    createdAt: normalizeText(memory.createdAt, new Date().toISOString()),
  };
  const authorization = normalizeMemoryAuthorization(memory.authorization);
  const attachments = normalizeAttachmentReferences(memory.attachments);

  if (authorization) {
    parsedMemory.authorization = authorization;
  }
  if (attachments.length > 0) {
    parsedMemory.attachments = attachments;
  }

  return parsedMemory;
}

function normalizeText(value, fallback) {
  const normalized = String(value ?? "").trim();
  return normalized.length > 0 ? normalized : fallback;
}

function normalizeMemoryAuthorization(value) {
  if (value == null) {
    return undefined;
  }
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid MemoryQR payload.");
  }
  assertAllowedKeys(value, ["mode", "policy", "allowedReaderIds"]);

  const mode = normalizeText(value.mode, AUTHORIZATION_MODE_LOCAL_READER);
  if (mode !== AUTHORIZATION_MODE_LOCAL_READER) {
    throw new Error("Invalid MemoryQR payload.");
  }

  const policy = normalizeText(value.policy, "");
  const allowedReaderIds = normalizeAllowedReaderIds(value.allowedReaderIds);
  if (policy !== AUTHORIZATION_POLICY_LOCAL_READER_ALLOWLIST || allowedReaderIds.length === 0) {
    throw new Error("Invalid MemoryQR payload.");
  }

  return {
    mode,
    policy,
    allowedReaderIds,
  };
}

function normalizeAllowedReaderIds(value) {
  if (!Array.isArray(value)) {
    throw new Error("Invalid MemoryQR payload.");
  }

  const seen = new Set();
  const normalizedReaderIds = [];
  for (const readerId of value) {
    const normalized = normalizeReaderId(readerId);
    if (!seen.has(normalized)) {
      seen.add(normalized);
      normalizedReaderIds.push(normalized);
    }
  }
  return normalizedReaderIds;
}

function normalizeAttachmentReferences(value) {
  if (value == null) {
    return [];
  }
  if (!Array.isArray(value) || value.length > MAX_ATTACHMENTS) {
    throw new Error("Invalid MemoryQR payload.");
  }

  const seen = new Set();
  const attachments = value.map((attachment) => {
    const normalized = normalizeAttachmentReference(attachment);
    if (seen.has(normalized.id)) {
      throw new Error("Invalid MemoryQR payload.");
    }
    seen.add(normalized.id);
    return normalized;
  });

  if (textEncoder.encode(JSON.stringify(attachments)).byteLength > MAX_ATTACHMENT_REFERENCES_BYTES) {
    throw new Error("Invalid MemoryQR payload.");
  }
  return attachments;
}

function normalizeAttachmentReference(value) {
  if (typeof value !== "object" || value == null || Array.isArray(value)) {
    throw new Error("Invalid MemoryQR payload.");
  }
  assertAllowedKeys(value, ["id", "type", "size", "sha256", "storage"]);

  return {
    id: normalizeReaderId(value.id),
    type: normalizeAttachmentType(value.type),
    size: normalizeAttachmentSize(value.size),
    sha256: normalizeSha256(value.sha256),
    storage: normalizeAttachmentStorage(value.storage),
  };
}

function normalizeAttachmentStorage(value) {
  if (typeof value !== "object" || value == null || Array.isArray(value)) {
    throw new Error("Invalid MemoryQR payload.");
  }
  assertAllowedKeys(value, ["kind", "encryptedBundleRef"]);

  const kind = normalizeText(value.kind, "");
  if (kind !== ATTACHMENT_STORAGE_KIND_LOCAL_ENCRYPTED_BUNDLE) {
    throw new Error("Invalid MemoryQR payload.");
  }

  return {
    kind,
    encryptedBundleRef: normalizeEncryptedBundleRef(value.encryptedBundleRef),
  };
}

function normalizeAttachmentType(value) {
  const normalized = normalizeText(value, "").toLowerCase();
  if (!ATTACHMENT_TYPES.has(normalized)) {
    throw new Error("Invalid MemoryQR payload.");
  }
  return normalized;
}

function normalizeAttachmentSize(value) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error("Invalid MemoryQR payload.");
  }
  return value;
}

function normalizeSha256(value) {
  const normalized = normalizeText(value, "").toLowerCase();
  if (!SHA256_PATTERN.test(normalized)) {
    throw new Error("Invalid MemoryQR payload.");
  }
  return normalized;
}

function normalizeEncryptedBundleRef(value) {
  const normalized = normalizeText(value, "");
  if (
    normalized.length === 0 ||
    normalized.length > MAX_ENCRYPTED_BUNDLE_REF_LENGTH ||
    !ENCRYPTED_BUNDLE_REF_PATTERN.test(normalized)
  ) {
    throw new Error("Invalid MemoryQR payload.");
  }
  return normalized;
}

function normalizeReaderId(value) {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (!READER_ID_PATTERN.test(normalized)) {
    throw new Error("Invalid MemoryQR payload.");
  }
  return normalized;
}

function assertAllowedKeys(value, allowedKeys) {
  const allowed = new Set(allowedKeys);
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      throw new Error("Invalid MemoryQR payload.");
    }
  }
}
