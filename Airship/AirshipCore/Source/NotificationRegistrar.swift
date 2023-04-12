// Copyright Airship and Contributors

import Foundation
import UserNotifications

protocol NotificationRegistrar {

    #if !os(tvOS)
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
