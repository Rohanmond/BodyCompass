import Foundation
import WatchConnectivity

final class WatchRoutineStore: NSObject, ObservableObject, WCSessionDelegate {
    private enum Key {
        static let routine = "bodycompass.routine"
        static let strengthLog = "bodycompass.strengthLog"
        static let swimLog = "bodycompass.swimLog"
        static let acknowledgedLogID = "bodycompass.acknowledgedLogID"
        static let cachedRoutine = "bodycompass.watch.cachedRoutine"
        static let pendingStrength = "bodycompass.watch.pendingStrength"
        static let pendingSwim = "bodycompass.watch.pendingSwim"
    }

    @Published private(set) var routine: TrainingRoutine
    @Published private(set) var pendingStrengthLogs: [ExerciseSetLog]
    @Published private(set) var pendingSwimLogs: [SwimSessionLog]

    private let defaults: UserDefaults

    override init() {
        defaults = .standard
        routine = Self.load(TrainingRoutine.self, key: Key.cachedRoutine) ?? TrainingRoutineSeeder.skeleton()
        pendingStrengthLogs = Self.load([ExerciseSetLog].self, key: Key.pendingStrength) ?? []
        pendingSwimLogs = Self.load([SwimSessionLog].self, key: Key.pendingSwim) ?? []
        super.init()
        activate()
    }

    var today: TrainingDay {
        let weekday = Weekday(calendarWeekday: Calendar.current.component(.weekday, from: Date()))
        return routine.day(for: weekday) ?? TrainingDay(weekday: weekday)
    }

    func queue(_ log: ExerciseSetLog) {
        guard !pendingStrengthLogs.contains(where: { $0.id == log.id }) else { return }
        pendingStrengthLogs.append(log)
        persistPending()
        transfer(log)
    }

    func queue(_ log: SwimSessionLog) {
        guard !pendingSwimLogs.contains(where: { $0.id == log.id }) else { return }
        pendingSwimLogs.append(log)
        persistPending()
        transfer(log)
    }

    func localLogs(exerciseName: String, date: String) -> [ExerciseSetLog] {
        pendingStrengthLogs.filter { $0.exerciseName == exerciseName && $0.date == date }
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func sendPending() {
        pendingStrengthLogs.forEach(transfer)
        pendingSwimLogs.forEach(transfer)
    }

    private func transfer(_ log: ExerciseSetLog) {
        guard let data = try? JSONEncoder().encode(log) else { return }
        WCSession.default.transferUserInfo([Key.strengthLog: data])
    }

    private func transfer(_ log: SwimSessionLog) {
        guard let data = try? JSONEncoder().encode(log) else { return }
        WCSession.default.transferUserInfo([Key.swimLog: data])
    }

    private func apply(_ applicationContext: [String: Any]) {
        guard let data = applicationContext[Key.routine] as? Data,
              let updated = try? JSONDecoder().decode(TrainingRoutine.self, from: data) else { return }
        DispatchQueue.main.async {
            self.routine = updated
            Self.save(updated, key: Key.cachedRoutine)
        }
    }

    private func acknowledge(_ idString: String) {
        guard let id = UUID(uuidString: idString) else { return }
        DispatchQueue.main.async {
            self.pendingStrengthLogs.removeAll { $0.id == id }
            self.pendingSwimLogs.removeAll { $0.id == id }
            self.persistPending()
        }
    }

    private func persistPending() {
        Self.save(pendingStrengthLogs, key: Key.pendingStrength)
        Self.save(pendingSwimLogs, key: Key.pendingSwim)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        apply(session.receivedApplicationContext)
        sendPending()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let id = userInfo[Key.acknowledgedLogID] as? String {
            acknowledge(id)
        }
    }
}
