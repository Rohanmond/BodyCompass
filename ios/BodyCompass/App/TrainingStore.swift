import Foundation
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

/// Owns the structured weekly training program: routine versions, the setup
/// questionnaire, one-day exceptions, workout logs, and pending Coach
/// proposals. Separate from AppStore's generic daily habit schedule on
/// purpose — this store owns programming, performance, and progression.
@MainActor
final class TrainingStore: ObservableObject {
    private enum StorageKey {
        static let versions = "bodycompass.training.versions"
        static let setup = "bodycompass.training.setup"
        static let exceptions = "bodycompass.training.exceptions"
        static let strengthLogs = "bodycompass.training.strengthLogs"
        static let swimLogs = "bodycompass.training.swimLogs"
        static let proposal = "bodycompass.training.proposal"
    }

    private let defaults: UserDefaults
    private let watchSync = PhoneWatchSyncService.shared

    @Published private(set) var versions: [TrainingRoutine] = []
    @Published private(set) var setup: TrainingSetup?
    @Published private(set) var exceptions: [TrainingDayException] = []
    @Published private(set) var strengthLogs: [ExerciseSetLog] = []
    @Published private(set) var swimLogs: [SwimSessionLog] = []
    @Published private(set) var proposal: RoutineChangeProposal?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        versions = Self.load([TrainingRoutine].self, key: StorageKey.versions, from: defaults) ?? []
        setup = Self.load(TrainingSetup.self, key: StorageKey.setup, from: defaults)
        exceptions = Self.load([TrainingDayException].self, key: StorageKey.exceptions, from: defaults) ?? []
        strengthLogs = Self.load([ExerciseSetLog].self, key: StorageKey.strengthLogs, from: defaults) ?? []
        swimLogs = Self.load([SwimSessionLog].self, key: StorageKey.swimLogs, from: defaults) ?? []
        proposal = Self.load(RoutineChangeProposal.self, key: StorageKey.proposal, from: defaults)

        // First launch: seed the documented weekly split so the user always
        // has a plan to look at, even before answering the setup questions.
        if versions.isEmpty {
            versions = [TrainingRoutineSeeder.skeleton()]
            persist(versions, key: StorageKey.versions)
        }

