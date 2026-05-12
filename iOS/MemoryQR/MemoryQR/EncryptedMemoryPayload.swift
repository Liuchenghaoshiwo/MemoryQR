import CommonCrypto
import CryptoKit
import Foundation
import Security

enum EncryptedMemoryPayload {
    static let schema = "memoryqr.encrypted.v1"

    private static let algorithm = "AES-256-GCM"
    private static let keyDerivationFunction = "PBKDF2-HMAC-SHA256"
    private static let defaultIterations = 210_000
    private static let saltByteCount = 16
    private static let nonceByteCount = 12
    private static let tagByteCount = 16

    enum PayloadError: Error, Equatable {
        case emptyPassphrase
        case invalidEnvelope
        case unsupportedSchema
        case unsupportedAlgorithm
        case encryptionFailed
        case decryptionFailed
    }

    struct Envelope: Codable, Equatable {
        let schema: String
        let alg: String
        let kdf: String
        let iterations: Int
        let salt: String
        let nonce: String
        let ciphertext: String
        let createdAt: String
    }

    static func create(memoryPayload: String, passphrase: String) throws -> String {
        try create(
            memoryPayload: memoryPayload,
            passphrase: passphrase,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            salt: randomData(byteCount: saltByteCount),
            nonce: randomData(byteCount: nonceByteCount),
            iterations: defaultIterations
        )
    }

    static func create(
        memoryPayload: String,
        passphrase: String,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        salt: Data,
        nonce: Data,
        iterations: Int = defaultIterations
    ) throws -> String {
        try validatePassphrase(passphrase)
        _ = try MemoryPayload.parse(memoryPayload)

        guard salt.count == saltByteCount,
              nonce.count == nonceByteCount,
              iterations > 0,
              !createdAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PayloadError.invalidEnvelope
        }

        let metadata = EnvelopeMetadata(
            schema: schema,
            alg: algorithm,
            kdf: keyDerivationFunction,
            iterations: iterations,
            salt: salt.base64URLEncodedString(),
            nonce: nonce.base64URLEncodedString(),
            createdAt: createdAt
        )
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        let aesNonce = try AES.GCM.Nonce(data: nonce)
        let sealedBox = try AES.GCM.seal(
            Data(memoryPayload.utf8),
            using: key,
            nonce: aesNonce,
            authenticating: metadata.authenticatedData
        )
        let encryptedBytes = sealedBox.ciphertext + sealedBox.tag

        let envelope = Envelope(
            schema: metadata.schema,
            alg: metadata.alg,
            kdf: metadata.kdf,
            iterations: metadata.iterations,
            salt: metadata.salt,
            nonce: metadata.nonce,
            ciphertext: encryptedBytes.base64URLEncodedString(),
            createdAt: metadata.createdAt
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw PayloadError.encryptionFailed
        }
        return payload
    }

    static func inspect(_ payload: String) throws -> Envelope {
        guard let data = payload.data(using: .utf8) else {
            throw PayloadError.invalidEnvelope
        }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw PayloadError.invalidEnvelope
        }

        guard envelope.schema == schema else {
            throw PayloadError.unsupportedSchema
        }
        guard envelope.alg == algorithm,
              envelope.kdf == keyDerivationFunction else {
            throw PayloadError.unsupportedAlgorithm
        }
        guard envelope.iterations > 0,
              !envelope.createdAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let salt = Data(base64URLEncoded: envelope.salt),
              let nonce = Data(base64URLEncoded: envelope.nonce),
              let ciphertext = Data(base64URLEncoded: envelope.ciphertext),
              salt.count == saltByteCount,
              nonce.count == nonceByteCount,
              ciphertext.count > tagByteCount else {
            throw PayloadError.invalidEnvelope
        }

        return envelope
    }

    static func decrypt(_ envelopePayload: String, passphrase: String) throws -> MemoryPayload.Memory {
        try validatePassphrase(passphrase)

        let envelope = try inspect(envelopePayload)
        guard let salt = Data(base64URLEncoded: envelope.salt),
              let nonce = Data(base64URLEncoded: envelope.nonce),
              let encryptedBytes = Data(base64URLEncoded: envelope.ciphertext) else {
            throw PayloadError.invalidEnvelope
        }

        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: envelope.iterations)
        let ciphertext = encryptedBytes.prefix(encryptedBytes.count - tagByteCount)
        let tag = encryptedBytes.suffix(tagByteCount)
        let metadata = EnvelopeMetadata(envelope: envelope)

        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: ciphertext,
                tag: tag
            )
            let plaintext = try AES.GCM.open(
                sealedBox,
                using: key,
                authenticating: metadata.authenticatedData
            )
            guard let memoryPayload = String(data: plaintext, encoding: .utf8) else {
                throw PayloadError.decryptionFailed
            }
            return try MemoryPayload.parse(memoryPayload)
        } catch {
            throw PayloadError.decryptionFailed
        }
    }

    private static func validatePassphrase(_ passphrase: String) throws {
        if passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PayloadError.emptyPassphrase
        }
    }

    private static func deriveKey(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let keyByteCount = 32
        var keyData = Data(repeating: 0, count: keyByteCount)
        let passwordBytes = Array(passphrase.utf8)
        let saltBytes = Array(salt)

        let status = keyData.withUnsafeMutableBytes { keyBuffer in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes,
                passwordBytes.count,
                saltBytes,
                saltBytes.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(iterations),
                keyBuffer.bindMemory(to: UInt8.self).baseAddress,
                keyByteCount
            )
        }

        guard status == kCCSuccess else {
            throw PayloadError.encryptionFailed
        }

        return SymmetricKey(data: keyData)
    }

    private static func randomData(byteCount: Int) throws -> Data {
        var data = Data(repeating: 0, count: byteCount)
        let status = data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, byteCount, baseAddress)
        }

        guard status == errSecSuccess else {
            throw PayloadError.encryptionFailed
        }
        return data
    }
}

private struct EnvelopeMetadata {
    let schema: String
    let alg: String
    let kdf: String
    let iterations: Int
    let salt: String
    let nonce: String
    let createdAt: String

    init(
        schema: String,
        alg: String,
        kdf: String,
        iterations: Int,
        salt: String,
        nonce: String,
        createdAt: String
    ) {
        self.schema = schema
        self.alg = alg
        self.kdf = kdf
        self.iterations = iterations
        self.salt = salt
        self.nonce = nonce
        self.createdAt = createdAt
    }

    init(envelope: EncryptedMemoryPayload.Envelope) {
        self.init(
            schema: envelope.schema,
            alg: envelope.alg,
            kdf: envelope.kdf,
            iterations: envelope.iterations,
            salt: envelope.salt,
            nonce: envelope.nonce,
            createdAt: envelope.createdAt
        )
    }

    var authenticatedData: Data {
        Data(
            """
            {"schema":"\(schema)","alg":"\(alg)","kdf":"\(kdf)","iterations":\(iterations),"salt":"\(salt)","nonce":"\(nonce)","createdAt":"\(createdAt)"}
            """.utf8
        )
    }
}

private extension Data {
    init?(base64URLEncoded value: String) {
        guard !value.isEmpty,
              value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else {
            return nil
        }

        let base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - base64.count % 4) % 4)

        guard let data = Data(base64Encoded: base64 + padding),
              data.base64URLEncodedString() == value else {
            return nil
        }
        self = data
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
