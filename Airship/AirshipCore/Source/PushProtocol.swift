/* Copyright Airship and Contributors */

import Foundation

import UserNotifications
import UIKit

/**
 * Airship Push protocol.
 */
@objc(UAPushProtocol)
public protocol PushProtocol {

    /// Enables/disables background remote notifications on this device through Airship.
    /// Defaults to `true`.
    @objc
    var backgroundPushNotificationsEnabled: Bool { get set }

    /// Enables/disables user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications.
    @objc
    var userPushNotificationsEnabled: Bool { get set }

    /// Enables/disables extended App Clip user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications if userPushNotificationsEnabled and the user currently has
    /// ephemeral authorization.
    @objc
    @available(*, deprecated, message: "Use requestExplicitPermissionWhenEphemeralKey instead")
    var extendedPushNotificationPermissionEnabled: Bool { get set }

    /// When enabled, if the user has ephemeral notification authorization the SDK will promp the user for
    /// notifications.  Defaults to `false`.
    @objc
    var requestExplicitPermissionWhenEphemeral: Bool { get set }

    /// The device token for this device, as a hex string.
    @objc
    var deviceToken: String? { get }

    /// User Notification options this app will request from APNS. Changes to this value
    /// will not take effect until the next time the app registers with
    /// updateRegistration.
    ///
    /// Defaults to alert, sound and badge.
    @objc
    var notificationOptions: UANotificationOptions { get set }

    #if !os(tvOS)
    /// Custom notification categories. Airship default notification
    /// categories will be unaffected by this field.
    ///
    /// Changes to this value will not take effect until the next time the app registers
    /// with updateRegistration.
    @objc
    var customCategories: Set<UNNotificationCategory> { get set }

    /// The combined set of notification categories from `customCategories` set by the app
    /// and the Airship provided categories.
    @objc
    var combinedCategories: Set<UNNotificationCategory> { get }

    /// The set of Accengage notification categories.
    /// - Note For internal use only. :nodoc:
    @objc
    var accengageCategories: Set<UNNotificationCategory> { get set }
    #endif
    /// Sets authorization required for the default Airship categories. Only applies
    /// to background user notification actions.
    ///
    /// Changes to this value will not take effect until the next time the app registers
    /// with updateRegistration.
    @objc
    var requireAuthorizationForDefaultCategories : Bool { get set }

    /// Set a delegate that implements the PushNotificationDelegate protocol.
    @objc
    weak var pushNotificationDelegate: PushNotificationDelegate? { get set}

    /// Set a delegate that implements the RegistrationDelegate protocol.
    @objc
    weak var registrationDelegate: RegistrationDelegate? { get set }

    #if !os(tvOS)
    /// Notification response that launched the application.
    @objc
    var launchNotificationResponse: UNNotificationResponse? { get }
    #endif
    
    /// The current authorized notification settings.
    /// If push is disabled in privacy manager, this value could be out of date.
    ///
    /// Note: this value reflects all the notification settings currently enabled in the
    /// Settings app and does not take into account which options were originally requested.
    @objc
    var authorizedNotificationSettings: UAAuthorizedNotificationSettings { get }

    /// The current authorization status.
    /// If push is disabled in privacy manager, this value could be out of date.
    @objc
    var authorizationStatus: UAAuthorizationStatus { get }

    /// Indicates whether the user has been prompted for notifications or not.
    /// If push is disabled in privacy manager, this value will be out of date.
    @objc
    var userPromptedForNotifications: Bool { get }

    /// The default presentation options to use for foreground notifications.
    @objc
    var defaultPresentationOptions: UNNotificationPresentationOptions { get set}

    #if !os(watchOS)
    /// The current badge number used by the device and on the Airship server.
    ///
    /// - Note: This property must be accessed on the main thread.
    @objc
    var badgeNumber: Int { get set }
    #endif
}

protocol InternalPushProtocol {
    var deviceToken: String? { get }
    func updateAuthorizedNotificationTypes()
    func didRegisterForRemoteNotifications(_ deviceToken: Data)
    func didFailToRegisterForRemoteNotifications(_ error: Error)
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], isForeground: Bool, completionHandler: @escaping (Any) -> Void)
    func presentationOptionsForNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions
    
    #if !os(tvOS)
    func didReceiveNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void)
    var combinedCategories: Set<UNNotificationCategory> { get }
    #endif
}
