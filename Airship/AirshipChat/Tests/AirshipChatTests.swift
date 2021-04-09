/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class AirshipChatTests: XCTestCase {
    var airshipChat: AirshipChat!
    var mockConversation: MockConversation!

    override func setUp() {
        let mockConversation = MockConversation()
        let dataStore = UAPreferenceDataStore(keyPrefix: UUID().uuidString)

        self.airshipChat = AirshipChat(dataStore: dataStore,
                                       conversation: mockConversation)

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
}
