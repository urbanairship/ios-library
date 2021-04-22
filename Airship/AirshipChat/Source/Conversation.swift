/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

/**
 * Conversation delegate.
 */
@available(iOS 13.0, *)
@objc(UAConversationDelegate)
public protocol ConversationDelegate : AnyObject {

    /**
      * Called when the message list updated.
     */
    @objc
    func onMessagesUpdated()

    /**
     * Called when the `isConnected` property changes.
     */
    @objc
    func onConnectionStatusChanged()
}

@available(iOS 13.0, *)
@objc(UAConversationProtocol)
public protocol ConversationProtocol {

    /**
     * Connection status.
     */
    @objc
    var isConnected : Bool { get }

    @objc
    var delegate: ConversationDelegate? { get set }

   /**
    * Sends a message.
    * @param text The message.
    * @param attachment The attachment.
    */
    @objc
    func sendMessage(_ text: String?, attachment: URL?)

    /**
     * Sends a message.
     * @param text The message.
     */
    @objc
    func sendMessage(_ text: String)

    /**
     * Fetches the messages.
     * @param completionHandler The message completion handler.
     */
    @objc
    func fetchMessages(completionHandler: @escaping (Array<ChatMessage>) -> ())
}

protocol InternalConversationProtocol: ConversationProtocol  {
    func refresh()
    var enabled : Bool { get set }
    func clearData()
}

/**
 * Chat conversation.
 */
@available(iOS 13.0, *)
class Conversation : InternalConversationProtocol, ChatConnectionDelegate {


    private static let uvpStorageKey : String = "AirshipChat.UVP"
    private static let uvpRetryDelay : Double = 30
    private static let chatReconnectionDelay : Double = 10

    private let dataStore : UAPreferenceDataStore
    private let chatConfig: ChatConfig

    private let channel: AirshipChannel
    private let appStateTracker: UAAppStateTracker
    private let client: ChatAPIClientProtocol
    private let dispatcher: UADispatcher
    private var chatConnection: ChatConnectionProtocol
    private let chatDAO : ChatDAOProtocol

    private var isPendingSent = false
    private var isUVPCreating = false

    var enabled: Bool = true {
        didSet {
            self.updateConnection()
        }
    }

    @objc
    private(set) var isConnected: Bool = false {
        didSet {
            if (oldValue != isConnected) {
                UADispatcher.main().dispatchAsync {
                    self.delegate?.onConnectionStatusChanged()
                }
            }
        }
    }

    @objc
    weak var delegate: ConversationDelegate?

    convenience init(dataStore: UAPreferenceDataStore,
                     chatConfig: ChatConfig,
                     channel: AirshipChannel) {
        self.init(dataStore: dataStore,
                  chatConfig: chatConfig,
                  channel: channel,
                  client: ChatAPIClient(chatConfig: chatConfig),
                  chatConnection: ChatConnection(chatConfig: chatConfig),
                  chatDAO: ChatDAO(config: chatConfig))
    }

    init(dataStore: UAPreferenceDataStore,
         chatConfig: ChatConfig,
         channel: AirshipChannel,
         client: ChatAPIClientProtocol,
         chatConnection: ChatConnectionProtocol,
         chatDAO: ChatDAOProtocol,
         appStateTracker: UAAppStateTracker = UAAppStateTracker.shared(),
         dispatcher: UADispatcher = UADispatcher.serial(),
         notificationCenter: NotificationCenter = NotificationCenter.default) {

        self.dataStore = dataStore
        self.chatConfig = chatConfig
        self.channel = channel
        self.client = client
        self.chatConnection = chatConnection
        self.chatDAO = chatDAO
        self.appStateTracker = appStateTracker
        self.dispatcher = dispatcher

        self.chatConnection.delegate = self

        notificationCenter.addObserver(
            self,
            selector: #selector(self.onForeground),
            name: NSNotification.Name.UAApplicationDidTransitionToForeground,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(self.onBackground),
            name: NSNotification.Name.UAApplicationDidTransitionToBackground,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(self.onChannelCreated),
            name: NSNotification.Name.UAChannelCreatedEvent,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(self.onRemoteConfigUpdated),
            name: NSNotification.Name.UARemoteConfigURLManagerConfigUpdated,
            object: nil)
    }

