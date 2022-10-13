/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI
import Combine
import AirshipMessageCenter
import AirshipCore

class MessageCenterListViewModel: ObservableObject {
    @Published
    var messageIDs: [String] = []

    private var messageItems: [String: MessageCenterListItemViewModel] = [:]
    private var updates = Set<AnyCancellable>()
    private let messageCenter: MessageCenter?

    init() {
        if Airship.isFlying {
            messageCenter = MessageCenter.shared
        } else {
            messageCenter = nil
        }

        self.messageCenter?.inbox.messagePublisher
            .receive(on: RunLoop.main)
            .sink { incoming in
                self.objectWillChange.send()
                var incomingIDs = [String]()
                incoming.forEach { message in
                    incomingIDs.append(message.id)
                    if let existing = self.messageItems[message.id] {
                        if (existing.unread != message.unread) {
                            Task {
                                await existing.markRead()
                            }
                        }
                    } else {
                        let item = MessageCenterListItemViewModel(
                            message: message
                        )
                        self.messageItems[message.id] = item
                    }
                }
                Set(self.messageItems.keys)
                    .subtracting(incomingIDs)
                    .forEach {
                        self.messageItems.removeValue(forKey: $0)
                    }

                self.messageIDs = incomingIDs
            }.store(in: &self.updates)

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
            await self.messageCenter?.inbox.markRead(messageIDs: Array(messages))
        }

    }

    func delete(messages: Set<String>) {
        Task {
            await self.messageCenter?.inbox.delete(messageIDs: Array(messages))
        }

    }

}

