/* Copyright Airship and Contributors */

import Foundation
public import AirshipMessageCenter

/// Delegate protocol for receiving callbacks related to message center.
@objc(OUAMessageCenterDisplayDelegate)
public protocol OUAMessageCenterDisplayDelegate {

    /// Called when a message is requested to be displayed.
    ///
    /// - Parameters:
    ///   - messageID: The message ID.
    @objc(displayMessageCenterForMessageID:)
    @MainActor
    func displayMessageCenter(messageID: String)

    /// Called when the message center is requested to be displayed.
    @objc
    @MainActor
    func displayMessageCenter()

    /// Called when the message center is requested to be dismissed.
    @objc
    @MainActor
    func dismissMessageCenter()
}

@objc
public protocol OUAMessageCenterPredicate {
    /// Evaluate the message center message. Used to filter the message center list
    /// - Parameters:
    ///     - message: The message center message
    /// - Returns: True if the message passed the evaluation, otherwise false.
    func evaluate(message: MessageCenterMessage) -> Bool
}

@objc
public class OUAMessageCenter: NSObject {
    
    private var _displayDelegate: OUAMessageCenterDisplayDelegate?
    /// Message center display delegate.
    @objc
    @MainActor
    public var displayDelegate: OUAMessageCenterDisplayDelegate? {
        didSet {
            if let displayDelegate {
                MessageCenter.shared.displayDelegate = OUAMessageCenterDisplayDelegateWrapper(delegate: displayDelegate)
            } else {
                MessageCenter.shared.displayDelegate = nil
            }
        }
    }
    
    /// Message center inbox.
    @objc
    var inbox: OUAMessageCenterInbox {
        get {
            return OUAMessageCenterInbox()
        }
    }

    /// Loads a Message center theme from a plist file. If you are embedding the MessageCenterView directly
    ///  you should pass the theme in through the view extension `.messageCenterTheme(_:)`.
    /// - Parameters:
    ///     - plist: The name of the plist in the bundle.
    @objc
    @MainActor
    public func setThemeFromPlist(_ plist: String) throws {
        try MessageCenter.shared.setThemeFromPlist(plist)
    }

    private var _predicate: OUAMessageCenterPredicate?
    /// Default message center predicate. Only applies to the OOTB Message Center. If you are embedding the MessageCenterView directly
    ///  you should pass the predicate in through the view extension `.messageCenterPredicate(_:)`.
    @objc
    @MainActor
    public var predicate: OUAMessageCenterPredicate? {
        didSet {
            if let predicate {
                MessageCenter.shared.predicate = OUAMessageCenterPredicateWrapper(delegate: predicate)
            } else {
                MessageCenter.shared.predicate = nil
            }
        }
    }

    /// Display the message center.
    @objc
    @MainActor
    public func display() {
        MessageCenter.shared.display()
    }

    /// Display the given message with animation.
    /// - Parameters:
    ///     - messageID:  The messageID of the message.
    @objc(displayWithMessageID:)
    @MainActor
    public func display(messageID: String) {
        MessageCenter.shared.display(messageID: messageID)
    }

    /// Dismiss the message center.
    @objc
    @MainActor
    public func dismiss() {
        MessageCenter.shared.dismiss()
    }

}

public class OUAMessageCenterDisplayDelegateWrapper: NSObject, MessageCenterDisplayDelegate {
    private let delegate: OUAMessageCenterDisplayDelegate
    
    init(delegate: OUAMessageCenterDisplayDelegate) {
        self.delegate = delegate
    }
    
    public func displayMessageCenter(messageID: String) {
        self.delegate.displayMessageCenter(messageID: messageID)
    }
    
    public func displayMessageCenter() {
        self.delegate.dismissMessageCenter()
    }
    
    public func dismissMessageCenter() {
        self.delegate.dismissMessageCenter()
    }
}

public class OUAMessageCenterPredicateWrapper: NSObject, MessageCenterPredicate {
    private let delegate: OUAMessageCenterPredicate
    
    init(delegate: OUAMessageCenterPredicate) {
        self.delegate = delegate
    }
    
    public func evaluate(message: MessageCenterMessage) -> Bool {
        self.delegate.evaluate(message: message)
    }
}
