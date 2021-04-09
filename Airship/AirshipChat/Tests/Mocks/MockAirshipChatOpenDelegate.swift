/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockAirshipChatOpenDelegate : AirshipChatOpenDelegate {
    var openCalled = false
    var lastOpenMessage: String?
    
    func openChat(message: String?) {
        openCalled = true
        lastOpenMessage = message
    }

}
