import Foundation

enum MemoryPayload {
    static let schema = "memoryqr.memory.v1"
    private static let localReaderMode = "local-reader"
    private static let localReaderAllowlistPolicy = "local-reader-allowlist"
    private static let readerIdPattern = #"^[a-z0-9][a-z0-9._:-]{0,63}$"#
    private static let maxAttachments = 8
    private static let maxAttachmentReferencesByteCount = 2048

    enum PayloadError: Error, Equatable {
        case invalidJSON
        case unsupportedSchema
    }

    struct AuthorizationContext: Equatable {
        let localReaderId: String?

        init(localReaderId: String? = nil) {
            self.localReaderId = localReaderId
        }
    }

    struct Authorization: Codable, Equatable {
        let mode: String
        let policy: String
        let allowedReaderIds: [String]

        var requiresLocalReaderId: Bool {
            policy == MemoryPayload.localReaderAllowlistPolicy
        }

        static func localReaderAllowlist(_ readerIds: [String]) throws -> Authorization {
            let normalizedReaderIds = try normalizeAllowedReaderIds(readerIds)
            guard !normalizedReaderIds.isEmpty else {
                throw PayloadError.invalidJSON
            }

            return Authorization(
                mode: MemoryPayload.localReaderMode,
                policy: MemoryPayload.localReaderAllowlistPolicy,
                allowedReaderIds: normalizedReaderIds
            )
        }

        func allows(_ context: AuthorizationContext) -> Bool {
            guard requiresLocalReaderId else {
                return true
            }

            guard let normalizedReaderId = Self.normalizeReaderIdForContext(context.localReaderId) else {
                return false
            }
            return allowedReaderIds.contains(normalizedReaderId)
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

            guard mode == MemoryPayload.localReaderMode,
                  policy == MemoryPayload.localReaderAllowlistPolicy else {
                throw PayloadError.invalidJSON
            }

            self = try .localReaderAllowlist(allowedReaderIds)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(mode, forKey: .mode)
            try container.encode(policy, forKey: .policy)
            try container.encode(allowedReaderIds, forKey: .allowedReaderIds)
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
                of: MemoryPayload.readerIdPattern,
                options: .regularExpression
            ) != nil else {
                throw PayloadError.invalidJSON
            }
            return normalized
        }

        private static func normalizeReaderIdForContext(_ value: String?) -> String? {
            let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard normalized.range(
                of: MemoryPayload.readerIdPattern,
                options: .regularExpression
            ) != nil else {
                return nil
            }
            return normalized
        }

        private enum CodingKeys: String, CodingKey {
            case mode
            case policy
            case allowedReaderIds
        }
    }

    struct Memory: Codable, Equatable {
        typealias AttachmentReference = EncryptedMemoryPayload.AttachmentReference

        let schema: String
        let title: String
        let message: String
        let createdAt: String
        let authorization: Authorization?
        let attachments: [AttachmentReference]

        init(
            schema: String,
            title: String,
            message: String,
            createdAt: String,
            authorization: Authorization? = nil,
            attachments: [AttachmentReference] = []
        ) {
            self.schema = schema
            self.title = title
            self.message = message
            self.createdAt = createdAt
            self.authorization = authorization
            self.attachments = attachments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schema = try container.decode(String.self, forKey: .schema)
            title = try container.decode(String.self, forKey: .title)
            message = try container.decode(String.self, forKey: .message)
            createdAt = try container.decode(String.self, forKey: .createdAt)
            authorization = try container.decodeIfPresent(Authorization.self, forKey: .authorization)
            attachments = try MemoryPayload.validateAttachmentReferences(
                container.decodeIfPresent([AttachmentReference].self, forKey: .attachments) ?? []
            )
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(schema, forKey: .schema)
            try container.encode(title, forKey: .title)
            try container.encode(message, forKey: .message)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(authorization, forKey: .authorization)
            if !attachments.isEmpty {
                try container.encode(attachments, forKey: .attachments)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case schema
            case title
            case message
            case createdAt
            case authorization
            case attachments
        }
    }

    static func create(
        title: String,
        message: String,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        authorization: Authorization? = nil,
        attachments: [Memory.AttachmentReference] = []
    ) throws -> String {
        let memory = Memory(
            schema: schema,
            title: normalize(title, fallback: "Untitled memory"),
            message: normalize(message, fallback: ""),
            createdAt: createdAt,
            authorization: authorization,
            attachments: try validateAttachmentReferences(attachments)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(memory)

        guard let payload = String(data: data, encoding: .utf8) else {
            throw PayloadError.invalidJSON
        }

        return payload
    }

    static func parse(_ payload: String) throws -> Memory {
        guard let data = payload.data(using: .utf8) else {
            throw PayloadError.invalidJSON
        }

        let decoded: Memory

        do {
            decoded = try JSONDecoder().decode(Memory.self, from: data)
        } catch {
            throw PayloadError.invalidJSON
        }

        guard decoded.schema == schema else {
            throw PayloadError.unsupportedSchema
        }

        return Memory(
            schema: decoded.schema,
            title: normalize(decoded.title, fallback: "Untitled memory"),
            message: normalize(decoded.message, fallback: ""),
            createdAt: normalize(decoded.createdAt, fallback: ISO8601DateFormatter().string(from: Date())),
            authorization: decoded.authorization,
            attachments: decoded.attachments
        )
    }

    private static func validateAttachmentReferences(
        _ attachments: [Memory.AttachmentReference]
    ) throws -> [Memory.AttachmentReference] {
        guard attachments.count <= maxAttachments else {
            throw PayloadError.invalidJSON
        }

        var seen = Set<String>()
        for attachment in attachments {
            guard !seen.contains(attachment.id) else {
                throw PayloadError.invalidJSON
            }
            seen.insert(attachment.id)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(attachments)
        guard data.count <= maxAttachmentReferencesByteCount else {
            throw PayloadError.invalidJSON
        }

        return attachments
    }

    private static func normalize(_ value: String, fallback: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? fallback : normalized
    }
}
