import Photos
import SwiftUI

struct CreateOptionsState: Equatable {
    enum EditorSection: Equatable {
        case encryptToggle
        case passphraseFields
        case readerAllowlistToggle
        case readerAllowlistFields
        case attachmentReferenceToggle
        case attachmentReferenceFields
    }

    var shouldEncrypt = false
    var usesReaderAllowlist = false
    var includesAttachmentReference = false

    var hasOptionalMetadata: Bool {
        usesReaderAllowlist || includesAttachmentReference
    }

    var showsPassphraseFields: Bool {
        shouldEncrypt
    }

    var showsReaderAllowlistFields: Bool {
        usesReaderAllowlist
    }

    var showsAttachmentReferenceFields: Bool {
        includesAttachmentReference
    }

    var metadataRequiresEncryption: Bool {
        false
    }

    var canGenerateAutomatically: Bool {
        !shouldEncrypt && !hasOptionalMetadata
    }

    var visibleEditorSections: [EditorSection] {
        var sections: [EditorSection] = [.encryptToggle]
        if showsPassphraseFields {
            sections.append(.passphraseFields)
        }

        sections.append(.readerAllowlistToggle)
        if showsReaderAllowlistFields {
            sections.append(.readerAllowlistFields)
        }

        sections.append(.attachmentReferenceToggle)
        if showsAttachmentReferenceFields {
            sections.append(.attachmentReferenceFields)
        }

        return sections
    }
}

