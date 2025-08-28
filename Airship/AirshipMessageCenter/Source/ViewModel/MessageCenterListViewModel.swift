/* Copyright Urban Airship and Contributors */

import Combine

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
class MessageCenterListViewModel: ObservableObject {

    @Published
    var messages: [MessageCenterMessage] = []

    @Published
    var messagesLoaded: Bool = false
    
    private var messageItems: [String: MessageCenterListItemViewModel] = [:]
    private var updates = Set<AnyCancellable>()
    private let messageCenter: MessageCenter?

    init() {
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
                incoming.forEach { message in
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
            await self.refreshList()
        }
    }

    func messageItem(forID: String) -> MessageCenterListItemViewModel? {
        return self.messageItems[forID]
    }

    func refreshList() async {
        await self.messageCenter?.inbox.refreshMessages()
    }

    func markRead(messages: Set<String>) {
        Task {
            await self.messageCenter?.inbox
                .markRead(
                    messageIDs: Array(messages)
                )
        }
    }

    func delete(messages: Set<String>) {
        Task {
            await self.messageCenter?.inbox
                .delete(
                    messageIDs: Array(messages)
                )
        }
    }

}
