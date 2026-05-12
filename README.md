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

The iOS app can encrypt a memory payload with a user-entered passphrase and unlock it later with the same passphrase. Authentication, whitelist authorization, cloud sync, secure sharing, and media attachments are still planned work.

## Roadmap

- Generate real QR codes from memory payloads
- Add authentication and whitelist authorization
- Add secure attachment support for photos, audio, and video
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
