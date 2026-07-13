import SwiftUI

struct DataPrivacyView: View {
    @EnvironmentObject private var app: AppStore
    @StateObject private var checkIns = ProgressCheckInStore()
    @State private var token = ""
    @State private var includeImages = false
    @State private var exportURL: URL?
    @State private var isWorking = false
    @State private var showDeleteConfirmation = false
    @State private var message: String?

    var body: some View {
        List {
            Section("Private server") {
                LabeledContent("Backup status") { syncLabel }
                SecureField("Bearer token (optional for local server)", text: $token)
                    .textContentType(.password)
                Button("Save server token") {
                    ServerCredentialStore.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    retryBackup()
                }
                Button { retryBackup() } label: { Label("Retry backup", systemImage: "arrow.clockwise") }
                    .disabled(isWorking)
            }

            Section("Export") {
                Toggle("Include encrypted photo contents", isOn: $includeImages)
                Button {
                    createExport()
                } label: {
                    if isWorking { ProgressView() } else { Label("Prepare JSON export", systemImage: "square.and.arrow.up") }
                }
                .disabled(isWorking)
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share BodyCompass export", systemImage: "doc.badge.arrow.up")
                    }
                }
            }

            Section("Delete") {
                Button("Delete all BodyCompass data", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(isWorking)
                Text("Deletes server database records, encrypted server photos, local logs, and local meal/progress photos. Apple Health data is not deleted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message {
                Section { Text(message).font(.callout).foregroundStyle(message.hasPrefix("Could not") ? Theme.warning : .secondary) }
            }
        }
        .navigationTitle("Data & Privacy")
        .onAppear { token = ServerCredentialStore.token ?? "" }
        .confirmationDialog("Delete all BodyCompass data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete server and device data", role: .destructive) { deleteEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. It does not remove data stored by Apple Health.")
        }
    }

    @ViewBuilder private var syncLabel: some View {
        switch app.serverSync {
        case .idle: Text("Not synced").foregroundStyle(.secondary)
        case .syncing: ProgressView()
        case let .synced(date): Text(date.formatted(date: .omitted, time: .shortened)).foregroundStyle(Theme.accent)
        case .failed: Text("Offline").foregroundStyle(Theme.warning)
        }
    }

    private func createExport() {
        isWorking = true
        message = nil
        Task {
            do {
                let data = try await app.exportServerData(includeImages: includeImages)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("BodyCompass-export.json")
                try data.write(to: url, options: [.atomic, .completeFileProtection])
                exportURL = url
                message = "Export prepared."
            } catch {
                message = "Could not export data: \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    private func retryBackup() {
        isWorking = true
        message = nil
        Task {
            await app.syncNow()
            await checkIns.syncAll()
            switch app.serverSync {
            case .failed(let error): message = "Could not back up data: \(error)"
            default: message = "Private backup is up to date."
            }
            isWorking = false
        }
    }

    private func deleteEverything() {
        isWorking = true
        message = nil
        Task {
            do {
                try await app.deleteAllServerData()
                checkIns.deleteAllLocalData()
                ServerCredentialStore.token = nil
                app.deleteAllLocalData()
            } catch {
                message = "Could not delete server data: \(error.localizedDescription). Device data was kept so you can retry."
            }
            isWorking = false
        }
    }
}
