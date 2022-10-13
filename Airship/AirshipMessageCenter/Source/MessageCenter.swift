/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Delegate protocol for receiving callbacks related to message center.
@objc(UAMessageCenterDisplayDelegate)
public protocol MessageCenterDisplayDelegate {
    
    /// Called when a message is requested to be displayed.
    ///
    /// - Parameters:
    ///   - messageID: The message ID.
    func displayMessageCenter(forMessageID messageID: String)
    
    /// Called when the message center is requested to be displayed.
    func displayMessageCenter()
    
    /// Called when the message center is requested to be dismissed.
    func dismissMessageCenter()
}

@objc(UAMessageCenter)
public class MessageCenter: NSObject {

    @objc
    public var displayDelegate: MessageCenterDisplayDelegate?
    
    private let privacyManager: PrivacyManager
    private let disableHelper: ComponentDisableHelper

    @objc
    public var inbox: MessageCenterInbox
    
    private var enabled: Bool {
        return self.isComponentEnabled && self.privacyManager.isEnabled(.messageCenter)
    }
    
    /// The shared PreferenceCenter instance.
    @objc
    public static var shared: MessageCenter {
        return Airship.requireComponent(ofType: MessageCenter.self)
    }
    
    init(
        dataStore: PreferenceDataStore,
        privacyManager: PrivacyManager,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        inbox: MessageCenterInbox
    ) {
        self.inbox = inbox
        self.privacyManager = privacyManager
        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "MessageCenter"
        )
        
        super.init()
        
        notificationCenter.addObserver(
            forName: PrivacyManager.changeEvent,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.updateEnableState()
        }
        
        self.disableHelper.onChange = {
            self.updateEnableState()
        }
        
        self.updateEnableState()
    }
    
    convenience init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        channel: Channel,
        privacyManager: PrivacyManager,
        workManager: AirshipWorkManagerProtocol
    ) {
        
        let inbox = MessageCenterInbox(
            with: config,
            dataStore: dataStore,
            channel: channel,
            workManager: workManager
        )
        
        self.init(
            dataStore: dataStore,
            privacyManager: privacyManager,
            inbox: inbox
        )
    }
    
    /// Display the message center.
    @objc
    public func display() {
        guard self.enabled else {
            AirshipLogger.warn("Message center disabled. Unable to display.");
            return
        }
        
        guard let displayDelegate = self.displayDelegate else {
            // TODO
            return
        }
        
        displayDelegate.displayMessageCenter()
    }
    
    ///
    /// Display the given message with animation.
    /// - Parameters:
    ///     - messageID:  The messageID of the message.
    @objc
    public func display(withMessageID messageID: String) {
        guard self.enabled else {
            AirshipLogger.warn("Message center disabled. Unable to display.");
            return
        }
        
        guard let displayDelegate = self.displayDelegate else {
            // TODO
            return
        }
        
        displayDelegate.displayMessageCenter(
            forMessageID: messageID
        )
    }
    
    /// Dismiss the message center.
    @objc
    public func dismiss() {
        if let displayDelegate = self.displayDelegate {
            displayDelegate.dismissMessageCenter()
        } else {
            // TODO
        }
    }

    private func updateEnableState() {
        self.inbox.enabled = self.enabled
    }
}

extension MessageCenter: Component, PushableComponent {
    
    private static let kUARichPushMessageIDKey = "_uamid"
    
    // MARK: Component
    
    public var isComponentEnabled: Bool {
        get {
            return self.disableHelper.enabled
        }
        
        set {
            self.disableHelper.enabled = newValue
        }
    }
    
    func deepLink(deepLink: URL) -> Bool {
        if !(deepLink.scheme == Airship.deepLinkScheme) {
            return false
        }
        
        if !(deepLink.host == "message_center") {
            return false
        }
        
        if (deepLink.path.hasPrefix("/message/")) {
            if (deepLink.pathComponents.count != 3) {
                return false
            }
            let messageID: String = deepLink.pathComponents[2]
            self.display(withMessageID: messageID)
        } else {
            if ((deepLink.path.count != 0) && !(deepLink.path == "/")) {
                return false
            }
            
            self.display()
        }
        
        return true
    }
    
    // MARK: PushableComponent
    
    public func receivedRemoteNotification(_
                                           notification: [AnyHashable : Any],
                                           completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        guard let messageID = MessageCenterMessage.parseMessageID(userInfo: notification) else {
            completionHandler(.noData)
            return
        }
        
        Task {
            let result = await self.inbox.refreshMessages()
            
            if !result {
                completionHandler(.failed)
                return
            }
            
            let message = await self.inbox.message(forID: messageID)
            
            guard message != nil else {
                completionHandler(.noData)
                return
            }
            completionHandler(.newData)
        }
    }
}
