import { parseMemoryPayload } from "./memoryPayload.js";

const ENCRYPTED_SCHEMA = "memoryqr.encrypted.v1";
const ALGORITHM = "AES-256-GCM";
const KDF = "PBKDF2-HMAC-SHA256";
const AUTHORIZATION_MODE = "local-passphrase";
const AUTHORIZATION_POLICY_PASSPHRASE_ONLY = "passphrase-only";
const AUTHORIZATION_POLICY_LOCAL_READER_ALLOWLIST = "local-reader-allowlist";
const ATTACHMENT_STORAGE_KIND_LOCAL_ENCRYPTED_BUNDLE = "local-encrypted-bundle";
const DEFAULT_ITERATIONS = 210000;
const SALT_BYTES = 16;
const NONCE_BYTES = 12;
const GCM_TAG_BYTES = 16;
const MAX_ATTACHMENTS = 8;
const MAX_ATTACHMENT_REFERENCES_BYTES = 2048;
const MAX_ENCRYPTED_BUNDLE_REF_LENGTH = 512;
const READER_ID_PATTERN = /^[a-z0-9][a-z0-9._:-]{0,63}$/u;
const ENCRYPTED_BUNDLE_REF_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:/?#@!$&'()*+,;=%~-]{0,511}$/u;
const ATTACHMENT_TYPES = new Set(["image", "audio", "video"]);
const SHA256_PATTERN = /^[a-f0-9]{64}$/u;

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

export async function createEncryptedMemoryPayload({
  memoryPayload,
  passphrase,
  createdAt = new Date().toISOString(),
  salt = randomBytes(SALT_BYTES),
  nonce = randomBytes(NONCE_BYTES),
  iterations = DEFAULT_ITERATIONS,
  authorization,
  attachments = [],
}) {
  assertPassphrase(passphrase);
  parseMemoryPayload(memoryPayload);

  const saltBytes = normalizeBytes(salt);
  const nonceBytes = normalizeBytes(nonce);
  if (saltBytes.byteLength !== SALT_BYTES || nonceBytes.byteLength !== NONCE_BYTES) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }
  if (!Number.isInteger(iterations) || iterations <= 0) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }

  const envelopeMetadata = {
    schema: ENCRYPTED_SCHEMA,
    alg: ALGORITHM,
    kdf: KDF,
    iterations,
    salt: bytesToBase64Url(saltBytes),
    nonce: bytesToBase64Url(nonceBytes),
    createdAt: normalizeText(createdAt, new Date().toISOString()),
    authorization: normalizeAuthorization(authorization),
    attachments: normalizeAttachmentReferences(attachments),
  };
  const key = await deriveKey(passphrase, saltBytes, iterations, ["encrypt"]);
  const ciphertext = await webCrypto().subtle.encrypt(
    {
      name: "AES-GCM",
      iv: nonceBytes,
      additionalData: authenticatedData(envelopeMetadata),
      tagLength: 128,
    },
    key,
    textEncoder.encode(memoryPayload),
  );

  return JSON.stringify({
    ...envelopeMetadata,
    ciphertext: bytesToBase64Url(new Uint8Array(ciphertext)),
  });
}

export function parseEncryptedMemoryEnvelope(payload) {
  let envelope;

  try {
    envelope = JSON.parse(payload);
  } catch {
    throw new Error("Expected valid encrypted MemoryQR JSON.");
  }

  if (!envelope || envelope.schema !== ENCRYPTED_SCHEMA) {
    throw new Error("Unsupported encrypted MemoryQR schema.");
  }

  const hasAuthorization = Object.prototype.hasOwnProperty.call(envelope, "authorization");
  const hasAttachments = Object.prototype.hasOwnProperty.call(envelope, "attachments");
  const authorization = normalizeAuthorization(envelope.authorization);
  const attachments = normalizeAttachmentReferences(envelope.attachments);

  if (
    envelope.alg !== ALGORITHM ||
    envelope.kdf !== KDF ||
    !Number.isInteger(envelope.iterations) ||
    envelope.iterations <= 0 ||
    !isNonEmptyString(envelope.createdAt)
  ) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }

  const salt = decodeBase64UrlField(envelope.salt);
  const nonce = decodeBase64UrlField(envelope.nonce);
  const ciphertext = decodeBase64UrlField(envelope.ciphertext);
  if (
    salt.byteLength !== SALT_BYTES ||
    nonce.byteLength !== NONCE_BYTES ||
    ciphertext.byteLength <= GCM_TAG_BYTES
  ) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }

  const parsedEnvelope = {
    schema: envelope.schema,
    alg: envelope.alg,
    kdf: envelope.kdf,
    iterations: envelope.iterations,
    salt: envelope.salt,
    nonce: envelope.nonce,
    ciphertext: envelope.ciphertext,
    createdAt: envelope.createdAt,
    authorization,
    attachments,
  };

  Object.defineProperty(parsedEnvelope, "usesLegacyAuthenticatedData", {
    value: !hasAuthorization,
    enumerable: false,
  });
  Object.defineProperty(parsedEnvelope, "usesLegacyAttachmentAuthenticatedData", {
    value: !hasAttachments,
    enumerable: false,
  });
  return parsedEnvelope;
}

