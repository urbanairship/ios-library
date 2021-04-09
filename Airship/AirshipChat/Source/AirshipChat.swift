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

    private static let refreshKey = "com.urbanairship.chat"

    /**
     * Chat delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB chat screen.
     */
    @objc
    public weak var openChatDelegate: AirshipChatOpenDelegate?

    /**
     * The default conversation.
     */
    @objc
    public let conversation : ConversationProtocol

    convenience init(dataStore: UAPreferenceDataStore, config: UARuntimeConfig, channel: UAChannel) {
        let conversation = Conversation(dataStore: dataStore,
                                         chatConfig: config,
                                         channel: channel)

        self.init(dataStore: dataStore, conversation: conversation)
    }

    init(dataStore: UAPreferenceDataStore,
         conversation: ConversationProtocol) {

        self.conversation = conversation
        super.init(dataStore: dataStore)

        AirshipLogger.info("AirshipChat initialized")
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
            // TODO: launch OOTB chat
        }
    }

    /**
     * @note For internal use only. :nodoc:
     */
    public func receivedRemoteNotification(_ notification: UANotificationContent, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let refreshable = self.conversation as? Refreshable {
            refreshable.refresh()
        }
        completionHandler(.newData)
    }
}