struct ContentView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case create = "Create"
        case scan = "Scan"

        var id: String {
            rawValue
        }
    }

    private enum CreateError: Error {
        case emptyAllowlist
        case emptyAttachmentReference
    }

    @State private var selectedMode = Mode.create
    @State private var title = "Beach day"
    @State private var message = "The afternoon light felt golden."
    @State private var createOptions = CreateOptionsState()
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var allowedReaderIds = ""
    @State private var attachmentDraft = AttachmentReferenceDraft()
    @State private var payload = ""
    @State private var qrImage: UIImage?
    @State private var statusMessage = ""
    @State private var isSaving = false

    private var securityBoundaryMessage: String {
        if createOptions.shouldEncrypt {
            return "This QR is encrypted with your passphrase. Reader limits and attachment references are independent metadata that can also be used without encryption. Login, account-based whitelist authorization, secure sharing, and real media storage are still future work."
        }

        if createOptions.hasOptionalMetadata {
            return "This QR is not encrypted. Reader limits are local app metadata and attachment references are pointers only; the memory text remains visible to anyone who reads the QR payload directly. Login, account-based whitelist authorization, secure sharing, and real media storage are still future work."
        }

        return "This QR is not encrypted. Turn on passphrase encryption to create an encrypted MemoryQR. Login, whitelist authorization, and secure sharing are still future work."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedMode {
                    case .create:
                        introSection
                        editorSection
                        qrSection
                        payloadSection
                        securityNote
                    case .scan:
                        ScanView()
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("MemoryQR")
            .task {
                generateQRCode()
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create a memory QR")
                .font(.title2.bold())
            Text("This iOS MVP stores a title and message in a local MemoryQR payload, then renders it as a QR image on device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .onChange(of: title) {
                    if createOptions.canGenerateAutomatically {
                        generateQRCode()
                    }
                }

            TextField("Memory message", text: $message, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)
                .onChange(of: message) {
                    if createOptions.canGenerateAutomatically {
                        generateQRCode()
                    }
                }

            Toggle(isOn: $createOptions.shouldEncrypt) {
                Label("Encrypt with passphrase", systemImage: createOptions.shouldEncrypt ? "lock.fill" : "lock.open")
            }
            .onChange(of: createOptions.shouldEncrypt) {
                if createOptions.shouldEncrypt {
                    clearGeneratedQRCode(status: "Enter a passphrase, then generate an encrypted QR.")
                } else {
                    passphrase = ""
                    confirmPassphrase = ""
                    if createOptions.hasOptionalMetadata {
                        clearGeneratedQRCode(status: "Generate again to update the QR.")
                    } else {
                        generateQRCode()
                    }
                }
            }

            if createOptions.showsPassphraseFields {
                SecureField("Passphrase", text: $passphrase)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm passphrase", text: $confirmPassphrase)
                    .textFieldStyle(.roundedBorder)

                Text("The passphrase is not stored. You will need it to recover this encrypted MemoryQR.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(isOn: $createOptions.usesReaderAllowlist) {
                Label("Limit to local reader IDs", systemImage: "person.badge.key")
            }
            .onChange(of: createOptions.usesReaderAllowlist) {
                if createOptions.usesReaderAllowlist {
                    clearGeneratedQRCode(status: createOptions.shouldEncrypt ? "Enter allowed local reader IDs, then generate an encrypted QR." : "Enter allowed local reader IDs, then generate a QR.")
                } else {
                    allowedReaderIds = ""
                    clearGeneratedQRCode(status: "Generate again to update the QR.")
                }
            }

            if createOptions.showsReaderAllowlistFields {
                TextField("Allowed reader IDs, comma-separated", text: $allowedReaderIds)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Text("Reader IDs are local MVP metadata for the decode boundary. They are not account identities or cloud authorization.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(isOn: $createOptions.includesAttachmentReference) {
                Label("Add attachment reference", systemImage: "paperclip")
            }
            .onChange(of: createOptions.includesAttachmentReference) {
                if createOptions.includesAttachmentReference {
                    clearGeneratedQRCode(status: createOptions.shouldEncrypt ? "Enter attachment reference metadata, then generate an encrypted QR." : "Enter attachment reference metadata, then generate a QR.")
                } else {
                    attachmentDraft = AttachmentReferenceDraft()
                    clearGeneratedQRCode(status: "Generate again to update the QR.")
                }
            }

            if createOptions.showsAttachmentReferenceFields {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Attachment type", selection: $attachmentDraft.mediaType) {
                        ForEach(AttachmentReferenceDraft.MediaType.allCases) { mediaType in
                            Text(mediaType.label).tag(mediaType)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Attachment ID", text: $attachmentDraft.id)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    TextField("Byte size", text: $attachmentDraft.size)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    TextField("SHA-256 digest", text: $attachmentDraft.sha256)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    TextField("Encrypted bundle reference", text: $attachmentDraft.encryptedBundleRef)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Text("Attachment references are metadata only. Media bytes are not stored in the QR code.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                generateQRCode()
            } label: {
                Label(createOptions.shouldEncrypt ? "Generate Encrypted QR" : "Generate QR", systemImage: "qrcode")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var qrSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("QR Preview")
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                        .accessibilityLabel("Generated MemoryQR code")
                } else {
                    ContentUnavailableView("No QR code", systemImage: "qrcode", description: Text("Enter a memory to generate a QR image."))
                        .padding()
                }
            }
            .aspectRatio(1, contentMode: .fit)

            Button {
                saveQRCode()
            } label: {
                Label("Save QR Image", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(qrImage == nil || isSaving)

            if !statusMessage.isEmpty && !createOptions.shouldEncrypt {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var payloadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Payload")
                .font(.headline)
            Text(payload)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var securityNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Security boundary", systemImage: "lock.shield")
                .font(.headline)
            Text(securityBoundaryMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func generateQRCode() {
        do {
            if createOptions.shouldEncrypt {
                let memoryPayload = try MemoryPayload.create(title: title, message: message)
                guard !passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    clearGeneratedQRCode(status: "Enter a passphrase before generating an encrypted QR.")
                    return
                }

                guard passphrase == confirmPassphrase else {
                    clearGeneratedQRCode(status: "Passphrases do not match.")
                    return
                }

                let authorization = try encryptedAuthorizationForCurrentInputs()
                let attachments = try attachmentReferencesForCurrentInputs()
                payload = try EncryptedMemoryPayload.create(
                    memoryPayload: memoryPayload,
                    passphrase: passphrase,
                    authorization: authorization,
                    attachments: attachments
                )
            } else {
                payload = try MemoryPayload.create(
                    title: title,
                    message: message,
                    authorization: try plainAuthorizationForCurrentInputs(),
                    attachments: try attachmentReferencesForCurrentInputs()
                )
            }

            qrImage = QRCodeGenerator.makeImage(from: payload)
            statusMessage = qrImage == nil ? "QR generation failed." : ""
        } catch CreateError.emptyAllowlist {
            clearGeneratedQRCode(status: "Enter at least one allowed local reader ID.")
        } catch CreateError.emptyAttachmentReference {
            clearGeneratedQRCode(status: "Enter attachment reference metadata or turn off Add attachment reference.")
        } catch EncryptedMemoryPayload.PayloadError.invalidEnvelope {
            payload = ""
            qrImage = nil
            statusMessage = "Could not create a MemoryQR payload. Check reader IDs and attachment metadata."
        } catch MemoryPayload.PayloadError.invalidJSON {
            payload = ""
            qrImage = nil
            statusMessage = "Could not create a MemoryQR payload. Check reader IDs and attachment metadata."
        } catch {
            payload = ""
            qrImage = nil
            statusMessage = "Could not create a MemoryQR payload."
        }
    }

    private func encryptedAuthorizationForCurrentInputs() throws -> EncryptedMemoryPayload.Authorization {
        guard createOptions.usesReaderAllowlist else {
            return .passphraseOnly
        }

        let readerIds = allowedReaderIds
            .split(separator: ",")
            .map(String.init)

        guard !readerIds.isEmpty else {
            throw CreateError.emptyAllowlist
        }

        return try .localReaderAllowlist(readerIds)
    }

    private func plainAuthorizationForCurrentInputs() throws -> MemoryPayload.Authorization? {
        guard createOptions.usesReaderAllowlist else {
            return nil
        }

        let readerIds = allowedReaderIds
            .split(separator: ",")
            .map(String.init)

        guard !readerIds.isEmpty else {
            throw CreateError.emptyAllowlist
        }

        return try .localReaderAllowlist(readerIds)
    }

    private func attachmentReferencesForCurrentInputs() throws -> [EncryptedMemoryPayload.AttachmentReference] {
        guard createOptions.includesAttachmentReference else {
            return []
        }

        guard let attachmentReference = try attachmentDraft.makeAttachmentReference() else {
            throw CreateError.emptyAttachmentReference
        }

        return [attachmentReference]
    }

    private func clearGeneratedQRCode(status: String) {
        payload = ""
        qrImage = nil
        statusMessage = status
    }

    private func saveQRCode() {
        guard let qrImage else {
            return
        }

        isSaving = true
        statusMessage = "Saving..."

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    isSaving = false
                    statusMessage = "Photo library permission is required to save the QR image."
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: qrImage)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    isSaving = false
                    if success {
                        statusMessage = "QR image saved to Photos."
                    } else {
                        statusMessage = error?.localizedDescription ?? "Could not save the QR image."
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
