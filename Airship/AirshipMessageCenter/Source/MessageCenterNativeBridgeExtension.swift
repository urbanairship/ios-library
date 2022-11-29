/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc(UAMessageCenterNativeBridgeExtension)
public class MessageCenterNativeBridgeExtension: NSObject,
    NativeBridgeExtensionDelegate
{

    let message: MessageCenterMessage
    let user: MessageCenterUser

    @objc
    public init(
        message: MessageCenterMessage,
        user: MessageCenterUser
    ) {
        self.message = message
        self.user = user
    }

    public func actionsMetadata(
        for command: JavaScriptCommand,
        webView: WKWebView
    ) -> [AnyHashable: Any] {
        return [
            UAActionMetadataInboxMessageIDKey: message.id
        ]
    }

    public func extendJavaScriptEnvironment(
        _ js: JavaScriptEnvironmentProtocol,
        webView: WKWebView
    ) {
        js.add("getMessageId", string: self.message.id)
        js.add("getMessageTitle", string: self.message.title)
        js.add(
            "getMessageSentDateMS",
            number: (self.message.sentDate.timeIntervalSince1970 * 1000.0)
                .rounded()
                as NSNumber
        )
        js.add(
            "getMessageSentDate",
            string: Utils.ISODateFormatterUTC().string(from: message.sentDate)
        )
        js.add("getMessageExtras", dictionary: message.extra)
        js.add("getUserId", string: self.user.username)
    }
}
