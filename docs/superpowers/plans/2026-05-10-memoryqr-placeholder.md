# MemoryQR Placeholder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a public-ready static placeholder app and repository shell for MemoryQR.

**Architecture:** Use a zero-dependency static site. Keep the future QR payload contract in a small tested module so the placeholder has real code without pretending the full app exists.

**Tech Stack:** HTML, CSS, browser JavaScript modules, Node built-in test runner, GitHub Pages.

---

### Task 1: Memory Payload Contract

**Files:**
- Create: `test/memoryPayload.test.js`
- Create: `src/memoryPayload.js`

- [x] **Step 1: Write failing tests**

```js
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
```

- [x] **Step 2: Run test and verify it fails**

Run: `node --test test/memoryPayload.test.js`

- [ ] **Step 3: Implement the module**

Create `src/memoryPayload.js` with `createMemoryPayload` and `parseMemoryPayload`.

- [ ] **Step 4: Run test and verify it passes**

Run: `node --test test/memoryPayload.test.js`

### Task 2: Static App Shell

**Files:**
- Create: `index.html`
- Create: `src/app.js`
- Create: `src/styles.css`

- [ ] Build a single-page public preview that explains MemoryQR and shows a payload preview.
- [ ] Verify it opens through a local static server.

### Task 3: Public Repository Packaging

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `.github/workflows/pages.yml`
- Create: `package.json`

- [ ] Document project status, run instructions, roadmap, and license.
- [ ] Add GitHub Pages deployment workflow.
- [ ] Commit and push to a public GitHub repository named `MemoryQR`.
