/* Copyright Urban Airship and Contributors */

import AirshipCore
import AirshipMessageCenter
import AirshipPreferenceCenter
import UIKit
import SwiftUI

#if canImport(ActivityKit)
import ActivityKit
#endif

class AppDelegate: UIResponder, UIApplicationDelegate,
    MessageCenterDisplayDelegate, PreferenceCenterOpenDelegate, DeepLinkDelegate
{

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        var config = try! AirshipConfig.default()
        config.productionLogLevel = .verbose
        config.developmentLogLevel = .verbose

        try! Airship.takeOff(config, launchOptions: launchOptions)

        Airship.push.autobadgeEnabled = true
        Airship.push.notificationOptions = [.alert, .badge, .sound, .carPlay]
        Airship.push.defaultPresentationOptions = [.sound, .banner, .list]

        Airship.deepLinkDelegate = self

        Airship.messageCenter.displayDelegate = self
        Airship.preferenceCenter.openDelegate = self

        NotificationCenter.default.addObserver(
            forName: AppStateTracker.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task {
                // Set the icon badge to zero
                try? await Airship.push.resetBadge()
            }
        }

        return true
    }

    func displayMessageCenter(messageID: String) {
        AppState.shared.selectedTab = .messageCenter
        Airship.messageCenter.controller.navigate(messageID: messageID)
    }

    func displayMessageCenter() {
        AppState.shared.selectedTab = .messageCenter
    }

    func dismissMessageCenter() {}

    func openPreferenceCenter(_ preferenceCenterID: String) -> Bool {
        guard preferenceCenterID == MainApp.preferenceCenterID else {
            return false
        }

        DispatchQueue.main.async {
            withAnimation {
                AppState.shared.selectedTab = .preferenceCenter
            }
        }
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
        case "home":
            AppState.shared.selectedTab = .home
        case "preferences":
            AppState.shared.selectedTab = .preferenceCenter
        case "message_center":
            AppState.shared.selectedTab = .messageCenter
        default:
            self.showInvalidDeepLinkAlert(deepLink)
        }
    }
}
