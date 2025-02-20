/* Copyright Airship and Contributors */

import Foundation

@preconcurrency
import UserNotifications

#if !TARGET_OS_TV
@objc
open class UANotificationServiceExtension: UNNotificationServiceExtension {
    open var airshipConfig: AirshipExtensionConfig { .init() }
    private var onExpire: (@Sendable () -> Void)?

    open override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @Sendable @escaping (UNNotificationContent) -> Void
    ) {

        let config = airshipConfig
        let logger = AirshipExtensionLogger(
            logHandler: config.logHandler,
            logLevel: config.logLevel
        )
        
        let downloadTask = Task { @MainActor in
            logger.debug(
                "New request received: \(request)"
            )

            guard let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
                logger.error(
                    "Unable to make mutable copy of request"
                )
                try Task.checkCancellation()
                contentHandler(request.content)
                return
            }

            do {
                let args = try request.mediaAttachmentPayload
                guard let args else {
                    logger.debug(
                        "Finishing request, no Airship args: \(request.identifier)"
                    )
                    try Task.checkCancellation()
                    contentHandler(request.content)
                    return
                }

                logger.info(
                    "Found Airship arguments for request \(request.identifier): \(args)"
                )
                let mutationsProvider = AirshipNotificationMutationProvider(
                    logger: logger
                )
                try await mutationsProvider.mutations(for: args)?.apply(to: mutableContent)
            } catch {
                logger.error(
                    "Failed to apply mutations to request \(request.identifier): \(error)"
                )
            }

            try Task.checkCancellation()

            logger.info(
                "Finished processing request: \(request.identifier): \(mutableContent)"
            )
            contentHandler(mutableContent)
        }

        self.onExpire = {
            logger.error(
                "serviceExtensionTimeWillExpire expiring, canceling airshipTask"
            )
            downloadTask.cancel()
            contentHandler(request.content)
        }
    }

    open override func serviceExtensionTimeWillExpire() {
        self.onExpire?()
    }
}

extension UNNotificationRequest {
    fileprivate static let airshipMediaAttachment = "com.urbanairship.media_attachment"

    // Checks if the request is from Airship
    public var isAirship: Bool {
        return containsAirshipMediaAttachments ||
        self.content.userInfo["com.urbanairship.metadata"] != nil ||
        self.content.userInfo["_"] != nil
    }

    /// Checks if the request is from Airship and contains media attachments
    public var containsAirshipMediaAttachments: Bool {
        return self.content.userInfo[Self.airshipMediaAttachment] != nil
    }

    var mediaAttachmentPayload: MediaAttachmentPayload? {
        get throws {
            guard
                let source = content.userInfo[Self.airshipMediaAttachment],
                let payloadInfo = source as? [String: Any]
            else {
                return nil
            }
            let data = try JSONSerialization.data(withJSONObject: payloadInfo)
            return try JSONDecoder().decode(MediaAttachmentPayload.self, from: data)
        }
    }
}



#endif


