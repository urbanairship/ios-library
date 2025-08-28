/* Copyright Airship and Contributors */

@testable
import AirshipCore

import UserNotifications
import UIKit

import Combine

final class TestPush: NSObject, InternalPushProtocol, AirshipPushProtocol, AirshipComponent, @unchecked Sendable {
    func enableUserPushNotifications(fallback: AirshipCore.PromptPermissionFallback) async -> Bool {
        return true
    }
    
    
    override init() {
        (self.notificationStatusUpdates, self.statusUpdateContinuation) = AsyncStream<AirshipNotificationStatus>.airshipMakeStreamWithContinuation()
        
        super.init()
    }
    
    var quietTime: QuietTimeSettings?
    
    func enableUserPushNotifications() async -> Bool {
        return true
    }

    func setBadgeNumber(_ newBadgeNumber: Int) async {

    }

    func resetBadge() async {

    }

    var autobadgeEnabled: Bool = false

    var timeZone: NSTimeZone?

    var quietTimeEnabled: Bool = false

    func setQuietTimeStartHour(_ startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {

    }

    let notificationStatusSubject: PassthroughSubject<AirshipNotificationStatus, Never> = PassthroughSubject()
    
    let notificationStatusUpdates: AsyncStream<AirshipNotificationStatus>
    let statusUpdateContinuation: AsyncStream<AirshipNotificationStatus>.Continuation

    var notificationStatusPublisher: AnyPublisher<AirshipNotificationStatus, Never> {
        notificationStatusSubject.removeDuplicates().eraseToAnyPublisher()
    }

    var notificationStatus: AirshipNotificationStatus = AirshipNotificationStatus(
        isUserNotificationsEnabled: false,
        areNotificationsAllowed: false,
        isPushPrivacyFeatureEnabled: false,
        isPushTokenRegistered: false,
        displayNotificationStatus: .denied
    )


    var isPushNotificationsOptedIn: Bool = false

    var backgroundPushNotificationsEnabled: Bool = false

    var userPushNotificationsEnabled: Bool = false

    var extendedPushNotificationPermissionEnabled: Bool = false

    var requestExplicitPermissionWhenEphemeral: Bool = false

    var notificationOptions: UNAuthorizationOptions  = []

    var customCategories: Set<UNNotificationCategory> = Set()

    var accengageCategories: Set<UNNotificationCategory> = Set()

    var requireAuthorizationForDefaultCategories: Bool = false

    var pushNotificationDelegate: PushNotificationDelegate?

    var registrationDelegate: RegistrationDelegate?

    var launchNotificationResponse: UNNotificationResponse?

    var authorizedNotificationSettings: AirshipAuthorizedNotificationSettings = []

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var userPromptedForNotifications: Bool = false

    var defaultPresentationOptions: UNNotificationPresentationOptions = []

    var badgeNumber: Int = 0

    var deviceToken: String?
    var updateAuthorizedNotificationTypesCalled = false
    var registrationError: Error?
    var didReceiveRemoteNotificationCallback: (
        ([AnyHashable: Any], Bool) -> UIBackgroundFetchResult
    )?
    var combinedCategories: Set<UNNotificationCategory> = Set()

    func dispatchUpdateAuthorizedNotificationTypes() {
        self.updateAuthorizedNotificationTypesCalled = true
    }

    func didRegisterForRemoteNotifications(_ deviceToken: Data) {
        self.deviceToken = String(data: deviceToken, encoding: .utf8)
    }

    func didFailToRegisterForRemoteNotifications(_ error: Error) {
        self.registrationError = error
    }

    func didReceiveRemoteNotification(
        _ userInfo: [AnyHashable: Any],
        isForeground: Bool
    ) async -> any Sendable {
        return self.didReceiveRemoteNotificationCallback!(
            userInfo,
            isForeground
        )
    }


    func presentationOptionsForNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions {
        return []
    }


    func didReceiveNotificationResponse(_ response: UNNotificationResponse) async {
        assertionFailure("Unable to create UNNotificationResponse in tests.")
    }
}

