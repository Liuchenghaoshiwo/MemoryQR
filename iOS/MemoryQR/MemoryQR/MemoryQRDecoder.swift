import Foundation

enum MemoryQRDecoder {
    enum DecodeError: Error, Equatable {
        case invalidPayload
        case unsupportedSchema
    }

    static func decode(_ scannedText: String) throws -> MemoryPayload.Memory {
        do {
            return try MemoryPayload.parse(scannedText)
        } catch MemoryPayload.PayloadError.unsupportedSchema {
            throw DecodeError.unsupportedSchema
        } catch {
            throw DecodeError.invalidPayload
        }
    }
}

