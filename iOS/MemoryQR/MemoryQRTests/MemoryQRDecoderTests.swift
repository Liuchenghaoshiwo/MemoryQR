import XCTest
import UIKit
@testable import MemoryQR

final class MemoryQRDecoderTests: XCTestCase {
    func testDecodeReturnsMemoryFromScannedPayload() throws {
        let payload = try MemoryPayload.create(
            title: "  Museum day  ",
            message: "  The blue room was quiet.  ",
            createdAt: "2026-05-10T12:00:00.000Z"
        )

        let memory = try MemoryQRDecoder.decode(payload)

        XCTAssertEqual(memory.schema, "memoryqr.memory.v1")
        XCTAssertEqual(memory.title, "Museum day")
        XCTAssertEqual(memory.message, "The blue room was quiet.")
        XCTAssertEqual(memory.createdAt, "2026-05-10T12:00:00.000Z")
    }

    func testDecodeRejectsInvalidScannedText() {
        XCTAssertThrowsError(try MemoryQRDecoder.decode("https://example.com/not-memoryqr")) { error in
            XCTAssertEqual(error as? MemoryQRDecoder.DecodeError, .invalidPayload)
        }
    }

    func testDecodeRejectsUnsupportedSchema() {
        let payload = """
        {"schema":"memoryqr.memory.v0","title":"Old","message":"Nope","createdAt":"2026-05-10T12:00:00.000Z"}
        """

        XCTAssertThrowsError(try MemoryQRDecoder.decode(payload)) { error in
            XCTAssertEqual(error as? MemoryQRDecoder.DecodeError, .unsupportedSchema)
        }
    }

    func testInspectReturnsPlainMemoryResultForPlainPayload() throws {
        let payload = try MemoryPayload.create(
            title: "Plain",
            message: "Still supported.",
            createdAt: "2026-05-12T10:00:00.000Z"
        )
        let memory = try MemoryPayload.parse(payload)

        let result = try MemoryQRDecoder.inspect(payload)

        XCTAssertEqual(result, .plain(memory))
    }

    func testInspectReturnsEncryptedResultForEncryptedEnvelope() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Locked",
            message: "Needs a passphrase.",
            createdAt: "2026-05-12T10:30:00.000Z"
        )
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "scan-passphrase",
            salt: Data((1...16).map(UInt8.init)),
            nonce: Data((21...32).map(UInt8.init)),
            iterations: 1000
        )
        let envelope = try EncryptedMemoryPayload.inspect(envelopePayload)

        let result = try MemoryQRDecoder.inspect(envelopePayload)

        XCTAssertEqual(result, .encrypted(envelope))
    }

    func testDecryptEncryptedPayloadReturnsMemory() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Unlocked",
            message: "The passphrase worked.",
            createdAt: "2026-05-12T11:00:00.000Z"
        )
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "unlock-passphrase",
            salt: Data((1...16).map(UInt8.init)),
            nonce: Data((21...32).map(UInt8.init)),
            iterations: 1000
        )

        let memory = try MemoryQRDecoder.decrypt(envelopePayload, passphrase: "unlock-passphrase")

        XCTAssertEqual(memory.title, "Unlocked")
        XCTAssertEqual(memory.message, "The passphrase worked.")
        XCTAssertEqual(memory.createdAt, "2026-05-12T11:00:00.000Z")
    }

    func testDecryptEncryptedPayloadRejectsWrongPassphrase() throws {
        let memoryPayload = try MemoryPayload.create(title: "Private", message: "Keep sealed.")
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "right-passphrase",
            salt: Data((1...16).map(UInt8.init)),
            nonce: Data((21...32).map(UInt8.init)),
            iterations: 1000
        )

        XCTAssertThrowsError(try MemoryQRDecoder.decrypt(envelopePayload, passphrase: "wrong-passphrase")) { error in
            XCTAssertEqual(error as? MemoryQRDecoder.DecodeError, .decryptionFailed)
        }
    }

    func testDecryptEncryptedPayloadRejectsUnauthorizedLocalReader() throws {
        let memoryPayload = try MemoryPayload.create(title: "Allowlisted", message: "Local reader gate.")
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "right-passphrase",
            salt: Data((1...16).map(UInt8.init)),
            nonce: Data((21...32).map(UInt8.init)),
            iterations: 1000,
            authorization: try .localReaderAllowlist(["family-phone"])
        )

        XCTAssertThrowsError(
            try MemoryQRDecoder.decrypt(
                envelopePayload,
                passphrase: "right-passphrase",
                authorizationContext: .init(localReaderId: "visitor-phone")
            )
        ) { error in
            XCTAssertEqual(error as? MemoryQRDecoder.DecodeError, .unauthorizedReader)
        }
    }

    func testQRImageDecoderReadsGeneratedMemoryQRImage() throws {
        let payload = try MemoryPayload.create(
            title: "Train window",
            message: "Rain moved sideways across the glass.",
            createdAt: "2026-05-10T13:00:00.000Z"
        )
        let image = try XCTUnwrap(QRCodeGenerator.makeImage(from: payload, scale: 16))

        let decodedPayload = try QRImageDecoder.decode(from: image)

        XCTAssertEqual(decodedPayload, payload)
    }

    func testQRImageDecoderReadsGeneratedEncryptedMemoryQREnvelope() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Short locked note",
            message: "Small enough for QR.",
            createdAt: "2026-05-12T12:00:00.000Z"
        )
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "qr-passphrase",
            salt: Data((1...16).map(UInt8.init)),
            nonce: Data((21...32).map(UInt8.init)),
            iterations: 1000
        )
        let image = try XCTUnwrap(QRCodeGenerator.makeImage(from: envelopePayload, scale: 16))

        let decodedPayload = try QRImageDecoder.decode(from: image)
        let envelope = try EncryptedMemoryPayload.inspect(decodedPayload)

        XCTAssertEqual(envelope.schema, "memoryqr.encrypted.v1")
    }

    func testQRImageDecoderRejectsImagesWithoutQRCode() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 160))
        let image = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
        }

        XCTAssertThrowsError(try QRImageDecoder.decode(from: image)) { error in
            XCTAssertEqual(error as? QRImageDecoder.DecodeError, .noQRCodeFound)
        }
    }

    func testScanFlowStopsCameraWhenPhotoImportBegins() {
        var state = ScanFlowState()
        state.startCameraScan()

        state.beginPhotoImport()

        XCTAssertFalse(state.isCameraScanActive)
        XCTAssertTrue(state.isLoadingPhoto)
        XCTAssertEqual(state.statusMessage, "Reading selected image...")
    }

    func testScanFlowShowsNoQRCodePhotoImportError() {
        var state = ScanFlowState()
        state.startCameraScan()
        state.beginPhotoImport()

        state.failPhotoImportNoQRCode()

        XCTAssertFalse(state.isCameraScanActive)
        XCTAssertFalse(state.isLoadingPhoto)
        XCTAssertEqual(state.statusMessage, "No QR code was found in that image.")
    }
}
