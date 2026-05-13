import CommonCrypto
import CryptoKit
import Foundation
import Security

enum EncryptedMemoryPayload {
    static let schema = "memoryqr.encrypted.v1"

    private static let algorithm = "AES-256-GCM"
    private static let keyDerivationFunction = "PBKDF2-HMAC-SHA256"
    private static let authorizationMode = "local-passphrase"
    private static let passphraseOnlyPolicy = "passphrase-only"
    private static let localReaderAllowlistPolicy = "local-reader-allowlist"
    private static let defaultIterations = 210_000
    private static let saltByteCount = 16
    private static let nonceByteCount = 12
    private static let tagByteCount = 16
    private static let readerIdPattern = #"^[a-z0-9][a-z0-9._:-]{0,63}$"#

    enum PayloadError: Error, Equatable {
        case emptyPassphrase
        case invalidEnvelope
        case unsupportedSchema
        case unsupportedAlgorithm
        case encryptionFailed
        case decryptionFailed
        case unauthorizedReader
    }

    struct AuthorizationContext: Equatable {
        let localReaderId: String?

        init(localReaderId: String? = nil) {
            self.localReaderId = localReaderId
        }
    }

    struct Authorization: Codable, Equatable {
        static let passphraseOnly = Authorization(
            mode: EncryptedMemoryPayload.authorizationMode,
            policy: EncryptedMemoryPayload.passphraseOnlyPolicy,
            allowedReaderIds: []
        )

        let mode: String
        let policy: String
        let allowedReaderIds: [String]

        var requiresLocalReaderId: Bool {
            policy == EncryptedMemoryPayload.localReaderAllowlistPolicy
        }

        static func localReaderAllowlist(_ readerIds: [String]) throws -> Authorization {
            try validated(
                mode: EncryptedMemoryPayload.authorizationMode,
                policy: EncryptedMemoryPayload.localReaderAllowlistPolicy,
                allowedReaderIds: readerIds
            )
        }

        fileprivate static func normalizeReaderIdForContext(_ value: String?) -> String? {
            let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard normalized.range(
                of: EncryptedMemoryPayload.readerIdPattern,
                options: .regularExpression
            ) != nil else {
                return nil
            }
            return normalized
        }

        fileprivate var authenticatedJSONString: String {
            let readerIds = allowedReaderIds.map { "\"\($0)\"" }.joined(separator: ",")
            return """
            {"mode":"\(mode)","policy":"\(policy)","allowedReaderIds":[\(readerIds)]}
            """
        }

        private init(mode: String, policy: String, allowedReaderIds: [String]) {
            self.mode = mode
            self.policy = policy
            self.allowedReaderIds = allowedReaderIds
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let mode = try container.decode(String.self, forKey: .mode)
            let policy = try container.decode(String.self, forKey: .policy)
            let allowedReaderIds = try container.decode([String].self, forKey: .allowedReaderIds)

            self = try Self.validated(
                mode: mode,
                policy: policy,
                allowedReaderIds: allowedReaderIds
            )
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(mode, forKey: .mode)
            try container.encode(policy, forKey: .policy)
            try container.encode(allowedReaderIds, forKey: .allowedReaderIds)
        }

        private static func validated(
            mode: String,
            policy: String,
            allowedReaderIds: [String]
        ) throws -> Authorization {
            guard mode == EncryptedMemoryPayload.authorizationMode else {
                throw PayloadError.invalidEnvelope
            }

            let normalizedReaderIds = try normalizeAllowedReaderIds(allowedReaderIds)
            switch policy {
            case EncryptedMemoryPayload.passphraseOnlyPolicy:
                guard normalizedReaderIds.isEmpty else {
                    throw PayloadError.invalidEnvelope
                }
                return .passphraseOnly
            case EncryptedMemoryPayload.localReaderAllowlistPolicy:
                guard !normalizedReaderIds.isEmpty else {
                    throw PayloadError.invalidEnvelope
                }
                return Authorization(
                    mode: mode,
                    policy: policy,
                    allowedReaderIds: normalizedReaderIds
                )
            default:
                throw PayloadError.invalidEnvelope
            }
        }

        private static func normalizeAllowedReaderIds(_ readerIds: [String]) throws -> [String] {
            var seen = Set<String>()
            var normalizedReaderIds: [String] = []

            for readerId in readerIds {
                let normalized = try normalizeReaderId(readerId)
                if !seen.contains(normalized) {
                    seen.insert(normalized)
                    normalizedReaderIds.append(normalized)
                }
            }

            return normalizedReaderIds
        }

        private static func normalizeReaderId(_ value: String) throws -> String {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard normalized.range(
                of: EncryptedMemoryPayload.readerIdPattern,
                options: .regularExpression
            ) != nil else {
                throw PayloadError.invalidEnvelope
            }
            return normalized
        }

        private enum CodingKeys: String, CodingKey {
            case mode
            case policy
            case allowedReaderIds
        }
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
        let authorization: Authorization
        fileprivate let usesLegacyAuthenticatedData: Bool

