import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ScanView: View {
    @State private var cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var decodedMemory: MemoryPayload.Memory?
    @State private var gatedPlainMemory: MemoryPayload.Memory?
    @State private var gatedPlainPayload = ""
    @State private var lockedEnvelope: EncryptedMemoryPayload.Envelope?
    @State private var lockedEnvelopePayload = ""
    @State private var unlockPassphrase = ""
    @State private var localReaderId = ""
    @State private var rawPayload = ""
    @State private var flowState = ScanFlowState()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            introSection
            cameraSection
            photoSection
            statusSection
            lockedSection
            resultSection
            securityNote
        }
        .onChange(of: selectedPhoto) {
            loadSelectedPhoto()
        }
        .onAppear {
            cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recover a memory")
                .font(.title2.bold())
            Text("Scan a MemoryQR with the camera or choose a QR image from Photos. Plain payloads open directly; encrypted payloads require the passphrase.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Camera Scan")
                .font(.headline)

            switch cameraAuthorization {
            case .authorized:
                if flowState.isCameraScanActive {
                    CameraScannerView(
                        onCodeScanned: { scannedText in
                            flowState.stopCameraScan()
                            handleScannedText(scannedText)
                        },
                        onError: { message in
                            flowState.statusMessage = message
                        }
                    )
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .center) {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.7), lineWidth: 2)
                            .frame(width: 210, height: 210)
                    }

                    Button {
                        flowState.stopCameraScan()
                    } label: {
                        Label("Stop Camera Scan", systemImage: "camera.badge.ellipsis")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        flowState.startCameraScan()
                    } label: {
                        Label("Start Camera Scan", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .notDetermined:
                Button {
                    requestCameraAccess()
                } label: {
                    Label("Enable Camera Scan", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

            case .denied, .restricted:
                Label("Camera permission is required for live scanning. You can still import a QR image from Photos.", systemImage: "camera.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            @unknown default:
                Label("Camera status is unavailable. Try importing a QR image from Photos.", systemImage: "camera.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Photo Import")
                .font(.headline)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(flowState.isLoadingPhoto ? "Reading QR Image..." : "Choose QR Image", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(flowState.isLoadingPhoto)
            .simultaneousGesture(TapGesture().onEnded {
                flowState.stopCameraScan()
            })
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusSection: some View {
        if !flowState.statusMessage.isEmpty {
            Label(flowState.statusMessage, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var lockedSection: some View {
        if let gatedPlainMemory {
            VStack(alignment: .leading, spacing: 14) {
                Label("Local Reader MemoryQR", systemImage: "person.badge.key")
                    .font(.headline)

                Text("This QR declares a local reader allowlist. Enter this device's local reader ID to show the memory.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(gatedPlainMemory.createdAt, systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !gatedPlainMemory.attachments.isEmpty {
                    attachmentReferencesSection(gatedPlainMemory.attachments)
                }

                TextField("Local reader ID", text: $localReaderId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Button {
                    showPlainMemoryAfterReaderCheck()
                } label: {
                    Label("Show MemoryQR", systemImage: "person.badge.key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        } else if let lockedEnvelope {
            VStack(alignment: .leading, spacing: 14) {
                Label("Encrypted MemoryQR", systemImage: "lock.fill")
                    .font(.headline)

                Text("Enter the passphrase used to create this QR code.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(lockedEnvelope.createdAt, systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !lockedEnvelope.attachments.isEmpty {
                    attachmentReferencesSection(lockedEnvelope.attachments)
                }

                if lockedEnvelope.authorization.requiresLocalReaderId {
                    Text("This QR declares a local reader allowlist. Enter this device's local reader ID before unlocking.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Local reader ID", text: $localReaderId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                }

                SecureField("Passphrase", text: $unlockPassphrase)
                    .textFieldStyle(.roundedBorder)

                Button {
                    unlockEncryptedMemory()
                } label: {
                    Label("Unlock MemoryQR", systemImage: "lock.open")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let decodedMemory {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recovered Memory")
                    .font(.headline)
                Text(decodedMemory.title)
                    .font(.title3.bold())
                Text(decodedMemory.message.isEmpty ? "No message." : decodedMemory.message)
                    .foregroundStyle(.primary)
                Label(decodedMemory.createdAt, systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let authorization = decodedMemory.authorization,
                   authorization.requiresLocalReaderId {
                    Label("Local reader allowlist matched.", systemImage: "person.badge.key")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !decodedMemory.attachments.isEmpty {
                    attachmentReferencesSection(decodedMemory.attachments)
                }

                if !rawPayload.isEmpty {
                    Text(rawPayload)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var securityNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Passphrase encryption", systemImage: "lock.shield")
                .font(.headline)
            Text("This scanner can recover plain MemoryQR JSON or unlock passphrase-encrypted MemoryQR envelopes. Local reader allowlists and attachment references are MVP metadata only; login, account-based whitelist authorization, secure sharing, and real media storage are still future work.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func attachmentReferencesSection(
        _ attachments: [EncryptedMemoryPayload.AttachmentReference]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Attachment References", systemImage: "paperclip")
                .font(.subheadline.bold())

            ForEach(attachments, id: \.id) { attachment in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(attachment.id) · \(attachment.type)")
                        .font(.footnote.bold())
                    Text("\(attachment.size) bytes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(attachment.sha256)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)
                    Text(attachment.storage.encryptedBundleRef)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { _ in
            DispatchQueue.main.async {
                cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    private func loadSelectedPhoto() {
        guard let selectedPhoto else {
            return
        }

        flowState.beginPhotoImport()

        Task {
            do {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw QRImageDecoder.DecodeError.unreadableImage
                }

                let decodedPayload = try QRImageDecoder.decode(from: image)
                await MainActor.run {
                    handleScannedText(decodedPayload)
                    flowState.finishPhotoImport()
                }
            } catch QRImageDecoder.DecodeError.noQRCodeFound {
                await MainActor.run {
                    decodedMemory = nil
                    clearPlainGate()
                    clearLockedEnvelope()
                    rawPayload = ""
                    flowState.failPhotoImportNoQRCode()
                }
            } catch {
                await MainActor.run {
                    decodedMemory = nil
                    clearPlainGate()
                    clearLockedEnvelope()
                    rawPayload = ""
                    flowState.failPhotoImportUnreadable()
                }
            }
        }
    }

    private func handleScannedText(_ scannedText: String) {
        do {
            let result = try MemoryQRDecoder.inspect(scannedText)
            switch result {
            case .plain(let memory):
                if let authorization = memory.authorization,
                   authorization.requiresLocalReaderId {
                    decodedMemory = nil
                    clearLockedEnvelope()
                    gatedPlainMemory = memory
                    gatedPlainPayload = scannedText
                    localReaderId = ""
                    rawPayload = ""
                    flowState.statusMessage = "MemoryQR found. Enter your local reader ID to show it."
                } else {
                    showDecodedMemory(memory, payload: scannedText, status: "MemoryQR decoded.")
                }
            case .encrypted(let envelope):
                decodedMemory = nil
                clearPlainGate()
                lockedEnvelope = envelope
                lockedEnvelopePayload = scannedText
                unlockPassphrase = ""
                localReaderId = ""
                rawPayload = ""
                flowState.statusMessage = envelope.authorization.requiresLocalReaderId ? "Encrypted MemoryQR found. Enter your local reader ID and passphrase to unlock it." : "Encrypted MemoryQR found. Enter the passphrase to unlock it."
            }
        } catch MemoryQRDecoder.DecodeError.unsupportedSchema {
            decodedMemory = nil
            clearPlainGate()
            clearLockedEnvelope()
            rawPayload = scannedText
            flowState.statusMessage = "This MemoryQR schema is not supported yet."
        } catch {
            decodedMemory = nil
            clearPlainGate()
            clearLockedEnvelope()
            rawPayload = scannedText
            flowState.statusMessage = "This QR code is not a valid MemoryQR payload."
        }
    }

    private func showPlainMemoryAfterReaderCheck() {
        guard let gatedPlainMemory,
              let authorization = gatedPlainMemory.authorization else {
            return
        }

        guard authorization.allows(.init(localReaderId: localReaderId)) else {
            decodedMemory = nil
            rawPayload = ""
            flowState.statusMessage = "This local reader ID is not authorized for this MemoryQR."
            return
        }

        showDecodedMemory(gatedPlainMemory, payload: gatedPlainPayload, status: "MemoryQR decoded.")
    }

    private func unlockEncryptedMemory() {
        do {
            let context = EncryptedMemoryPayload.AuthorizationContext(localReaderId: localReaderId)
            let memory = try MemoryQRDecoder.decrypt(
                lockedEnvelopePayload,
                passphrase: unlockPassphrase,
                authorizationContext: context
            )
            decodedMemory = memory
            rawPayload = lockedEnvelopePayload
            clearLockedEnvelope()
            clearPlainGate()
            flowState.statusMessage = "Encrypted MemoryQR unlocked."
        } catch MemoryQRDecoder.DecodeError.emptyPassphrase {
            flowState.statusMessage = "Enter the passphrase for this encrypted MemoryQR."
        } catch MemoryQRDecoder.DecodeError.unauthorizedReader {
            decodedMemory = nil
            rawPayload = ""
            flowState.statusMessage = "This local reader ID is not authorized for this MemoryQR."
        } catch {
            decodedMemory = nil
            rawPayload = ""
            flowState.statusMessage = "Could not decrypt this MemoryQR with that passphrase."
        }
    }

    private func clearLockedEnvelope() {
        lockedEnvelope = nil
        lockedEnvelopePayload = ""
        unlockPassphrase = ""
        localReaderId = ""
    }

    private func clearPlainGate() {
        gatedPlainMemory = nil
        gatedPlainPayload = ""
        localReaderId = ""
    }

    private func showDecodedMemory(
        _ memory: MemoryPayload.Memory,
        payload: String,
        status: String
    ) {
        decodedMemory = memory
        rawPayload = payload
        clearPlainGate()
        clearLockedEnvelope()
        flowState.statusMessage = status
    }
}

struct ScanFlowState: Equatable {
    var isCameraScanActive = false
    var isLoadingPhoto = false
    var statusMessage = ""

    mutating func startCameraScan() {
        isCameraScanActive = true
        statusMessage = ""
    }

    mutating func stopCameraScan() {
        isCameraScanActive = false
    }

    mutating func beginPhotoImport() {
        isCameraScanActive = false
        isLoadingPhoto = true
        statusMessage = "Reading selected image..."
    }

    mutating func finishPhotoImport() {
        isLoadingPhoto = false
    }

    mutating func failPhotoImportNoQRCode() {
        isCameraScanActive = false
        isLoadingPhoto = false
        statusMessage = "No QR code was found in that image."
    }

    mutating func failPhotoImportUnreadable() {
        isCameraScanActive = false
        isLoadingPhoto = false
        statusMessage = "That image could not be read as a MemoryQR."
    }
}

#Preview {
    ScrollView {
        ScanView()
            .padding(20)
    }
    .background(Color(.systemGroupedBackground))
}
