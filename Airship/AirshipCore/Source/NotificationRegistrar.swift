// Copyright Airship and Contributors

import Foundation
import UserNotifications

protocol NotificationRegistrar {

#if !os(tvOS)
    func setCategories(_ categories: Set<UNNotificationCategory>)
#endif

    func checkStatus(completionHandler: @escaping (UAAuthorizationStatus, UAAuthorizedNotificationSettings) -> Void)

    func updateRegistration(options: UANotificationOptions,
                            skipIfEphemeral: Bool,
                            completionHandler: @escaping () -> Void)
}
