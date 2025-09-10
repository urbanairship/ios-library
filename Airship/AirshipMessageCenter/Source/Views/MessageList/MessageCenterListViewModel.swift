/* Copyright Airship and Contributors */

public import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

/// A view model for the message center list.
@MainActor
public class MessageCenterMessageListViewModel: ObservableObject {

    /// The list of messages.
    @Published
    public private(set) var messages: [MessageCenterMessage] = []

    /// The set of selected message IDs in edit mode.
    @Published
    public var editModeSelection: Set<String> = []

    /// The selected message ID.
    @Published
    public var selectedMessageID: String? = nil

    /// A flag indicating if the messages have been loaded.
    @Published
    public private(set) var messagesLoaded: Bool = false

    private var messageItems: [String: MessageCenterListItemViewModel] = [:]
    private var updates = Set<AnyCancellable>()
    private let messageCenter: MessageCenter?

    /// Initializer.
    /// - Parameters:
    ///   - predicate: A predicate to filter messages.
    public init(predicate: (any MessageCenterPredicate)? = nil) {
        if Airship.isFlying {
            messageCenter = Airship.messageCenter
        } else {
            messageCenter = nil
        }

        self.messageCenter?.inbox.messagePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] incoming in
                guard let self else { return }
                self.objectWillChange.send()

                self.messagesLoaded = true

                var incomings: [MessageCenterMessage] = []
                incoming.filter {
                    predicate?.evaluate(message: $0) ?? true
                }
                .forEach { message in
                    incomings.append(message)
                    if self.messageItems[message.id] == nil {
                        self.messageItems[message.id] =
                        MessageCenterListItemViewModel(
                            message: message
                        )
                    }
                }

                let incomingIDs = incomings.map { $0.id }
                Set(self.messageItems.keys)
                    .subtracting(incomingIDs)
                    .forEach {
                        self.messageItems.removeValue(forKey: $0)
                    }
                self.messages = incomings
            }
            .store(in: &self.updates)

        Task {
            await self.refresh()
        }
    }

    func messageItem(forID: String) -> MessageCenterListItemViewModel? {
        return self.messageItems[forID]
    }

    /// Refreshes the list of messages.
    public func refresh() async {
        await self.messageCenter?.inbox.refreshMessages()
    }

    /// Marks a set of messages as read.
    /// - Parameters:
    ///   - messages: A set of message IDs to mark as read.
    public func markRead(messages: Set<String>) {
        Task {
            await self.messageCenter?.inbox
                .markRead(
                    messageIDs: Array(messages)
                )
        }
    }

    /// Deletes a set of messages.
    /// - Parameters:
    ///   - messages: A set of message IDs to delete.
    public func delete(messages: Set<String>) {
        Task {
            await self.messageCenter?.inbox
                .delete(
                    messageIDs: Array(messages)
                )
        }
    }

    /// Selects all messages in edit mode.
    public func editModeSelectAll() {
        editModeSelection = Set(messages.map { $0.id })
    }

    /// Clears the selection in edit mode.
    public func editModeClearAll() {
        editModeSelection.removeAll()
    }
}
