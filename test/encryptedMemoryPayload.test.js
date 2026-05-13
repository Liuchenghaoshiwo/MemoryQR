import test from "node:test";
import assert from "node:assert/strict";

import { createMemoryPayload } from "../src/memoryPayload.js";
import {
  createEncryptedMemoryPayload,
  decryptEncryptedMemoryPayload,
  parseEncryptedMemoryEnvelope,
} from "../src/encryptedMemoryPayload.js";

const salt = Uint8Array.from(Array.from({ length: 16 }, (_, index) => index + 1));
const nonce = Uint8Array.from(Array.from({ length: 12 }, (_, index) => index + 21));

test("createEncryptedMemoryPayload emits stable encrypted envelope metadata", async () => {
  const memoryPayload = createMemoryPayload({
    title: "  Train window  ",
    message: "  Rain moved sideways.  ",
    createdAt: "2026-05-12T08:00:00.000Z",
  });

  const envelopePayload = await createEncryptedMemoryPayload({
    memoryPayload,
    passphrase: "correct horse battery staple",
    createdAt: "2026-05-12T08:01:00.000Z",
    salt,
    nonce,
    iterations: 1000,
  });

  const envelope = parseEncryptedMemoryEnvelope(envelopePayload);
  assert.equal(envelope.schema, "memoryqr.encrypted.v1");
  assert.equal(envelope.alg, "AES-256-GCM");
  assert.equal(envelope.kdf, "PBKDF2-HMAC-SHA256");
  assert.equal(envelope.iterations, 1000);
  assert.equal(envelope.salt, "AQIDBAUGBwgJCgsMDQ4PEA");
  assert.equal(envelope.nonce, "FRYXGBkaGxwdHh8g");
  assert.equal(envelope.createdAt, "2026-05-12T08:01:00.000Z");
  assert.deepEqual(envelope.authorization, {
    mode: "local-passphrase",
    policy: "passphrase-only",
    allowedReaderIds: [],
  });
  assert.notEqual(envelope.ciphertext.length, 0);
});

test("createEncryptedMemoryPayload can declare a local reader allowlist", async () => {
  const memoryPayload = createMemoryPayload({
    title: "Family archive",
    message: "Only named local readers should unlock this QR.",
    createdAt: "2026-05-13T08:00:00.000Z",
  });

  const envelopePayload = await createEncryptedMemoryPayload({
    memoryPayload,
    passphrase: "family-passphrase",
    createdAt: "2026-05-13T08:01:00.000Z",
    salt,
    nonce,
    iterations: 1000,
    authorization: {
      allowedReaderIds: [" Family.Phone ", "family.phone", "guest-1"],
    },
  });

  const envelope = parseEncryptedMemoryEnvelope(envelopePayload);
  assert.deepEqual(envelope.authorization, {
    mode: "local-passphrase",
    policy: "local-reader-allowlist",
    allowedReaderIds: ["family.phone", "guest-1"],
  });
});

test("decryptEncryptedMemoryPayload recovers memory with correct passphrase", async () => {
  const memoryPayload = createMemoryPayload({
    title: "Garden",
    message: "Jasmine after rain.",
    createdAt: "2026-05-12T09:00:00.000Z",
  });

  const envelopePayload = await createEncryptedMemoryPayload({
    memoryPayload,
    passphrase: "garden-passphrase",
    salt,
    nonce,
    iterations: 1000,
  });

  const memory = await decryptEncryptedMemoryPayload(envelopePayload, "garden-passphrase");

  assert.deepEqual(memory, {
    schema: "memoryqr.memory.v1",
    title: "Garden",
    message: "Jasmine after rain.",
    createdAt: "2026-05-12T09:00:00.000Z",
  });
});