        init(
            schema: String,
            alg: String,
            kdf: String,
            iterations: Int,
            salt: String,
            nonce: String,
            ciphertext: String,
            createdAt: String,
            authorization: Authorization,
            usesLegacyAuthenticatedData: Bool = false
        ) {
            self.schema = schema
            self.alg = alg
            self.kdf = kdf
            self.iterations = iterations
            self.salt = salt
            self.nonce = nonce
            self.ciphertext = ciphertext
            self.createdAt = createdAt
            self.authorization = authorization
            self.usesLegacyAuthenticatedData = usesLegacyAuthenticatedData
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schema = try container.decode(String.self, forKey: .schema)
            alg = try container.decode(String.self, forKey: .alg)
            kdf = try container.decode(String.self, forKey: .kdf)
            iterations = try container.decode(Int.self, forKey: .iterations)
            salt = try container.decode(String.self, forKey: .salt)
            nonce = try container.decode(String.self, forKey: .nonce)
            ciphertext = try container.decode(String.self, forKey: .ciphertext)
            createdAt = try container.decode(String.self, forKey: .createdAt)

            if container.contains(.authorization) {
                authorization = try container.decode(Authorization.self, forKey: .authorization)
                usesLegacyAuthenticatedData = false
            } else {
                authorization = .passphraseOnly
                usesLegacyAuthenticatedData = true
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(schema, forKey: .schema)
            try container.encode(alg, forKey: .alg)
            try container.encode(kdf, forKey: .kdf)
            try container.encode(iterations, forKey: .iterations)
            try container.encode(salt, forKey: .salt)
            try container.encode(nonce, forKey: .nonce)
            try container.encode(ciphertext, forKey: .ciphertext)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(authorization, forKey: .authorization)
        }

        private enum CodingKeys: String, CodingKey {
            case schema
            case alg
            case kdf
            case iterations
            case salt
            case nonce
            case ciphertext
            case createdAt
            case authorization
        }
    }

    static func create(
        memoryPayload: String,
        passphrase: String,
        authorization: Authorization = .passphraseOnly
    ) throws -> String {
        try create(
            memoryPayload: memoryPayload,
            passphrase: passphrase,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            salt: randomData(byteCount: saltByteCount),
            nonce: randomData(byteCount: nonceByteCount),
            iterations: defaultIterations,
            authorization: authorization
        )
    }

    static func create(
        memoryPayload: String,
        passphrase: String,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        salt: Data,
        nonce: Data,
        iterations: Int = defaultIterations,
        authorization: Authorization = .passphraseOnly
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
            createdAt: createdAt,
            authorization: authorization
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
            createdAt: metadata.createdAt,
            authorization: metadata.authorization
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

    static func decrypt(
        _ envelopePayload: String,
        passphrase: String,
        authorizationContext: AuthorizationContext = .init()
    ) throws -> MemoryPayload.Memory {
        try validatePassphrase(passphrase)

        let envelope = try inspect(envelopePayload)
        try validateAuthorization(envelope.authorization, context: authorizationContext)
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

    private static func validateAuthorization(
        _ authorization: Authorization,
        context: AuthorizationContext
    ) throws {
        guard authorization.requiresLocalReaderId else {
            return
        }

        guard let localReaderId = Authorization.normalizeReaderIdForContext(context.localReaderId),
              authorization.allowedReaderIds.contains(localReaderId) else {
            throw PayloadError.unauthorizedReader
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
    let authorization: EncryptedMemoryPayload.Authorization
    let usesLegacyAuthenticatedData: Bool

    init(
        schema: String,
        alg: String,
        kdf: String,
        iterations: Int,
        salt: String,
        nonce: String,
        createdAt: String,
        authorization: EncryptedMemoryPayload.Authorization,
        usesLegacyAuthenticatedData: Bool = false
    ) {
        self.schema = schema
        self.alg = alg
        self.kdf = kdf
        self.iterations = iterations
        self.salt = salt
        self.nonce = nonce
        self.createdAt = createdAt
        self.authorization = authorization
        self.usesLegacyAuthenticatedData = usesLegacyAuthenticatedData
    }

    init(envelope: EncryptedMemoryPayload.Envelope) {
        self.init(
            schema: envelope.schema,
            alg: envelope.alg,
            kdf: envelope.kdf,
            iterations: envelope.iterations,
            salt: envelope.salt,
            nonce: envelope.nonce,
            createdAt: envelope.createdAt,
            authorization: envelope.authorization,
            usesLegacyAuthenticatedData: envelope.usesLegacyAuthenticatedData
        )
    }

    var authenticatedData: Data {
        let metadataJSON: String
        if usesLegacyAuthenticatedData {
            metadataJSON = """
            {"schema":"\(schema)","alg":"\(alg)","kdf":"\(kdf)","iterations":\(iterations),"salt":"\(salt)","nonce":"\(nonce)","createdAt":"\(createdAt)"}
            """
        } else {
            metadataJSON = """
            {"schema":"\(schema)","alg":"\(alg)","kdf":"\(kdf)","iterations":\(iterations),"salt":"\(salt)","nonce":"\(nonce)","createdAt":"\(createdAt)","authorization":\(authorization.authenticatedJSONString)}
            """
        }

        return Data(metadataJSON.utf8)
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
