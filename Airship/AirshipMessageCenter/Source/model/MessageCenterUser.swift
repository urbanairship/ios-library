/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
    import AirshipCore
#endif

/// Model object for holding user data.
@objc(UAMessageCenterUser)
public class MessageCenterUser: NSObject, Codable {

    /// The username.
    @objc
    public let password: String

    /// The password.
    @objc
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

extension MessageCenterUser {
    @objc
    public var basicAuthString: String {
        return Utils.authHeader(
            username: self.username,
            password: self.password
        ) ?? ""
    }
}
