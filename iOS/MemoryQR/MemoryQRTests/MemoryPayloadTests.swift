import XCTest
@testable import MemoryQR

final class MemoryPayloadTests: XCTestCase {
    func testCreateTrimsTextAndEmitsStableSchema() throws {
        let payload = try MemoryPayload.create(
            title: "  Beach day  ",
            message: "  The afternoon light felt golden.  ",
            createdAt: "2026-05-10T09:00:00.000Z"
        )

        let memory = try MemoryPayload.parse(payload)

        XCTAssertEqual(memory.schema, "memoryqr.memory.v1")
        XCTAssertEqual(memory.title, "Beach day")
        XCTAssertEqual(memory.message, "The afternoon light felt golden.")
        XCTAssertEqual(memory.createdAt, "2026-05-10T09:00:00.000Z")
    }

    func testParseReturnsStructuredMemoryData() throws {
        let payload = """
        {"schema":"memoryqr.memory.v1","title":"First concert","message":"A song I never wanted to forget.","createdAt":"2026-05-10T10:00:00.000Z"}
        """

        let memory = try MemoryPayload.parse(payload)

        XCTAssertEqual(memory.schema, "memoryqr.memory.v1")
        XCTAssertEqual(memory.title, "First concert")
        XCTAssertEqual(memory.message, "A song I never wanted to forget.")
        XCTAssertEqual(memory.createdAt, "2026-05-10T10:00:00.000Z")
    }

    func testCreateCanDeclareLocalReaderAllowlistWithoutEncryption() throws {
        let payload = try MemoryPayload.create(
            title: "Family note",
            message: "Visible through the local reader gate.",
            createdAt: "2026-05-14T11:00:00.000Z",
            authorization: try .localReaderAllowlist([
                " Family.Phone ",
                "family.phone",
                "guest-1"
            ])
        )

        let memory = try MemoryPayload.parse(payload)

        XCTAssertEqual(memory.authorization?.mode, "local-reader")
        XCTAssertEqual(memory.authorization?.policy, "local-reader-allowlist")
        XCTAssertEqual(memory.authorization?.allowedReaderIds, ["family.phone", "guest-1"])
    }

    func testLocalReaderAllowlistAllowsOnlyMatchingReaderWithoutEncryption() throws {
        let authorization = try MemoryPayload.Authorization.localReaderAllowlist(["family-phone"])

        XCTAssertTrue(authorization.allows(.init(localReaderId: " Family-Phone ")))
        XCTAssertFalse(authorization.allows(.init(localReaderId: "visitor-phone")))
    }

    func testCreateCanDeclareAttachmentReferencesWithoutEncryption() throws {
        let attachment = try EncryptedMemoryPayload.AttachmentReference.localEncryptedBundle(
            id: " Cover.Photo ",
            type: "image",
            size: 245_760,
            sha256: String(repeating: "A", count: 64),
            encryptedBundleRef: "memoryqr-local-bundle://anniversary-2026/cover-photo"
        )
        let payload = try MemoryPayload.create(
            title: "Anniversary album",
            message: "A plain QR can point to a local encrypted bundle.",
            createdAt: "2026-05-14T11:30:00.000Z",
            attachments: [attachment]
        )

        let memory = try MemoryPayload.parse(payload)

        XCTAssertEqual(memory.attachments, [attachment])
        XCTAssertEqual(memory.attachments.first?.id, "cover.photo")
    }

    func testParseRejectsInvalidJSON() {
        XCTAssertThrowsError(try MemoryPayload.parse("not json")) { error in
            XCTAssertEqual(error as? MemoryPayload.PayloadError, .invalidJSON)
        }
    }

    func testParseRejectsUnsupportedSchemas() {
        let payload = """
        {"schema":"memoryqr.memory.v0","title":"Old","message":"Nope","createdAt":"2026-05-10T10:00:00.000Z"}
        """

        XCTAssertThrowsError(try MemoryPayload.parse(payload)) { error in
            XCTAssertEqual(error as? MemoryPayload.PayloadError, .unsupportedSchema)
        }
    }

    func testQRCodeGeneratorCreatesImageForPayload() throws {
        let payload = try MemoryPayload.create(
            title: "Dinner",
            message: "A table by the window.",
            createdAt: "2026-05-10T11:00:00.000Z"
        )

        let image = QRCodeGenerator.makeImage(from: payload)

        XCTAssertNotNil(image)
        XCTAssertGreaterThan(image?.size.width ?? 0, 0)
        XCTAssertGreaterThan(image?.size.height ?? 0, 0)
    }
}
