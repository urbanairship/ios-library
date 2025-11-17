/* Copyright Airship and Contributors */

import Foundation
import Combine

#if canImport(AirshipCore)
public import AirshipCore
#endif

#if canImport(UIKit)
import UIKit
#endif


/// Delegate protocol for receiving callbacks related to message center.
public protocol MessageCenterDisplayDelegate {

    /// Called when a message is requested to be displayed.
    ///
    /// - Parameters:
    ///   - messageID: The message ID.
    @MainActor
    func displayMessageCenter(messageID: String)

    /// Called when the message center is requested to be displayed.
    @MainActor
    func displayMessageCenter()

    /// Called when the message center is requested to be dismissed.
    @MainActor
    func dismissMessageCenter()
}

/// Airship Message Center Protocol.
@MainActor
public protocol MessageCenter: AnyObject, Sendable {

    /// Called when the Message Center is requested to be displayed.
    /// Return `true` if the display was handled, `false` to fall back to default SDK behavior.
    var onDisplay: (@MainActor @Sendable (_ messageID: String?) -> Bool)? { get set }

    /// Called when the Message Center is requested to be dismissed.
    var onDismissDisplay: (@MainActor @Sendable () -> Void)? { get set }

    /// Message center display delegate.
    var displayDelegate: (any MessageCenterDisplayDelegate)? { get set }

    /// Message center inbox.
    var inbox: any MessageCenterInbox { get }

    /// The message center controller.
    var controller: MessageCenterController { get set }

    /// Default message center theme.
    var theme: MessageCenterTheme? { get set }

    /// Default message center predicate. Only applies to the OOTB Message Center. If you are embedding the MessageCenterView directly
    ///  you should pass the predicate in through the view extension `.messageCenterPredicate(_:)`.
    var predicate: (any MessageCenterPredicate)? { get set }

    /// Loads a Message center theme from a plist file. If you are embedding the MessageCenterView directly
    ///  you should pass the theme in through the view extension `.messageCenterTheme(_:)`.
    /// - Parameters:
    ///     - plist: The name of the plist in the bundle.
    func setThemeFromPlist(_ plist: String) throws

    /// Display the message center.
    func display()

    /// Display the given message with animation.
    /// - Parameters:
    ///     - messageID:  The messageID of the message.
    func display(messageID: String)

    /// Dismiss the message center.
    func dismiss()
}


/// Airship Message Center module.
final class DefaultMessageCenter: MessageCenter {

    @MainActor
    public var onDisplay: (@MainActor @Sendable (_ messageID: String?) -> Bool)?

    @MainActor
    public var onDismissDisplay: (@MainActor @Sendable () -> Void)?

    @MainActor
    public var displayDelegate: (any MessageCenterDisplayDelegate)? {
        get {
            mutable.displayDelegate
        }
        set {
            mutable.displayDelegate = newValue
        }
    }

    private let mutable: MutableValues
    private let privacyManager: any AirshipPrivacyManager

    public let inbox: any MessageCenterInbox

    @MainActor
    public var controller: MessageCenterController {
        get {
            self.mutable.controller
        }
        set {
            self.mutable.controller = newValue
        }
    }

    @MainActor
    public var theme: MessageCenterTheme? {
        get {
            self.mutable.theme
        }
        set {
            self.mutable.theme = newValue
        }
    }

    @MainActor
    public func setThemeFromPlist(_ plist: String) throws {
        self.theme = try MessageCenterTheme.fromPlist(plist)
    }

    @MainActor
    public var predicate: (any MessageCenterPredicate)? {
        get {
            self.mutable.predicate
        }
        set {
            self.mutable.predicate = newValue
        }
    }

    private var enabled: Bool {
        return self.privacyManager.isEnabled(.messageCenter)
    }

