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
        XCTAssertEqual(envelope.authorization, .passphraseOnly)
        XCTAssertFalse(envelope.ciphertext.isEmpty)
    }

    func testCreateCanDeclareLocalReaderAllowlist() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Family archive",
            message: "Only named local readers should unlock this QR.",
            createdAt: "2026-05-13T08:00:00.000Z"
        )
        let authorization = try EncryptedMemoryPayload.Authorization.localReaderAllowlist([
            " Family.Phone ",
            "family.phone",
            "guest-1"
        ])

        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "family-passphrase",
            createdAt: "2026-05-13T08:01:00.000Z",
            salt: salt,
            nonce: nonce,
            iterations: 1000,
            authorization: authorization
        )

        let envelope = try EncryptedMemoryPayload.inspect(envelopePayload)
        XCTAssertEqual(envelope.authorization, authorization)
        XCTAssertEqual(envelope.authorization.allowedReaderIds, ["family.phone", "guest-1"])
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

    func testDecryptRejectsReadersOutsideLocalAllowlist() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Private table",
            message: "The reader ID must match before passphrase unlock."
        )
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "shared-passphrase",
            salt: salt,
            nonce: nonce,
            iterations: 1000,
            authorization: try .localReaderAllowlist(["family-phone"])
        )

        XCTAssertThrowsError(
            try EncryptedMemoryPayload.decrypt(
                envelopePayload,
                passphrase: "shared-passphrase",
                authorizationContext: .init(localReaderId: "visitor-phone")
            )
        ) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .unauthorizedReader)
        }
    }

    func testDecryptAcceptsReadersInsideLocalAllowlist() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Kitchen note",
            message: "The local reader ID matched.",
            createdAt: "2026-05-13T09:00:00.000Z"
        )
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "kitchen-passphrase",
            salt: salt,
            nonce: nonce,
            iterations: 1000,
            authorization: try .localReaderAllowlist(["kitchen-ipad"])
        )

        let memory = try EncryptedMemoryPayload.decrypt(
            envelopePayload,
            passphrase: "kitchen-passphrase",
            authorizationContext: .init(localReaderId: " Kitchen-iPad ")
        )

        XCTAssertEqual(memory.title, "Kitchen note")
        XCTAssertEqual(memory.message, "The local reader ID matched.")
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
