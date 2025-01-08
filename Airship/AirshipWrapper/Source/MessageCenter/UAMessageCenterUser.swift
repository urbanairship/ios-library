/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipMessageCenter
import AirshipCore
#endif

/// Message Center user.
@objc
public final class UAMessageCenterUser: NSObject, Sendable {

    private let mcUser: MessageCenterUser

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
}
