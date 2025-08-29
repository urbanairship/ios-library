/* Copyright Airship and Contributors */

import Foundation

struct SessionState: Equatable, Sendable {
    var sessionID: String
    var conversionSendID: String?
    var conversionMetadata: String?

    init(
        sessionID: String = UUID().uuidString,
        conversionSendID: String? = nil,
        conversionMetadata: String? = nil
    ) {
        self.sessionID = sessionID
        self.conversionSendID = conversionSendID
        self.conversionMetadata = conversionMetadata
    }
}
