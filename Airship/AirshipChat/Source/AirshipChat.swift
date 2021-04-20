/* Copyright Airship and Contributors */

import Foundation;

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

/**
 * Open chat delegate.
 */
@objc(UAirshipChatDelegate)
public protocol AirshipChatOpenDelegate {

    /**
     * Called when the chat should be openend.
     * @param message Optional message to prefill the chat input.
     */
    @objc
    func openChat(message: String?)
}

/**
 * Airship chat module.
 */
@available(iOS 13.0, *)
@objc(UAirshipChat)
public class AirshipChat : UAComponent, UAPushableComponent {

    private static let refreshKey = "com.urbanairship.refresh_chat"

    /**
     * Chat delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB chat screen.
     */
    @objc
    public weak var openChatDelegate: AirshipChatOpenDelegate?


    private static let enableKey = "AirshipChat.enabled"
    /**
     * Enables or disables chat.
     */
    public var enabled: Bool {
        get {
            return self.dataStore.bool(forKey: AirshipChat.enableKey, defaultValue:true)
        }
        set {
            self.dataStore.setBool(newValue, forKey: AirshipChat.enableKey)
            self.updateConversationEnablement()
        }
    }

    /**
     * The default conversation.
     */
    @objc
    public var conversation : ConversationProtocol {
        get {
            return self.internalConversation
        }
    }

    let internalConversation : InternalConversationProtocol


    private let dataStore: UAPreferenceDataStore

    private var viewController : UIViewController?

    internal convenience init(dataStore: UAPreferenceDataStore, config: UARuntimeConfig, channel: UAChannel) {

        let conversation = Conversation(dataStore: dataStore,
                                         chatConfig: config,
                                         channel: channel)

        self.init(dataStore: dataStore, conversation: conversation)
    }

    internal init(dataStore: UAPreferenceDataStore,
                  conversation: InternalConversationProtocol) {

        self.dataStore = dataStore
        self.internalConversation = conversation
        super.init(dataStore: dataStore)

        AirshipLogger.info("AirshipChat initialized")
    }

    public override func onComponentEnableChange() {
        self.updateConversationEnablement()
    }

    public override func onDataCollectionEnabledChanged() {
        self.updateConversationEnablement()
    }

    func updateConversationEnablement() {
        self.internalConversation.enabled = self.enabled && self.componentEnabled() && self.isDataCollectionEnabled
        if (!self.isDataCollectionEnabled) {
            self.internalConversation.clearData()
        }
    }

    /**
     * Opens the chat.
     * @param message Optional message to prefill the chat input.
     */
    @objc
    public func openChat(message: String? = nil) {
        if let strongDelegate = self.openChatDelegate {
            AirshipLogger.trace("Opening chat through delegate with message \(message ?? "")")
            strongDelegate.openChat(message: message)
        } else {
            AirshipLogger.trace("Launching OOTB chat")
            openDefaultChat(message: message)
        }
    }

    /**
     * @note For internal use only. :nodoc:
     */
    public func receivedRemoteNotification(_ notification: UANotificationContent, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.internalConversation.refresh()
        completionHandler(.newData)
    }

    private func openDefaultChat(message: String? = nil) {
        guard viewController == nil else {
            AirshipLogger.debug("Already displaying chat: \(self.viewController!.description)")
            return
        }

        AirshipLogger.debug("Opening default chat UI")
        let vc = chatViewController(message: message)
        viewController = vc

        UAUtils.topController()?.present(vc, animated: true, completion: {
            AirshipLogger.trace("Presented chat view controller: \(vc.description)")
        })
    }

    private func chatViewController(message: String?) -> UIViewController {
        let nav = UINavigationController(nibName: nil, bundle: nil)

        nav.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        nav.modalPresentationStyle = UIModalPresentationStyle.fullScreen

        let cvc = ChatViewController.init(nibName: "UAChatViewController", bundle: ChatResources.bundle())
        cvc.message = message

        // TODO: Localization
        cvc.title = "Chat"

        cvc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismiss))

        nav.viewControllers.append(cvc)

        return nav
    }

    @objc private func dismiss(sender: Any) {
        if let vc = viewController {
            vc.dismiss(animated: true) {
                AirshipLogger.trace("Dismissed chat view controller: \(vc.description)")
                self.viewController = nil
            }
        } else {
            AirshipLogger.debug("Chat already dismissed")
        }
    }
}


