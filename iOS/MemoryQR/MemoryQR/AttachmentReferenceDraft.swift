import Foundation

struct AttachmentReferenceDraft: Equatable {
    enum MediaType: String, CaseIterable, Identifiable {
        case image
        case audio
        case video

        var id: String {
            rawValue
        }

        var label: String {
            rawValue.capitalized
        }
    }

    var id = ""
    var mediaType: MediaType = .image
    var size = ""
    var sha256 = ""
    var encryptedBundleRef = ""

    var isEmpty: Bool {
        id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            size.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            sha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            encryptedBundleRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func makeAttachmentReference() throws -> EncryptedMemoryPayload.AttachmentReference? {
        if isEmpty {
            return nil
        }

        guard let byteSize = Int(size.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw EncryptedMemoryPayload.PayloadError.invalidEnvelope
        }

        return try .localEncryptedBundle(
            id: id,
            type: mediaType.rawValue,
            size: byteSize,
            sha256: sha256,
            encryptedBundleRef: encryptedBundleRef
        )
    }
}
