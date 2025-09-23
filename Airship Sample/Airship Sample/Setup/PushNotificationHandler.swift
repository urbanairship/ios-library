/* Copyright Airship and Contributors */

import AirshipCore
import Foundation

/// Example push notification configuration handler.
///
/// This is a sample implementation showing how to configure push notification
/// settings and callbacks for the Airship SDK.
///
/// - Note: This is an example - customize for your app's needs.
struct PushNotificationHandler {

    /// Sets up example push notification handling.
    @MainActor
    static func setup() {
        // Default presentation options
        Airship.push.defaultPresentationOptions = [.sound, .banner, .list]

        // APNS registration
        Airship.push.onAPNSRegistrationFinished = { result in
            switch(result) {
            case .success(deviceToken: let deviceToken):
                print("APNS registration succeeded :) \(deviceToken)")
            case .failure(error: let error):
                print("APNS registration failed :( \(error)")
            @unknown default:
                fatalError()
            }
        }

        // Notification registration
        Airship.push.onNotificationRegistrationFinished = { result in
            print("Notification registration finished \(result.status)")
        }

        Airship.push.onNotificationAuthorizedSettingsDidChange = { settings in
            print("Authorized notification settings changed \(settings)")
        }
    }
}
