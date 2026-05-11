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

    @State private var selectedMode = Mode.create
    @State private var title = "Beach day"
    @State private var message = "The afternoon light felt golden."
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
                    generateQRCode()
                }

            TextField("Memory message", text: $message, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)
                .onChange(of: message) {
                    generateQRCode()
                }

            Button {
                generateQRCode()
            } label: {
                Label("Generate QR", systemImage: "qrcode")
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

            if !statusMessage.isEmpty {
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
            Text("This QR is not encrypted yet. Authentication, whitelist checks, secure scanning, and encrypted payloads are planned for the next phase.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func generateQRCode() {
        do {
            payload = try MemoryPayload.create(title: title, message: message)
            qrImage = QRCodeGenerator.makeImage(from: payload)
            statusMessage = qrImage == nil ? "QR generation failed." : ""
        } catch {
            payload = ""
            qrImage = nil
            statusMessage = "Could not create a MemoryQR payload."
        }
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
