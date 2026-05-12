import Foundation

enum MemoryQRDecoder {
    enum DecodeError: Error, Equatable {
        case invalidPayload
        case unsupportedSchema
        case emptyPassphrase
        case decryptionFailed
    }

    enum DecodeResult: Equatable {
        case plain(MemoryPayload.Memory)
        case encrypted(EncryptedMemoryPayload.Envelope)
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

    static func inspect(_ scannedText: String) throws -> DecodeResult {
        do {
            return try .plain(MemoryPayload.parse(scannedText))
        } catch MemoryPayload.PayloadError.unsupportedSchema {
            return try inspectEncrypted(scannedText)
        } catch {
            do {
                return try inspectEncrypted(scannedText)
            } catch DecodeError.unsupportedSchema {
                throw DecodeError.invalidPayload
            }
        }
    }

    static func decrypt(_ envelopePayload: String, passphrase: String) throws -> MemoryPayload.Memory {
        do {
            return try EncryptedMemoryPayload.decrypt(envelopePayload, passphrase: passphrase)
        } catch EncryptedMemoryPayload.PayloadError.emptyPassphrase {
            throw DecodeError.emptyPassphrase
        } catch EncryptedMemoryPayload.PayloadError.unsupportedSchema {
            throw DecodeError.unsupportedSchema
        } catch EncryptedMemoryPayload.PayloadError.unsupportedAlgorithm {
            throw DecodeError.unsupportedSchema
        } catch {
            throw DecodeError.decryptionFailed
        }
    }

    private static func inspectEncrypted(_ scannedText: String) throws -> DecodeResult {
        do {
            return try .encrypted(EncryptedMemoryPayload.inspect(scannedText))
        } catch EncryptedMemoryPayload.PayloadError.unsupportedSchema {
            throw DecodeError.unsupportedSchema
        } catch EncryptedMemoryPayload.PayloadError.unsupportedAlgorithm {
            throw DecodeError.unsupportedSchema
        } catch {
            throw DecodeError.invalidPayload
        }
    }
}
