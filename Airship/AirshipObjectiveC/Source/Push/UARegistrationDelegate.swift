/* Copyright Airship and Contributors */

import Foundation

public import UserNotifications

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Implement this protocol and add as a Push.registrationDelegate to receive
/// registration success and failure callbacks.
///
@objc
public protocol UARegistrationDelegate {
    #if !os(tvOS)
    /// Called when APNS registration completes.
    ///
    /// - Parameters:
    ///   - authorizedSettings: The settings that were authorized at the time of registration.
    ///   - categories: Set of the categories that were most recently registered.
    ///   - status: The authorization status.
    @objc
    func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings:
            UAAuthorizedNotificationSettings,
        categories: Set<UNNotificationCategory>,
        status: UNAuthorizationStatus
    )
    #endif

    /// Called when APNS registration completes.
    ///
    /// - Parameters:
    ///   - authorizedSettings: The settings that were authorized at the time of registration.
    ///   - status: The authorization status.
    @objc
    func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings:
            UAAuthorizedNotificationSettings,
        status: UNAuthorizationStatus
    )

    /// Called when notification authentication changes with the new authorized settings.
    ///
    /// - Parameter authorizedSettings: AirshipAuthorizedNotificationSettings The newly changed authorized settings.
    @objc
    func notificationAuthorizedSettingsDidChange(
        _ authorizedSettings: UAAuthorizedNotificationSettings
    )

    /// Called when the UIApplicationDelegate's application:didRegisterForRemoteNotificationsWithDeviceToken:
    /// delegate method is called.
    ///
    /// - Parameter deviceToken: The APNS device token.
    @objc
    func apnsRegistrationSucceeded(
        withDeviceToken deviceToken: Data
    )

    /// Called when the UIApplicationDelegate's application:didFailToRegisterForRemoteNotificationsWithError:
    /// delegate method is called.
    ///
    /// - Parameter error: An NSError object that encapsulates information why registration did not succeed.
    @objc
    func apnsRegistrationFailedWithError(_ error: any Error)
}

final class UARegistrationDelegateWrapper: NSObject, RegistrationDelegate {

    weak var forwardDelegate: (any UARegistrationDelegate)?

    init(_ forwardDelegate: any UARegistrationDelegate) {
        self.forwardDelegate = forwardDelegate
    }
    
    public func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings:
            AirshipAuthorizedNotificationSettings,
        categories: Set<UNNotificationCategory>,
        status: UNAuthorizationStatus
    ) {
        self.forwardDelegate?.notificationRegistrationFinished(
            withAuthorizedSettings: authorizedSettings.asUAAuthorizedNotificationSettings,
            categories: categories,
            status: status
        )
    }
    
    public func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings:
            AirshipAuthorizedNotificationSettings,
        status: UNAuthorizationStatus
    ) {
        self.forwardDelegate?.notificationRegistrationFinished(
            withAuthorizedSettings: authorizedSettings.asUAAuthorizedNotificationSettings,
            status: status
        )
    }
    
    public func apnsRegistrationSucceeded(
        withDeviceToken deviceToken: Data
    ) {
        self.forwardDelegate?.apnsRegistrationSucceeded(withDeviceToken: deviceToken)
    }
    
    public func apnsRegistrationFailedWithError(_ error: any Error) {
        self.forwardDelegate?.apnsRegistrationFailedWithError(error)
    }
    
    public func notificationAuthorizedSettingsDidChange(_ authorizedSettings: AirshipAuthorizedNotificationSettings) {
        self.forwardDelegate?.notificationAuthorizedSettingsDidChange(
            authorizedSettings.asUAAuthorizedNotificationSettings
        )
    }
}
