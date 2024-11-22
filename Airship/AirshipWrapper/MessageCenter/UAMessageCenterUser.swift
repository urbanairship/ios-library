/* Copyright Airship and Contributors */

import Foundation
public import AirshipMessageCenter

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc
public class UAMessageCenterUser: NSObject {
    
    public var mcUser: MessageCenterUser
    
    public init(user: MessageCenterUser) {
        self.mcUser = user
    }
    
    @objc
    /// The username.
    public var password: String {
        get {
            return mcUser.password
        }
    }

    @objc
    /// The password.
    public var username: String {
        get {
            return mcUser.username
        }
    }
}
