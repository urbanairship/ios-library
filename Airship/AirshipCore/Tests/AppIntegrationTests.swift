/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore
@testable import AirshipBasement

class AppIntegrationTests: XCTestCase {
    private var testDelegate: TestIntegrationDelegate!

    @MainActor
    override func setUpWithError() throws {
        self.testDelegate = TestIntegrationDelegate()
        AppIntegration.integrationDelegate = self.testDelegate
    }

    @MainActor
    override func tearDownWithError() throws {
        AppIntegration.integrationDelegate = nil
    }

    @MainActor
    func testPerformFetchWithCompletionHandler() throws {
        let appCallbackCalled = expectation(description: "Callback called")
        AppIntegration.application(
            UIApplication.shared,
            performFetchWithCompletionHandler: { result in
                XCTAssertEqual(result, .noData)
                appCallbackCalled.fulfill()
            }
        )
        wait(for: [appCallbackCalled], timeout: 10)
        XCTAssertTrue(self.testDelegate.onBackgroundAppRefreshCalled!)
    }

    @MainActor
    func testDidRegisterForRemoteNotificationsWithDeviceToken() throws {
        let token = Data("some token".utf8)
        AppIntegration.application(
            UIApplication.shared,
            didRegisterForRemoteNotificationsWithDeviceToken: token
        )
        XCTAssertEqual(token, self.testDelegate.deviceToken)
    }

    @MainActor
    func testDidFailToRegisterForRemoteNotificationsWithError() throws {
        let error = AirshipErrors.error("some error") as NSError
        AppIntegration.application(
            UIApplication.shared,
            didFailToRegisterForRemoteNotificationsWithError: error
        )
        XCTAssertEqual(error, self.testDelegate.registrationError as NSError?)
    }

    @MainActor
    func testDidReceiveRemoteNotifications() async throws {
        let notification = ["some": "alert"]

        let testHookCalled = expectation(description: "Callback called")
        self.testDelegate.didReceiveRemoteNotificationCallback = { userInfo, isForeground in
            XCTAssertEqual(
                notification as NSDictionary,
                userInfo as NSDictionary
            )
            testHookCalled.fulfill()
            return .newData
        }

        let result = await AppIntegration.application(
            UIApplication.shared,
            didReceiveRemoteNotification: notification
        )

        XCTAssertEqual(result, .newData)

        await fulfillment(of: [testHookCalled], timeout: 10)
    }
}

@MainActor
final class TestIntegrationDelegate: NSObject, AppIntegrationDelegate {
    var onBackgroundAppRefreshCalled: Bool?
    var deviceToken: Data?
    var registrationError: Error?
    var didReceiveRemoteNotificationCallback: (@MainActor ([AnyHashable: Any], Bool) async -> UIBackgroundFetchResult)?

    func onBackgroundAppRefresh() {
        self.onBackgroundAppRefreshCalled = true
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        self.deviceToken = deviceToken
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        self.registrationError = error
    }

    func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        isForeground: Bool
    ) async -> UIBackgroundFetchResult {
        return await self.didReceiveRemoteNotificationCallback!(
            userInfo,
            isForeground
        )
    }

    func willPresentNotification(
        notification: UNNotification,
        presentationOptions options: UNNotificationPresentationOptions = []
    ) async {
        assertionFailure("Unable to mock UNNotification.")
    }

    func didReceiveNotificationResponse(
        response: UNNotificationResponse
    ) async {
        assertionFailure("Unable to mock UNNotificationResponse.")
    }
    
    func presentationOptionsForNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions {
        return []
    }
}
