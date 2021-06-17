/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Action to open chat.
 *
 * The action will call `openChat` on the `AirshipChat` instance.
 *
 * This action is registered under the name `open_chat_action`.
 *
 * Expected argument value is nil, or a dictionary with `chat_input` key with the prefilled message as a String.
 *
 * Valid situations:  UASituationLaunchedFromPush, UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Result value: empty
 */
@available(iOS 13.0, *)
@objc(UAOpenChatAction)
public class OpenChatAction : UAAction {

    public static let name = "open_chat_action"

    public typealias AirshipChatProvider = () -> Chat

    private let chatProvider : AirshipChatProvider

    @objc
    public override convenience init() {
        self.init {
            return Chat.shared()
        }
    }

    init(chatProvider: @escaping AirshipChatProvider) {
        self.chatProvider = chatProvider
        super.init()
    }

    public override func acceptsArguments(_ arguments: UAActionArguments) -> Bool {
        switch(arguments.situation) {
        case .automation, .manualInvocation, .webViewInvocation, .launchedFromPush, .foregroundInteractiveButton:
            return true
        default:
            return false
        }
    }

    public override func perform(with arguments: UAActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        let args = arguments.value as? [String: Any]
        let message = args?["chat_input"] as? String
        self.chatProvider().openChat(message: message)

        completionHandler(UAActionResult.empty())
    }
}
