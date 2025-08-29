/* Copyright Airship and Contributors */

import AirshipCore
import Foundation
import SwiftUI
import AirshipAutomation

class AppDelegate: NSObject, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        do {
            var config = try AirshipConfig.default()
            config.isWebViewInspectionEnabled = true
            config.developmentLogLevel = .verbose
            config.productionLogLevel = .verbose
            try Airship.takeOff(config)
        } catch {
            showInvalidConfigAlert()
            return true
        }

        registerCustomViews()

        Airship.inAppAutomation.inAppMessaging.themeManager.htmlThemeExtender = { message, theme in
            theme.maxWidth = 300
            theme.maxHeight = 300
        }
        
        Task {
            // Set the icon badge to zero on startup (optional)
            try await Airship.push.resetBadge()
        }

        Airship.inAppAutomation.inAppMessaging.themeManager.htmlThemeExtender = { message, theme in
            if message.extras?.object?["squareview"]?.string == "true" {
                theme.maxWidth = (min(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)-24*2)
                theme.maxHeight = theme.maxWidth
            }
        }

        return true
    }

    func showInvalidConfigAlert() {
        let alertController = UIAlertController.init(
            title: "Invalid AirshipConfig.plist",
            message:
                "The AirshipConfig.plist must be a part of the app bundle and include a valid appkey and secret for the selected production level.",
            preferredStyle: .actionSheet
        )
        alertController.addAction(
            UIAlertAction.init(
                title: "Exit Application",
                style: UIAlertAction.Style.default,
                handler: { (UIAlertAction) in
                    exit(1)
                }
            )
        )

        DispatchQueue.main.async {
            alertController.popoverPresentationController?.sourceView =
                self.window?.rootViewController?.view

            self.window?.rootViewController?
                .present(alertController, animated: true, completion: nil)
        }
    }

    @MainActor
    private func registerCustomViews() {
        AirshipCustomViewManager.shared.register(name: "weather_custom_view") { args in
            WeatherView()
        }

        AirshipCustomViewManager.shared.register(name: "camera_custom_view") { args in
            CameraView()
        }

        #if !os(tvOS)
        AirshipCustomViewManager.shared.register(name: "map_custom_view") { args in
            MapRouteView()
        }

        AirshipCustomViewManager.shared.register(name: "biometric_login_custom_view") { args in
            BiometricLoginView()
        }
        #endif

        AirshipCustomViewManager.shared.fallbackBuilder = { args in
            ZStack {
                Text("Missing custom view \(args.name)")
                    .foregroundColor(Color.black)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .border(Color.red)
            .background(Color.white)
        }
    }
}
