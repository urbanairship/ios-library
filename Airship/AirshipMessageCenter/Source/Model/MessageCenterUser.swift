/* Copyright Airship and Contributors */

import AirshipCore

/// Model object for holding user data.
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

extension MessageCenterUser {
    public var basicAuthString: String {
        return AirshipUtils.authHeader(
            username: self.username,
            password: self.password
        ) ?? ""
    }
}
