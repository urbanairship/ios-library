/* Copyright Airship and Contributors */

import Foundation;

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Open chat delegate.
 */
@objc(UAirshipChatDelegate)
public protocol ChatOpenDelegate {

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
public class Chat : UAComponent, UAPushableComponent {

    private static let refreshKey = "com.urbanairship.refresh_chat"

    /**
     * Chat delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB chat screen.
     */
    @objc
    public weak var openChatDelegate: ChatOpenDelegate?


    private static let enableKey = "AirshipChat.enabled"

    /**
     * Enables or disables chat.
     */
    @objc
    @available(*, deprecated, message: "Deprecated – to be removed in SDK version 15.0. Please use the Privacy Manager.")
    public var enabled: Bool {
        get {
            return self.privacyManager.isEnabled(UAFeatures.chat)
        }
        set {
            if (newValue) {
                self.privacyManager.enableFeatures(UAFeatures.chat)
            } else {
                self.privacyManager.disableFeatures(UAFeatures.chat)
            }
        }
    }

    /**
     * Chat style
     */
    @objc
    public var style: ChatStyle?

    /**
     * The default conversation.
     */
    @objc
    public var conversation : ConversationProtocol {
        get {
            return self.internalConversation
        }
    }

    private let internalConversation : InternalConversationProtocol

    private let dataStore: UAPreferenceDataStore
    
    private let privacyManager: UAPrivacyManager

    private var viewController : UIViewController?

    internal convenience init(dataStore: UAPreferenceDataStore, config: UARuntimeConfig, channel: Channel, privacyManager: UAPrivacyManager) {

        let conversation = Conversation(dataStore: dataStore,
                                         chatConfig: config,
                                         channel: channel)

        self.init(dataStore: dataStore, conversation: conversation, privacyManager: privacyManager)
    }

    internal init(dataStore: UAPreferenceDataStore,
                  conversation: InternalConversationProtocol,
                  privacyManager: UAPrivacyManager) {
        
        self.dataStore = dataStore
        self.internalConversation = conversation
        self.privacyManager = privacyManager
        self.style = ChatStyle(file: "AirshipChatStyle")
        
        super.init(dataStore: dataStore)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.onEnabledFeaturesChange),
            name: UAPrivacyManager.changeEvent,
            object: nil)

        AirshipLogger.info("AirshipChat initialized")
    }

    public override func onComponentEnableChange() {
        self.updateConversationEnablement()
    }

    private func updateConversationEnablement() {
        self.internalConversation.enabled = self.componentEnabled() && self.privacyManager.isEnabled(UAFeatures.chat)
        if (!self.privacyManager.isEnabled(UAFeatures.chat)) {
            self.internalConversation.clearData()
        }
    }
    
    @objc
    func onEnabledFeaturesChange() {
        self.updateConversationEnablement()
    }

    /**
     * Opens the chat.
     */
    @objc
    public func openChat() {
        openChat(message: nil)
    }

    /**
     * Opens the chat.
     * @param message Optional message to prefill the chat input.
     */
    @objc
    public func openChat(message: String?) {
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
    public func receivedRemoteNotification(_ userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.internalConversation.refresh()
        completionHandler(.newData)
    }

    private func openDefaultChat(message: String? = nil) {
        guard viewController == nil else {
            AirshipLogger.debug("Already displaying chat: \(self.viewController?.description ?? "")")
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
        cvc.messageDraft = message
        cvc.chatStyle = style

        cvc.title = style?.title ?? ChatResources.localizedString(key: "ua_chat_title")

        nav.navigationBar.barTintColor = style?.navigationBarColor ?? nav.navigationBar.barTintColor

        var titleAttributes: [NSAttributedString.Key : Any] = [:]
        titleAttributes[NSAttributedString.Key.foregroundColor] = style?.titleColor
        titleAttributes[NSAttributedString.Key.font] = style?.titleFont

        nav.navigationBar.titleTextAttributes = titleAttributes
        nav.navigationBar.tintColor = style?.tintColor

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
    
    // NOTE: For internal use only. :nodoc:
    public override func deepLink(_ deepLink: URL) -> Bool {
        guard deepLink.scheme == UAirshipDeepLinkScheme,
              deepLink.host == "chat",
              deepLink.path.isEmpty || deepLink.path == "/" else {
            return false
        }
        
        let urlComponents = URLComponents(url: deepLink, resolvingAgainstBaseURL: false)
        let queryMap = urlComponents?.queryItems?.reduce(into: [String : String?]()) {
            $0[$1.name] = $1.value
        } ?? [:]
        
        if let routing = queryMap["routing"] as? String {
            do {
                let parsedRouting = try JSONDecoder().decode(ChatRouting.self, from: Data(routing.utf8))
                self.conversation.routing = parsedRouting
            } catch {
                AirshipLogger.error("Failed to parse routing \(error)")
            }
        }
        
        let draft = queryMap["chat_input"] as? String
        self.openChat(message: draft)
        
        return true
    }
}