    @objc
    public func sendMessage(_ text: String) {
        self.sendMessage(text, attachment: nil)
    }

    @objc
    public func sendMessage(_ text: String?, attachment: URL? = nil) {
        guard text != nil || attachment != nil else {
            AirshipLogger.error("Both text and attachment should not be nil")
            return
        }

        guard self.enabled else {
            AirshipLogger.error("Unable to send message, chat disabled.")
            return
        }

        let requestID = UUID().uuidString

        self.chatDAO.insertPending(requestID: requestID, text: text, attachment: attachment, createdOn: Date())
        UADispatcher.main().dispatchAsync {
            self.delegate?.onMessagesUpdated()
        }

        dispatcher.dispatchAsync {
            if (self.chatConnection.isOpenOrOpening && self.isPendingSent) {
                self.chatConnection.sendMessage(requestID: requestID, text: text, attachment: attachment)
            } else {
                self.updateConnection()
            }
        }
    }

    /**
     * Fetches the messages.
     * @param completionHandler The message completion handler.
     */
    @objc
    public func fetchMessages(completionHandler: @escaping (Array<ChatMessage>) -> ()) {
        self.chatDAO.fetchMessages(completionHandler: { (messageData, pendingMessages) in
            var messages = [ChatMessage]()
            messages.append(contentsOf: messageData.map { $0.toChatMessage() })
            messages.append(contentsOf: pendingMessages.map { $0.toChatMessage() })
            UADispatcher.main().dispatchAsync {
                completionHandler(messages)
            }
        })
    }

    @objc
    private func onForeground() {
        self.updateConnection()
    }

    @objc
    private func onBackground() {
        self.updateConnection()
    }

    @objc
    private func onChannelCreated() {
        createUVP()
    }

    /**
     * Updates the connection. When the connection opens, it will remain open
     * until the conversation is fetched and the pending messages are sent.
     */
    private func updateConnection(open: Bool = false) {
        dispatcher.dispatchAsyncIfNecessary {
            guard self.enabled && self.isConfigured() else {
                self.chatConnection.close()
                return
            }

            var shouldOpen = false
            if (open || !self.isPendingSent || self.appStateTracker.state == UAApplicationState.active) {
                shouldOpen = true
            } else {
                let semaphore = UASemaphore()
                self.chatDAO.hasPendingMessages { (result) in
                    shouldOpen = result
                    semaphore.signal()
                }

                semaphore.wait()
            }

            if (shouldOpen) {
                guard !self.chatConnection.isOpenOrOpening else {
                    return
                }

                self.isPendingSent = false

                guard let uvp = self.getUVP() else {
                    self.createUVP()
                    return
                }

                self.chatConnection.open(uvp: uvp)
                self.chatConnection.requestConversation()
            } else {
                self.chatConnection.close()
            }
        }
    }

    private func isConfigured() -> Bool {
        return self.chatConfig.chatURL != nil && self.chatConfig.chatWebSocketURL != nil
    }

    private func getUVP() -> String? {
        return self.dataStore.string(forKey: Conversation.uvpStorageKey)
    }

    private func createUVP(after: TimeInterval = 0) {
        self.dispatcher.dispatch(after: after) {
            guard self.enabled else {
                self.chatConnection.close()
                return
            }
            
            guard !self.isUVPCreating else {
                return
            }

            guard let channelID = self.channel.identifier else {
                return
            }

            self.isUVPCreating = true
            self.client.createUVP(channelID:channelID) { [weak self] (response, error) in
                self?.dispatcher.dispatchAsync {
                    self?.isUVPCreating = false
                    if (response?.uvp != nil) {
                        self?.dataStore.setValue(response?.uvp!, forKey: Conversation.uvpStorageKey)
                        self?.updateConnection()
                    } else {
                        self?.createUVP(after: Conversation.uvpRetryDelay)
                    }
                }
            }
        }
    }

