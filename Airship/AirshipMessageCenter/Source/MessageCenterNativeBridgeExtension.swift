/* Copyright Airship and Contributors */

#if !os(tvOS)
import Foundation
public import WebKit

public import AirshipCore

private let messageSentDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

/// Airship native bridge extension for the Message Center.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
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
        _ js: any JavaScriptEnvironmentProtocol,
        webView: WKWebView
    ) async {
        js.add("getMessageId", string: self.message.id)
        js.add("getMessageTitle", string: self.message.title)
        js.add(
            "getMessageSentDateMS",
            number: (self.message.sentDate.timeIntervalSince1970 * 1000.0).rounded()
        )
        js.add(
            "getMessageSentDate",
            string: messageSentDateFormatter.string(from: message.sentDate)
        )
        js.add("getMessageExtras", dictionary: message.extra)
        js.add("getUserId", string: self.user.username)
    }
}

#endif
