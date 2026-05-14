# MemoryQR

MemoryQR is an early prototype for a small tool that stores memories inside QR-friendly payloads.

This repository now contains the original static public preview plus a native SwiftUI iOS MVP that can generate plain or passphrase-encrypted MemoryQR payloads as QR images.

## Preview

The app is designed to run as a static site and deploy through GitHub Pages.

## Current Status

- Static landing page for the project
- Memory payload preview demo
- Tested plain and passphrase-encrypted payload helpers
- GitHub Pages workflow
- SwiftUI iOS app shell under `iOS/MemoryQR`
- Native QR generation with Apple's Core Image `CIQRCodeGenerator`
- Save generated QR images to Photos from the iOS app
- Camera QR scanning with AVFoundation
- QR image import and parsing from Photos
- Passphrase-encrypted QR payload creation and recovery in the iOS app
- Local reader allowlist metadata for app-level QR decode gating
- Attachment reference metadata for photos, audio, and video bundles
- Manual iOS entry and scan display for attachment reference metadata

The iOS app can encrypt a memory payload with a user-entered passphrase and unlock it later with the same passphrase. Passphrase encryption, local reader IDs, and attachment references are independent controls: plain MemoryQR payloads can declare a local reader allowlist and small attachment references, while encrypted envelopes can also carry the same reader and attachment metadata around encrypted memory text. Attachment references include an id, media type, byte size, SHA-256 digest, local encrypted bundle storage kind, and encrypted bundle reference. Media bytes are not stored in the QR code.

Local reader allowlists are app-level MVP metadata. If a QR is not encrypted, its title and message are still visible to anyone who reads the QR payload directly, even if the app asks for a matching local reader ID before displaying it.

This is not account authentication, real cloud authorization, or media storage. Authentication, secure whitelist authorization, cloud sync, secure sharing, encrypted bundle storage, and attachment import/export UX are still planned work.

See [`docs/authorized-decode-boundary.md`](docs/authorized-decode-boundary.md) for the current authorization boundary.

## Roadmap

- Generate real QR codes from memory payloads
- Replace the local reader allowlist MVP with real authentication and secure whitelist authorization
- Add secure local encrypted bundle storage for referenced photos, audio, and video
- Add export and download options
- Explore local-first storage for private memories

## Run Locally

No dependency install is required.

```bash
python3 -m http.server 4173
```

Then open:

```text
http://localhost:4173
```

## Test

```bash
node --test test/*.test.js
```

## iOS App

Open the native project in Xcode:

```bash
open iOS/MemoryQR/MemoryQR.xcodeproj
```

The current bundle identifier is:

```text
com.chenghaoliu.MemoryQR
```

To deploy to a real iPhone, select your Apple Developer Team in Xcode's signing settings, then choose your device and run the `MemoryQR` scheme.

Build from the command line:

```bash
xcodebuild build \
  -project iOS/MemoryQR/MemoryQR.xcodeproj \
  -scheme MemoryQR \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/MemoryQR-xcode
```

Run iOS tests:

```bash
xcodebuild test \
  -project iOS/MemoryQR/MemoryQR.xcodeproj \
  -scheme MemoryQR \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath /private/tmp/MemoryQR-xcode
```

Use `/private/tmp` for DerivedData when working from a synced `Documents` folder; local Finder metadata in `Documents` can make codesign reject simulator build products.

## License

MIT
