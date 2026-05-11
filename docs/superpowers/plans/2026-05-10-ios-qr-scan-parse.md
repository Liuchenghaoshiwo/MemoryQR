# MemoryQR iOS QR Scan and Parse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add camera QR scanning and Photos QR image parsing to the iOS app.

**Architecture:** Keep QR parsing in small testable services and isolate camera capture behind a SwiftUI wrapper. `ScanView` coordinates camera/photo inputs and displays parsed `MemoryPayload.Memory` results.

**Tech Stack:** Swift, SwiftUI, AVFoundation, PhotosUI, Core Image, XCTest.

---

### Task 1: Ignore Xcode User State

**Files:**
- Modify: `.gitignore`

- [ ] Add ignore rules for `*.xcuserstate`, `xcuserdata/`, and `project.xcworkspace/xcuserdata/`.

### Task 2: Add Decoder Tests First

**Files:**
- Create: `iOS/MemoryQR/MemoryQRTests/MemoryQRDecoderTests.swift`
- Modify: `iOS/MemoryQR/MemoryQR.xcodeproj/project.pbxproj`

- [ ] Add tests for decoded MemoryQR scan strings and invalid scan strings.
- [ ] Add tests for decoding a generated QR image and rejecting an image without QR content.
- [ ] Run:

```bash
xcodebuild test -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /private/tmp/MemoryQR-xcode
```

Expected: fail because `MemoryQRDecoder` and `QRImageDecoder` do not exist yet.

### Task 3: Implement Testable Scan Services

**Files:**
- Create: `iOS/MemoryQR/MemoryQR/MemoryQRDecoder.swift`
- Create: `iOS/MemoryQR/MemoryQR/QRImageDecoder.swift`
- Modify: `iOS/MemoryQR/MemoryQR.xcodeproj/project.pbxproj`

- [ ] Implement `MemoryQRDecoder.decode(_:)` as a small wrapper around `MemoryPayload.parse(...)`.
- [ ] Implement `QRImageDecoder.decode(from:)` with `CIDetector(ofType: CIDetectorTypeQRCode, ...)`.
- [ ] Run the Xcode tests and confirm decoder tests pass.

### Task 4: Add Camera and Scan UI

**Files:**
- Create: `iOS/MemoryQR/MemoryQR/CameraScannerView.swift`
- Create: `iOS/MemoryQR/MemoryQR/ScanView.swift`
- Modify: `iOS/MemoryQR/MemoryQR/ContentView.swift`
- Modify: `iOS/MemoryQR/MemoryQR.xcodeproj/project.pbxproj`

- [ ] Add a SwiftUI camera scanner wrapper using `AVCaptureSession`, `AVCaptureVideoPreviewLayer`, and `.qr` metadata detection.
- [ ] Add a `ScanView` with camera scan, Photos import, result display, and error display.
- [ ] Add a segmented create/scan switch in `ContentView`.
- [ ] Add camera usage text to generated Info.plist settings in the Xcode project.

### Task 5: Update Docs and Handoff

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] Document camera scanning and Photos QR image parsing.
- [ ] Record the media attachment requirement for future work.
- [ ] Keep security language precise: scanning parses plain unencrypted payloads only.

### Task 6: Verify

- [ ] Run `node --test test/*.test.js`.
- [ ] Run the iOS XCTest command with `/private/tmp/MemoryQR-xcode`.
- [ ] Check `git status` to ensure Xcode user files are ignored.

