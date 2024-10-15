/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc(OUAPush)
public class OUAPush: NSObject {
    
    /// Enables/disables background remote notifications on this device through Airship.
    /// Defaults to `true`.
    @objc
    @MainActor
    public var backgroundPushNotificationsEnabled: Bool {
        set {
            Airship.push.backgroundPushNotificationsEnabled = newValue
        }
        get {
            return Airship.push.backgroundPushNotificationsEnabled
        }
    }

    /// Enables/disables user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications.
    @objc
    public var userPushNotificationsEnabled: Bool {
        set {
            Airship.push.userPushNotificationsEnabled = newValue
        }

        get {
            return Airship.push.userPushNotificationsEnabled
        }
    }


    /// When enabled, if the user has ephemeral notification authorization the SDK will prompt the user for
    /// notifications.  Defaults to `false`.
    @objc
    public var requestExplicitPermissionWhenEphemeral: Bool {
        set {
            Airship.push.requestExplicitPermissionWhenEphemeral = newValue
        }
        get {
            return Airship.push.requestExplicitPermissionWhenEphemeral
        }
    }

    /// The device token for this device, as a hex string.
    @objc
    @MainActor
    public var deviceToken: String? {
        get {
            return Airship.push.deviceToken
        }
    }

    /// User Notification options this app will request from APNS. Changes to this value
    /// will not take effect until the next time the app registers with
    /// updateRegistration.
    ///
    /// Defaults to alert, sound and badge.
    @objc
    public var notificationOptions: UANotificationOptions {
        set {
            Airship.push.notificationOptions = newValue
        }

        get {
            return Airship.push.notificationOptions
        }
    }

    #if !os(tvOS)
    /// Custom notification categories. Airship default notification
    /// categories will be unaffected by this field.
    ///
    /// Changes to this value will not take effect until the next time the app registers
    /// with updateRegistration.
    @objc
    @MainActor
    public var customCategories: Set<UNNotificationCategory> {
        set {
            Airship.push.customCategories = newValue
        }

        get {
            return Airship.push.customCategories
        }
    }

    /// The combined set of notification categories from `customCategories` set by the app
    /// and the Airship provided categories.
    @objc
    @MainActor
    public var combinedCategories: Set<UNNotificationCategory> {
        get {
            return Airship.push.combinedCategories
        }
    }

    #endif

    /// Sets authorization required for the default Airship categories. Only applies
    /// to background user notification actions.
    ///
    /// Changes to this value will not take effect until the next time the app registers
    /// with updateRegistration.
    @objc
    @MainActor
    public var requireAuthorizationForDefaultCategories: Bool {
        set {
            Airship.push.requireAuthorizationForDefaultCategories = newValue
        }

        get {
            return Airship.push.requireAuthorizationForDefaultCategories
        }
    }

    private var _pushNotificationDelegate: OUAPushNotificationDelegate?
    @objc
    public var pushNotificationDelegate: OUAPushNotificationDelegate? {
        didSet {
            if let pushNotificationDelegate {
                Airship.push.pushNotificationDelegate = OUAPushNotificationDelegateWrapper(delegate: pushNotificationDelegate)
            } else {
                Airship.push.pushNotificationDelegate = nil
            }
        }
    }

    private var _registrationDelegate: OUARegistrationDelegate?
    @objc
    public var registrationDelegate: OUARegistrationDelegate? {
        didSet {
            if let registrationDelegate {
                Airship.push.registrationDelegate = OUARegistrationDelegateWrapper(delegate: registrationDelegate)
            } else {
                Airship.push.registrationDelegate = nil
            }
        }
    }

    #if !os(tvOS)
    /// Notification response that launched the application.
    @objc
    public var launchNotificationResponse: UNNotificationResponse? {
        get {
            return Airship.push.launchNotificationResponse
        }
    }
    #endif

    @objc
    @MainActor
    public var authorizedNotificationSettings: UAAuthorizedNotificationSettings {
        get {
            return Airship.push.authorizedNotificationSettings
        }
    }

    @objc
    public var authorizationStatus: UAAuthorizationStatus {
        get {
            return Airship.push.authorizationStatus
        }
    }

    @objc
    public var userPromptedForNotifications: Bool {
        get {
            return Airship.push.userPromptedForNotifications
        }
    }

    @objc
    public var defaultPresentationOptions: UNNotificationPresentationOptions {
        set {
            Airship.push.defaultPresentationOptions = newValue
        }
        
        get {
            return Airship.push.defaultPresentationOptions
        }
    }
        
    @objc
    public func enableUserPushNotifications() async -> Bool {
        return await Airship.push.enableUserPushNotifications()
    }
    
    @objc
    @MainActor
    public var isPushNotificationsOptedIn: Bool {
        get {
            return Airship.push.isPushNotificationsOptedIn
        }
    }

    public var notificationStatus: AirshipNotificationStatus {
        get async {
            return await Airship.push.notificationStatus
        }
    }

   
    #if !os(watchOS)

    public func setBadgeNumber(_ newBadgeNumber: Int) async throws {
        try await Airship.push.setBadgeNumber(newBadgeNumber)
    }

    /// deprecation warning
    @objc
    @MainActor
    public var badgeNumber: Int {
        get {
            return Airship.push.badgeNumber
        }
    }

    @objc
    public var autobadgeEnabled: Bool {
        set {
            Airship.push.autobadgeEnabled = newValue
        }

        get {
            return Airship.push.autobadgeEnabled
        }
    }

    @objc
    @MainActor
    func resetBadge() async throws {
        try await Airship.push.resetBadge()
    }

    #endif

    /// Time Zone for quiet time. If the time zone is not set, the current
    /// local time zone is returned.
    @objc
    public var timeZone: NSTimeZone? {
        set {
            Airship.push.timeZone = newValue
        }

        get {
            return Airship.push.timeZone
        }
    }

    /// Enables/Disables quiet time
    @objc
    public var quietTimeEnabled: Bool {
        set {
            Airship.push.quietTimeEnabled = newValue
        }

        get {
            return Airship.push.quietTimeEnabled
        }
    }

    @objc
    public func setQuietTimeStartHour(
        _ startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) {
        Airship.push.setQuietTimeStartHour(startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute)
    }

   
}

public extension OUAAirshipNotifications {

    /// NSNotification info when enabled feature changed on PrivacyManager.
    @objc(OUAAirshipNotificationReceivedNotificationResponse)
    final class ReceivedNotificationResponse: NSObject {

        /// NSNotification name.
        @objc
        public static let name = NSNotification.Name(
            "com.urbanairship.push.received_notification_response"
        )
    }


    /// NSNotification info when enabled feature changed on PrivacyManager.
    @objc(OUAAirshipNotificationRecievedNotification)
    final class RecievedNotification: NSObject {

        /// NSNotification name.
        @objc
        public static let name = NSNotification.Name(
            "com.urbanairship.push.received_notification"
        )
    }
 
}

    
