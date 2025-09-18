/* Copyright Airship and Contributors */

import Foundation
import UIKit
import UserNotifications
public import Combine

/// Airship Push protocol.
public protocol AirshipPushProtocol: AnyObject, Sendable {

    /// If set, this block will be called when APNs registration succeeds or fails.
    /// This will be called in place of the `RegistrationDelegate` delegates `apnsRegistrationSucceeded`
    /// and `apnsRegistrationFailedWithError` methods.
    @MainActor
    var onAPNSRegistrationFinished: (@MainActor @Sendable (APNSRegistrationResult) -> Void)? { get set }

    /// If set, this block will be called when the user notifications registration finishes.
    /// This will be called in place of the `RegistrationDelegate` delegates `notificationRegistrationFinished` method.
    @MainActor
    var onNotificationRegistrationFinished: (@MainActor @Sendable (NotificationRegistrationResult) -> Void)? { get set }

    /// If set, this block will be called when the notification authorization settings change.
    /// This will be called in place of the of the `RegistrationDelegate` delegates  `notificationAuthorizedSettingsDidChange` method.
    @MainActor
    var onNotificationAuthorizedSettingsDidChange: (@MainActor @Sendable (AirshipAuthorizedNotificationSettings) -> Void)? { get set }

    /// Checks to see if push notifications are opted in.
    @MainActor
    var isPushNotificationsOptedIn: Bool { get }

    /// Enables/disables background remote notifications on this device through Airship.
    /// Defaults to `true`.
    @MainActor
    var backgroundPushNotificationsEnabled: Bool { get set }

    /// Enables/disables user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications.
    var userPushNotificationsEnabled: Bool { get set }

    /// When enabled, if the user has ephemeral notification authorization the SDK will prompt the user for
    /// notifications.  Defaults to `false`.
    var requestExplicitPermissionWhenEphemeral: Bool { get set }

    /// The device token for this device, as a hex string.
    @MainActor
    var deviceToken: String? { get }

    /// User Notification options this app will request from APNS.
    ///
    /// Defaults to alert, sound and badge.
    var notificationOptions: UNAuthorizationOptions { get set }

    #if !os(tvOS)
    /// Custom notification categories. Airship default notification
    /// categories will be unaffected by this field.
    ///
    /// Changes to this value will not take effect until the next time the app registers
    /// with updateRegistration.
    @MainActor
    var customCategories: Set<UNNotificationCategory> { get set }

    /// The combined set of notification categories from `customCategories` set by the app
    /// and the Airship provided categories.
    @MainActor
    var combinedCategories: Set<UNNotificationCategory> { get }

    #endif
    /// Sets authorization required for the default Airship categories. Only applies
    /// to background user notification actions.
    @MainActor
    var requireAuthorizationForDefaultCategories: Bool { get set }

    /// Set a delegate that implements the PushNotificationDelegate protocol.
    @MainActor
    var pushNotificationDelegate: (any PushNotificationDelegate)? { get set }

    /// Set a delegate that implements the RegistrationDelegate protocol.
    @MainActor
    var registrationDelegate: (any RegistrationDelegate)? { get set }

    #if !os(tvOS)
    /// Notification response that launched the application.
    var launchNotificationResponse: UNNotificationResponse? { get }
    #endif

    /// The current authorized notification settings.
    /// If push is disabled in privacy manager, this value could be out of date.
    ///
    /// Note: this value reflects all the notification settings currently enabled in the
    /// Settings app and does not take into account which options were originally requested.
    var authorizedNotificationSettings: AirshipAuthorizedNotificationSettings { get }

    /// The current authorization status.
    /// If push is disabled in privacy manager, this value could be out of date.
    var authorizationStatus: UNAuthorizationStatus { get }

    /// Indicates whether the user has been prompted for notifications or not.
    /// If push is disabled in privacy manager, this value will be out of date.
    var userPromptedForNotifications: Bool { get }

    /// The default presentation options to use for foreground notifications.
    var defaultPresentationOptions: UNNotificationPresentationOptions {
        get set
    }