export async function decryptEncryptedMemoryPayload(
  envelopePayload,
  passphrase,
  authorizationContext = {},
) {
  assertPassphrase(passphrase);

  const envelope = parseEncryptedMemoryEnvelope(envelopePayload);
  assertAuthorizedToDecode(envelope.authorization, authorizationContext);
  const salt = base64UrlToBytes(envelope.salt);
  const nonce = base64UrlToBytes(envelope.nonce);
  const ciphertext = base64UrlToBytes(envelope.ciphertext);
  const key = await deriveKey(passphrase, salt, envelope.iterations, ["decrypt"]);

  let plaintext;
  try {
    plaintext = await webCrypto().subtle.decrypt(
      {
        name: "AES-GCM",
        iv: nonce,
        additionalData: authenticatedData(envelope),
        tagLength: 128,
      },
      key,
      ciphertext,
    );
  } catch {
    throw new Error("Could not decrypt encrypted MemoryQR payload.");
  }

  try {
    return parseMemoryPayload(textDecoder.decode(plaintext));
  } catch {
    throw new Error("Could not decrypt encrypted MemoryQR payload.");
  }
}

async function deriveKey(passphrase, salt, iterations, keyUsages) {
  const keyMaterial = await webCrypto().subtle.importKey(
    "raw",
    textEncoder.encode(passphrase),
    "PBKDF2",
    false,
    ["deriveKey"],
  );

  return webCrypto().subtle.deriveKey(
    {
      name: "PBKDF2",
      salt,
      iterations,
      hash: "SHA-256",
    },
    keyMaterial,
    { name: "AES-GCM", length: 256 },
    false,
    keyUsages,
  );
}

function authenticatedData(envelope) {
  const metadata = {
    schema: envelope.schema,
    alg: envelope.alg,
    kdf: envelope.kdf,
    iterations: envelope.iterations,
    salt: envelope.salt,
    nonce: envelope.nonce,
    createdAt: envelope.createdAt,
  };

  if (!envelope.usesLegacyAuthenticatedData) {
    metadata.authorization = envelope.authorization;
  }
  if (!envelope.usesLegacyAttachmentAuthenticatedData) {
    metadata.attachments = envelope.attachments ?? [];
  }

  return textEncoder.encode(JSON.stringify(metadata));
}

function assertPassphrase(passphrase) {
  if (normalizeText(passphrase, "").length === 0) {
    throw new Error("Passphrase is required.");
  }
}

function normalizeText(value, fallback) {
  const normalized = String(value ?? "").trim();
  return normalized.length > 0 ? normalized : fallback;
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function normalizeAuthorization(value) {
  if (value == null) {
    return passphraseOnlyAuthorization();
  }
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }

  const mode = normalizeText(value.mode, AUTHORIZATION_MODE);
  if (mode !== AUTHORIZATION_MODE) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }

  const allowedReaderIds = normalizeAllowedReaderIds(value.allowedReaderIds);
  const policy = normalizeText(
    value.policy,
    allowedReaderIds.length > 0
      ? AUTHORIZATION_POLICY_LOCAL_READER_ALLOWLIST
      : AUTHORIZATION_POLICY_PASSPHRASE_ONLY,
  );

  if (policy === AUTHORIZATION_POLICY_PASSPHRASE_ONLY) {
    if (allowedReaderIds.length > 0) {
      throw new Error("Invalid encrypted MemoryQR envelope.");
    }
    return passphraseOnlyAuthorization();
  }

  if (policy === AUTHORIZATION_POLICY_LOCAL_READER_ALLOWLIST) {
    if (allowedReaderIds.length === 0) {
      throw new Error("Invalid encrypted MemoryQR envelope.");
    }
    return {
      mode: AUTHORIZATION_MODE,
      policy,
      allowedReaderIds,
    };
  }

  throw new Error("Invalid encrypted MemoryQR envelope.");
}

