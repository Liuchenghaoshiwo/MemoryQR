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
}