    @objc
    private func onRemoteConfigUpdated() {
        self.dispatcher.dispatchAsync {
            self.chatConnection.close()
            self.dataStore.removeObject(forKey: Conversation.uvpStorageKey)
            self.createUVP()
        }
    }

    private func syncPending() {
        self.dispatcher.dispatchAsync {
            let semaphore = UASemaphore()
            var pendingCopy: [(String, String?, URL?)]? = nil

            self.chatDAO.fetchPending { pending in
                // Copy to tuples to keep honor
                pendingCopy = pending.map { ($0.requestID, $0.text, $0.attachment) }
                semaphore.signal()
            }

            semaphore.wait()

            if (self.chatConnection.isOpenOrOpening) {
                pendingCopy?.forEach {
                    self.chatConnection.sendMessage(requestID: $0.0, text: $0.1, attachment: $0.2)
                }
                self.isPendingSent = true
            }
            self.updateConnection()
        }
    }

    func onOpen() {
        self.isConnected = true
    }

    func refresh() {
        dispatcher.dispatchAsync {
            self.updateConnection(open: true)
        }
    }

    func clearData() {
        dispatcher.dispatchAsync {
            self.chatConnection.close()
            self.dataStore.removeObject(forKey: Conversation.uvpStorageKey)
            self.chatDAO.deleteAll()
        }
    }

    func onClose(_ reason: CloseReason) {
        self.isConnected = false

        if (reason != .manual) {
            self.dispatcher.dispatch(after: Conversation.chatReconnectionDelay) { [weak self] in
                self?.updateConnection()
            }
        }
    }

    func onChatResponse(_ response: ChatResponse) {
        switch response.payload {
        case let convoLoadedResponse as ChatResponse.ConversationLoadedResponsePayload:
            convoLoadedResponse.messages?.forEach {
                if let requestID = $0.requestID {
                    self.chatDAO.removePending(requestID)
                }
                self.chatDAO.upsertResponseMessage($0)
            }
            syncPending()
        case let newMessageResponse as ChatResponse.NewMessageResponsePayload:
            self.chatDAO.upsertResponseMessage(newMessageResponse.message)
        case let sentMessageResponse as ChatResponse.SentMessageResponsePayload:
            self.chatDAO.upsertResponseMessage(sentMessageResponse.message)
            if (sentMessageResponse.message.requestID != nil) {
                self.chatDAO.removePending(sentMessageResponse.message.requestID!)
            }
            updateConnection()
        default:
            AirshipLogger.trace("Unexpected response: \(response)")
        }

        UADispatcher.main().dispatchAsync {
            self.delegate?.onMessagesUpdated()
        }
    }
}

@available(iOS 13.0, *)
extension ChatMessageDataProtocol {
    func toChatMessage() -> ChatMessage {
        let chatDirection = ChatMessageDirection.init(rawValue: self.direction) ?? .incoming
        return ChatMessage(messageID: self.requestID ?? "\(self.messageID)",
                           text: self.text,
                           timestamp: self.createdOn,
                           direction: chatDirection,
                           delivered: true,
                           attachment:self.attachment)
    }
}

@available(iOS 13.0, *)
extension PendingChatMessageDataProtocol {
    func toChatMessage() -> ChatMessage {
        return ChatMessage(messageID: self.requestID, text: self.text, timestamp: Date.distantFuture, direction: .outgoing, delivered: false)
    }
}

@available(iOS 13.0, *)
extension ChatDAOProtocol {
    func upsertResponseMessage(_ message: ChatResponse.Message) {
        upsertMessage(messageID: message.messageID, requestID: message.requestID, text: message.text, createdOn: message.createdOn, direction: message.direction, attachment: message.attachment)
    }
}
