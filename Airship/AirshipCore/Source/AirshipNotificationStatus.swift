/* Copyright Airship and Contributors */

import Foundation


/// Airship push notification status
public struct AirshipNotificationStatus: Sendable, Equatable {
    /// If user notifications are enabled on AirshipPush.
    public let isUserNotificationsEnabled: Bool

    /// If notifications are either  ephemeral or granted and has at least one authorized type.
    public let areNotificationsAllowed: Bool

    /// If the push feature is enabled on AirshipPrivacyManager.
    public let isPushPrivacyFeatureEnabled: Bool

    /// If a push token is generated.
    public let isPushTokenRegistered: Bool
    
    /// Display notification status
    public let displayNotificationStatus: AirshipPermissionStatus


    /// If isUserNotificationsEnabled, isPushPrivacyFeatureEnabled, and areNotificationsAllowed are all true..
    public var isUserOptedIn: Bool {
        return isUserNotificationsEnabled && isPushPrivacyFeatureEnabled && areNotificationsAllowed && displayNotificationStatus == .granted
    }

    /// If isUserOptedIn and isPushTokenRegistered are both true.
    public var isOptedIn: Bool {
        isUserOptedIn && isPushTokenRegistered
    }
}
