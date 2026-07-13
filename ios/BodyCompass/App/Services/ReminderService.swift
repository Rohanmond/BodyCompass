import Foundation
import UserNotifications
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

/// Wraps local daily reminders for schedule items. All BodyCompass reminders
/// share an identifier prefix so we can clear and rebuild them atomically.
final class ReminderService {
    private let center = UNUserNotificationCenter.current()
    private static let prefix = "bodycompass.reminder."
    private static let testIdentifier = "bodycompass.reminder.test"

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Removes every BodyCompass reminder, then schedules a daily-repeating one
    /// for each item that has a reminder time. Safe to call on any change.
    func reschedule(for items: [ScheduleItem]) async {
        let existing = await center.pendingNotificationRequests()
        let ours = existing.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard await authorizationStatus() == .authorized else { return }

        for item in items where item.hasReminder {
            var components = DateComponents()
            components.hour = item.reminderHour
            components.minute = item.reminderMinute

            let content = UNMutableNotificationContent()
            content.title = "BodyCompass"
            content.body = item.title
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.prefix + item.id.uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelAll() async {
        let existing = await center.pendingNotificationRequests()
        let ours = existing.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    /// Schedules a one-off reminder so signed-device builds can verify that
    /// permission, sounds, banners, and lock-screen delivery all work.
    func scheduleTest(after delay: TimeInterval = 10) async -> Bool {
        guard await authorizationStatus() == .authorized else { return false }

        center.removePendingNotificationRequests(withIdentifiers: [Self.testIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "BodyCompass"
        content.body = "Test reminder delivered. Your daily schedule is ready."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.testIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}
