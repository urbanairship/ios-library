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

    func testDidRegisterForRemoteNotifications() async throws {
        let data = Data()
        delegate.didRegisterForRemoteNotifications(deviceToken: data)
        let token = await push.deviceToken?.data(using: .utf8)
        XCTAssertEqual(data, token)
        XCTAssertTrue(self.analytics.onDeviceRegistrationCalled)
    }

    func testDidFailToRegisterForRemoteNotifications() throws {
        let error = AirshipErrors.error("some error")
        delegate.didFailToRegisterForRemoteNotifications(error: error)
        XCTAssertEqual("some error", error.localizedDescription)
    }

    @MainActor
    func testDidReceiveRemoteNotification() async throws {
        let expectedUserInfo = ["neat": "story"]

        self.push.didReceiveRemoteNotificationCallback = {
            userInfo,
            isForeground in
            XCTAssertEqual(
                expectedUserInfo as NSDictionary,
                userInfo as NSDictionary
            )
            XCTAssertTrue(isForeground)
            return .noData
        }

        self.pushableComponent.didReceiveRemoteNotificationCallback = {
            userInfo in
            XCTAssertEqual(
                expectedUserInfo as NSDictionary,
                userInfo as NSDictionary
            )
            return .newData
        }

        let result = await delegate.didReceiveRemoteNotification(
            userInfo: expectedUserInfo,
            isForeground: true
        )
        
        XCTAssertEqual(result, .newData)
    }
}


class TestPushableComponent: AirshipPushableComponent, @unchecked Sendable {
    
    var didReceiveRemoteNotificationCallback:(
        ([AnyHashable: Any]) -> UIBackgroundFetchResult
    )?

    public func receivedRemoteNotification(
        _ notification: AirshipJSON
    ) async -> UIBackgroundFetchResult {
        let unwrapped = notification.unWrap() as? [AnyHashable: Any] ?? [:]
        return self.didReceiveRemoteNotificationCallback!(unwrapped)
    }

    public func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        assertionFailure("Unable to create UNNotificationResponse in tests.")
    }
}
