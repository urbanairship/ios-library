/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class AirshipChatTests: XCTestCase {
    var airshipChat: Chat!
    var dataStore: PreferenceDataStore!
    var mockConversation: MockConversation!
    var privacyManager : PrivacyManager!

    override func setUp() {
        self.mockConversation = MockConversation()
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.privacyManager = PrivacyManager(dataStore: self.dataStore, defaultEnabledFeatures: .all)

        self.airshipChat = Chat(dataStore: dataStore,
                                conversation: self.mockConversation,
                                privacyManager: self.privacyManager)

        self.privacyManager.enabledFeatures = Features.all
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

        // uairship://chat?routing={"agent":"smith"}&chat_input=Hello Person!&prepopulated_messages=[{"msg":"msg1","url":"https://fakeu.rl","date":"2021-01-01T00:00:00Z","id":"asdfasdf"},{"msg":"msg2","url":"https://fakeu.rl"},"date":"2021-01-02T00:00:00Z","id":"fdsafdsa"}]
        
        let encodedWithOptions = URL(string: "uairship://chat?routing=%7B%22agent%22%3A%22smith%22%7D&chat_input=Hello%20Person%21&prepopulated_messages=%5B%7B%22msg%22%3A%22msg1%22%2C%22url%22%3A%22https%3A%2F%2Ffakeu.rl%22%2C%22date%22%3A%222021-01-01T00%3A00%3A00Z%22%2C%22id%22%3A%22asdfasdf%22%7D%2C%7B%22msg%22%3A%22msg2%22%2C%22url%22%3A%22https%3A%2F%2Ffakeu.rl%22%2C%22date%22%3A%222021-01-02T00%3A00%3A00Z%22%2C%22id%22%3A%22fdsafdsa%22%7D%5D%0A%0A")!
        XCTAssertTrue(self.airshipChat.deepLink(encodedWithOptions))
        XCTAssertTrue(mockOpenDelegate.openCalled)
        
        XCTAssertEqual("Hello Person!", mockOpenDelegate.lastOpenMessage)
        XCTAssertEqual("smith", mockConversation.routing?.agent)
        
        let expectedIncoming = [
            ChatIncomingMessage(message: "msg1",
                                url: "https://fakeu.rl",
                                date: Utils.parseISO8601Date(from:"2021-01-01T00:00:00"),
                                messageID: "asdfasdf"),
            ChatIncomingMessage(message: "msg2",
                                url: "https://fakeu.rl",
                                date: Utils.parseISO8601Date(from:"2021-01-02T00:00:00"),
                                messageID: "fdsafdsa"),
                       ]
        
        XCTAssertEqual(expectedIncoming, mockConversation.incoming)

    }
    
    func testSimpleDeepLinkEncodedOptions() throws {
        let mockOpenDelegate = MockChatOpenDelegate()
        self.airshipChat.openChatDelegate = mockOpenDelegate

        // uairship://chat?route_agent=smith&prepopulated_message=msg1
        
        let encodedWithOptions = URL(string: "uairship://chat?route_agent=smith&prepopulated_message=msg1")!
        XCTAssertTrue(self.airshipChat.deepLink(encodedWithOptions))
        XCTAssertTrue(mockOpenDelegate.openCalled)
        
        XCTAssertEqual("smith", mockConversation.routing?.agent)
        
        let expectedIncoming = [
            ChatIncomingMessage(message: "msg1",
                                url: nil,
                                date: nil,
                                messageID: nil)
                       ]
        
        XCTAssertEqual(expectedIncoming, mockConversation.incoming)

    }
}
