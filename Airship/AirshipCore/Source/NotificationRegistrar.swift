// Copyright Airship and Contributors

import Foundation
import UserNotifications

protocol NotificationRegistrar: Sendable {

    #if !os(tvOS)
    @MainActor
    func setCategories(_ categories: Set<UNNotificationCategory>)
    #endif

    @MainActor
    func checkStatus() async -> (UAAuthorizationStatus, UAAuthorizedNotificationSettings)

    @MainActor
    func updateRegistration(
        options: UANotificationOptions,
        skipIfEphemeral: Bool
    ) async -> Void
}
