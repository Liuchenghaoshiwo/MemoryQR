# MemoryQR Passphrase Encrypted Payload Design

## Goal

Add a real local-first encrypted MemoryQR payload path. A user can create a memory QR protected by a passphrase, scan it later, enter the same passphrase, and recover the original memory. This phase does not add accounts, cloud sync, server authorization, whitelist checks, or media attachments.

## Scope

This phase adds one new payload format alongside the existing plain payload:

- Existing plain payload: `memoryqr.memory.v1`
- New encrypted envelope: `memoryqr.encrypted.v1`

Plain QR generation and plain scan parsing remain supported for compatibility. Encrypted QR generation is opt-in from the iOS create flow. Encrypted scan recovery requires a passphrase before the memory title, message, or created time are displayed.

The static JavaScript contract gains tested encrypted envelope helpers so the repository has one understandable payload contract across web and iOS. The static preview keeps its current plain demo UI in this phase.

## Envelope Format

The QR stores a compact JSON object:

```json
{
  "schema": "memoryqr.encrypted.v1",
  "alg": "AES-256-GCM",
  "kdf": "PBKDF2-HMAC-SHA256",
  "iterations": 210000,
  "salt": "<base64url 16 bytes>",
  "nonce": "<base64url 12 bytes>",
  "ciphertext": "<base64url AES-GCM ciphertext followed by 16-byte GCM tag>",
  "createdAt": "2026-05-12T00:00:00.000Z"
}
```

After decryption, the ciphertext bytes decode to the existing `MemoryPayload.Memory` JSON, not a new memory schema. The `ciphertext` field stores AES-GCM ciphertext followed by the 16-byte authentication tag so the envelope stays compact while remaining portable across Swift, browser, and Node implementations. Large attachments are not embedded in this envelope. Future media support should put encrypted references, content hashes, and bundle metadata in a small plaintext-before-encryption memory extension or in a later encrypted payload version.

All binary fields use base64url without padding. The implementation rejects missing fields, unsupported algorithms, unsupported KDF names, non-positive iteration counts, malformed base64url, empty ciphertext, empty passphrases, and decryption authentication failures.

## Cryptography

iOS uses `CommonCrypto` PBKDF2-HMAC-SHA256 to derive a 256-bit key from the user passphrase and random salt, then `CryptoKit` AES-GCM to encrypt and authenticate the memory JSON. JavaScript uses Web Crypto in the browser and Node's `crypto` module in tests.

Each encryption uses:

- a fresh 16-byte random salt
- a fresh 12-byte random AES-GCM nonce
- PBKDF2-HMAC-SHA256 with 210,000 iterations
- AES-256-GCM with the envelope metadata bound as authenticated data

This is passphrase-based encryption, not identity-based authorization. The app must describe it as "encrypted with a passphrase" and must not claim whitelist authorization, account authentication, or secure sharing is complete.

## iOS Architecture

Add a focused service, `EncryptedMemoryPayload.swift`, with:

- `Envelope`: Codable and Equatable representation of `memoryqr.encrypted.v1`
- `create(memoryPayload:passphrase:createdAt:) throws -> String`
- `decrypt(_ envelopePayload:passphrase:) throws -> MemoryPayload.Memory`
- `inspect(_ payload:) throws -> Envelope` for validating envelope shape without decrypting

Keep `MemoryPayload.swift` unchanged except where tests reveal small reusable helpers are justified.

Update `MemoryQRDecoder.swift` to route scanned text without forcing every QR into `MemoryPayload.parse(...)`. A new inspection API should return either:

- plain memory already decoded
- encrypted envelope metadata that still needs a passphrase

The existing plain `decode(_:) -> MemoryPayload.Memory` can remain for compatibility with current tests.

## iOS Create Flow

`ContentView` adds an "Encrypt with passphrase" toggle and secure passphrase fields. Plain mode keeps the current immediate plain payload behavior. Encrypted mode should avoid regenerating on every keystroke because each encrypted QR intentionally uses new random salt and nonce. The `Generate QR` button becomes the explicit encrypted generation action, and encrypted generation is disabled or fails clearly when the passphrase is empty.

The encrypted QR preview still uses `QRCodeGenerator.makeImage(from:)`; only the payload string changes. The payload display may show the encrypted envelope JSON, but it must not display plaintext memory fields as a security feature. The visible note should say the QR is passphrase-encrypted and that whitelist authorization is still future work.

## iOS Scan Flow

`ScanView` keeps the current plain path. When scanning or importing a `memoryqr.encrypted.v1` envelope, it enters a locked state:

- no recovered memory is shown yet
- raw plaintext is not available because the QR only contains ciphertext
- the user sees a secure passphrase field and an unlock button
- correct passphrase decrypts and displays the recovered memory
- wrong passphrase or tampered envelope shows a generic "Could not decrypt this MemoryQR with that passphrase." message

The UI should not reveal whether the passphrase was wrong or the ciphertext was tampered with. Unsupported schemas still show the existing unsupported-schema path.

## JavaScript Contract

Add `src/encryptedMemoryPayload.js` and `test/encryptedMemoryPayload.test.js`. The tests should exercise deterministic behavior by injecting salt and nonce where needed, while production code uses secure randomness.

The JavaScript helpers should cover:

- create encrypted envelope from a valid plain memory payload
- parse and validate encrypted envelope metadata
- decrypt with the correct passphrase
- reject empty passphrases
- reject malformed envelopes
- reject wrong passphrases

Browser UI encryption is optional for this phase. The contract tests are required so the public repo documents the payload format independent of the iOS app.

## Error Handling

Use precise errors internally and conservative messages in UI:

- Empty passphrase: shown during create/unlock as a user-correctable validation error
- Unsupported encrypted algorithm or KDF: unsupported schema/format message
- Malformed envelope JSON or base64url: invalid MemoryQR message
- Authentication failure: generic decrypt failure
- Plain payload parsing: unchanged current behavior

## Testing

Add tests before implementation:

- Node tests for encrypted envelope creation, validation, round-trip decryption, empty passphrase rejection, malformed envelope rejection, and wrong passphrase rejection
- XCTest coverage for the same iOS service behavior
- XCTest coverage that `MemoryQRDecoder` can distinguish plain memory payloads from encrypted envelopes
- XCTest coverage that generated encrypted QR images can be decoded back to the envelope string with `QRImageDecoder`

Existing tests must continue to pass:

```bash
node --test test/*.test.js
xcodebuild test -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /private/tmp/MemoryQR-xcode
```

## Documentation And Handoff

Update `README.md` and `AGENTS.md` after implementation. Documentation must say the app supports passphrase-encrypted MemoryQR payloads, while login, whitelist authorization, cloud storage, secure sharing, and media attachment storage remain incomplete.