        watchSync.onStrengthLog = { [weak self] log, acknowledge in
            Task { @MainActor in
                self?.mergeWatchStrengthLog(log)
                acknowledge()
            }
        }
        watchSync.onSwimLog = { [weak self] log, acknowledge in
            Task { @MainActor in
                self?.mergeWatchSwimLog(log)
                acknowledge()
            }
        }
        watchSync.activate()
        syncWatchContext()
    }

    // MARK: - Routine access

    var activeRoutine: TrainingRoutine {
        versions.last ?? TrainingRoutineSeeder.skeleton()
    }

    /// Until the questionnaire is answered we only show the split skeleton;
    /// detailed sets/reps are never invented without experience, equipment,
    /// limitations, and swim-load context.
    var needsSetup: Bool { setup == nil }

    func effectiveDay(for date: Date = Date()) -> EffectiveTrainingDay {
        let weekday = Weekday(calendarWeekday: Calendar.current.component(.weekday, from: date))
        return TrainingScheduleResolver.effectiveDay(
            routine: activeRoutine,
            weekday: weekday,
            dateKey: HealthKitService.dayKey(for: date),
            exceptions: exceptions
        )
    }

    // MARK: - Setup

    func completeSetup(_ newSetup: TrainingSetup) {
        setup = newSetup
        if let data = try? JSONEncoder().encode(newSetup) {
            defaults.set(data, forKey: StorageKey.setup)
        }
        let detailed = TrainingRoutineSeeder.detailed(setup: newSetup, version: nextVersionNumber)
        appendVersion(detailed)
    }

    // MARK: - Manual edits & versions

    /// Validates and saves a manual edit as a new active version. Returns
    /// validation errors instead of saving when the edit is invalid; the
    /// caller shows them and nothing changes.
    @discardableResult
    func saveManualEdit(days: [TrainingDay], summary: String) -> [RoutineValidationError] {
        let errors = RoutineValidator.validate(days: days, requireDetail: !needsSetup)
        guard errors.isEmpty else { return errors }
        appendVersion(TrainingRoutine(
            version: nextVersionNumber,
            source: .user,
            changeSummary: summary.isEmpty ? "Manual edit" : summary,
            days: days
        ))
        return []
    }

    func editWarnings(for days: [TrainingDay]) -> [String] {
        RoutineChangeReview.warnings(from: activeRoutine.days, to: days)
    }

    /// Rollback restores an old version by copying it forward as a new
    /// version, so history stays linear and nothing is destroyed.
    func rollback(to routine: TrainingRoutine) {
        guard routine.id != activeRoutine.id else { return }
        appendVersion(TrainingRoutine(
            version: nextVersionNumber,
            source: .user,
            changeSummary: "Restored version \(routine.version)",
            days: routine.days
        ))
    }

    private var nextVersionNumber: Int {
        (versions.map(\.version).max() ?? 0) + 1
    }

    private func appendVersion(_ routine: TrainingRoutine) {
        versions.append(routine)
        // Keep the full run bounded; 30 versions is ample history.
        if versions.count > 30 {
            versions.removeFirst(versions.count - 30)
        }
        persist(versions, key: StorageKey.versions)
        syncWatchContext()
    }

    // MARK: - One-day exceptions

    func setException(dateKey: String, sessions: [TrainingSession], note: String) {
        exceptions.removeAll { $0.date == dateKey }
        exceptions.append(TrainingDayException(date: dateKey, sessions: sessions, note: note))
        // Old exception dates are dead weight once the day has passed.
        let cutoff = HealthKitService.dayKey(for: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date())
        exceptions.removeAll { $0.date < cutoff }
        persist(exceptions, key: StorageKey.exceptions)
    }

    func removeException(dateKey: String) {
        exceptions.removeAll { $0.date == dateKey }
        persist(exceptions, key: StorageKey.exceptions)
    }

    // MARK: - Workout logging

    func logStrengthSet(
        date: Date = Date(),
        sessionID: UUID,
        exerciseName: String,
        loadKg: Double,
        reps: Int,
        rir: Int?,
        painNote: String?
    ) {
        let dateKey = HealthKitService.dayKey(for: date)
        let setNumber = strengthLogs
            .filter { $0.date == dateKey && $0.exerciseName == exerciseName }
            .count + 1
        strengthLogs.append(ExerciseSetLog(
            date: dateKey,
            sessionID: sessionID,
            exerciseName: exerciseName,
            setNumber: setNumber,
            loadKg: loadKg,
            reps: reps,
            rir: rir,
            painNote: painNote?.isEmpty == true ? nil : painNote
        ))
        trimAndPersistLogs()
    }

    func deleteStrengthLog(_ log: ExerciseSetLog) {
        strengthLogs.removeAll { $0.id == log.id }
        trimAndPersistLogs()
    }

    func logSwim(
        date: Date = Date(),
        sessionID: UUID,
        minutes: Int,
        distanceMeters: Int?,
        intensity: SwimIntensity,
        note: String?
    ) {
        swimLogs.append(SwimSessionLog(
            date: HealthKitService.dayKey(for: date),
            sessionID: sessionID,
            minutes: minutes,
            distanceMeters: distanceMeters,
            intensity: intensity,
            note: note?.isEmpty == true ? nil : note
        ))
        trimAndPersistLogs()
    }

    func strengthLogs(on date: Date, exerciseName: String) -> [ExerciseSetLog] {
        let dateKey = HealthKitService.dayKey(for: date)
        return strengthLogs
            .filter { $0.date == dateKey && $0.exerciseName == exerciseName }
            .sorted { $0.setNumber < $1.setNumber }
    }

    func swimLogs(on date: Date, sessionID: UUID) -> [SwimSessionLog] {
        let dateKey = HealthKitService.dayKey(for: date)
        return swimLogs.filter { $0.date == dateKey && $0.sessionID == sessionID }
    }

    func suggestion(for prescription: ExercisePrescription) -> ProgressionSuggestion {
        ProgressionAdvisor.suggest(prescription: prescription, history: strengthLogs)
    }

    private func trimAndPersistLogs() {
        // Keep roughly three months of history.
        let cutoff = HealthKitService.dayKey(for: Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date())
        strengthLogs.removeAll { $0.date < cutoff }
        swimLogs.removeAll { $0.date < cutoff }
        persist(strengthLogs, key: StorageKey.strengthLogs)
        persist(swimLogs, key: StorageKey.swimLogs)
        syncWatchContext()
    }

    private func syncWatchContext() {
        watchSync.send(routine: activeRoutine, strengthHistory: strengthLogs)
    }

    private func mergeWatchStrengthLog(_ log: ExerciseSetLog) {
        guard !strengthLogs.contains(where: { $0.id == log.id }) else { return }
        strengthLogs.append(log)
        trimAndPersistLogs()
    }

    private func mergeWatchSwimLog(_ log: SwimSessionLog) {
        guard !swimLogs.contains(where: { $0.id == log.id }) else { return }
        swimLogs.append(log)
        trimAndPersistLogs()
    }

    // MARK: - Coach proposals (mock until Phase 6)

    enum ProposalRequestResult: Equatable {
        case created
        case needsSetup
        case alreadyPending
    }

    /// Builds a deterministic mock proposal so the Confirm/Edit/Reject flow
    /// can be exercised end to end. Real provider-backed proposals arrive in
    /// Phase 6; the confirmation contract stays identical.
    @discardableResult
    func requestMockProposal() -> ProposalRequestResult {
        // Refusing without setup context is the "unsafe proposal" guard:
        // Coach never programs without experience/equipment/limitation info.
        guard !needsSetup else { return .needsSetup }
        if proposal?.status == .pending { return .alreadyPending }

        var proposedDays = activeRoutine.days
        // Mock adjustment: make Sunday's swim an easy recovery swim and trim
        // ten minutes, respecting accumulated weekly fatigue.
        if let index = proposedDays.firstIndex(where: { $0.weekday == .sunday }),
           let sessionIndex = proposedDays[index].sessions.firstIndex(where: { $0.kind == .swimming }),
           let plan = proposedDays[index].sessions[sessionIndex].swimPlan {
            proposedDays[index].sessions[sessionIndex].swimPlan = SwimPlan(
                targetMinutes: max(15, plan.targetMinutes - 10),
                intensity: .easy
            )
            proposedDays[index].sessions[sessionIndex].notes =
                "Recovery swim: long easy strokes, finish feeling fresher than you started."
        }

        setProposal(RoutineChangeProposal(
            baseVersion: activeRoutine.version,
            proposedDays: proposedDays,
            reasons: [
                "Nine weekly exposures with no full rest day",
                "Sunday follows your two hardest back-to-back days (Arms + swim)"
            ],
            expectedBenefit: "Better recovery going into Monday's chest session without losing swim consistency.",
            recoveryImpact: "Slightly lower Sunday load; weekly volume otherwise unchanged."
        ))
        return .created
    }

    func confirmProposal() {
        guard var current = proposal, current.status == .pending else { return }
        appendVersion(TrainingRoutine(
            version: nextVersionNumber,
            source: .coach,
            changeSummary: "Coach change confirmed by you",
            days: current.proposedDays
        ))
        current.status = .confirmed
        current.decidedAt = Date()
        setProposal(current)
    }

    func rejectProposal() {
        guard var current = proposal, current.status == .pending else { return }
        current.status = .rejected
        current.decidedAt = Date()
        setProposal(current)
    }

    /// "Edit" outcome: the user adjusted the proposed week; the revision
    /// replaces the pending proposal and still requires explicit confirmation.
    func reviseProposal(days: [TrainingDay]) {
        guard let current = proposal, current.status == .pending else { return }
        setProposal(RoutineChangeProposal(
            baseVersion: current.baseVersion,
            proposedDays: days,
            reasons: current.reasons + ["Adjusted by you before confirming"],
            expectedBenefit: current.expectedBenefit,
            recoveryImpact: current.recoveryImpact
        ))
    }

    func dismissDecidedProposal() {
        guard let current = proposal, current.status != .pending else { return }
        proposal = nil
        defaults.removeObject(forKey: StorageKey.proposal)
    }

    private func setProposal(_ newValue: RoutineChangeProposal) {
        proposal = newValue
        persist(newValue, key: StorageKey.proposal)
    }

    // MARK: - Persistence helpers

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
