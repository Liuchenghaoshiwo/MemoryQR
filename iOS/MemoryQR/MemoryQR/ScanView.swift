import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ScanView: View {
    @State private var cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var decodedMemory: MemoryPayload.Memory?
    @State private var lockedEnvelope: EncryptedMemoryPayload.Envelope?
    @State private var lockedEnvelopePayload = ""
    @State private var unlockPassphrase = ""
    @State private var rawPayload = ""
    @State private var statusMessage = ""
    @State private var isLoadingPhoto = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            introSection
            cameraSection
            photoSection
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
                CameraScannerView(
                    onCodeScanned: { scannedText in
                        handleScannedText(scannedText)
                    },
                    onError: { message in
                        statusMessage = message
                    }
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .center) {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.7), lineWidth: 2)
                        .frame(width: 210, height: 210)
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

            if !statusMessage.isEmpty {
                Text(statusMessage)
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
                Label(isLoadingPhoto ? "Reading QR Image..." : "Choose QR Image", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isLoadingPhoto)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var lockedSection: some View {
        if let lockedEnvelope {
            VStack(alignment: .leading, spacing: 14) {
                Label("Encrypted MemoryQR", systemImage: "lock.fill")
                    .font(.headline)

                Text("Enter the passphrase used to create this QR code.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(lockedEnvelope.createdAt, systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

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
            Text("This scanner can recover plain MemoryQR JSON or unlock passphrase-encrypted MemoryQR envelopes. Login, whitelist authorization, secure sharing, and media attachments are still future work.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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

        isLoadingPhoto = true
        statusMessage = "Reading selected image..."

        Task {
            do {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw QRImageDecoder.DecodeError.unreadableImage
                }

                let decodedPayload = try QRImageDecoder.decode(from: image)
                await MainActor.run {
                    handleScannedText(decodedPayload)
                    isLoadingPhoto = false
                }
            } catch QRImageDecoder.DecodeError.noQRCodeFound {
                await MainActor.run {
                    decodedMemory = nil
                    clearLockedEnvelope()
                    rawPayload = ""
                    statusMessage = "No QR code was found in that image."
                    isLoadingPhoto = false
                }
            } catch {
                await MainActor.run {
                    decodedMemory = nil
                    clearLockedEnvelope()
                    rawPayload = ""
                    statusMessage = "That image could not be read as a MemoryQR."
                    isLoadingPhoto = false
                }
            }
        }
    }

    private func handleScannedText(_ scannedText: String) {
        do {
            let result = try MemoryQRDecoder.inspect(scannedText)
            switch result {
            case .plain(let memory):
                decodedMemory = memory
                clearLockedEnvelope()
                rawPayload = scannedText
                statusMessage = "MemoryQR decoded."
            case .encrypted(let envelope):
                decodedMemory = nil
                lockedEnvelope = envelope
                lockedEnvelopePayload = scannedText
                unlockPassphrase = ""
                rawPayload = ""
                statusMessage = "Encrypted MemoryQR found. Enter the passphrase to unlock it."
            }
        } catch MemoryQRDecoder.DecodeError.unsupportedSchema {
            decodedMemory = nil
            clearLockedEnvelope()
            rawPayload = scannedText
            statusMessage = "This MemoryQR schema is not supported yet."
        } catch {
            decodedMemory = nil
            clearLockedEnvelope()
            rawPayload = scannedText
            statusMessage = "This QR code is not a valid MemoryQR payload."
        }
    }

    private func unlockEncryptedMemory() {
        do {
            let memory = try MemoryQRDecoder.decrypt(lockedEnvelopePayload, passphrase: unlockPassphrase)
            decodedMemory = memory
            rawPayload = lockedEnvelopePayload
            clearLockedEnvelope()
            statusMessage = "Encrypted MemoryQR unlocked."
        } catch MemoryQRDecoder.DecodeError.emptyPassphrase {
            statusMessage = "Enter the passphrase for this encrypted MemoryQR."
        } catch {
            decodedMemory = nil
            rawPayload = ""
            statusMessage = "Could not decrypt this MemoryQR with that passphrase."
        }
    }

    private func clearLockedEnvelope() {
        lockedEnvelope = nil
        lockedEnvelopePayload = ""
        unlockPassphrase = ""
    }
}

#Preview {
    ScrollView {
        ScanView()
            .padding(20)
    }
    .background(Color(.systemGroupedBackground))
}
