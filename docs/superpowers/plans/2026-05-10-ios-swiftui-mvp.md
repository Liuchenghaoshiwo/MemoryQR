# MemoryQR iOS SwiftUI MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native SwiftUI iOS app that generates a MemoryQR payload and renders it as a QR image.

**Architecture:** Keep the existing static site unchanged and add an Xcode project under `iOS/MemoryQR`. Payload logic, QR rendering, and UI are separated so payload behavior can be unit-tested without the SwiftUI view.

**Tech Stack:** Swift, SwiftUI, Core Image, UIKit image saving, XCTest, Xcode project.

---

### Task 1: Create the iOS Project Shell

**Files:**
- Create: `iOS/MemoryQR/MemoryQR.xcodeproj/project.pbxproj`
- Create: `iOS/MemoryQR/MemoryQR/Assets.xcassets/Contents.json`
- Create: `iOS/MemoryQR/MemoryQR/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `iOS/MemoryQR/MemoryQR/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] Create a single iOS app target named `MemoryQR` and a unit test target named `MemoryQRTests`.
- [ ] Set the bundle identifier to `com.chenghaoliu.MemoryQR`.
- [ ] Set the deployment target to iOS 18.0 and use Swift 5.0 language mode for broad simulator/device compatibility.

### Task 2: Add Swift Payload Tests First

**Files:**
- Create: `iOS/MemoryQR/MemoryQRTests/MemoryPayloadTests.swift`

- [ ] Add tests proving `MemoryPayload.create(...)` trims title/message and emits `memoryqr.memory.v1`.
- [ ] Add tests proving `MemoryPayload.parse(...)` returns structured memory data.
- [ ] Add tests proving invalid JSON and unsupported schemas throw errors.
- [ ] Run `xcodebuild test` and confirm these tests fail because production Swift files do not exist yet.

### Task 3: Implement Payload and QR Units

**Files:**
- Create: `iOS/MemoryQR/MemoryQR/MemoryPayload.swift`
- Create: `iOS/MemoryQR/MemoryQR/QRCodeGenerator.swift`

- [ ] Implement `MemoryPayload.Memory`, `MemoryPayload.create(...)`, and `MemoryPayload.parse(...)`.
- [ ] Implement `QRCodeGenerator.makeImage(from:)` with `CIQRCodeGenerator` and nearest-neighbor scaling.
- [ ] Run `xcodebuild test` and confirm payload and QR tests pass.

### Task 4: Add SwiftUI App UI

**Files:**
- Create: `iOS/MemoryQR/MemoryQR/MemoryQRApp.swift`
- Create: `iOS/MemoryQR/MemoryQR/ContentView.swift`

- [ ] Add a SwiftUI entry point.
- [ ] Add title/message inputs, a QR preview, a payload preview, a generate button, and a save button.
- [ ] Keep the copy accurate: this is an MVP and secure whitelist decoding is planned, not implemented.

### Task 5: Update Public Docs and Session Handoff

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] Document the new `iOS/MemoryQR` Xcode project.
- [ ] Keep the root static preview instructions intact.
- [ ] Update `AGENTS.md` with what changed, what was verified, what remains incomplete, and the best next task.

### Task 6: Final Verification and Git

- [ ] Run `node --test test/*.test.js`.
- [ ] Run `xcodebuild test -project iOS/MemoryQR/MemoryQR.xcodeproj -scheme MemoryQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`.
- [ ] Commit the changes on the feature branch.
- [ ] Push the feature branch to GitHub.

