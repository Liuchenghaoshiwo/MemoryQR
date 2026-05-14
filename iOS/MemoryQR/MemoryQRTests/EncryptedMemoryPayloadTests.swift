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

    func testCreateCanDeclareEncryptedAttachmentReferences() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Anniversary album",
            message: "The QR points to a local encrypted photo bundle.",
            createdAt: "2026-05-14T08:00:00.000Z"
        )
        let attachment = try EncryptedMemoryPayload.AttachmentReference.localEncryptedBundle(
            id: " Cover.Photo ",
            type: "image",
            size: 245_760,
            sha256: String(repeating: "A", count: 64),
            encryptedBundleRef: "memoryqr-local-bundle://anniversary-2026/cover-photo"
        )

        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "album-passphrase",
            createdAt: "2026-05-14T08:01:00.000Z",
            salt: salt,
            nonce: nonce,
            iterations: 1000,
            attachments: [attachment]
        )

        let envelope = try EncryptedMemoryPayload.inspect(envelopePayload)
        XCTAssertEqual(envelope.attachments, [attachment])
        XCTAssertEqual(envelope.attachments.first?.id, "cover.photo")
        XCTAssertEqual(envelope.attachments.first?.sha256, String(repeating: "a", count: 64))
    }

    func testAttachmentReferenceDraftReturnsNilWhenEmpty() throws {
        let draft = AttachmentReferenceDraft()

        XCTAssertNil(try draft.makeAttachmentReference())
    }

    func testAttachmentReferenceDraftBuildsLocalEncryptedBundleReference() throws {
        let draft = AttachmentReferenceDraft(
            id: " Cover.Photo ",
            mediaType: .image,
            size: "245760",
            sha256: String(repeating: "A", count: 64),
            encryptedBundleRef: "memoryqr-local-bundle://anniversary-2026/cover-photo"
        )

        let attachment = try XCTUnwrap(draft.makeAttachmentReference())

        XCTAssertEqual(attachment.id, "cover.photo")
        XCTAssertEqual(attachment.type, "image")
        XCTAssertEqual(attachment.size, 245_760)
        XCTAssertEqual(attachment.sha256, String(repeating: "a", count: 64))
        XCTAssertEqual(attachment.storage.kind, "local-encrypted-bundle")
        XCTAssertEqual(
            attachment.storage.encryptedBundleRef,
            "memoryqr-local-bundle://anniversary-2026/cover-photo"
        )
    }

    func testCreateOptionsShowPassphraseFieldsOnlyWhenEncryptIsOn() throws {
        let allowlistOnly = CreateOptionsState(
            shouldEncrypt: false,
            usesReaderAllowlist: true,
            includesAttachmentReference: false
        )
        let attachmentOnly = CreateOptionsState(
            shouldEncrypt: false,
            usesReaderAllowlist: false,
            includesAttachmentReference: true
        )
        let encrypted = CreateOptionsState(
            shouldEncrypt: true,
            usesReaderAllowlist: true,
            includesAttachmentReference: true
        )

        XCTAssertFalse(allowlistOnly.showsPassphraseFields)
        XCTAssertFalse(attachmentOnly.showsPassphraseFields)
        XCTAssertTrue(encrypted.showsPassphraseFields)
    }

    func testCreateOptionsKeepMetadataIndependentFromEncryption() throws {
        let allowlistOnly = CreateOptionsState(
            shouldEncrypt: false,
            usesReaderAllowlist: true,
            includesAttachmentReference: false
        )
        let attachmentOnly = CreateOptionsState(
            shouldEncrypt: false,
            usesReaderAllowlist: false,
            includesAttachmentReference: true
        )
        let plain = CreateOptionsState(
            shouldEncrypt: false,
            usesReaderAllowlist: false,
            includesAttachmentReference: false
        )

        XCTAssertTrue(allowlistOnly.hasOptionalMetadata)
        XCTAssertFalse(allowlistOnly.metadataRequiresEncryption)
        XCTAssertFalse(attachmentOnly.metadataRequiresEncryption)
        XCTAssertFalse(plain.metadataRequiresEncryption)
    }

    func testCreateOptionsExposeExpandedFieldsAfterTheirOwnToggle() throws {
        let allEnabled = CreateOptionsState(
            shouldEncrypt: true,
            usesReaderAllowlist: true,
            includesAttachmentReference: true
        )

        XCTAssertEqual(
            allEnabled.visibleEditorSections,
            [
                .encryptToggle,
                .passphraseFields,
                .readerAllowlistToggle,
                .readerAllowlistFields,
                .attachmentReferenceToggle,
                .attachmentReferenceFields
            ]
        )
    }

    func testAttachmentReferencesAreAuthenticatedWithEnvelopeMetadata() throws {
        let memoryPayload = try MemoryPayload.create(
            title: "Voice note",
            message: "The bundle reference must not be rewritten."
        )
        let envelopePayload = try EncryptedMemoryPayload.create(
            memoryPayload: memoryPayload,
            passphrase: "voice-passphrase",
            salt: salt,
            nonce: nonce,
            iterations: 1000,
            attachments: [
                try .localEncryptedBundle(
                    id: "voice-1",
                    type: "audio",
                    size: 4096,
                    sha256: String(repeating: "b", count: 64),
                    encryptedBundleRef: "memoryqr-local-bundle://voice-notes/voice-1"
                )
            ]
        )
        var tamperedEnvelope = try JSONSerialization.jsonObject(
            with: Data(envelopePayload.utf8)
        ) as! [String: Any]
        var attachments = tamperedEnvelope["attachments"] as! [[String: Any]]
        var attachment = attachments[0]
        var storage = attachment["storage"] as! [String: Any]
        storage["encryptedBundleRef"] = "memoryqr-local-bundle://voice-notes/rewritten"
        attachment["storage"] = storage
        attachments[0] = attachment
        tamperedEnvelope["attachments"] = attachments
        let tamperedData = try JSONSerialization.data(withJSONObject: tamperedEnvelope)
        let tamperedPayload = String(data: tamperedData, encoding: .utf8)!

        XCTAssertThrowsError(try EncryptedMemoryPayload.decrypt(tamperedPayload, passphrase: "voice-passphrase")) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .decryptionFailed)
        }
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

    func testRejectsInvalidAttachmentReferences() throws {
        XCTAssertThrowsError(
            try EncryptedMemoryPayload.AttachmentReference.localEncryptedBundle(
                id: "video-1",
                type: "video",
                size: 1024,
                sha256: "not-a-sha",
                encryptedBundleRef: "memoryqr-local-bundle://video-1"
            )
        ) { error in
            XCTAssertEqual(error as? EncryptedMemoryPayload.PayloadError, .invalidEnvelope)
        }

        let payloadWithInlineMedia = """
        {
          "schema": "memoryqr.encrypted.v1",
          "alg": "AES-256-GCM",
          "kdf": "PBKDF2-HMAC-SHA256",
          "iterations": 1000,
          "salt": "AQIDBAUGBwgJCgsMDQ4PEA",
          "nonce": "FRYXGBkaGxwdHh8g",
          "ciphertext": "abcdefghijklmnopqrstuvwxyz",
          "createdAt": "2026-05-14T08:01:00.000Z",
          "attachments": [
            {
              "id": "inline-media",
              "type": "image",
              "size": 1,
              "sha256": "\(String(repeating: "c", count: 64))",
              "data": "base64-media-does-not-belong-in-the-qr",
              "storage": {
                "kind": "local-encrypted-bundle",
                "encryptedBundleRef": "memoryqr-local-bundle://inline-media"
              }
            }
          ]
        }
        """

        XCTAssertThrowsError(try EncryptedMemoryPayload.inspect(payloadWithInlineMedia)) { error in
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
