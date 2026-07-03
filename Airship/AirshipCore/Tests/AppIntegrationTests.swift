/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
@_spi(AirshipInternal) @testable import AirshipBasement
import Foundation
import UserNotifications
#if !os(watchOS)
import UIKit
#else
import WatchKit
#endif

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct AppIntegrationTests {
    private let testDelegate: TestIntegrationDelegate

    init() {
        self.testDelegate = TestIntegrationDelegate()
        AppIntegration.integrationDelegate = self.testDelegate
    }


    @Test
    @MainActor
    func testDidRegisterForRemoteNotificationsWithDeviceToken() throws {
        let token = Data("some token".utf8)
        AppIntegration.application(
            UIApplication.shared,
            didRegisterForRemoteNotificationsWithDeviceToken: token
        )
        #expect(token == self.testDelegate.deviceToken)
    }

    @Test
    @MainActor
    func testDidFailToRegisterForRemoteNotificationsWithError() throws {
        let error = AirshipErrors.error("some error") as NSError
        AppIntegration.application(
            UIApplication.shared,
            didFailToRegisterForRemoteNotificationsWithError: error
        )
        #expect(error == self.testDelegate.registrationError as NSError?)
    }

    @Test
    @MainActor
    func testDidReceiveRemoteNotifications() async throws {
        let notification = ["some": "alert"]

        let testHookCalled = AirshipTestExpectation(description: "Callback called")
        self.testDelegate.didReceiveRemoteNotificationCallback = { userInfo, isForeground in
            #expect(
                notification as NSDictionary ==
                userInfo as NSDictionary
            )
            testHookCalled.fulfill()
            return .newData
        }

        let result = await AppIntegration.application(
            UIApplication.shared,
            didReceiveRemoteNotification: notification
        )

        #expect(result == .newData)

        await fulfillment(of: [testHookCalled], timeout: 10)
    }
}

@MainActor
final class TestIntegrationDelegate: NSObject, AppIntegrationDelegate {
    var deviceToken: Data?
    var registrationError: Error?
    var didReceiveRemoteNotificationCallback: (@MainActor ([AnyHashable: Any], Bool) async -> UIBackgroundFetchResult)?


    func didRegisterForRemoteNotifications(deviceToken: Data) {
        self.deviceToken = deviceToken
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        self.registrationError = error
    }

    func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        isForeground: Bool,
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            let result = await self.didReceiveRemoteNotificationCallback?(userInfo, isForeground) ?? .noData
            completionHandler(result)
        }
    }

    func willPresentNotification(
        notification: UNNotification,
        presentationOptions: UNNotificationPresentationOptions,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    func didReceiveNotificationResponse(
        response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
    
    func presentationOptions(
        for notification: UNNotification,
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}
