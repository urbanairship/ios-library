/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Push notification status
@objc
public final class UAPushNotificationStatus: NSObject, Sendable {
    /// If user notifications are enabled on AirshipPush.
    @objc
    public let isUserNotificationsEnabled: Bool

    /// If notifications are either ephemeral or granted and has at least one authorized type.
    @objc
    public let areNotificationsAllowed: Bool

    /// If the push feature is enabled on `AirshipPrivacyManager`.
    @objc
    public let isPushPrivacyFeatureEnabled: Bool

    /// If a push token is generated.
    @objc
    public let isPushTokenRegistered: Bool

    /// Display notification permission status
    @objc
    public let notificationPermissionStatus: UAPermissionStatus

    /// If isUserNotificationsEnabled, isPushPrivacyFeatureEnabled, and areNotificationsAllowed are all true.
    @objc
    public let isUserOptedIn: Bool

    /// If isUserOptedIn and isPushTokenRegistered are both true.
    @objc
    public let isOptedIn: Bool

    init(_ status: AirshipNotificationStatus) {
        self.isUserNotificationsEnabled = status.isUserNotificationsEnabled
        self.areNotificationsAllowed = status.areNotificationsAllowed
        self.isPushPrivacyFeatureEnabled = status.isPushPrivacyFeatureEnabled
        self.isPushTokenRegistered = status.isPushTokenRegistered
        self.notificationPermissionStatus = UAPermissionStatus(status.displayNotificationStatus)
        self.isUserOptedIn = status.isUserOptedIn
        self.isOptedIn = status.isOptedIn
    }
}
