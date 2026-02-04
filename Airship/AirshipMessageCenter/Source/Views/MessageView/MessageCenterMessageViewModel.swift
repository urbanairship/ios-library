/* Copyright Airship and Contributors */

public import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

/// A view model for a message.
@MainActor
public final class MessageCenterMessageViewModel: ObservableObject {
    /// The message ID.
    public let messageID: String

    /// The message.
    @Published
    public var message: MessageCenterMessage? = nil

    /// Initializer.
    /// - Parameters:
    ///   - messageID: The message ID.
    public init(messageID: String) {
        self.messageID = messageID
    }

    private var fetchMessageTask: Task<MessageCenterMessage?, Never>? = nil
    
    let timer: any AirshipTimerProtocol = AirshipTimer()
    weak var backButtonCallbackDelegate: (any MessageViewBackButtonCallback)? = nil
    
    private var nativeAnalytics: ThomasDisplayListener? = nil
    
    func makeAnalytics(
        messageCenter: DefaultMessageCenter = Airship.internalMessageCenter,
        onDismiss: @MainActor @escaping () async -> Void
    ) -> ThomasDisplayListener? {
        guard let message else { return nil }
        
        if let cached = nativeAnalytics {
            return cached
        }
        
        let result = ThomasDisplayListener(
            analytics: DefaultMessageViewAnalytics(
                message: message,
                eventRecorder: ThomasLayoutEventRecorder(
                    airshipAnalytics: messageCenter.analytics,
                    meteredUsage: messageCenter.meteredUsage
                ),
                historyStorage: MessageDisplayHistoryStore(
                    storageGetter: { messageID in
                        await messageCenter.internalInbox.message(forID: messageID)?.associatedData
                    },
                    storageSetter: { messageID, data in
                        await messageCenter.internalInbox.saveDisplayHistory(for: messageID, history: data)
                    })
            ),
            onDismiss: {  _ in
                Task { @MainActor in
                    await onDismiss()
                }
            })
        
        nativeAnalytics = result
        return result
    }

    /// Fetches the message.
    /// - Returns: The message.
    @MainActor
    public func fetchMessage() async -> MessageCenterMessage? {
        _ = await fetchMessageTask?.value

        if let message = message {
            return message
        }

        self.fetchMessageTask = Task<MessageCenterMessage?, Never> {
            var message = await Airship.messageCenter.inbox.message(
                forID: messageID
            )

            if message == nil {
                await Airship.messageCenter.inbox.refreshMessages()
                message = await Airship.messageCenter.inbox.message(
                    forID: messageID
                )
            }

            return message
        }

        self.message = await self.fetchMessageTask?.value

        return self.message
    }

    /// Marks the message as read.
    /// - Returns: `true` if the message was marked as read, `false` otherwise.
    @discardableResult
    public func markRead() async -> Bool {
        guard let message = await fetchMessage() else { return false }
        await Airship.messageCenter.inbox.markRead(messageIDs: [message.id])
        return true
    }

    /// Deletes the message.
    /// - Returns: `true` if the message was deleted, `false` otherwise.
    @discardableResult
    public func delete() async -> Bool {
        guard let message = await fetchMessage() else { return false }
        await Airship.messageCenter.inbox.delete(messageIDs: [message.id])
        return true
    }
}

protocol MessageViewBackButtonCallback: AnyObject, Sendable {
    @MainActor
    func onBackButtonTapped()
}
