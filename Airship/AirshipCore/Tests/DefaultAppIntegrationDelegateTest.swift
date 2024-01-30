/* Copyright Airship and Contributors */

import XCTest
import Combine

@testable import AirshipCore

class DefaultAppIntegrationdelegateTest: XCTestCase {

    private var delegate: DefaultAppIntegrationDelegate!
    private let push = TestPush()
    private let analytics = TestAnalytics()
    private let pushableComponent = TestPushableComponent()
    private let airshipInstance = TestAirshipInstance()

    @MainActor
    override func setUp() async throws {
        self.airshipInstance.actionRegistry = ActionRegistry()
        self.airshipInstance.makeShared()

        self.delegate = DefaultAppIntegrationDelegate(
            push: self.push,
            analytics: self.analytics,
            pushableComponents: [pushableComponent]
        )
    }

    func testOnBackgroundAppRefresh() throws {
        delegate.onBackgroundAppRefresh()
        XCTAssertTrue(push.updateAuthorizedNotificationTypesCalled)
    }

    func testDidRegisterForRemoteNotifications() throws {
        let data = Data()
        delegate.didRegisterForRemoteNotifications(deviceToken: data)
        XCTAssertEqual(data, push.deviceToken?.data(using: .utf8))
        XCTAssertTrue(self.analytics.onDeviceRegistrationCalled)
    }

    func testDidFailToRegisterForRemoteNotifications() throws {
        let error = AirshipErrors.error("some error")
        delegate.didFailToRegisterForRemoteNotifications(error: error)
        XCTAssertEqual("some error", error.localizedDescription)
    }

    @MainActor
    func testDidReceiveRemoteNotification() throws {
        let expectedUserInfo = ["neat": "story"]

        self.push.didReceiveRemoteNotificationCallback = {
            userInfo,
            isForeground,
            completionHandler in
            XCTAssertEqual(
                expectedUserInfo as NSDictionary,
                userInfo as NSDictionary
            )
            XCTAssertTrue(isForeground)
            completionHandler(.noData)
        }

        self.pushableComponent.didReceiveRemoteNotificationCallback = {
            userInfo,
            completionHandler in
            XCTAssertEqual(
                expectedUserInfo as NSDictionary,
                userInfo as NSDictionary
            )
            completionHandler(.newData)
        }

        let delegateCalled = expectation(description: "callback called")
        delegate.didReceiveRemoteNotification(
            userInfo: expectedUserInfo,
            isForeground: true
        ) { result in
            XCTAssertEqual(result, .newData)
            delegateCalled.fulfill()
        }

        self.wait(for: [delegateCalled], timeout: 10)
    }
}

final class TestPush: InternalPushProtocol, PushProtocol, @unchecked Sendable {

    let notificationStatusSubject: PassthroughSubject<AirshipNotificationStatus, Never> = PassthroughSubject()

    var notificationStatusPublisher: AnyPublisher<AirshipNotificationStatus, Never> {
        notificationStatusSubject.removeDuplicates().eraseToAnyPublisher()
    }

    var notificationStatus: AirshipNotificationStatus = AirshipNotificationStatus(
        isUserNotificationsEnabled: false,
        areNotificationsAllowed: false,
        isPushPrivacyFeatureEnabled: false,
        isPushTokenRegistered: false
    )


    var isPushNotificationsOptedIn: Bool = false

    var backgroundPushNotificationsEnabled: Bool = false

    var userPushNotificationsEnabled: Bool = false

    var extendedPushNotificationPermissionEnabled: Bool = false

    var requestExplicitPermissionWhenEphemeral: Bool = false

    var notificationOptions: UANotificationOptions  = []

    var customCategories: Set<UNNotificationCategory> = Set()

    var accengageCategories: Set<UNNotificationCategory> = Set()

    var requireAuthorizationForDefaultCategories: Bool = false

    var pushNotificationDelegate: PushNotificationDelegate?

    var registrationDelegate: RegistrationDelegate?

    var launchNotificationResponse: UNNotificationResponse?

    var authorizedNotificationSettings: UAAuthorizedNotificationSettings = []

    var authorizationStatus: UAAuthorizationStatus = .notDetermined

    var userPromptedForNotifications: Bool = false

    var defaultPresentationOptions: UNNotificationPresentationOptions = []

    var badgeNumber: Int = 0

    var deviceToken: String?
    var updateAuthorizedNotificationTypesCalled = false
    var registrationError: Error?
    var didReceiveRemoteNotificationCallback:
        (
            (
                [AnyHashable: Any], Bool,
                @escaping (UIBackgroundFetchResult) -> Void
            ) ->
                Void
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
        isForeground: Bool,
        completionHandler: @escaping (Any) -> Void
    ) {
        self.didReceiveRemoteNotificationCallback!(
            userInfo,
            isForeground,
            completionHandler
        )
    }


    func presentationOptionsForNotification(_ notification: UNNotification, completionHandler: (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
    
    
    func didReceiveNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        assertionFailure("Unable to create UNNotificationResponse in tests.")
    }
}



class TestPushableComponent: PushableComponent {
    var didReceiveRemoteNotificationCallback:
        (
            ([AnyHashable: Any], @escaping (UIBackgroundFetchResult) -> Void) ->
                Void
        )?

    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        self.didReceiveRemoteNotificationCallback!(
            notification,
            completionHandler
        )
    }

    public func receivedNotificationResponse(
        _ response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) {
        assertionFailure("Unable to create UNNotificationResponse in tests.")
    }
}
