/* Copyright Airship and Contributors */

import Foundation

///Protocol for querying APNS authorization and updating registration.
///For internal use only. :nodoc:
@objc(UAAPNSRegistrationProtocol)
public protocol APNSRegistrationProtocol {
    @objc(getAuthorizedSettingsWithCompletionHandler:)
    func getAuthorizedSettings(completionHandler: @escaping (UAAuthorizedNotificationSettings, UAAuthorizationStatus) -> Void)

    #if !os(tvOS)
    @objc
    func updateRegistration(options: UANotificationOptions, categories: Set<UNNotificationCategory>, completionHandler: @escaping (Bool, UAAuthorizedNotificationSettings, UAAuthorizationStatus) -> Void)
    #endif

    @objc
    func updateRegistration(options: UANotificationOptions, completionHandler: @escaping (Bool, UAAuthorizedNotificationSettings, UAAuthorizationStatus) -> Void)
}
