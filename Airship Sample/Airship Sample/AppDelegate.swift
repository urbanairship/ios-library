/* Copyright Urban Airship and Contributors */

import AirshipCore
import AirshipMessageCenter
import AirshipPreferenceCenter
import UIKit

#if canImport(ActivityKit)
import ActivityKit
#endif

class AppDelegate: UIResponder, UIApplicationDelegate, DeepLinkDelegate,
    MessageCenterDisplayDelegate, PreferenceCenterOpenDelegate
{

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        let config = AirshipConfig.default()
        config.productionLogLevel = .verbose
        config.developmentLogLevel = .verbose

        Airship.takeOff(config, launchOptions: launchOptions)

        Airship.push.autobadgeEnabled = true
        Airship.push.notificationOptions = [.alert, .badge, .sound, .carPlay]
        Airship.push.defaultPresentationOptions = [.sound, .banner, .list]

        Airship.deepLinkDelegate = self
        MessageCenter.shared.displayDelegate = self
        PreferenceCenter.shared.openDelegate = self

        NotificationCenter.default.addObserver(
            forName: AppStateTracker.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task {
                // Set the icon badge to zero
                do {
                    try await Airship.push.resetBadge()
                } catch {
                    AirshipLogger.error("failed to reset badge")
                }
            }
        }
        
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Airship.channel.restoreLiveActivityTracking { restorer in
                await restorer.restore(
                    forType: Activity<DeliveryAttributes>.self
                )
            }
        }

        if #available(iOS 17.2, *) {
            LiveActivityUtils<DeliveryAttributes>.trackActivitiesOnPushToStartUpdates {
                $0.orderNumber
            }
        }
        #endif

        return true
    }

    func showInvalidDeepLinkAlert(_ url: URL) {
        AppState.shared.toastMessage = Toast.Message(
            text: "App does not know how to handle deepLink \(url)",
            duration: 2.0
        )
    }

    @MainActor
    func receivedDeepLink(_ deepLink: URL) async  {
        guard deepLink.host?.lowercased() == "deeplink" else {
            self.showInvalidDeepLinkAlert(deepLink)
            return
        }

        let components = deepLink.path.lowercased().split(separator: "/")
        switch components.first {
        case "settings":
            AppState.shared.homeDestination = .settings
            AppState.shared.selectedTab = .home
        case "home":
            AppState.shared.homeDestination = nil
            AppState.shared.selectedTab = .home
        case "preferences":
            AppState.shared.selectedTab = .preferenceCenter
        case "message_center":
            AppState.shared.selectedTab = .messageCenter
        default:
            self.showInvalidDeepLinkAlert(deepLink)
        }
    }

    func displayMessageCenter(messageID: String) {
        AppState.shared.selectedTab = .messageCenter
        AppState.shared.messageCenterController.navigate(messageID: messageID)
    }

    func displayMessageCenter() {
        AppState.shared.selectedTab = .messageCenter
    }

    func dismissMessageCenter() {
    }

    func openPreferenceCenter(_ preferenceCenterID: String) -> Bool {
        guard preferenceCenterID == MainApp.preferenceCenterID else {
            return false
        }

        DispatchQueue.main.async {
            AppState.shared.selectedTab = .preferenceCenter
        }
        return true
    }
}

@available(iOS 16.2, *)
struct LiveActivityUtils<T: ActivityAttributes>  {
    public static func trackActivities(
        nameBlock: @escaping @Sendable (T) -> String?
    ) {
        Activity<T>.activities.filter { activity in
            activity.activityState == .active || activity.activityState == .stale
        }.forEach { activity in
            if let name = nameBlock(activity.attributes) {
                Airship.channel.trackLiveActivity(activity, name: name)
            }
        }
    }

    @available(iOS 17.2, *)
    public static func trackActivitiesOnPushToStartUpdates(
        nameBlock: @escaping @Sendable (T) -> String?
    ) {
        Task {
            trackActivities(nameBlock: nameBlock)
            for await update in Activity<T>.pushToStartTokenUpdates {
                trackActivities(nameBlock: nameBlock)
            }
        }
    }
}
