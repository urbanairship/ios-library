// Copyright Airship and Contributors

import Foundation
@preconcurrency public import UserNotifications

/// The result of the initial notification registration prompt.
public struct NotificationRegistrationResult: Sendable {
    /// The settings that were authorized at the time of registration.
    public let authorizedSettings: AirshipAuthorizedNotificationSettings

    /// The authorization status.
    public let status: UNAuthorizationStatus

    #if !os(tvOS)
    /// Set of the categories that were most recently registered.
    public let categories: Set<UNNotificationCategory>
    #endif
}
