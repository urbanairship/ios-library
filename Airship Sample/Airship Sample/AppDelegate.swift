/* Copyright Urban Airship and Contributors */

import UIKit
import AirshipCore
import AirshipMessageCenter
import AirshipPreferenceCenter

class AppDelegate: UIResponder, UIApplicationDelegate, DeepLinkDelegate, MessageCenterDisplayDelegate, PreferenceCenterOpenDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        let config = Config.default()
        config.productionLogLevel = .trace
        config.developmentLogLevel = .trace

        Airship.takeOff(config, launchOptions: launchOptions)

        Airship.push.autobadgeEnabled = true
        Airship.push.notificationOptions = [.alert, .badge, .sound, .carPlay]
        Airship.push.defaultPresentationOptions = [.sound, .banner, .list]


        Airship.shared.deepLinkDelegate = self
        MessageCenter.shared.displayDelegate = self
        PreferenceCenter.shared.openDelegate = self

        NotificationCenter.default.addObserver(
            forName: AppStateTracker.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            // Set the icon badge to zero
            Airship.push.resetBadge()
        }

        return true
    }

    
    func showInvalidDeepLinkAlert(_ url: URL) {
        AppState.shared.toastMessage = Toast.Message(
            text: "App does not know how to handle deepLink \(url)",
            duration: 2.0
        )
    }

    func receivedDeepLink(_ deepLink: URL,
                          completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            guard deepLink.host?.lowercased() == "deeplink" else {
                self.showInvalidDeepLinkAlert(deepLink)
                completionHandler()
                return
            }

            let components = deepLink.path.lowercased().split(separator: "/")
            switch(components.first) {
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

            completionHandler()
        }
    }

    func displayMessageCenter(forMessageID messageID: String, animated: Bool) {
        AppState.shared.messageID = messageID
        AppState.shared.selectedTab = .messageCenter
    }

    func displayMessageCenter(animated: Bool) {
        AppState.shared.messageID = nil
        AppState.shared.selectedTab = .messageCenter
    }

    func dismissMessageCenter(animated: Bool) {
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


