/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class AirshipChatTests: XCTestCase {
    var airshipChat: Chat!
    var dataStore: UAPreferenceDataStore!
    var mockConversation: MockConversation!
    var privacyManager : UAPrivacyManager!

    override func setUp() {
        self.mockConversation = MockConversation()
        self.dataStore = UAPreferenceDataStore(keyPrefix: UUID().uuidString)
        self.privacyManager = UAPrivacyManager(dataStore: self.dataStore, defaultEnabledFeatures: .all)

        self.airshipChat = Chat(dataStore: dataStore,
                                conversation: self.mockConversation,
                                privacyManager: self.privacyManager)

        self.privacyManager.enabledFeatures = UAFeatures.all
    }

    func testOpenDelegate() throws {
        let mockOpenDelegate = MockChatOpenDelegate()
        self.airshipChat.openChatDelegate = mockOpenDelegate

        self.airshipChat.openChat()

        XCTAssertTrue(mockOpenDelegate.openCalled)
        XCTAssertNil(mockOpenDelegate.lastOpenMessage)
    }

    func testOpenDelegateWithMessage() throws {
        let mockOpenDelegate = MockChatOpenDelegate()
        self.airshipChat.openChatDelegate = mockOpenDelegate

        self.airshipChat.openChat(message: "neat")

        XCTAssertTrue(mockOpenDelegate.openCalled)
        XCTAssertEqual("neat", mockOpenDelegate.lastOpenMessage)
    }

    func testDataCollectionDisabled() throws {
        XCTAssertTrue(self.mockConversation.enabled)

        self.privacyManager.enabledFeatures = []
        XCTAssertFalse(self.mockConversation.enabled)
        XCTAssertTrue(self.mockConversation.clearDataCalled)
    }

    func testBackgroundPushRefresh() throws {
        let notificationInfo = ["com.urbanairship.refresh_chat": true ]

        let expectation = XCTestExpectation(description: "Callback")
        self.airshipChat.receivedRemoteNotification(notificationInfo, completionHandler: { (result) in
            XCTAssertEqual(UIBackgroundFetchResult.newData, result)
            expectation.fulfill()
        })

        XCTAssertTrue(mockConversation.refreshed)
    }
    
    func testDeepLink() throws {
        let mockOpenDelegate = MockChatOpenDelegate()
        self.airshipChat.openChatDelegate = mockOpenDelegate
        
        let valid = URL(string: "uairship://chat")!
        XCTAssertTrue(self.airshipChat.deepLink(valid))
        XCTAssertTrue(mockOpenDelegate.openCalled)
        
        mockOpenDelegate.openCalled = false
        
        let trailingSlash = URL(string: "uairship://chat/")!
        XCTAssertTrue(self.airshipChat.deepLink(trailingSlash))
        XCTAssertTrue(mockOpenDelegate.openCalled)
    }
    
    func testDeepLinkEncodedOptions() throws {
        let mockOpenDelegate = MockChatOpenDelegate()
        self.airshipChat.openChatDelegate = mockOpenDelegate

        // uairship://chat?routing={"agent":"smith"}&chat_input=Hello Person!
        let encodedWithOptions = URL(string: "uairship://chat?routing=%7B%22agent%22%3A%22smith%22%7D&chat_input=Hello%20Person%21")!
        XCTAssertTrue(self.airshipChat.deepLink(encodedWithOptions))
        XCTAssertTrue(mockOpenDelegate.openCalled)
        
        XCTAssertEqual("Hello Person!", mockOpenDelegate.lastOpenMessage)
        XCTAssertEqual("smith", mockConversation.routing?.agent)
    }
}
