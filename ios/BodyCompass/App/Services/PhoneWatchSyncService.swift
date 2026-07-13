import Foundation
import WatchConnectivity
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

final class PhoneWatchSyncService: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSyncService()

    private enum Key {
        static let routine = "bodycompass.routine"
        static let strengthHistory = "bodycompass.strengthHistory"
        static let strengthLog = "bodycompass.strengthLog"
        static let swimLog = "bodycompass.swimLog"
        static let acknowledgedLogID = "bodycompass.acknowledgedLogID"
    }

    var onStrengthLog: ((ExerciseSetLog, @escaping () -> Void) -> Void)?
    var onSwimLog: ((SwimSessionLog, @escaping () -> Void) -> Void)?

    private var latestRoutineContext: [String: Any]?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(routine: TrainingRoutine, strengthHistory: [ExerciseSetLog]) {
        guard WCSession.isSupported(),
              let routineData = try? JSONEncoder().encode(routine),
              let historyData = try? JSONEncoder().encode(Array(strengthHistory.suffix(300))) else { return }
        latestRoutineContext = [
            Key.routine: routineData,
            Key.strengthHistory: historyData
        ]
        sendLatestRoutine()
    }

    private func sendLatestRoutine() {
        guard WCSession.default.activationState == .activated,
              let latestRoutineContext else { return }
        do {
            try WCSession.default.updateApplicationContext(latestRoutineContext)
        } catch {
            // Keep the latest context in memory for the next activation/change.
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            sendLatestRoutine()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let data = userInfo[Key.strengthLog] as? Data,
           let log = try? JSONDecoder().decode(ExerciseSetLog.self, from: data) {
            onStrengthLog?(log) {
                session.transferUserInfo([Key.acknowledgedLogID: log.id.uuidString])
            }
        }

        if let data = userInfo[Key.swimLog] as? Data,
           let log = try? JSONDecoder().decode(SwimSessionLog.self, from: data) {
            onSwimLog?(log) {
                session.transferUserInfo([Key.acknowledgedLogID: log.id.uuidString])
            }
        }
    }
}
