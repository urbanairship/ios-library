/* Copyright Airship and Contributors */

import Testing
import Combine

@testable import AirshipCore
import Foundation
import UserNotifications

@MainActor
@Suite struct DefaultAppIntegrationdelegateTest {

    private let delegate: DefaultAppIntegrationDelegate
    private let push = TestPush()
    private let analytics = TestAnalytics()
    private let pushableComponent = TestPushableComponent()
    private let airshipInstance: TestAirshipInstance

    init() async throws {
        airshipInstance = TestAirshipInstance()
        self.airshipInstance.actionRegistry = DefaultAirshipActionRegistry()
        self.airshipInstance.makeShared()

        self.delegate = DefaultAppIntegrationDelegate(
            push: self.push,
            analytics: self.analytics,
            pushableComponents: [pushableComponent]
        )
    }


    @Test
    @MainActor
    func testDidRegisterForRemoteNotifications() async throws {
        let data = Data()
        delegate.didRegisterForRemoteNotifications(deviceToken: data)
        let token = push.deviceToken?.data(using: .utf8)
        #expect(data == token)
    }

    @Test
    @MainActor
    func testDidFailToRegisterForRemoteNotifications() throws {
        let error = AirshipErrors.error("some error")
        delegate.didFailToRegisterForRemoteNotifications(error: error)
        #expect("some error" == error.localizedDescription)
    }

    @Test
    @MainActor
    func testDidReceiveRemoteNotification() async throws {
        let expectedUserInfo = ["neat": "story"]

        self.push.didReceiveRemoteNotificationCallback = {
            userInfo,
            isForeground in
            #expect(
                (expectedUserInfo as NSDictionary) ==
                (userInfo as NSDictionary)
            )
            #expect(isForeground)
            return .noData
        }

        self.pushableComponent.didReceiveRemoteNotificationCallback = {
            userInfo in
            #expect(
                (expectedUserInfo as NSDictionary) ==
                (userInfo as NSDictionary)
            )
            return .newData
        }

        let result = await withCheckedContinuation { continuation in
            delegate.didReceiveRemoteNotification(
                userInfo: expectedUserInfo,
                isForeground: true
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        #expect(result == .newData)
    }
}


fileprivate class TestPushableComponent: AirshipPushableComponent, @unchecked Sendable {
    
    var didReceiveRemoteNotificationCallback:(
        ([AnyHashable: Any]) -> UABackgroundFetchResult
    )?

    public func receivedRemoteNotification(
        _ notification: AirshipJSON
    ) async -> UABackgroundFetchResult {
        let unwrapped = notification.unWrap() as? [AnyHashable: Any] ?? [:]
        return self.didReceiveRemoteNotificationCallback!(unwrapped)
    }

    public func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        assertionFailure("Unable to create UNNotificationResponse in tests.")
    }
}
