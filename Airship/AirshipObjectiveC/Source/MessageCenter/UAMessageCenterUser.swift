/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipMessageCenter
import AirshipCore
#endif

/// Message Center user.
@objc
public final class UAMessageCenterUser: NSObject, Sendable {

    internal let mcUser: MessageCenterUser

    init(user: MessageCenterUser) {
        self.mcUser = user
    }

    /// The password.
    @objc
    public var password: String {
        get {
            return mcUser.password
        }
    }

    /// The username.
    @objc
    public var username: String {
        get {
            return mcUser.username
        }
    }

    /// The basic auth string for the user.
    /// - Returns: An HTTP Basic Auth header string value in the form of: `Basic [Base64 Encoded "username:password"]`
    @objc
    public var basicAuthString: String {
        get {
            return mcUser.basicAuthString
        }
    }
}
