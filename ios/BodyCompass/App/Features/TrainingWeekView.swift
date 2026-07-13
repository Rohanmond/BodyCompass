import SwiftUI
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

/// The repeating weekly program: seven days, editable, versioned.
struct TrainingWeekView: View {
    @EnvironmentObject private var training: TrainingStore

    @State private var showingSetup = false
    @State private var showingHistory = false
    @State private var showingProposal = false
    @State private var editingDay: TrainingDay?
    @State private var pendingEditedDay: TrainingDay?
    @State private var editWarnings: [String] = []
    @State private var validationMessages: [String] = []
    @State private var proposalNotice: String?

    var body: some View {
        List {
            if training.needsSetup {
                setupBanner
            }
            if let proposal = training.proposal, proposal.status == .pending {
                proposalBanner
            }

            Section {
                ForEach(training.activeRoutine.days) { day in
                    Button {
                        editingDay = day
                    } label: {
                        dayRow(day)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Week · version \(training.activeRoutine.version)")
            } footer: {
                Text("Tap a day to edit it. Edits are saved as a new version, and you can restore any earlier version from History.")
            }

            Section {
                Button {
                    handleProposalRequest()
                } label: {
                    Label("Ask Coach to review my week (mock)", systemImage: "sparkles")
                }
            } footer: {
                Text("Coach suggestions are previews until you confirm them. Nothing changes your plan silently.")
            }
        }
        .navigationTitle("Training week")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingHistory = true
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(isPresented: $showingSetup) {
            TrainingSetupView()
        }
        .sheet(isPresented: $showingHistory) {
            RoutineVersionHistoryView()
        }
        .sheet(isPresented: $showingProposal) {
            RoutineProposalView()
        }
        .sheet(item: $editingDay) { day in
            TrainingDayEditorView(day: day, requireDetail: !training.needsSetup) { edited in
                reviewAndSave(edited)
            }
        }
        .alert("Heads up", isPresented: warningAlertBinding) {
            Button("Save anyway") { commitPendingEdit() }
            Button("Cancel", role: .cancel) { pendingEditedDay = nil; editWarnings = [] }
        } message: {
            Text(editWarnings.joined(separator: "\n\n"))
        }
        .alert("Can't save this edit", isPresented: validationAlertBinding) {
            Button("OK", role: .cancel) { validationMessages = [] }
        } message: {
            Text(validationMessages.joined(separator: "\n"))
        }
        .alert("Coach", isPresented: proposalNoticeBinding) {
            Button("OK", role: .cancel) { proposalNotice = nil }
        } message: {
            Text(proposalNotice ?? "")
        }
    }

    // MARK: - Rows and banners

    private func dayRow(_ day: TrainingDay) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(day.weekday.shortName)
                .font(.subheadline.bold())
                .frame(width: 44, alignment: .leading)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 4) {
                if day.sessions.isEmpty {
                    Text("Rest")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(day.sessions) { session in
                        HStack(spacing: 6) {
                            Image(systemName: session.kind.systemImage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(session.title)
                            if let plan = session.swimPlan {
                                Text("· \(plan.targetMinutes) min \(plan.intensity.displayName.lowercased())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var setupBanner: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Finish your training setup")
                    .font(.headline)
                Text("Answer four quick questions (experience, equipment, limitations, swim time) and the split fills in with exact exercises, sets, and effort targets. No guessed weights — ever.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Set up my program") {
                    showingSetup = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .padding(.vertical, 4)
        }
    }

    private var proposalBanner: some View {
        Section {
            Button {
                showingProposal = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coach suggested a change")
                            .font(.subheadline.bold())
                        Text("Review the before/after and decide. Your plan is untouched until you confirm.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Edit flow

    private func reviewAndSave(_ edited: TrainingDay) {
        var days = training.activeRoutine.days
        guard let index = days.firstIndex(where: { $0.weekday == edited.weekday }) else { return }
        days[index] = edited

        let warnings = training.editWarnings(for: days)
        if warnings.isEmpty {
            saveEdit(days: days, summary: "Edited \(edited.weekday.displayName)")
        } else {
            pendingEditedDay = edited
            editWarnings = warnings
        }
    }

    private func commitPendingEdit() {
        guard let edited = pendingEditedDay else { return }
        var days = training.activeRoutine.days
        if let index = days.firstIndex(where: { $0.weekday == edited.weekday }) {
            days[index] = edited
            saveEdit(days: days, summary: "Edited \(edited.weekday.displayName)")
        }
        pendingEditedDay = nil
        editWarnings = []
    }

    private func saveEdit(days: [TrainingDay], summary: String) {
        let errors = training.saveManualEdit(days: days, summary: summary)
        if !errors.isEmpty {
            validationMessages = errors.map(\.message)
        }
    }

    private func handleProposalRequest() {
        switch training.requestMockProposal() {
        case .created:
            showingProposal = true
        case .needsSetup:
            proposalNotice = "Coach won't program changes without knowing your experience, equipment, limitations, and swim load. Finish the training setup first."
        case .alreadyPending:
            showingProposal = true
        }
    }

    // MARK: - Alert bindings

    private var warningAlertBinding: Binding<Bool> {
        Binding(get: { !editWarnings.isEmpty }, set: { if !$0 { editWarnings = [] } })
    }

    private var validationAlertBinding: Binding<Bool> {
        Binding(get: { !validationMessages.isEmpty }, set: { if !$0 { validationMessages = [] } })
    }

    private var proposalNoticeBinding: Binding<Bool> {
        Binding(get: { proposalNotice != nil }, set: { if !$0 { proposalNotice = nil } })
    }
}

/// Every saved version of the routine, newest first, with one-tap restore.
struct RoutineVersionHistoryView: View {
    @EnvironmentObject private var training: TrainingStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(training.versions.reversed()) { routine in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Version \(routine.version)")
                                .font(.headline)
                            if routine.id == training.activeRoutine.id {
                                Text("ACTIVE")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.accent.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundStyle(Theme.accent)
                            }
                            Spacer()
                            Text(routine.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(routine.source.displayName) · \(routine.changeSummary)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(routine.days.map { "\($0.weekday.shortName): \($0.summary)" }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(3)
                        if routine.id != training.activeRoutine.id {
                            Button("Restore this version") {
                                training.rollback(to: routine)
                                dismiss()
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Routine history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
