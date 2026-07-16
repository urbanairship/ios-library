/* Copyright Airship and Contributors */

import Foundation

/// Model object for holding user data.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct MessageCenterUser: Codable, Sendable, Equatable {

    /// The username.
    public var password: String

    /// The password.
    public var username: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    private enum CodingKeys: String, CodingKey {
        case username = "user_id"
        case password = "password"
    }
}

@_spi(AirshipInternal)
extension MessageCenterUser {
    public var basicAuthString: String {
        guard let data = "\(self.username):\(self.password)".data(using: .utf8) else {
            return ""
        }
        return "Basic \(data.base64EncodedString())"
    }
}
