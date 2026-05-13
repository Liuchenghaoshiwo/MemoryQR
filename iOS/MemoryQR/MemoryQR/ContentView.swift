import Photos
import SwiftUI

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
    }

    @State private var selectedMode = Mode.create
    @State private var title = "Beach day"
    @State private var message = "The afternoon light felt golden."
    @State private var shouldEncrypt = false
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var usesReaderAllowlist = false
    @State private var allowedReaderIds = ""
    @State private var payload = ""
    @State private var qrImage: UIImage?
    @State private var statusMessage = ""
    @State private var isSaving = false

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
                    if !shouldEncrypt {
                        generateQRCode()
                    }
                }

            TextField("Memory message", text: $message, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)
                .onChange(of: message) {
                    if !shouldEncrypt {
                        generateQRCode()
                    }
                }

            Toggle(isOn: $shouldEncrypt) {
                Label("Encrypt with passphrase", systemImage: shouldEncrypt ? "lock.fill" : "lock.open")
            }
            .onChange(of: shouldEncrypt) {
                if shouldEncrypt {
                    clearGeneratedQRCode(status: "Enter a passphrase, then generate an encrypted QR.")
                } else {
                    passphrase = ""
                    confirmPassphrase = ""
                    usesReaderAllowlist = false
                    allowedReaderIds = ""
                    generateQRCode()
                }
            }

            if shouldEncrypt {
                SecureField("Passphrase", text: $passphrase)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm passphrase", text: $confirmPassphrase)
                    .textFieldStyle(.roundedBorder)

                Text("The passphrase is not stored. You will need it to recover this encrypted MemoryQR.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $usesReaderAllowlist) {
                    Label("Limit to local reader IDs", systemImage: "person.badge.key")
                }
                .onChange(of: usesReaderAllowlist) {
                    if usesReaderAllowlist {
                        clearGeneratedQRCode(status: "Enter allowed local reader IDs, then generate an encrypted QR.")
                    } else {
                        allowedReaderIds = ""
                        clearGeneratedQRCode(status: "Generate again to update the encrypted QR.")
                    }
                }

                if usesReaderAllowlist {
                    TextField("Allowed reader IDs, comma-separated", text: $allowedReaderIds)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Text("Reader IDs are local MVP metadata for the decode boundary. They are not account identities or cloud authorization.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                generateQRCode()
            } label: {
                Label(shouldEncrypt ? "Generate Encrypted QR" : "Generate QR", systemImage: "qrcode")
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

            if !statusMessage.isEmpty && !shouldEncrypt {
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
            Text(shouldEncrypt ? "This QR is encrypted with your passphrase. A local reader allowlist can gate the decode flow, but login, account-based whitelist authorization, secure sharing, and media attachments are still future work." : "This QR is not encrypted. Turn on passphrase encryption to create an encrypted MemoryQR. Login, whitelist authorization, and secure sharing are still future work.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func generateQRCode() {
        do {
            let memoryPayload = try MemoryPayload.create(title: title, message: message)
            if shouldEncrypt {
                guard !passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    clearGeneratedQRCode(status: "Enter a passphrase before generating an encrypted QR.")
                    return
                }

                guard passphrase == confirmPassphrase else {
                    clearGeneratedQRCode(status: "Passphrases do not match.")
                    return
                }

                let authorization = try authorizationForCurrentInputs()
                payload = try EncryptedMemoryPayload.create(
                    memoryPayload: memoryPayload,
                    passphrase: passphrase,
                    authorization: authorization
                )
            } else {
                payload = memoryPayload
            }

            qrImage = QRCodeGenerator.makeImage(from: payload)
            statusMessage = qrImage == nil ? "QR generation failed." : ""
        } catch CreateError.emptyAllowlist {
            clearGeneratedQRCode(status: "Enter at least one allowed local reader ID.")
        } catch EncryptedMemoryPayload.PayloadError.invalidEnvelope {
            payload = ""
            qrImage = nil
            statusMessage = "Could not create a MemoryQR payload. Reader IDs can use letters, numbers, dots, dashes, underscores, or colons."
        } catch {
            payload = ""
            qrImage = nil
            statusMessage = "Could not create a MemoryQR payload."
        }
    }

    private func authorizationForCurrentInputs() throws -> EncryptedMemoryPayload.Authorization {
        guard usesReaderAllowlist else {
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
