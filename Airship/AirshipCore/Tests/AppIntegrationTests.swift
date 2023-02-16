/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class AppIntegrationTests: XCTestCase {
    private let testDelegate = TestIntegrationDelegate()
    
    override func setUpWithError() throws {
        AppIntegration.integrationDelegate = self.testDelegate
    }

    override func tearDownWithError() throws {
        AppIntegration.integrationDelegate = nil
    }
    
    func testPerformFetchWithCompletionHandler() throws {
        let appCallbackCalled = expectation(description: "Callback called")
        AppIntegration.application(UIApplication.shared, performFetchWithCompletionHandler: { result in
            XCTAssertEqual(result, .noData)
            appCallbackCalled.fulfill()
        })
        wait(for: [appCallbackCalled], timeout: 10)
        XCTAssertTrue(self.testDelegate.onBackgroundAppRefreshCalled!)
    }
    
    func testDidRegisterForRemoteNotificationsWithDeviceToken() throws {
        let token = Data("some token".utf8)
        AppIntegration.application(UIApplication.shared, didRegisterForRemoteNotificationsWithDeviceToken:token)
        XCTAssertEqual(token, self.testDelegate.deviceToken)
    }
    
    func testDidFailToRegisterForRemoteNotificationsWithError() throws {
        let error = AirshipErrors.error("some error") as NSError
        AppIntegration.application(UIApplication.shared, didFailToRegisterForRemoteNotificationsWithError:error)
        XCTAssertEqual(error, self.testDelegate.registrationError as NSError?)
    }

    func testDidReceiveRemoteNotifications() throws {
        let notification = ["some": "alert"]
        
        let testHookCalled = expectation(description: "Callback called")
        self.testDelegate.didReceiveRemoteNotificationCallback = { userInfo, isForeground, completionHandler in
            XCTAssertEqual(notification as NSDictionary, userInfo as NSDictionary)
            testHookCalled.fulfill()
            completionHandler(.newData)
        }
        
        let appCallbackCalled = expectation(description: "Callback called")
        AppIntegration.application(UIApplication.shared, didReceiveRemoteNotification: notification) { result in
            XCTAssertEqual(result, .newData)
            appCallbackCalled.fulfill()
        }
        
        wait(for: [testHookCalled, appCallbackCalled], timeout: 10)
    }
}

class TestIntegrationDelegate : NSObject, AppIntegrationDelegate {
    var onBackgroundAppRefreshCalled: Bool?
    var deviceToken: Data?
    var registrationError: Error?
    var didReceiveRemoteNotificationCallback: (([AnyHashable : Any], Bool, @escaping (UIBackgroundFetchResult) -> Void) -> Void)?

    func onBackgroundAppRefresh() {
        self.onBackgroundAppRefreshCalled = true
    }
    
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        self.deviceToken = deviceToken
    }
    
    func didFailToRegisterForRemoteNotifications(error: Error) {
        self.registrationError = error
    }
    
    func didReceiveRemoteNotification(userInfo: [AnyHashable : Any],
                                      isForeground: Bool,
                                      completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.didReceiveRemoteNotificationCallback!(userInfo, isForeground, completionHandler)
    }
    
    func willPresentNotification(notification: UNNotification,
                                 presentationOptions options: UNNotificationPresentationOptions = [],
                                 completionHandler: @escaping () -> Void) {
        assertionFailure("Unable to mock UNNotification.")
    }
    
    func didReceiveNotificationResponse(response: UNNotificationResponse,
                                        completionHandler: @escaping () -> Void) {
        assertionFailure("Unable to mock UNNotificationResponse.")
    }
    
    func presentationOptionsForNotification(_ notification: UNNotification, completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}
