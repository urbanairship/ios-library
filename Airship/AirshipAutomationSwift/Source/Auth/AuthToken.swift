/* Copyright Airship and Contributors */

import Foundation

/// Model object for auth tokens.
class AuthToken {
    
    /// The associated channel ID.
    private(set) var channelID: String
    /// The token.
    private(set) var token: String
    /// The expiration date.
    private(set) var expiration: Date
    
    /// Auth token initilizer.
    ///
    /// - Parameters:
    ///   - channelID: The channel ID.
    ///   - token: The token.
    ///   - expiration: The expiration date.
    init(
        channelID: String,
        token: String,
        expiration: Date
    ) {
        self.channelID = channelID
        self.token = token
        self.expiration = expiration
    }
    
}
