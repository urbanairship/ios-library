/* Copyright Airship and Contributors */

import Foundation
import Combine

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

/// Airship Message Center module.
@objc(UAMessageCenter)
public final class MessageCenter: NSObject, Sendable {
    /// Message center display delegate.
    @objc
    @MainActor
    public var displayDelegate: MessageCenterDisplayDelegate? {
        get {
            mutable.displayDelegate
        }
        set {
            mutable.displayDelegate = newValue
        }
    }

    private let mutable: MutableValues
    private let privacyManager: AirshipPrivacyManager

    /// Message center inbox.
    @objc(inbox)
    var _inbox: MessageCenterInboxBaseProtocol {
        return self.inbox
    }

    /// Message center inbox.
    public let inbox: MessageCenterInboxProtocol

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
    @objc
    @MainActor
    public func setThemeFromPlist(_ plist: String) throws {
        self.theme = try MessageCenterTheme.fromPlist(plist)
    }

    /// Default message center predicate. Only applies to the OOTB Message Center. If you are embedding the MessageCenterView directly
    ///  you should pass the predicate in through the view extension `.messageCenterPredicate(_:)`.
    @objc
    @MainActor
    public var predicate: MessageCenterPredicate? {
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
    @objc
    public static var shared: MessageCenter {
        return Airship.requireComponent(ofType: MessageCenterComponent.self).messageCenter
    }
    
    @MainActor
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        privacyManager: AirshipPrivacyManager,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        inbox: MessageCenterInbox,
        controller: MessageCenterController
    ) {
        self.inbox = inbox
        self.privacyManager = privacyManager
        self.mutable = MutableValues(controller: controller, theme: MessageCenterThemeLoader.defaultPlist())

        super.init()

        if let plist = config.messageCenterStyleConfig {
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
        channel: InternalAirshipChannelProtocol,
        privacyManager: AirshipPrivacyManager,
        workManager: AirshipWorkManagerProtocol
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
    @objc
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
    @objc(displayWithMessageID:)
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
    @objc
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
        var displayDelegate: MessageCenterDisplayDelegate?
        var controller: MessageCenterController
        var predicate: MessageCenterPredicate?
        var theme: MessageCenterTheme?
        var currentDisplay: AirshipMainActorCancellable?

        init(
            displayDelegate: MessageCenterDisplayDelegate? = nil,
            controller: MessageCenterController,
            predicate: MessageCenterPredicate? = nil,
            theme: MessageCenterTheme? = nil,
            currentDisplay: AirshipMainActorCancellable? = nil
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
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard
            let messageID = MessageCenterMessage.parseMessageID(
                userInfo: notification
            )
        else {
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

        var window: UIWindow? = UIWindow(windowScene: scene)

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
