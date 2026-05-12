# Passphrase Encrypted Payload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add passphrase-encrypted MemoryQR payload creation and recovery while preserving the existing plain payload flow.

**Architecture:** Add a tested JavaScript encrypted payload contract and a matching iOS `EncryptedMemoryPayload` service. Route scanned QR strings through a decoder result that distinguishes plain memories from encrypted envelopes, then update SwiftUI create and scan screens to generate encrypted QR codes and unlock encrypted scans with a passphrase.

**Tech Stack:** Node built-in test runner, Node `crypto`, Swift 5, SwiftUI, CommonCrypto PBKDF2, CryptoKit AES-GCM, XCTest.

---

### Task 1: JavaScript Encrypted Payload Contract

**Files:**
- Create: `src/encryptedMemoryPayload.js`
- Create: `test/encryptedMemoryPayload.test.js`

- [x] **Step 1: Write failing Node tests**

Create `test/encryptedMemoryPayload.test.js`:

```js
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
  assert.notEqual(envelope.ciphertext.length, 0);
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
```

- [x] **Step 2: Verify Node tests fail for missing module**

Run: `node --test test/encryptedMemoryPayload.test.js`

Expected: FAIL with module not found for `src/encryptedMemoryPayload.js`.

- [x] **Step 3: Implement JS encrypted helper**

Create `src/encryptedMemoryPayload.js` with `createEncryptedMemoryPayload`, `parseEncryptedMemoryEnvelope`, and `decryptEncryptedMemoryPayload`. Use Node `crypto.webcrypto.subtle` for PBKDF2 and AES-GCM. Encode `ciphertext` as encrypted bytes plus tag in Web Crypto's returned AES-GCM output. Use base64url without padding and validate every envelope field.

- [x] **Step 4: Verify Node encrypted tests pass**

Run: `node --test test/encryptedMemoryPayload.test.js`

Expected: PASS, 5 tests.

### Task 2: iOS Encrypted Payload Service

**Files:**
- Create: `iOS/MemoryQR/MemoryQR/EncryptedMemoryPayload.swift`
- Create: `iOS/MemoryQR/MemoryQRTests/EncryptedMemoryPayloadTests.swift`
- Modify: `iOS/MemoryQR/MemoryQR.xcodeproj/project.pbxproj`

- [x] **Step 1: Write failing XCTest service tests**

Create `iOS/MemoryQR/MemoryQRTests/EncryptedMemoryPayloadTests.swift`:

```swift
import XCTest
@testable import MemoryQR

final class EncryptedMemoryPayloadTests: XCTestCase {
    private let salt = Data((1...16).map(UInt8.init))
    private let nonce = Data((21...32).map(UInt8.init))

    func testCreateEmitsEncryptedEnvelopeMetadata() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "  Train window  ",
            message: "  Rain moved sideways.  ",
            createdAt: "2026-05-12T08:00:00.000Z"
        )

        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "correct horse battery staple",
            createdAt: "2026-05-12T08:01:00.000Z",
            salt: salt,
            nonce: nonce,
            iterations: 1000
        )

        let envelope = try EncryptedMemoryPayload.inspect(envelopePayload)
        XCTAssertEqual(envelope.schema, "memoryqr.encrypted.v1")
        XCTAssertEqual(envelope.alg, "AES-256-GCM")
        XCTAssertEqual(envelope.kdf, "PBKDF2-HMAC-SHA256")
        XCTAssertEqual(envelope.iterations, 1000)
        XCTAssertEqual(envelope.salt, "AQIDBAUGBwgJCgsMDQ4PEA")
        XCTAssertEqual(envelope.nonce, "FRYXGBkaGxwdHh8g")
        XCTAssertEqual(envelope.createdAt, "2026-05-12T08:01:00.000Z")
        XCTAssertFalse(envelope.ciphertext.isEmpty)
    }

    func testDecryptRecoversMemoryWithCorrectPassphrase() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Garden",
            message: "Jasmine after rain.",
            createdAt: "2026-05-12T09:00:00.000Z"
        )
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "garden-passphrase",
            salt: salt,
            nonce: nonce,
            iterations: 1000
        )

        let memory = try EncryptedMemoryPayload.decrypt(envelopePayload, passphrase: "garden-passphrase")

        XCTAssertEqual(memory.schema, "memoryqr.memory.v1")
        XCTAssertEqual(memory.title, "Garden")
        XCTAssertEqual(memory.message, "Jasmine after rain.")
        XCTAssertEqual(memory.createdAt, "2026-05-12T09:00:00.000Z")
    }

    func testRejectsEmptyPassphrase() throws {
        let memoryPayload = try MemoryPayload.create(title: "A", message: "B")

        XCTAssertThrowsError(
            try EncryptedMemoryPayload.create(memoryPayload: memoryPayload, passphrase: "", salt: salt, nonce: nonce)
        ) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .emptyPassphrase)
        }
        XCTAssertThrowsError(try EncryptedMemoryPayload.decrypt("{}", passphrase: "   ")) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .emptyPassphrase)
        }
    }

    func testInspectRejectsMalformedEnvelope() {
        XCTAssertThrowsError(try EncryptedMemoryPayload.inspect("not json")) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .invalidEnvelope)
        }
    }

    func testDecryptRejectsWrongPassphrase() throws {
        let memoryPayload = try MemoryPayload.create(title: "Wrong key", message: "This should stay private.")
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "right-passphrase",
            salt: salt,
            nonce: nonce,
            iterations: 1000
        )

        XCTAssertThrowsError(try EncryptedMemoryPayload.decrypt(envelopePayload, passphrase: "wrong-passphrase")) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .decryptionFailed)
        }
    }
}
```

- [x] **Step 2: Add test file to Xcode project and verify RED**

Run:

