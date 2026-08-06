import UIKit
import UserNotifications

/// Handles Complete / Snooze taps on mission notifications — including when
/// the app is launched cold by the action.
final class OttoAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var missionStore: MissionStore?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.registerCategories()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let missionId = UUID(uuidString: response.notification.request.identifier) else { return }
        let title = response.notification.request.content.body

        switch response.actionIdentifier {
        case NotificationScheduler.completeAction:
            await MainActor.run { missionStore?.complete(id: missionId) }
        case NotificationScheduler.snoozeAction:
            NotificationScheduler.schedule(missionId: missionId, title: title,
                                           at: Date().addingTimeInterval(15 * 60))
        default:
            break // plain tap just opens the app
        }
    }

    // Show mission reminders even while the app is foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
