# MemoryQR Project Context

## Project

MemoryQR is a public open-source app concept by Chenghao Liu.

The goal is to build a small tool that lets people store personal memories in QR-code-friendly payloads. The current repository is intentionally an early placeholder: it presents the idea, provides a static preview, and defines a tiny tested payload contract for future QR generation.

## Current State

- GitHub repository: https://github.com/Liuchenghaoshiwo/MemoryQR
- Live preview: https://liuchenghaoshiwo.github.io/MemoryQR/
- Deployment: GitHub Pages through `.github/workflows/pages.yml`
- Web runtime: zero-dependency static HTML/CSS/JavaScript
- iOS runtime: SwiftUI app under `iOS/MemoryQR`
- Tests: Node built-in test runner plus Xcode XCTest target

## Important Files

- `index.html` - static app shell and public preview page
- `src/styles.css` - visual design and responsive layout
- `src/app.js` - browser-side demo behavior
- `src/memoryPayload.js` - memory payload create/parse helpers
- `src/encryptedMemoryPayload.js` - passphrase encrypted payload envelope helpers
- `test/memoryPayload.test.js` - payload contract tests
- `test/encryptedMemoryPayload.test.js` - encrypted payload contract tests
- `iOS/MemoryQR/MemoryQR.xcodeproj` - native iOS Xcode project
- `iOS/MemoryQR/MemoryQR/ContentView.swift` - SwiftUI memory entry, QR preview, and save flow
- `iOS/MemoryQR/MemoryQR/ScanView.swift` - camera scan, Photos import, result display, and scan errors
- `iOS/MemoryQR/MemoryQR/CameraScannerView.swift` - AVFoundation camera QR scanner wrapper
- `iOS/MemoryQR/MemoryQR/MemoryPayload.swift` - Swift payload create/parse helpers
- `iOS/MemoryQR/MemoryQR/EncryptedMemoryPayload.swift` - passphrase encryption envelope create/decrypt helpers
- `iOS/MemoryQR/MemoryQR/MemoryQRDecoder.swift` - scanned text to MemoryQR parser boundary
- `iOS/MemoryQR/MemoryQR/QRCodeGenerator.swift` - Core Image QR rendering helper
- `iOS/MemoryQR/MemoryQR/QRImageDecoder.swift` - still-image QR detector
- `iOS/MemoryQR/MemoryQRTests/MemoryPayloadTests.swift` - iOS payload and QR tests
- `iOS/MemoryQR/MemoryQRTests/EncryptedMemoryPayloadTests.swift` - iOS encrypted payload tests
- `iOS/MemoryQR/MemoryQRTests/MemoryQRDecoderTests.swift` - iOS scan parsing and image decode tests
- `README.md` - public-facing repository introduction
- `.github/workflows/pages.yml` - GitHub Pages deployment workflow

## Product Direction

The eventual app should let users:

1. Write a memory with a title, message, and optional metadata.
2. Encode that memory into a QR code.
3. Save, share, print, or download the QR code.
4. Scan a MemoryQR later and recover the original memory.
5. Eventually attach photos, audio, and video to memories through a secure attachment design.

Privacy matters. Prefer local-first behavior unless the user explicitly asks for accounts, cloud sync, or sharing services.

Media note: do not store large images, audio, or video directly inside QR codes. QR codes should carry a small encrypted envelope, content hashes, and authorized references to encrypted local bundles or backend/iCloud storage.

## Current Non-Goals

Do not pretend the app is complete. The current version does not yet include:

- file or image attachment support
- audio or video attachment support
- cloud storage
- login or user accounts
- real whitelist authorization

The iOS app now generates real QR images, can scan/parse plain MemoryQR JSON from the camera or Photos images, and can create/unlock passphrase-encrypted MemoryQR envelopes. Any security language must be precise: passphrase encryption exists, but authentication, whitelist checks, secure sharing, and account-based authorization are planned, not complete.

## Next Good Tasks

Recommended next implementation steps:

1. Choose an authentication and whitelist approach for authorized decoding.
2. Design secure attachment support for photos, audio, and video.
3. Add encrypted attachment reference tests around payload size, invalid payloads, and attachment references.
4. Review iOS encrypted create/scan UX on a real device.
5. Improve README with screenshots once the iOS flow is visually reviewed.

## Latest Session Notes

- Added native SwiftUI iOS MVP under `iOS/MemoryQR`.
- Added Core Image QR generation, Swift payload create/parse helpers, QR preview, and save-to-Photos flow.
- Added XCTest coverage for Swift payload behavior and QR generation.
- Updated README with Xcode open/build/test instructions.
- Verified `node --test test/*.test.js`.
- Verified `xcodebuild build -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/MemoryQR-xcode`.
- Verified `xcodebuild test -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /private/tmp/MemoryQR-xcode`.
- Build note: use `/private/tmp` for Xcode DerivedData because the repository lives in `Documents`, where File Provider/Finder metadata can make codesign reject simulator products.
- Still incomplete: authentication, login, whitelist authorization, encrypted payloads, secure decoding, and real app icon assets.
- Best next task: design and implement the secure encrypted payload plus authorized decode boundary before adding public sharing.

## 2026-05-10 Scan Session Notes

- Added camera QR scanning in the iOS app with AVFoundation.
- Added Photos QR image import and parsing.
- Added shared scan parsing boundaries in `MemoryQRDecoder.swift` and `QRImageDecoder.swift`.
- Added XCTest coverage for scanned text parsing, invalid scans, unsupported schemas, generated QR image decoding, and images without QR codes.
- Added Xcode ignore rules for user-specific workspace state.
- Updated docs with the future requirement for photos, audio, and video attachments.
- Verified `xcodebuild test -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /private/tmp/MemoryQR-xcode`.
- Still incomplete: encrypted payloads, login, whitelist authorization, secure decode, actual media attachment storage, and manual camera testing on a physical iPhone.
- Best next task: design encrypted payload and authorized decode before adding media attachment storage.

## 2026-05-12 Encrypted Payload Session Notes

- Added `memoryqr.encrypted.v1` passphrase encrypted envelope helpers in JavaScript and Swift.
- Added PBKDF2-HMAC-SHA256 key derivation and AES-256-GCM encryption/decryption for iOS payloads.
- Added iOS Create controls for passphrase-encrypted QR generation and Scan controls for unlocking encrypted MemoryQR scans.
- Added decoder routing so scans distinguish plain payloads from encrypted envelopes.
- Added Node and XCTest coverage for encrypted envelope metadata, correct passphrase decrypt, wrong passphrase rejection, malformed envelopes, and encrypted QR image round trips.
- Verified `node --test test/*.test.js`.
- Verified `xcodebuild test -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /private/tmp/MemoryQR-xcode`.
- Still incomplete: login, whitelist authorization, account-based authorized decode, cloud storage, secure sharing, actual media attachment storage, and manual camera testing on a physical iPhone.
- Best next task: design authorization/whitelist semantics and encrypted attachment references before adding media storage.

## Session Handoff Rule

Every future Codex session should start by reading this file. After finishing any meaningful change, update this file before the final response so the next session knows:

- what changed
- what was verified
- what is still incomplete
- the best next task

Keep this document concise. Move detailed implementation notes into `docs/` if they become too long.

## Development Notes

Use the existing lightweight static structure unless the requested feature clearly needs a framework. Keep the public repo clean and easy to understand for visitors who may want to star, fork, or learn from it.

Before claiming work is complete, run:

```bash
node --test test/*.test.js
```

For iOS changes, also run:

```bash
xcodebuild test -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /private/tmp/MemoryQR-xcode
```
