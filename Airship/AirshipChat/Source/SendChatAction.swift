/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Action to send a chat message.
 *
 * The action will call `sendMessage` on the `AirshipChat` instance.
 *
 * This action is registered under the name `send_chat_action`.
 *
 * Expected argument value a dictionary with `message` key with the prefilled message as a String and optional `chat_routing` key with ChatRouting object
 *
 * Valid situations:  UASituationLaunchedFromPush, UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Result value: empty
 */
@available(iOS 13.0, *)
@objc(UASendChatAction)
public class SendChatAction : NSObject, Action {

    public static let name = "send_chat_action"
    static let routingKey = "chat_routing"
    static let messageKey = "message"

    public typealias AirshipChatProvider = () -> Chat

    private let chatProvider : AirshipChatProvider

    @objc
    public override convenience init() {
        self.init {
            return Chat.shared
        }
    }

    init(chatProvider: @escaping AirshipChatProvider) {
        self.chatProvider = chatProvider
        super.init()
    }

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        if let dict = arguments.value as? [String : Any] {
            guard dict[SendChatAction.messageKey] != nil || dict[SendChatAction.routingKey] != nil else {
                AirshipLogger.error("Both message and routing should not be nil")
                return false
            }
        }
        
        switch(arguments.situation) {
        case .automation, .manualInvocation, .webViewInvocation, .launchedFromPush, .foregroundInteractiveButton:
            return true
        default:
            return false
        }
    }

    public func perform(with arguments: ActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        let chat = self.chatProvider()
        let args = arguments.value as? [String: Any]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        
        if let routing = args?[OpenChatAction.routingKey] as? ChatRouting {
            chat.conversation.routing = routing
        } else if let routing = args?[SendChatAction.routingKey] as? [String : AnyHashable] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: routing, options:[])
                let parsed = try decoder.decode(ChatRouting.self, from: jsonData)
                chat.conversation.routing = parsed
            }
            catch {
                AirshipLogger.error("Failed to parse routing \(error)")
            }
        }

        if let message = args?[SendChatAction.messageKey] as? String {
            chat.conversation.sendMessage(message)
        }
        
        completionHandler(ActionResult.empty())
    }
}
