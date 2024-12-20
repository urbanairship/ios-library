/* Copyright Airship and Contributors */

import Foundation

@preconcurrency
import UserNotifications

#if !TARGET_OS_TV
@objc
open class UANotificationServiceExtension: UNNotificationServiceExtension {
    private var downloadTask: Task<Void, any Error>?
    private var reqeuest: UNNotificationRequest?
    private var deliverHandler: ((UNNotificationContent) -> Void)?
    
    open override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @Sendable @escaping (UNNotificationContent) -> Void
    ) {
        self.deliverHandler = contentHandler
        self.reqeuest = request

        self.downloadTask = Task { @MainActor in
            guard let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
                contentHandler(request.content)
                return
            }

            do {
                let args = try request.mediaAttachmentPayload
                guard let args else {
                    contentHandler(request.content)
                    return
                }

                let mutations = try await AirshipNotificationMutationProvider().mutations(for: args)
                try mutations?.apply(to: mutableContent)
            } catch {
                print("Failed to apply AirshipMutableNotificaitonArgs: \(error)")
            }

            try Task.checkCancellation()
            contentHandler(mutableContent)
        }
    }
    
    open override func serviceExtensionTimeWillExpire() {
        self.downloadTask?.cancel()

        if let reqeuest, let deliverHandler {
            deliverHandler(reqeuest.content)
        }
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


