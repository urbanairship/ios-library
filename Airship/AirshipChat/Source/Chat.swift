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
@objc(UAChat)
public class Chat : NSObject, Component, PushableComponent {

    /// The shared Chat instance.
    @objc
    public static var shared: Chat! {
        return Airship.requireComponent(ofType: Chat.self)
    }
    
    static let routingKey = "routing"
    static let routeAgentKey = "route_agent"
    static let singlePrepopulatedMessageKey = "prepopulated_message"
    static let prepopulatedMessagesKey = "prepopulated_messages"
    static let inputKey = "chat_input"
    static let deepLinkHost = "chat"
    private static let refreshKey = "com.urbanairship.refresh_chat"

    /**
     * Chat delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB chat screen.
     */
    @objc
    public weak var openChatDelegate: ChatOpenDelegate?

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

    private let dataStore: PreferenceDataStore
    
    private let privacyManager: PrivacyManager

    private var chatWindow: UIWindow?
    
    private var viewController : UIViewController?

    private let disableHelper: ComponentDisableHelper
        
    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }
    
    internal convenience init(dataStore: PreferenceDataStore, config: RuntimeConfig, channel: Channel, privacyManager: PrivacyManager) {

        let conversation = Conversation(dataStore: dataStore,
                                         chatConfig: config,
                                         channel: channel)

        self.init(dataStore: dataStore, conversation: conversation, privacyManager: privacyManager)
    }

    internal init(dataStore: PreferenceDataStore,
                  conversation: InternalConversationProtocol,
                  privacyManager: PrivacyManager) {
        
        self.dataStore = dataStore
        self.internalConversation = conversation
        self.privacyManager = privacyManager
        self.style = ChatStyle(file: "AirshipChatStyle")
        
        self.disableHelper = ComponentDisableHelper(dataStore: dataStore, className: "Chat")
        super.init()
        
        self.disableHelper.onChange = { [weak self] in
            self?.onComponentEnableChange()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.onEnabledFeaturesChange),
            name: PrivacyManager.changeEvent,
            object: nil)

        AirshipLogger.info("AirshipChat initialized")
    }

    private func onComponentEnableChange() {
        self.updateConversationEnablement()
    }

    private func updateConversationEnablement() {
        self.internalConversation.enabled = self.isComponentEnabled && self.privacyManager.isEnabled(Features.chat)

        if (!self.privacyManager.isEnabled(Features.chat)) {
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

        if let window = Utils.presentInNewWindow(vc) {
            AirshipLogger.trace("Presented chat view controller: \(vc.description)")
            self.chatWindow = window
        }
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
        chatWindow = nil
    }
    
    // NOTE: For internal use only. :nodoc:
    public func deepLink(_ deepLink: URL) -> Bool {
        guard deepLink.scheme == Airship.deepLinkScheme,
              deepLink.host == Chat.deepLinkHost,
              deepLink.path.isEmpty || deepLink.path == "/" else {
            return false
        }
        
        let urlComponents = URLComponents(url: deepLink, resolvingAgainstBaseURL: false)
        let queryMap = urlComponents?.queryItems?.reduce(into: [String : String?]()) {
            $0[$1.name] = $1.value
        } ?? [:]
        
        if (queryMap.keys.contains(Chat.routingKey) || queryMap.keys.contains(Chat.routeAgentKey)) {
            do {
                var parsedRouting: ChatRouting? = nil
                
                if let routing = queryMap[Chat.routingKey] as? String {
                    parsedRouting = try JSONDecoder().decode(ChatRouting.self, from: Data(routing.utf8))
                }
                
                if parsedRouting == nil, let agent = queryMap[Chat.routeAgentKey] as? String {
                    parsedRouting = ChatRouting(agent: agent)
                }
                
                self.conversation.routing = parsedRouting
            }
            catch {
                AirshipLogger.error("Failed to parse routing \(error)")
            }
        }
        
        if (queryMap.keys.contains(Chat.prepopulatedMessagesKey) || queryMap.keys.contains(Chat.singlePrepopulatedMessageKey)) {
            do {
                var incomingMessages: [ChatIncomingMessage] = []
                if let incoming = queryMap[Chat.prepopulatedMessagesKey] as? String {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                        
                    incomingMessages = try decoder.decode([ChatIncomingMessage].self, from: Data(incoming.utf8))
                }
                
                if incomingMessages.count == 0, let singlePrepop = queryMap[Chat.singlePrepopulatedMessageKey] as? String {
                    let newMessage = ChatIncomingMessage(message: singlePrepop, url: nil, date: nil, messageID: nil)
                    incomingMessages.append(newMessage)
                }
                
                self.internalConversation.addIncoming(incomingMessages)
            }
            catch {
                AirshipLogger.error("Failed to parse prepopulated messages \(error)")
            }
        }
        
        let draft = queryMap[Chat.inputKey] as? String
        self.openChat(message: draft)
        
        return true
    }
    
    func addIncoming(_ messages: [ChatIncomingMessage]) {
        self.internalConversation.addIncoming(messages)
    }
}


