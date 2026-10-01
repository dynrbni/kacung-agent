import Foundation
import UserNotifications

/// Native notifications for meaningful task outcomes.
///
/// Deliberately quiet: internal tool calls never notify, only task transitions a
/// user would otherwise wait on screen for.
public final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()

    private var authorizationRequested = false

    private override init() {
        super.init()
    }

    public func requestAuthorization() {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Posts a task-level notification, skipping anything the user is already
    /// watching so the app does not talk over itself.
    @MainActor
    public func notifyTask(_ task: TaskSnapshot, isForeground: Bool) {
        guard !isForeground else { return }

        switch task.status {
        case .completed:
            notify(title: "Task completed", body: task.title)
        case .failed:
            notify(title: "Task failed", body: task.title)
        case .requiresForeground:
            notify(title: "Task requires your attention", body: task.title)
        case .cancelled:
            break
        default:
            // Planning / executing / waiting are noise while in progress.
            break
        }
    }

    public func notifyTaskCompleted(_ summary: String) {
        notify(title: "Task completed", body: summary)
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    public func nonIntrusiveStatuses() -> Set<TaskStatus> {
        [.completed, .failed, .requiresForeground, .cancelled]
    }

    // MARK: - UNUserNotificationCenterDelegate

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banners even when the app is frontmost: the window may be showing
        // a different conversation than the one that finished.
        completionHandler([.banner, .sound])
    }
}
