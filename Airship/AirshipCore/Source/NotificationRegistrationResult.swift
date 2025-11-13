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
    private let _categories: AirshipUnsafeSendableWrapper<Set<UNNotificationCategory>>
    public var categories: Set<UNNotificationCategory> {
        return _categories.value
    }

    init(authorizedSettings: AirshipAuthorizedNotificationSettings, status: UNAuthorizationStatus, categories: Set<UNNotificationCategory>) {
        self.authorizedSettings = authorizedSettings
        self.status = status
        self._categories = .init(categories)
    }
    #endif
}


