import test from "node:test";
import assert from "node:assert/strict";

import { createMemoryPayload, parseMemoryPayload } from "../src/memoryPayload.js";

test("createMemoryPayload trims text and emits stable schema", () => {
  const payload = createMemoryPayload({
    title: "  Beach day  ",
    message: "  The afternoon light felt golden.  ",
    createdAt: "2026-05-10T09:00:00.000Z",
  });

  assert.deepEqual(JSON.parse(payload), {
    schema: "memoryqr.memory.v1",
    title: "Beach day",
    message: "The afternoon light felt golden.",
    createdAt: "2026-05-10T09:00:00.000Z",
  });
});

test("parseMemoryPayload returns structured memory data", () => {
  const memory = parseMemoryPayload(
    JSON.stringify({
      schema: "memoryqr.memory.v1",
      title: "First concert",
      message: "A song I never wanted to forget.",
      createdAt: "2026-05-10T10:00:00.000Z",
    }),
  );

  assert.deepEqual(memory, {
    schema: "memoryqr.memory.v1",
    title: "First concert",
    message: "A song I never wanted to forget.",
    createdAt: "2026-05-10T10:00:00.000Z",
  });
});

test("createMemoryPayload can declare a local reader allowlist without encryption", () => {
  const payload = createMemoryPayload({
    title: "Family note",
    message: "Visible through the local reader gate.",
    createdAt: "2026-05-14T11:00:00.000Z",
    authorization: {
      mode: "local-reader",
      policy: "local-reader-allowlist",
      allowedReaderIds: [" Family.Phone ", "family.phone", "guest-1"],
    },
  });

  assert.deepEqual(JSON.parse(payload), {
    schema: "memoryqr.memory.v1",
    title: "Family note",
    message: "Visible through the local reader gate.",
    createdAt: "2026-05-14T11:00:00.000Z",
    authorization: {
      mode: "local-reader",
      policy: "local-reader-allowlist",
      allowedReaderIds: ["family.phone", "guest-1"],
    },
  });
});

test("createMemoryPayload can declare attachment references without encryption", () => {
  const attachment = {
    id: " Cover.Photo ",
    type: "image",
    size: 245760,
    sha256: "A".repeat(64),
    storage: {
      kind: "local-encrypted-bundle",
      encryptedBundleRef: "memoryqr-local-bundle://anniversary-2026/cover-photo",
    },
  };

  const payload = createMemoryPayload({
    title: "Anniversary album",
    message: "A plain QR can point to a local encrypted bundle.",
    createdAt: "2026-05-14T11:30:00.000Z",
    attachments: [attachment],
  });

  const memory = parseMemoryPayload(payload);

  assert.deepEqual(memory.attachments, [
    {
      id: "cover.photo",
      type: "image",
      size: 245760,
      sha256: "a".repeat(64),
      storage: {
        kind: "local-encrypted-bundle",
        encryptedBundleRef: "memoryqr-local-bundle://anniversary-2026/cover-photo",
      },
    },
  ]);
});

test("parseMemoryPayload rejects invalid JSON", () => {
  assert.throws(() => parseMemoryPayload("not json"), /valid MemoryQR JSON/);
});

test("parseMemoryPayload rejects unsupported schemas", () => {
  assert.throws(
    () => parseMemoryPayload(JSON.stringify({ schema: "memoryqr.memory.v0" })),
    /Unsupported MemoryQR schema/,
  );
});
