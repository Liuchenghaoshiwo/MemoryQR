# MemoryQR iOS QR Scan and Parse Design

## Goal

Add QR recovery to the native iOS app so a user can scan a MemoryQR with the camera or choose a QR image from Photos, then parse and display the original memory title, message, and created time.

## Scope

This phase adds plain MemoryQR payload recovery only:

- Camera QR scanning with `AVFoundation`.
- QR image import with `PhotosPicker` plus Core Image QR detection.
- Shared parsing of scanned strings through the existing `MemoryPayload.parse(...)` contract.
- Clear error states for invalid QR content, unsupported schemas, unreadable images, and camera permission issues.

This phase does not add encrypted payloads, login, whitelist authorization, secure decoding, or media attachments. Future media support should not store large images, audio, or video directly inside QR codes. Instead, QR codes should point to encrypted local bundles or authorized encrypted storage references.

## Architecture

The app remains a small SwiftUI project under `iOS/MemoryQR`.

- `MemoryQRDecoder.swift` converts raw scanned text into either a parsed `MemoryPayload.Memory` or a user-facing scan error.
- `QRImageDecoder.swift` extracts a QR message string from a still `UIImage`.
- `CameraScannerView.swift` wraps `AVCaptureSession` in SwiftUI and emits QR strings.
- `ScanView.swift` owns scan UI, camera permission state, Photos import, parse results, and errors.
- `ContentView.swift` switches between Create and Scan views without moving payload or QR generation responsibilities.

## Data Flow

For camera scanning, `CameraScannerView` receives QR metadata from `AVCaptureMetadataOutput`, sends the raw string to `ScanView`, and `ScanView` calls `MemoryQRDecoder.decode(...)`.

For Photos import, `ScanView` loads the selected image, `QRImageDecoder.decode(from:)` extracts the QR string, and the same `MemoryQRDecoder.decode(...)` path displays the result.

## Error Handling

- Invalid JSON or unsupported schemas become visible scan errors.
- Photos images without QR codes show a no-code error.
- Camera denial shows a permission message and keeps Photos import available.
- The app still labels current QR recovery as unencrypted/plain payload recovery.

## Testing

Unit tests cover:

- successful scanned text parsing
- invalid scanned text rejection
- unsupported schema rejection
- still-image QR decoding by generating a QR from a valid MemoryQR payload and reading it back
- still-image failure when no QR code exists

Manual verification after tests should confirm the app builds and the Scan tab is reachable in Xcode.

