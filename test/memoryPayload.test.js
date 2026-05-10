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

test("parseMemoryPayload rejects invalid JSON", () => {
  assert.throws(() => parseMemoryPayload("not json"), /valid MemoryQR JSON/);
});

test("parseMemoryPayload rejects unsupported schemas", () => {
  assert.throws(
    () => parseMemoryPayload(JSON.stringify({ schema: "memoryqr.memory.v0" })),
    /Unsupported MemoryQR schema/,
  );
});