test("decryptEncryptedMemoryPayload rejects local readers outside the allowlist", async () => {
  const memoryPayload = createMemoryPayload({
    title: "Private table",
    message: "The reader ID must match before passphrase unlock.",
  });
  const envelopePayload = await createEncryptedMemoryPayload({
    memoryPayload,
    passphrase: "shared-passphrase",
    salt,
    nonce,
    iterations: 1000,
    authorization: {
      allowedReaderIds: ["family-phone"],
    },
  });

  await assert.rejects(
    () =>
      decryptEncryptedMemoryPayload(envelopePayload, "shared-passphrase", {
        localReaderId: "visitor-phone",
      }),
    /not authorized/,
  );
});

test("decryptEncryptedMemoryPayload accepts local readers inside the allowlist", async () => {
  const memoryPayload = createMemoryPayload({
    title: "Kitchen note",
    message: "The local reader ID matched.",
    createdAt: "2026-05-13T09:00:00.000Z",
  });
  const envelopePayload = await createEncryptedMemoryPayload({
    memoryPayload,
    passphrase: "kitchen-passphrase",
    salt,
    nonce,
    iterations: 1000,
    authorization: {
      allowedReaderIds: ["kitchen-ipad"],
    },
  });

  const memory = await decryptEncryptedMemoryPayload(envelopePayload, "kitchen-passphrase", {
    localReaderId: " Kitchen-iPad ",
  });

  assert.equal(memory.title, "Kitchen note");
  assert.equal(memory.message, "The local reader ID matched.");
});

test("encrypted payload helpers reject empty passphrases", async () => {
  const memoryPayload = createMemoryPayload({ title: "A", message: "B" });

  await assert.rejects(
    () => createEncryptedMemoryPayload({ memoryPayload, passphrase: "", salt, nonce }),
    /Passphrase is required/,
  );
  await assert.rejects(
    () => decryptEncryptedMemoryPayload("{}", "   "),
    /Passphrase is required/,
  );
});

test("parseEncryptedMemoryEnvelope rejects malformed envelopes", () => {
  assert.throws(() => parseEncryptedMemoryEnvelope("not json"), /valid encrypted MemoryQR JSON/);
  assert.throws(
    () => parseEncryptedMemoryEnvelope(JSON.stringify({ schema: "memoryqr.memory.v1" })),
    /Unsupported encrypted MemoryQR schema/,
  );
  assert.throws(
    () =>
      parseEncryptedMemoryEnvelope(
        JSON.stringify({
          schema: "memoryqr.encrypted.v1",
          alg: "AES-256-GCM",
          kdf: "PBKDF2-HMAC-SHA256",
          iterations: 1000,
          salt: "not_base64url!",
          nonce: "FRYXGBkaGxwdHh8g",
          ciphertext: "abc",
          createdAt: "2026-05-12T08:01:00.000Z",
        }),
      ),
    /Invalid encrypted MemoryQR envelope/,
  );
  assert.throws(
    () =>
      parseEncryptedMemoryEnvelope(
        JSON.stringify({
          schema: "memoryqr.encrypted.v1",
          alg: "AES-256-GCM",
          kdf: "PBKDF2-HMAC-SHA256",
          iterations: 1000,
          salt: "AQIDBAUGBwgJCgsMDQ4PEA",
          nonce: "FRYXGBkaGxwdHh8g",
          ciphertext: "abcdefghijklmnopqrstuvwxyz",
          createdAt: "2026-05-12T08:01:00.000Z",
          authorization: {
            mode: "account-whitelist",
            policy: "local-reader-allowlist",
            allowedReaderIds: ["family-phone"],
          },
        }),
      ),
    /Invalid encrypted MemoryQR envelope/,
  );
});

test("decryptEncryptedMemoryPayload rejects wrong passphrases", async () => {
  const memoryPayload = createMemoryPayload({
    title: "Wrong key",
    message: "This should stay private.",
  });
  const envelopePayload = await createEncryptedMemoryPayload({
    memoryPayload,
    passphrase: "right-passphrase",
    salt,
    nonce,
    iterations: 1000,
  });

  await assert.rejects(
    () => decryptEncryptedMemoryPayload(envelopePayload, "wrong-passphrase"),
    /Could not decrypt encrypted MemoryQR payload/,
  );
});
