/* Copyright Airship and Contributors */

import XCTest
import Combine

@testable import AirshipCore

class DefaultAppIntegrationdelegateTest: XCTestCase {

    private var delegate: DefaultAppIntegrationDelegate!
    private let push = TestPush()
    private let analytics = TestAnalytics()
    private let pushableComponent = TestPushableComponent()
    private var airshipInstance: TestAirshipInstance!

    @MainActor
    override func setUp() async throws {
        airshipInstance = TestAirshipInstance()
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


class TestPushableComponent: AirshipPushableComponent {
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