function passphraseOnlyAuthorization() {
  return {
    mode: AUTHORIZATION_MODE,
    policy: AUTHORIZATION_POLICY_PASSPHRASE_ONLY,
    allowedReaderIds: [],
  };
}

function normalizeAllowedReaderIds(value) {
  if (value == null) {
    return [];
  }
  if (!Array.isArray(value)) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
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
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }

  const seen = new Set();
  const attachments = value.map((attachment) => {
    const normalized = normalizeAttachmentReference(attachment);
    if (seen.has(normalized.id)) {
      throw new Error("Invalid encrypted MemoryQR envelope.");
    }
    seen.add(normalized.id);
    return normalized;
  });

  if (textEncoder.encode(JSON.stringify(attachments)).byteLength > MAX_ATTACHMENT_REFERENCES_BYTES) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }
  return attachments;
}

function normalizeAttachmentReference(value) {
  if (typeof value !== "object" || value == null || Array.isArray(value)) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }
  assertAllowedKeys(value, ["id", "type", "size", "sha256", "storage"]);

  return {
    id: normalizeAttachmentId(value.id),
    type: normalizeAttachmentType(value.type),
    size: normalizeAttachmentSize(value.size),
    sha256: normalizeSha256(value.sha256),
    storage: normalizeAttachmentStorage(value.storage),
  };
}

function normalizeAttachmentStorage(value) {
  if (typeof value !== "object" || value == null || Array.isArray(value)) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }
  assertAllowedKeys(value, ["kind", "encryptedBundleRef"]);

  const kind = normalizeText(value.kind, "");
  if (kind !== ATTACHMENT_STORAGE_KIND_LOCAL_ENCRYPTED_BUNDLE) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }

  return {
    kind,
    encryptedBundleRef: normalizeEncryptedBundleRef(value.encryptedBundleRef),
  };
}

function normalizeAttachmentId(value) {
  return normalizeReaderId(value);
}

function normalizeAttachmentType(value) {
  const normalized = normalizeText(value, "").toLowerCase();
  if (!ATTACHMENT_TYPES.has(normalized)) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }
  return normalized;
}

function normalizeAttachmentSize(value) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }
  return value;
}

function normalizeSha256(value) {
  const normalized = normalizeText(value, "").toLowerCase();
  if (!SHA256_PATTERN.test(normalized)) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
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
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }
  return normalized;
}

function assertAllowedKeys(value, allowedKeys) {
  const allowed = new Set(allowedKeys);
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      throw new Error("Invalid encrypted MemoryQR envelope.");
    }
  }
}

function assertAuthorizedToDecode(authorization, authorizationContext) {
  if (authorization.policy === AUTHORIZATION_POLICY_PASSPHRASE_ONLY) {
    return;
  }

  const localReaderId = normalizeReaderIdForContext(authorizationContext.localReaderId);
  if (!authorization.allowedReaderIds.includes(localReaderId)) {
    throw new Error("This reader is not authorized to decode this MemoryQR.");
  }
}

function normalizeReaderIdForContext(value) {
  const normalized = String(value ?? "").trim().toLowerCase();
  return READER_ID_PATTERN.test(normalized) ? normalized : "";
}

function normalizeReaderId(value) {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (!READER_ID_PATTERN.test(normalized)) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }
  return normalized;
}

function normalizeBytes(value) {
  if (value instanceof Uint8Array) {
    return value;
  }
  if (value instanceof ArrayBuffer) {
    return new Uint8Array(value);
  }
  if (ArrayBuffer.isView(value)) {
    return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
  }
  throw new Error("Invalid encrypted MemoryQR envelope.");
}

function randomBytes(length) {
  const bytes = new Uint8Array(length);
  webCrypto().getRandomValues(bytes);
  return bytes;
}

function webCrypto() {
  if (!globalThis.crypto?.subtle || !globalThis.crypto?.getRandomValues) {
    throw new Error("Web Crypto is required for encrypted MemoryQR payloads.");
  }
  return globalThis.crypto;
}

function decodeBase64UrlField(value) {
  if (!isNonEmptyString(value) || !/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }

  const bytes = base64UrlToBytes(value);
  if (bytesToBase64Url(bytes) !== value) {
    throw new Error("Invalid encrypted MemoryQR envelope.");
  }
  return bytes;
}

function bytesToBase64Url(bytes) {
  const normalized = normalizeBytes(bytes);
  let binary = "";
  for (const byte of normalized) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/u, "");
}

function base64UrlToBytes(value) {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}