```bash
xcodebuild test -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /private/tmp/MemoryQR-xcode
```

Expected: FAIL because `EncryptedMemoryPayload` does not exist.

- [x] **Step 3: Implement `EncryptedMemoryPayload.swift`**

Use `CryptoKit` for AES-GCM, `CommonCrypto` for PBKDF2, base64url helpers, and sorted JSON encoding. Expose:

```swift
enum EncryptedMemoryPayload {
    static let schema = "memoryqr.encrypted.v1"

    enum PayloadError: Error, Equatable {
        case emptyPassphrase
        case invalidEnvelope
        case unsupportedSchema
        case unsupportedAlgorithm
        case encryptionFailed
        case decryptionFailed
    }

    struct Envelope: Codable, Equatable {
        let schema: String
        let alg: String
        let kdf: String
        let iterations: Int
        let salt: String
        let nonce: String
        let ciphertext: String
        let createdAt: String
    }

    static func create(memoryPayload: String, passphrase: String, createdAt: String, salt: Data, nonce: Data, iterations: Int) throws -> String
    static func create(memoryPayload: String, passphrase: String) throws -> String
    static func inspect(_ payload: String) throws -> Envelope
    static func decrypt(_ envelopePayload: String, passphrase: String) throws -> MemoryPayload.Memory
}
```

- [x] **Step 4: Verify iOS service tests pass**

Run the same `xcodebuild test` command.

Expected: PASS for existing and encrypted payload tests.

### Task 3: Decoder Routing For Plain vs Encrypted Payloads

**Files:**
- Modify: `iOS/MemoryQR/MemoryQR/MemoryQRDecoder.swift`
- Modify: `iOS/MemoryQR/MemoryQRTests/MemoryQRDecoderTests.swift`

- [x] **Step 1: Write failing decoder routing tests**

Append tests that expect:

```swift
let plainResult = try MemoryQRDecoder.inspect(plainPayload)
XCTAssertEqual(plainResult, .plain(memory))

let encryptedResult = try MemoryQRDecoder.inspect(envelopePayload)
XCTAssertEqual(encryptedResult, .encrypted(envelope))
```

Also test `MemoryQRDecoder.decrypt(envelopePayload, passphrase:)` returns the memory and wrong passphrase maps to `.decryptionFailed`.

- [x] **Step 2: Verify decoder tests fail**

Run the same `xcodebuild test` command.

Expected: FAIL because `MemoryQRDecoder.inspect` and encrypted decrypt routing do not exist.

- [x] **Step 3: Implement decoder routing**

Add:

```swift
enum DecodeResult: Equatable {
    case plain(MemoryPayload.Memory)
    case encrypted(EncryptedMemoryPayload.Envelope)
}

case decryptionFailed

static func inspect(_ scannedText: String) throws -> DecodeResult
static func decrypt(_ envelopePayload: String, passphrase: String) throws -> MemoryPayload.Memory
```

Keep existing `decode(_:)` behavior for plain scans.

- [x] **Step 4: Verify decoder routing passes**

Run the same `xcodebuild test` command.

Expected: PASS.

### Task 4: iOS Create And Scan UI Integration

**Files:**
- Modify: `iOS/MemoryQR/MemoryQR/ContentView.swift`
- Modify: `iOS/MemoryQR/MemoryQR/ScanView.swift`
- Modify: `iOS/MemoryQR/MemoryQRTests/MemoryQRDecoderTests.swift`

- [x] **Step 1: Add QR round-trip test for encrypted envelope images**

Add a test that creates an encrypted envelope payload, generates a QR image with `QRCodeGenerator.makeImage`, decodes it with `QRImageDecoder.decode`, and checks that `EncryptedMemoryPayload.inspect(decodedPayload)` returns `memoryqr.encrypted.v1`.

- [x] **Step 2: Verify the QR round-trip test passes against service code**

Run the same `xcodebuild test` command.

Expected: PASS.

- [x] **Step 3: Update create UI**

In `ContentView`, add:

- `@State private var shouldEncrypt = false`
- `@State private var passphrase = ""`
- `@State private var confirmPassphrase = ""`

Add a toggle and secure fields in the editor section. In plain mode, keep immediate regeneration on title/message changes. In encrypted mode, generate only when the button is tapped. Reject empty or mismatched passphrases with visible status text. Use `EncryptedMemoryPayload.create(memoryPayload:passphrase:)` when encryption is enabled.

- [x] **Step 4: Update scan UI**

In `ScanView`, add locked encrypted state:

- store `lockedEnvelopePayload`
- store inspected `lockedEnvelope`
- store `unlockPassphrase`
- route `handleScannedText` through `MemoryQRDecoder.inspect`
- show passphrase field and unlock button for encrypted envelopes
- call `MemoryQRDecoder.decrypt` on unlock
- show generic decrypt failure for wrong passphrase or tampering

- [x] **Step 5: Verify UI code compiles**

Run the same `xcodebuild test` command.

Expected: PASS.

### Task 5: Documentation, Handoff, And Final Verification

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Update docs**

Update current status to mention passphrase-encrypted QR payload creation and recovery. Keep language precise that login, whitelist authorization, cloud storage, secure sharing, and media attachments remain incomplete.

- [ ] **Step 2: Update AGENTS session notes**

Add a concise `2026-05-12 Encrypted Payload Session Notes` section with changed files, verification commands, incomplete work, and best next task.

- [ ] **Step 3: Run all project verification**

Run:

```bash
node --test test/*.test.js
xcodebuild test -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /private/tmp/MemoryQR-xcode
```

Expected: both commands PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: only intended files changed.

- [ ] **Step 5: Commit implementation**

Commit message:

```bash
git commit -m "feat: add passphrase encrypted MemoryQR payloads"
```
