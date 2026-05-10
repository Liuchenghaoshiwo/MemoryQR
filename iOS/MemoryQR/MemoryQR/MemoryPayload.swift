import Foundation

enum MemoryPayload {
    static let schema = "memoryqr.memory.v1"

    enum PayloadError: Error, Equatable {
        case invalidJSON
        case unsupportedSchema
    }

    struct Memory: Codable, Equatable {
        let schema: String
        let title: String
        let message: String
        let createdAt: String
    }

    static func create(
        title: String,
        message: String,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> String {
        let memory = Memory(
            schema: schema,
            title: normalize(title, fallback: "Untitled memory"),
            message: normalize(message, fallback: ""),
            createdAt: createdAt
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
            createdAt: normalize(decoded.createdAt, fallback: ISO8601DateFormatter().string(from: Date()))
        )
    }

    private static func normalize(_ value: String, fallback: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? fallback : normalized
    }
}

