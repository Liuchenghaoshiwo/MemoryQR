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
- `test/memoryPayload.test.js` - payload contract tests
- `iOS/MemoryQR/MemoryQR.xcodeproj` - native iOS Xcode project
- `iOS/MemoryQR/MemoryQR/ContentView.swift` - SwiftUI memory entry, QR preview, and save flow
- `iOS/MemoryQR/MemoryQR/MemoryPayload.swift` - Swift payload create/parse helpers
- `iOS/MemoryQR/MemoryQR/QRCodeGenerator.swift` - Core Image QR rendering helper
- `iOS/MemoryQR/MemoryQRTests/MemoryPayloadTests.swift` - iOS payload and QR tests
- `README.md` - public-facing repository introduction
- `.github/workflows/pages.yml` - GitHub Pages deployment workflow

## Product Direction

The eventual app should let users:

1. Write a memory with a title, message, and optional metadata.
2. Encode that memory into a QR code.
3. Save, share, print, or download the QR code.
4. Scan a MemoryQR later and recover the original memory.

Privacy matters. Prefer local-first behavior unless the user explicitly asks for accounts, cloud sync, or sharing services.

## Current Non-Goals

Do not pretend the app is complete. The current version does not yet include:

- encrypted QR payloads
- QR scanning
- file or image attachment support
- cloud storage
- login or user accounts
- real whitelist authorization

The iOS app now generates real QR images, but the payload is still plain MemoryQR JSON. Any security language must be precise: authentication, whitelist checks, secure decoding, and encryption are planned, not complete.

## Next Good Tasks

Recommended next implementation steps:

1. Design the secure payload format for encrypted MemoryQR QR codes.
2. Choose an authentication and whitelist approach for authorized decoding.
3. Add QR scanning support in the iOS app with AVFoundation.
4. Add encrypted encode/decode tests around payload size, empty fields, and invalid payloads.
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
- Still incomplete: authentication, login, whitelist authorization, encrypted payloads, secure decoding, QR scanning, and real app icon assets.
- Best next task: design and implement the secure encrypted payload plus authorized decode boundary before adding public sharing.

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