    /// Enables user notifications on this device through Airship.
    ///
    /// - Note: The completion handler will return the success state of system push authorization as it is defined by the
    /// user's response to the push authorization prompt. The completion handler success state does NOT represent the
    /// state of the userPushNotificationsEnabled flag, which will be invariably set to `true` after the completion of this call.
    ///
    /// - Parameter completionHandler: The completion handler with success flag representing the system authorization state.
    func enableUserPushNotifications() async -> Bool

#if !os(watchOS)
    /// The current badge number used by the device and on the Airship server.
    ///
    /// - Note: This property must be accessed on the main thread and must be set asynchronously using setBadgeNumber.
    @MainActor
    var badgeNumber: Int { get }

    /// The current badge number used by the device and on the Airship server.
    func setBadgeNumber(_ newBadgeNumber: Int) async throws

    /// Resets the badge to zero (0) on both the device and on Airships servers. This is a
    /// convenience method for setting the `badgeNumber` property to zero.
    func resetBadge() async throws

    /// Toggle the Airship auto-badge feature. Defaults to `false` If enabled, this will update the
    /// badge number stored by Airship every time the app is started or foregrounded.
    var autobadgeEnabled: Bool { get set }
#endif

    /// Time Zone for quiet time. If the time zone is not set, the current
    /// local time zone is returned.
    var timeZone: NSTimeZone? { get set }

    /// Enables/Disables quiet time
    var quietTimeEnabled: Bool { get set }

    /// Sets the quiet time start and end time.  The start and end time does not change
    /// if the time zone changes.  To set the time zone, see 'timeZone'.
    ///
    /// Update the server after making changes to the quiet time with the
    /// `updateRegistration` call. Batching these calls improves API and client performance.
    ///
    /// - Warning: This method does not automatically enable quiet time and does not
    /// automatically update the server. Please refer to `quietTimeEnabled` and
    /// `updateRegistration` for more information.
    ///
    /// - Parameters:
    ///   - startHour: Quiet time start hour. Only 0-23 is valid.
    ///   - startMinute: Quiet time start minute. Only 0-59 is valid.
    ///   - endHour: Quiet time end hour. Only 0-23 is valid.
    ///   - endMinute: Quiet time end minute. Only 0-59 is valid.
    func setQuietTimeStartHour(
        _ startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    )

    /// Quiet time settings. Setting this value only sets the start/end time for quiet time. It still needs to be
    /// enabled with `quietTimeEnabled`. The timzone can be set with `timeZone`.
    var quietTime: QuietTimeSettings? { get set }

    /// Notification status updates
    @MainActor
    var notificationStatusPublisher: AnyPublisher<AirshipNotificationStatus, Never> { get }
    
    /// Notification status updates
    var notificationStatusUpdates: AsyncStream<AirshipNotificationStatus> { get async }

    /// Gets the current notification status
    var notificationStatus: AirshipNotificationStatus { get async }

    /// Enables user notifications on this device through Airship.
    ///
    /// - Note: The result of this method does NOT represent the state of the userPushNotificationsEnabled flag,
    /// which will be invariably set to `true` after the completion of this call.
    ///
    /// - Parameters:
    ///   - fallback: The prompt permission fallback if the display notifications permission is already denied.
    ///
    /// - Returns: `true` if user notifications are enabled at the system level,  otherwise`false`.
    @discardableResult
    func enableUserPushNotifications(fallback: PromptPermissionFallback) async -> Bool
}

protocol InternalPushProtocol: Sendable {
    @MainActor
    var deviceToken: String? { get }
    
    func dispatchUpdateAuthorizedNotificationTypes()

    @MainActor
    func didRegisterForRemoteNotifications(_ deviceToken: Data)

    @MainActor
    func didFailToRegisterForRemoteNotifications(_ error: any Error)

    @MainActor
    func didReceiveRemoteNotification(
        _ notification: [AnyHashable: Any],
        isForeground: Bool
    ) async -> any Sendable
    
    @MainActor
    func presentationOptionsForNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions
    
    #if !os(tvOS)
    @MainActor
    func didReceiveNotificationResponse(_ response: UNNotificationResponse) async

    @MainActor
    var combinedCategories: Set<UNNotificationCategory> { get }
    #endif
}
