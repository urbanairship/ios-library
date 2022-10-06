/* Copyright Airship and Contributors */

import AirshipCore

///
/// Model object for holding user data.
///
@objc(UAMessageCenterUser)
public class MessageCenterUser: NSObject, Codable {

    ///
    /// The username.
    ///
    public let password: String
    
    ///
    /// The password.
    ///
    public let username: String

    /// - Note: for internal use only.  :nodoc:
    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    private enum CodingKeys: String, CodingKey {
        case username = "user_id"
        case password = "password"
    }
}
