/* Copyright Airship and Contributors */

import Foundation
public import WebKit

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// Airship native bridge extension for the Message Center.
public final class MessageCenterNativeBridgeExtension: NSObject, NativeBridgeExtensionDelegate, Sendable {

    let message: MessageCenterMessage
    let user: MessageCenterUser

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
    ) -> [String: String] {
        return [
            ActionArguments.inboxMessageIDMetadataKey: message.id
        ]
    }

    public func extendJavaScriptEnvironment(
        _ js: JavaScriptEnvironmentProtocol,
        webView: WKWebView
    ) async {
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
            string: AirshipDateFormatter.string(fromDate: message.sentDate, format: .iso)
        )
        js.add("getMessageExtras", dictionary: message.extra)
        js.add("getUserId", string: self.user.username)
    }
}
