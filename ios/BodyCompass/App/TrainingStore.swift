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
        static let recoveryCheckIns = "bodycompass.training.recoveryCheckIns"
        static let proposal = "bodycompass.training.proposal"

        static var all: [String] {
            [versions, setup, exceptions, strengthLogs, swimLogs, recoveryCheckIns, proposal]
        }
    }

    private let defaults: UserDefaults
    private let watchSync = PhoneWatchSyncService.shared

    @Published private(set) var versions: [TrainingRoutine] = []
    @Published private(set) var setup: TrainingSetup?
    @Published private(set) var exceptions: [TrainingDayException] = []
    @Published private(set) var strengthLogs: [ExerciseSetLog] = []
    @Published private(set) var swimLogs: [SwimSessionLog] = []
    @Published private(set) var recoveryCheckIns: [PostWorkoutCheckIn] = []
    @Published private(set) var proposal: RoutineChangeProposal?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        versions = Self.load([TrainingRoutine].self, key: StorageKey.versions, from: defaults) ?? []
        setup = Self.load(TrainingSetup.self, key: StorageKey.setup, from: defaults)
        exceptions = Self.load([TrainingDayException].self, key: StorageKey.exceptions, from: defaults) ?? []
        strengthLogs = Self.load([ExerciseSetLog].self, key: StorageKey.strengthLogs, from: defaults) ?? []
        swimLogs = Self.load([SwimSessionLog].self, key: StorageKey.swimLogs, from: defaults) ?? []
        recoveryCheckIns = Self.load([PostWorkoutCheckIn].self, key: StorageKey.recoveryCheckIns, from: defaults) ?? []
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

    func recoveryCheckIn(on date: Date, sessionID: UUID) -> PostWorkoutCheckIn? {
        let dateKey = HealthKitService.dayKey(for: date)
        return recoveryCheckIns.first { $0.date == dateKey && $0.sessionID == sessionID }
    }

    func saveRecoveryCheckIn(
        date: Date,
        sessionID: UUID,
        sessionRPE: Int,
        soreness: SorenessLevel,
        note: String?
    ) {
        let dateKey = HealthKitService.dayKey(for: date)
        let existingID = recoveryCheckIn(on: date, sessionID: sessionID)?.id ?? UUID()
        recoveryCheckIns.removeAll { $0.date == dateKey && $0.sessionID == sessionID }
        recoveryCheckIns.append(PostWorkoutCheckIn(
            id: existingID,
            date: dateKey,
            sessionID: sessionID,
            sessionRPE: sessionRPE,
            soreness: soreness,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : note,
            createdAt: Date()
        ))
        let cutoff = HealthKitService.dayKey(for: Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? Date())
        recoveryCheckIns.removeAll { $0.date < cutoff }
        persist(recoveryCheckIns, key: StorageKey.recoveryCheckIns)
    }

    func hasLoggedActivity(for session: TrainingSession, on date: Date) -> Bool {
        let dateKey = HealthKitService.dayKey(for: date)
        switch session.kind {
        case .strength:
            return strengthLogs.contains { $0.date == dateKey && $0.sessionID == session.id }
        case .swimming:
            return swimLogs.contains { $0.date == dateKey && $0.sessionID == session.id }
        case .recovery:
            return false
        }
    }

    func recoveryRecommendation(
        for session: TrainingSession,
        on date: Date,
        sleepHours: Double?,
        currentRestingHeartRate: Double?,
        baselineRestingHeartRate: Double?,
        oneMinuteHeartRateRecovery: Double?
    ) -> RecoveryRecommendation? {
        guard let checkIn = recoveryCheckIn(on: date, sessionID: session.id) else { return nil }
        let dateKey = HealthKitService.dayKey(for: date)
        let sessionSets = strengthLogs.filter { $0.date == dateKey && $0.sessionID == session.id }
        let plannedWork: Int
        let completedWork: Int
        switch session.kind {
        case .strength:
            plannedWork = session.exercises.reduce(0) { $0 + $1.workingSets }
            completedWork = sessionSets.count
        case .swimming:
            plannedWork = 1
            completedWork = swimLogs.contains { $0.date == dateKey && $0.sessionID == session.id } ? 1 : 0
        case .recovery:
            plannedWork = 0
            completedWork = 0
        }
        let ratedRIR = sessionSets.compactMap(\.rir)
        let averageRIR = ratedRIR.isEmpty ? nil : Double(ratedRIR.reduce(0, +)) / Double(ratedRIR.count)
        let windows = workloadWindows(endingOn: date)

        return RecoveryAdvisor.recommend(context: RecoveryContext(
            sleepHours: sleepHours,
            currentRestingHeartRate: currentRestingHeartRate,
            baselineRestingHeartRate: baselineRestingHeartRate,
            oneMinuteHeartRateRecovery: oneMinuteHeartRateRecovery,
            sessionRPE: checkIn.sessionRPE,
            soreness: checkIn.soreness,
            averageRIR: averageRIR,
            painReported: sessionSets.contains { $0.painNote?.isEmpty == false },
            plannedWork: plannedWork,
            completedWork: completedWork,
            recentWork: workload(from: windows.recentStart, through: windows.recentEnd),
            priorWork: workload(from: windows.priorStart, through: windows.priorEnd)
        ))
    }

    func deleteAllTrainingData() {
        StorageKey.all.forEach(defaults.removeObject(forKey:))
        versions = [TrainingRoutineSeeder.skeleton()]
        setup = nil
        exceptions = []
        strengthLogs = []
        swimLogs = []
        recoveryCheckIns = []
        proposal = nil
        persist(versions, key: StorageKey.versions)
        syncWatchContext()
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

    private func workloadWindows(endingOn date: Date) -> (
        recentStart: String,
        recentEnd: String,
        priorStart: String,
        priorEnd: String
    ) {
        let calendar = Calendar.current
        return (
            HealthKitService.dayKey(for: calendar.date(byAdding: .day, value: -6, to: date) ?? date),
            HealthKitService.dayKey(for: date),
            HealthKitService.dayKey(for: calendar.date(byAdding: .day, value: -13, to: date) ?? date),
            HealthKitService.dayKey(for: calendar.date(byAdding: .day, value: -7, to: date) ?? date)
        )
    }

    private func workload(from start: String, through end: String) -> Int {
        let strength = strengthLogs.filter { ($0.date >= start) && ($0.date <= end) }.count
        let swim = swimLogs
            .filter { ($0.date >= start) && ($0.date <= end) }
            .reduce(0) { $0 + max(1, Int(ceil(Double($1.minutes) / 10))) }
        return strength + swim
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

    // MARK: - Coach proposals

    enum CoachInstructionResult: Equatable {
        case created
        case needsSetup
        case alreadyPending
        case invalid(String)
    }

    /// Converts bounded AI change instructions into the existing proposal
    /// contract. Unknown targets and invalid routines are rejected; this
    /// method never activates the resulting routine.
    @discardableResult
    func createProposal(from instruction: CoachRoutineInstruction) -> CoachInstructionResult {
        guard !needsSetup else { return .needsSetup }
        if proposal?.status == .pending { return .alreadyPending }

        var days = activeRoutine.days
        var appliedChanges = 0

        for change in instruction.changes {
            guard let weekday = Weekday.allCases.first(where: {
                $0.displayName.lowercased() == change.weekday.lowercased()
            }), let dayIndex = days.firstIndex(where: { $0.weekday == weekday }) else {
                return .invalid("Coach referenced an unknown training day.")
            }

            switch change.action {
            case "make_rest_day":
                days[dayIndex].sessions = []
                appliedChanges += 1

            case "update_swim":
                guard (15...180).contains(change.targetMinutes),
                      let intensity = SwimIntensity(rawValue: change.intensity),
                      let sessionIndex = matchingSessionIndex(
                        in: days[dayIndex],
                        title: change.sessionTitle,
                        kind: .swimming
                      ) else {
                    return .invalid("Coach returned an invalid swimming change.")
                }
                days[dayIndex].sessions[sessionIndex].swimPlan = SwimPlan(
                    targetMinutes: change.targetMinutes,
                    intensity: intensity
                )
                appliedChanges += 1

            case "update_exercise":
                guard (1...10).contains(change.workingSets),
                      change.repRangeLower > 0,
                      change.repRangeUpper >= change.repRangeLower,
                      (0...5).contains(change.targetRIR),
                      (30...600).contains(change.restSeconds),
                      let sessionIndex = matchingSessionIndex(
                        in: days[dayIndex],
                        title: change.sessionTitle,
                        kind: .strength
                      ),
                      let exerciseIndex = days[dayIndex].sessions[sessionIndex].exercises.firstIndex(where: {
                        $0.name.caseInsensitiveCompare(change.exerciseName) == .orderedSame
                      }) else {
                    return .invalid("Coach referenced an unknown exercise or invalid prescription.")
                }
                days[dayIndex].sessions[sessionIndex].exercises[exerciseIndex].workingSets = change.workingSets
                days[dayIndex].sessions[sessionIndex].exercises[exerciseIndex].repRangeLower = change.repRangeLower
                days[dayIndex].sessions[sessionIndex].exercises[exerciseIndex].repRangeUpper = change.repRangeUpper
                days[dayIndex].sessions[sessionIndex].exercises[exerciseIndex].targetRIR = change.targetRIR
                days[dayIndex].sessions[sessionIndex].exercises[exerciseIndex].restSeconds = change.restSeconds
                appliedChanges += 1

            default:
                return .invalid("Coach returned an unsupported routine change.")
            }
        }

        guard appliedChanges > 0, !RoutineDiff.changes(from: activeRoutine.days, to: days).isEmpty else {
            return .invalid("Coach did not produce a change to the current routine.")
        }
        let errors = RoutineValidator.validate(days: days, requireDetail: true)
        guard errors.isEmpty else {
            return .invalid("Coach's routine change did not pass BodyCompass validation.")
        }

        setProposal(RoutineChangeProposal(
            baseVersion: activeRoutine.version,
            proposedDays: days,
            reasons: instruction.reasons.isEmpty ? [instruction.summary] : instruction.reasons,
            expectedBenefit: instruction.expectedBenefit,
            recoveryImpact: instruction.recoveryImpact
        ))
        return .created
    }

    private func matchingSessionIndex(
        in day: TrainingDay,
        title: String,
        kind: TrainingSessionKind
    ) -> Int? {
        if !title.isEmpty, let exact = day.sessions.firstIndex(where: {
            $0.kind == kind && $0.title.caseInsensitiveCompare(title) == .orderedSame
        }) {
            return exact
        }
        return day.sessions.firstIndex { $0.kind == kind }
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
