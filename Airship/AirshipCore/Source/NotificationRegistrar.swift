// Copyright Airship and Contributors

import Foundation
import UserNotifications

protocol NotificationRegistrar: Sendable {

    #if !os(tvOS)
    @MainActor
    func setCategories(_ categories: Set<UNNotificationCategory>)
    #endif

    @MainActor
    func checkStatus() async -> (UNAuthorizationStatus, AirshipAuthorizedNotificationSettings)

    @MainActor
    func updateRegistration(
        options: UNAuthorizationOptions,
        skipIfEphemeral: Bool
    ) async -> Void
}
