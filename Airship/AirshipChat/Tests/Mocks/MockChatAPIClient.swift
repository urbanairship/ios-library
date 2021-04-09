/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockChatAPIClient : ChatAPIClientProtocol {
    var lastChannel: String?

    var result: (UVPResponse?, Error?)?
    func createUVP(channelID: String, callback: @escaping (UVPResponse?, Error?) -> ()) {
        self.lastChannel = channelID
        callback(result?.0, result?.1)
    }
}
