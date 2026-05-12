import XCTest
@testable import MemoryQR

final class EncryptedMemoryPayloadTests: XCTestCase {
    private let salt = Data((1...16).map(UInt8.init))
    private let nonce = Data((21...32).map(UInt8.init))

    func testCreateEmitsEncryptedEnvelopeMetadata() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "  Train window  ",
            message: "  Rain moved sideways.  ",
            createdAt: "2026-05-12T08:00:00.000Z"
        )

        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "correct horse battery staple",
            createdAt: "2026-05-12T08:01:00.000Z",
            salt: salt,
            nonce: nonce,
            iterations: 1000
        )

        let envelope = try EncryptedMemoryPayload.inspect(envelopePayload)
        XCTAssertEqual(envelope.schema, "memoryqr.encrypted.v1")
        XCTAssertEqual(envelope.alg, "AES-256-GCM")
        XCTAssertEqual(envelope.kdf, "PBKDF2-HMAC-SHA256")
        XCTAssertEqual(envelope.iterations, 1000)
        XCTAssertEqual(envelope.salt, "AQIDBAUGBwgJCgsMDQ4PEA")
        XCTAssertEqual(envelope.nonce, "FRYXGBkaGxwdHh8g")
        XCTAssertEqual(envelope.createdAt, "2026-05-12T08:01:00.000Z")
        XCTAssertFalse(envelope.ciphertext.isEmpty)
    }

    func testDecryptRecoversMemoryWithCorrectPassphrase() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Garden",
            message: "Jasmine after rain.",
            createdAt: "2026-05-12T09:00:00.000Z"
        )
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "garden-passphrase",
            salt: salt,
            nonce: nonce,
            iterations: 1000
        )

        let memory = try EncryptedMemoryPayload.decrypt(envelopePayload, passphrase: "garden-passphrase")

        XCTAssertEqual(memory.schema, "memoryqr.memory.v1")
        XCTAssertEqual(memory.title, "Garden")
        XCTAssertEqual(memory.message, "Jasmine after rain.")
        XCTAssertEqual(memory.createdAt, "2026-05-12T09:00:00.000Z")
    }

    func testRejectsEmptyPassphrase() throws {
        let memoryPayload = try MemoryPayload.create(title: "A", message: "B")

        XCTAssertThrowsError(
            try EncryptedMemoryPayload.create(memoryPayload: memoryPayload, passphrase: "", salt: salt, nonce: nonce)
        ) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .emptyPassphrase)
        }
        XCTAssertThrowsError(try EncryptedMemoryPayload.decrypt("{}", passphrase: "   ")) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .emptyPassphrase)
        }
    }

    func testInspectRejectsMalformedEnvelope() {
        XCTAssertThrowsError(try EncryptedMemoryPayload.inspect("not json")) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .invalidEnvelope)
        }
    }

    func testDecryptRejectsWrongPassphrase() throws {
        let memoryPayload = try MemoryPayload.create(title: "Wrong key", message: "This should stay private.")
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "right-passphrase",
            salt: salt,
            nonce: nonce,
            iterations: 1000
        )

        XCTAssertThrowsError(try EncryptedMemoryPayload.decrypt(envelopePayload, passphrase: "wrong-passphrase")) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .decryptionFailed)
        }
    }
}
