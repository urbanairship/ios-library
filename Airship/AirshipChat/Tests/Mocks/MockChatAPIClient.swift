/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockChatAPIClient : ChatAPIClientProtocol {
    var lastAppKey: String?
    var lastChannel: String?

    var result: (UVPResponse?, Error?)?
    func createUVP(appKey: String, channelID: String, callback: @escaping (UVPResponse?, Error?) -> ()) {
        self.lastAppKey = appKey
        self.lastChannel = channelID
        callback(result?.0, result?.1)
    }
}
