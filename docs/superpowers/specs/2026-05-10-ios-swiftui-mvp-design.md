# MemoryQR iOS SwiftUI MVP Design

## Goal

Add a native iOS app that can be opened in Xcode and deployed to an iPhone, while keeping the existing static web preview in place.

## Scope

This version builds the first usable iOS surface:

- A SwiftUI form for entering a memory title and message.
- A local MemoryQR JSON payload using the existing schema id, `memoryqr.memory.v1`.
- QR image generation through Apple's built-in Core Image QR encoder.
- A save-to-Photos action for the generated QR image.
- A clear in-app note that authentication, whitelisting, encryption, and scanning are planned but not implemented yet.

This version does not implement accounts, cloud sync, real whitelist enforcement, encrypted QR payloads, or QR scanning.

## Architecture

The repository keeps the current static site at the root and adds the native app under `iOS/MemoryQR`. The Xcode project contains one app target and one unit test target.

The iOS app is split into small units:

- `MemoryPayload.swift` owns payload normalization, JSON encoding, and JSON parsing.
- `QRCodeGenerator.swift` owns Core Image QR rendering.
- `ContentView.swift` owns the SwiftUI user interface and save flow.
- `MemoryQRApp.swift` is the app entry point.
- `MemoryQRTests` verifies the Swift payload contract and QR generation smoke behavior.

## Data Flow

The user enters a title and message. `ContentView` calls `MemoryPayload.create(...)`, receives a JSON string, then passes it to `QRCodeGenerator.makeImage(from:)`. The generated `UIImage` is displayed in SwiftUI and can be saved to Photos.

## Security Boundary

The current QR payload is intentionally not treated as secure. It is plain JSON encoded into a QR code so the native QR flow can be validated first.

Future secure decoding should change the QR payload format before adding public sharing:

- authenticate users through a backend or identity provider
- store an allowlist of authorized users
- encrypt memory content before QR generation
- require an authorized app session to decrypt scanned payloads

## Testing

Verification for this phase:

- Existing Node tests must still pass with `node --test test/*.test.js`.
- Xcode unit tests should cover Swift payload creation, parsing, invalid JSON rejection, unsupported schema rejection, and QR image generation.
- `xcodebuild test` should run against an iPhone simulator destination.