    @MainActor
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        privacyManager: any AirshipPrivacyManager,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        inbox: DefaultMessageCenterInbox,
        controller: MessageCenterController
    ) {
        self.inbox = inbox
        self.privacyManager = privacyManager
        self.mutable = MutableValues(controller: controller, theme: MessageCenterThemeLoader.defaultPlist())

        if let plist = config.airshipConfig.messageCenterStyleConfig {
            do {
                try setThemeFromPlist(plist)
            } catch {
                AirshipLogger.error("Failed to load Message Center \(plist) theme \(error) ")
            }
        }

        notificationCenter.addObserver(
            forName: AirshipNotifications.PrivacyManagerUpdated.name,
            object: nil,
            queue: nil
        ) { [weak self, inbox] _ in
            Task { @MainActor in
                inbox.enabled = self?.enabled ?? false
            }
        }

        inbox.enabled = self.enabled
    }

    @MainActor
    convenience init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        channel: any InternalAirshipChannel,
        privacyManager: any AirshipPrivacyManager,
        workManager: any AirshipWorkManagerProtocol
    ) {

        let controller = MessageCenterController()
        let inbox = DefaultMessageCenterInbox(
            with: config,
            dataStore: dataStore,
            channel: channel,
            workManager: workManager
        )

        self.init(
            dataStore: dataStore,
            config: config,
            privacyManager: privacyManager,
            inbox: inbox,
            controller: controller
        )
    }

    @MainActor
    public func display() {
        guard self.enabled else {
            AirshipLogger.warn("Message center disabled. Unable to display.")
            return
        }

        let handled: Bool
        if let onDisplay {
            handled = onDisplay(nil)
        } else if let displayDelegate {
            displayDelegate.displayMessageCenter()
            handled = true
        } else {
            handled = false
        }

        guard !handled else {
            AirshipLogger.trace(
                "Message center display request handled by the app."
            )
            return
        }

        AirshipLogger.trace("Launching OOTB message center")
        showDefaultMessageCenter()
        self.controller.navigate(messageID: nil)
    }

    @MainActor
    public func display(messageID: String) {
        guard self.enabled else {
            AirshipLogger.warn("Message center disabled. Unable to display.")
            return
        }

        let handled: Bool
        if let onDisplay {
            handled = onDisplay(messageID)
        } else if let displayDelegate {
            displayDelegate.displayMessageCenter(messageID: messageID)
            handled = true
        } else {
            handled = false
        }

        guard !handled else {
            AirshipLogger.trace(
                "Message center display request for message \(messageID) handled by the app."
            )
            return
        }

        AirshipLogger.trace("Launching OOTB message center")
        showDefaultMessageCenter()
        self.controller.navigate(messageID: messageID)
    }

    @MainActor
    public func dismiss() {
        if let onDismissDisplay {
            onDismissDisplay()
        } else if let displayDelegate {
            displayDelegate.dismissMessageCenter()
        } else {
            Task { @MainActor in
                self.dismissDefaultMessageCenter()
            }
        }
    }

    @MainActor
    final class MutableValues: Sendable {
        var displayDelegate: (any MessageCenterDisplayDelegate)?
        var controller: MessageCenterController
        var predicate: (any MessageCenterPredicate)?
        var theme: MessageCenterTheme?
        var currentDisplay: (any AirshipMainActorCancellable)?

        init(
            displayDelegate: (any MessageCenterDisplayDelegate)? = nil,
            controller: MessageCenterController,
            predicate: (any MessageCenterPredicate)? = nil,
            theme: MessageCenterTheme? = nil,
            currentDisplay: (any AirshipMainActorCancellable)? = nil
        ) {
            self.displayDelegate = displayDelegate
            self.controller = controller
            self.predicate = predicate
            self.theme = theme
            self.currentDisplay = currentDisplay
        }
    }
}

extension DefaultMessageCenter {
    private static let kUARichPushMessageIDKey = "_uamid"

    @MainActor
    func deepLink(_ deepLink: URL) -> Bool {
        
        // Ensure the scheme matches Airship deeplLink scheme
        guard deepLink.scheme == Airship.deepLinkScheme else {
            return false
        }

        // Ensure the host matches
        guard deepLink.host == "message_center" else {
            return false
        }
        
        let components = deepLink.pathComponents
        let path = deepLink.path
        
        // Case 1: No path -> open message center
        if path.isEmpty || path == "/" {
            display()
            return true
        }
        
        // Case 2: /message/<id>
        if components.count == 3, components[1] == "message" {
            display(messageID: components[2])
            return true
        }
        
        // Case 3: /<id>
        if components.count == 2 {
            display(messageID: components[1])
            return true
        }
        
        // Anything else is unsupported
        return false
    }

    @MainActor
    func receivedRemoteNotification(
        _ notification: AirshipJSON
    ) async -> UABackgroundFetchResult {
        guard
            let userInfo = notification.unWrap() as? [AnyHashable: Any],
            let messageID = MessageCenterMessage.parseMessageID(
                userInfo: userInfo
            )
        else {
            return .noData
        }

        let result = await self.inbox.refreshMessages()

        if !result {
            return .failed
        }

        let message = await self.inbox.message(forID: messageID)

        guard message != nil else {
            return .noData
        }

        return .newData
    }

    @MainActor
    fileprivate func showDefaultMessageCenter() {
        guard self.mutable.currentDisplay == nil else {
            return
        }

        let displayable = AirshipDisplayTarget().prepareDisplay(for: .modal)

        let controller = MessageCenterViewControllerFactory.make(
            theme: theme,
            predicate: predicate,
            controller: self.controller
        ) {
            self.mutable.currentDisplay?.cancel()
            self.mutable.currentDisplay = nil
        }

        do {
            try displayable.display { _ in
                return controller
            }
            self.mutable.currentDisplay = AirshipMainActorCancellableBlock {
                displayable.dismiss()
            }
        } catch {
            AirshipLogger.error("Unable to display message center \(error)")
        }
    }

    @MainActor
    fileprivate func dismissDefaultMessageCenter() {
        self.mutable.currentDisplay?.cancel()
        self.mutable.currentDisplay = nil
    }
}

public extension Airship {
    /// The shared `MessageCenter` instance. `Airship.takeOff` must be called before accessing this instance.
    @MainActor
    static var messageCenter: any MessageCenter {
        Airship.requireComponent(
            ofType: MessageCenterComponent.self
        ).messageCenter
    }
}
