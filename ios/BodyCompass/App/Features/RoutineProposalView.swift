import SwiftUI
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

/// Review screen for a Coach routine proposal. The proposal is a preview:
/// only the Confirm button creates a new routine version. Reject leaves the
/// plan untouched. Edit revises the proposal, which still needs confirming.
struct RoutineProposalView: View {
    @EnvironmentObject private var training: TrainingStore
    @Environment(\.dismiss) private var dismiss

    @State private var editingDay: TrainingDay?

    var body: some View {
        NavigationStack {
            Group {
                if let proposal = training.proposal {
                    content(proposal)
                } else {
                    ContentUnavailableView(
                        "No proposal",
                        systemImage: "sparkles",
                        description: Text("Ask Coach to review your week from the Training screen.")
                    )
                }
            }
            .navigationTitle("Coach proposal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $editingDay) { day in
                TrainingDayEditorView(day: day, requireDetail: !training.needsSetup) { edited in
                    reviseProposal(with: edited)
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ proposal: RoutineChangeProposal) -> some View {
        let changes = RoutineDiff.changes(from: training.activeRoutine.days, to: proposal.proposedDays)
        let stale = proposal.isStale(activeVersion: training.activeRoutine.version)

        List {
            if proposal.status != .pending {
                decidedBanner(proposal)
            } else if stale {
                staleBanner
            }

            Section("Why Coach suggests this") {
                ForEach(proposal.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "info.circle")
                        .font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expected benefit")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(proposal.expectedBenefit)
                        .font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery impact")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(proposal.recoveryImpact)
                        .font(.subheadline)
                }
            }

            Section("Exact changes") {
                if changes.isEmpty {
                    Text(stale
                         ? "Your current plan already differs from the one this proposal was built against."
                         : "The proposal matches your current plan — nothing would change.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(changes) { change in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(change.weekday.displayName)
                                .font(.subheadline.bold())
                            beforeAfterRow(label: "Now", text: change.before, color: .secondary)
                            beforeAfterRow(label: "Proposed", text: change.after, color: Theme.accent)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if proposal.status == .pending {
                Section {
                    Button {
                        training.confirmProposal()
                        dismiss()
                    } label: {
                        Label("Confirm — apply as new version", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                    }
                    .disabled(stale || changes.isEmpty)

                    Button {
                        // Edit the first changed day (or Monday as fallback).
                        let weekday = changes.first?.weekday ?? .monday
                        editingDay = proposal.proposedDays.first { $0.weekday == weekday }
                    } label: {
                        Label("Edit before deciding", systemImage: "pencil")
                    }
                    .disabled(stale)

                    Button(role: .destructive) {
                        training.rejectProposal()
                        dismiss()
                    } label: {
                        Label("Reject — keep my plan", systemImage: "xmark.circle")
                    }
                } footer: {
                    Text(stale
                         ? "You've changed your routine since this proposal was made, so it can't be applied. Reject it and ask Coach again."
                         : "Confirming saves the proposed week as a new routine version. You can roll back anytime from History.")
                }
            }
        }
    }

    private func beforeAfterRow(label: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(color)
                .frame(width: 66, alignment: .leading)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func decidedBanner(_ proposal: RoutineChangeProposal) -> some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: proposal.status == .confirmed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(proposal.status == .confirmed ? Theme.accent : Theme.warning)
                Text(proposal.status == .confirmed
                     ? "You confirmed this change. It is now your active routine."
                     : "You rejected this change. Your plan was not modified.")
                    .font(.subheadline)
                Spacer()
                Button("Dismiss") {
                    training.dismissDecidedProposal()
                    dismiss()
                }
                .font(.subheadline.bold())
            }
        }
    }

    private var staleBanner: some View {
        Section {
            Label(
                "This proposal was built against version \(training.proposal?.baseVersion ?? 0) of your routine, but you're now on version \(training.activeRoutine.version).",
                systemImage: "exclamationmark.triangle"
            )
            .font(.subheadline)
            .foregroundStyle(Theme.warning)
        }
    }

    private func reviseProposal(with editedDay: TrainingDay) {
        guard let proposal = training.proposal else { return }
        var days = proposal.proposedDays
        if let index = days.firstIndex(where: { $0.weekday == editedDay.weekday }) {
            days[index] = editedDay
            training.reviseProposal(days: days)
        }
    }
}
