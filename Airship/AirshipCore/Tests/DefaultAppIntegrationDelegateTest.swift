/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class DefaultAppIntegrationdelegateTest: XCTestCase {

    private var delegate: DefaultAppIntegrationDelegate!
    private let push = TestPush()
    private let analytics = InternalTestAnalytics()
    private let pushableComponent = TestPushableComponent()
    private let airshipInstance = TestAirshipInstance()

    override func setUpWithError() throws {
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

class TestPush: InternalPushProtocol, PushProtocol {

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

class InternalTestAnalytics: InternalAnalyticsProtocol {
    func addHeaderProvider(_ headerProvider: @escaping () async -> [String : String]) {

    }

    var conversionSendID: String?

    var conversionPushMetadata: String?

    var sessionID: String?

    func addEvent(_ event: Event) {

    }

    func associateDeviceIdentifiers(_ associatedIdentifiers: AirshipCore.AssociatedIdentifiers) {

    }

    func currentAssociatedDeviceIdentifiers() -> AssociatedIdentifiers {
        return AssociatedIdentifiers()
    }

    func trackScreen(_ screen: String?) {

    }

    func registerSDKExtension(_ ext: AirshipCore.AirshipSDKExtension, version: String) {

    }

    func launched(fromNotification notification: [AnyHashable : Any]) {}

    var onDeviceRegistrationCalled = false

    func onDeviceRegistration(token: String) {
        onDeviceRegistrationCalled = true
    }

    func onNotificationResponse(
        response: UNNotificationResponse,
        action: UNNotificationAction?
    ) {
        assertionFailure("Unable to create UNNotificationResponse in tests.")
    }

}
