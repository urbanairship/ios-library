/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipMessageCenter
import AirshipCore
#endif


/// Delegate protocol for receiving callbacks related to message center.
@objc
public protocol UAMessageCenterDisplayDelegate {

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
public protocol UAMessageCenterPredicate: Sendable {
    /// Evaluate the message center message. Used to filter the message center list
    /// - Parameters:
    ///     - message: The message center message
    /// - Returns: True if the message passed the evaluation, otherwise false.
    func evaluate(message: UAMessageCenterMessage) -> Bool
}

@objc
public final class UAMessageCenter: NSObject, Sendable {

    @MainActor
    private let storage = Storage()
    

    /// Message center display delegate.
    @objc
    @MainActor
    public weak var displayDelegate: (any UAMessageCenterDisplayDelegate)? {
        get {
            guard let wrapped = Airship.messageCenter.displayDelegate as? UAMessageCenterDisplayDelegateWrapper else {
                return nil
            }
            return wrapped.forwardDelegate
        }

        set {
            if let newValue {
                let wrapper = UAMessageCenterDisplayDelegateWrapper(newValue)
                Airship.messageCenter.displayDelegate = wrapper
                storage.displayDelegate = wrapper
            } else {
                Airship.messageCenter.displayDelegate = nil
                storage.displayDelegate = nil
            }
        }
    }
    
    /// Message center inbox.
    @objc
    public let inbox: UAMessageCenterInbox = UAMessageCenterInbox()

    /// Loads a Message center theme from a plist file. If you are embedding the MessageCenterView directly
    ///  you should pass the theme in through the view extension `.messageCenterTheme(_:)`.
    /// - Parameters:
    ///     - plist: The name of the plist in the bundle.
    @objc
    @MainActor
    public func setThemeFromPlist(_ plist: String) throws {
        try Airship.messageCenter.setThemeFromPlist(plist)
    }

    /// Default message center predicate. Only applies to the OOTB Message Center. If you are embedding the MessageCenterView directly
    ///  you should pass the predicate in through the view extension `.messageCenterPredicate(_:)`.
    @objc
    @MainActor
    public var predicate: (any UAMessageCenterPredicate)? {
        didSet {
            if let predicate {
                Airship.messageCenter.predicate = UAMessageCenterPredicateWrapper(delegate: predicate)
            } else {
                Airship.messageCenter.predicate = nil
            }
        }
    }

    /// Display the message center.
    @objc
    @MainActor
    public func display() {
        Airship.messageCenter.display()
    }

    /// Display the given message with animation.
    /// - Parameters:
    ///     - messageID:  The messageID of the message.
    @objc(displayWithMessageID:)
    @MainActor
    public func display(messageID: String) {
        Airship.messageCenter.display(messageID: messageID)
    }

    /// Dismiss the message center.
    @objc
    @MainActor
    public func dismiss() {
        Airship.messageCenter.dismiss()
    }

    @MainActor
    fileprivate final class Storage  {
        var displayDelegate: (any MessageCenterDisplayDelegate)?
    }

}

fileprivate final class UAMessageCenterDisplayDelegateWrapper: NSObject, MessageCenterDisplayDelegate {
    weak var forwardDelegate: (any UAMessageCenterDisplayDelegate)?
    init(_ forwardDelegate: any UAMessageCenterDisplayDelegate) {
        self.forwardDelegate = forwardDelegate
    }
    
    public func displayMessageCenter(messageID: String) {
        self.forwardDelegate?.displayMessageCenter(messageID: messageID)
    }
    
    public func displayMessageCenter() {
        self.forwardDelegate?.dismissMessageCenter()
    }
    
    public func dismissMessageCenter() {
        self.forwardDelegate?.dismissMessageCenter()
    }
}

fileprivate final class UAMessageCenterPredicateWrapper: NSObject, MessageCenterPredicate {
    private let delegate: any UAMessageCenterPredicate
    
    init(delegate: any UAMessageCenterPredicate) {
        self.delegate = delegate
    }
    
    public func evaluate(message: MessageCenterMessage) -> Bool {
        let mcMessage = UAMessageCenterMessage(message: message)
        return self.delegate.evaluate(message: mcMessage)
    }
}
