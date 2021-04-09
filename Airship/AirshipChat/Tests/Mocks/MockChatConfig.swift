/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockChatConfig : ChatConfig {
    let appKey: String
    var chatURL: String?
    var chatWebSocketURL: String?

    init(appKey: String, chatURL: String?, chatWebSocketURL: String?) {
        self.appKey =  appKey
        self.chatURL = chatURL
        self.chatWebSocketURL = chatWebSocketURL
    }
}
