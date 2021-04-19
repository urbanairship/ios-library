/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class AirshipChatTests: XCTestCase {
    var airshipChat: AirshipChat!
    var mockConversation: MockConversation!

    override func setUp() {
        self.mockConversation = MockConversation()
        let dataStore = UAPreferenceDataStore(keyPrefix: UUID().uuidString)

        self.airshipChat = AirshipChat(dataStore: dataStore,
                                       conversation: self.mockConversation)

    }

    func testOpenDelegate() throws {
        let mockOpenDelegate = MockAirshipChatOpenDelegate()
        self.airshipChat.openChatDelegate = mockOpenDelegate

        self.airshipChat.openChat()

        XCTAssertTrue(mockOpenDelegate.openCalled)
        XCTAssertNil(mockOpenDelegate.lastOpenMessage)
    }

    func testOpenDelegateWithMessage() throws {
        let mockOpenDelegate = MockAirshipChatOpenDelegate()
        self.airshipChat.openChatDelegate = mockOpenDelegate

        self.airshipChat.openChat(message: "neat")

        XCTAssertTrue(mockOpenDelegate.openCalled)
        XCTAssertEqual("neat", mockOpenDelegate.lastOpenMessage)
    }

    func testDisable() throws {
        self.airshipChat.enabled = false
        XCTAssertFalse(self.mockConversation.enabled)

        self.airshipChat.enabled = true
        XCTAssertTrue(self.mockConversation.enabled)
    }

    func testBackgroundPushRefresh() throws {
        let notificationInfo = ["com.urbanairship.refresh_chat": true ]
        let notification = UANotificationContent.notification(withNotificationInfo: notificationInfo)

        let expectation = XCTestExpectation(description: "Callback")
        self.airshipChat.receivedRemoteNotification(notification, completionHandler: { (result) in
            XCTAssertEqual(UIBackgroundFetchResult.newData, result)
            expectation.fulfill()
        })

        XCTAssertTrue(mockConversation.refreshed)
    }
}
