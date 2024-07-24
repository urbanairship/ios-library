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

        // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
        // or set runtime properties here.
        let config = AirshipConfig.default()
        config.isWebViewInspectionEnabled = true

        if config.validate() != true {
            showInvalidConfigAlert()
            return true
        }

        // Set log level for debugging config loading (optional)
        // It will be set to the value in the loaded config upon takeOff
        Airship.logLevel = .verbose

        // You can then programmatically override the plist values:
        // config.developmentAppKey = "YourKey"
        // etc.

        // Call takeOff (which creates the UAirship singleton)
        Airship.takeOff(config, launchOptions: launchOptions)

        // Print out the application configuration for debugging (optional)
        print("Config:\n \(config)")

        CustomViewExampleHelper.registerWeatherView()
        CustomViewExampleHelper.registerMapRouteView()
        CustomViewExampleHelper.registerCameraView()
        CustomViewExampleHelper.registerBiometricLoginView()

        InAppAutomation.shared.inAppMessaging.themeManager.htmlThemeExtender = { message, theme in
            theme.maxWidth = 300
            theme.maxHeight = 300
        }
        
        Task {
            // Set the icon badge to zero on startup (optional)
            try await Airship.push.resetBadge()
        }

        InAppAutomation.shared.inAppMessaging.themeManager.htmlThemeExtender = { message, theme in
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
}
