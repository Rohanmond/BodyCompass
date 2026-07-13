import SwiftUI

struct DataPrivacyView: View {
    @EnvironmentObject private var app: AppStore
    @EnvironmentObject private var training: TrainingStore
    @EnvironmentObject private var authentication: AuthenticationStore
    @StateObject private var checkIns = ProgressCheckInStore()
    @State private var exportURL: URL?
    @State private var isWorking = false
    @State private var showDeleteConfirmation = false
    @State private var message: String?

    var body: some View {
        List {
            Section("Account") {
                if let user = authentication.user {
                    LabeledContent("Name", value: user.displayName)
                    LabeledContent("Email", value: user.email)
                }
                Button(role: .destructive) {
                    Task { await authentication.signOut() }
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section("Private backup") {
                LabeledContent("Backup status") { syncLabel }
                Button { retryBackup() } label: { Label("Retry backup", systemImage: "arrow.clockwise") }
                    .disabled(isWorking)
            }

            Section("Export") {
                Text("Exports contain saved results and logs only. Meal and progress photos are never retained by BodyCompass.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Button("Delete account and all data", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(isWorking)
                Text("Deletes server database records and local logs. BodyCompass does not retain meal or progress photos. Apple Health data is not deleted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message {
                Section { Text(message).font(.callout).foregroundStyle(message.hasPrefix("Could not") ? Theme.warning : .secondary) }
            }
        }
        .navigationTitle("Data & Privacy")
        .confirmationDialog("Delete your BodyCompass account?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete account and data", role: .destructive) { deleteEverything() }
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
                let data = try await app.exportServerData()
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
                training.deleteAllTrainingData()
                app.deleteAllLocalData()
                authentication.accountWasDeleted()
            } catch {
                message = "Could not delete server data: \(error.localizedDescription). Device data was kept so you can retry."
            }
            isWorking = false
        }
    }
}
