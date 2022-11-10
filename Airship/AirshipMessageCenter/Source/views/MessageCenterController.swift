/* Copyright Urban Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Controller for the Message Center View.
@objc(UAMessageCenterController)
public class MessageCenterController: NSObject, ObservableObject {
    
    @Published
    var messageID: String? = nil

    /// Navigates to the message ID.
    /// - Parameters:
    ///     - messageID: The message ID to navigate to.
    @objc
    public func navigate(messageID: String?) {
        self.messageID = messageID
    }

    @objc
    public override init() {}
}


