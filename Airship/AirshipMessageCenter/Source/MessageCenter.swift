/* Copyright Airship and Contributors */


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

/// Airship Message Center module.
public final class MessageCenter: Sendable {
    /// Message center display delegate.
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
    private let privacyManager: any PrivacyManagerProtocol

    /// Message center inbox.
    public let inbox: any MessageCenterInboxProtocol

    /// The message center controller.
    @MainActor
    public var controller: MessageCenterController {
        get {
            self.mutable.controller
        }
        set {
            self.mutable.controller = newValue
        }
    }

    /// Default message center theme. Only applies to the OOTB Message Center. If you are embedding the MessageCenterView directly
    ///  you should pass the theme in through the view extension `.messageCenterTheme(_:)`.
    @MainActor
    public var theme: MessageCenterTheme? {
        get {
            self.mutable.theme
        }
        set {
            self.mutable.theme = newValue
        }
    }

    /// Loads a Message center theme from a plist file. If you are embedding the MessageCenterView directly
    ///  you should pass the theme in through the view extension `.messageCenterTheme(_:)`.
    /// - Parameters:
    ///     - plist: The name of the plist in the bundle.
    @MainActor
    public func setThemeFromPlist(_ plist: String) throws {
        self.theme = try MessageCenterTheme.fromPlist(plist)
    }

    /// Default message center predicate. Only applies to the OOTB Message Center. If you are embedding the MessageCenterView directly
    ///  you should pass the predicate in through the view extension `.messageCenterPredicate(_:)`.
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

    /// The shared MessageCenter instance. `Airship.takeOff` must be called before accessing this instance.
    @available(*, deprecated, message: "Use Airship.messageCenter instead")
    public static var shared: MessageCenter {
        return Airship.messageCenter
    }
    
    @MainActor
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        privacyManager: any PrivacyManagerProtocol,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        inbox: MessageCenterInbox,
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
            inbox.enabled = self?.enabled ?? false
        }

        inbox.enabled = self.enabled
    }

    @MainActor
    convenience init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        channel: any InternalAirshipChannelProtocol,
        privacyManager: any PrivacyManagerProtocol,
        workManager: any AirshipWorkManagerProtocol
    ) {

        let controller = MessageCenterController()
        let inbox = MessageCenterInbox(
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

    /// Display the message center.
    @MainActor
    public func display() {
        guard self.enabled else {
            AirshipLogger.warn("Message center disabled. Unable to display.")
            return
        }

        guard let displayDelegate = self.displayDelegate else {
            AirshipLogger.trace("Launching OOTB message center")
            showDefaultMessageCenter()
            self.controller.navigate(messageID: nil)
            return
        }

        AirshipLogger.trace("Message center opened through delegate")
        displayDelegate.displayMessageCenter()
    }

    /// Display the given message with animation.
    /// - Parameters:
    ///     - messageID:  The messageID of the message.
    @MainActor
    public func display(messageID: String) {
        guard self.enabled else {
            AirshipLogger.warn("Message center disabled. Unable to display.")
            return
        }

        guard let displayDelegate = self.displayDelegate else {
            AirshipLogger.trace("Launching OOTB message center")
            showDefaultMessageCenter()
            self.controller.navigate(messageID: messageID)
            return
        }

        displayDelegate.displayMessageCenter(
            messageID: messageID
        )

    }

    /// Dismiss the message center.
    @MainActor
    public func dismiss() {
        if let displayDelegate = self.displayDelegate {
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

extension MessageCenter {
    private static let kUARichPushMessageIDKey = "_uamid"

    @MainActor
    func deepLink(_ deepLink: URL) -> Bool {
        if !(deepLink.scheme == Airship.deepLinkScheme) {
            return false
        }

        if !(deepLink.host == "message_center") {
            return false
        }

        if deepLink.path.hasPrefix("/message/") {
            if deepLink.pathComponents.count != 3 {
                return false
            }
            let messageID: String = deepLink.pathComponents[2]
            self.display(messageID: messageID)
        } else {
            if (deepLink.path.count != 0) && !(deepLink.path == "/") {
                return false
            }

            self.display()
        }

        return true
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

        guard let scene = try? AirshipSceneManager.shared.lastActiveScene else {
            AirshipLogger.error(
                "Unable to display message center, missing scene."
            )
            return
        }

        var window: UIWindow? = AirshipWindowFactory.shared.makeWindow(windowScene: scene)

        self.mutable.currentDisplay = AirshipMainActorCancellableBlock {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }

        let viewController = MessageCenterViewControllerFactory.make(
            theme: theme, 
            predicate: predicate,
            controller: self.controller
        ) {
            self.mutable.currentDisplay?.cancel()
            self.mutable.currentDisplay = nil
        }

        window?.isHidden = false
        window?.windowLevel = .alert
        window?.makeKeyAndVisible()
        window?.rootViewController = viewController
    }

    @MainActor
    fileprivate func dismissDefaultMessageCenter() {
        self.mutable.currentDisplay?.cancel()
        self.mutable.currentDisplay = nil
    }
}

public extension Airship {
    /// The shared MessageCenter instance. `Airship.takeOff` must be called before accessing this instance.
    static var messageCenter: MessageCenter {
        return Airship.requireComponent(ofType: MessageCenterComponent.self).messageCenter
    }
}
