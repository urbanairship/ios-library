/* Copyright Airship and Contributors */

import Foundation

/// Implement this protocol and add as a Push.registrationDelegate to receive
/// registration success and failure callbacks.
///
@objc(UARegistrationDelegate)
public protocol RegistrationDelegate: NSObjectProtocol {
#if !os(tvOS)
    /// Called when APNS registration completes.
    ///
    /// - Parameters:
    ///   - authorizedSettings: The settings that were authorized at the time of registration.
    ///   - categories: Set of the categories that were most recently registered.
    ///   - status: The authorization status.
    @objc
    optional func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings: UAAuthorizedNotificationSettings,
        categories: Set<UNNotificationCategory>,
        status: UAAuthorizationStatus
    )
#endif

    /// Called when APNS registration completes.
    ///
    /// - Parameters:
    ///   - authorizedSettings: The settings that were authorized at the time of registration.
    ///   - status: The authorization status.
    @objc
    optional func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings: UAAuthorizedNotificationSettings,
        status: UAAuthorizationStatus
    )

    /// Called when notification authentication changes with the new authorized settings.
    ///
    /// - Parameter authorizedSettings: UAAuthorizedNotificationSettings The newly changed authorized settings.
    @objc optional func notificationAuthorizedSettingsDidChange(_ authorizedSettings: UAAuthorizedNotificationSettings)

    /// Called when the UIApplicationDelegate's application:didRegisterForRemoteNotificationsWithDeviceToken:
    /// delegate method is called.
    ///
    /// - Parameter deviceToken: The APNS device token.
    @objc optional func apnsRegistrationSucceeded(withDeviceToken deviceToken: Data)

    /// Called when the UIApplicationDelegate's application:didFailToRegisterForRemoteNotificationsWithError:
    /// delegate method is called.
    ///
    /// - Parameter error: An NSError object that encapsulates information why registration did not succeed.
    @objc optional func apnsRegistrationFailedWithError(_ error: Error)
}
