/* Copyright Airship and Contributors */

import Foundation


/// AIrship push notificaiton status
public struct AirshipNotificationStatus: Sendable, Equatable {
    /// If user notifications are enabled on AirshipPush.
    public let isUserNotificationsEnabled: Bool

    /// If notifications are either  ephemeral or granted and has at least one authroized type.
    public let areNotificationsAllowed: Bool

    /// If the push feature is enabled on AirshipPrivacyManager.
    public let isPushPrivacyFeatureEnabled: Bool

    /// If a push token is generated.
    public let isPushTokenRegistered: Bool


    /// If isUserNotificationsEnabled, isPushPrivacyFeatureEnabled, and areNotificationsAllowed are all true..
    public var isUserOptedIn: Bool {
        return isUserNotificationsEnabled && isPushPrivacyFeatureEnabled && areNotificationsAllowed
    }

    /// If isUserOptedIn and isPushTokenRegistered are both true.
    public var isOptedIn: Bool {
        isUserOptedIn && isPushTokenRegistered
    }
}
