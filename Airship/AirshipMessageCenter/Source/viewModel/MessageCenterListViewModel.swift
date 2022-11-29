/* Copyright Urban Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

class MessageCenterListViewModel: ObservableObject {

    @Published
    var messageIDs: [String] = []

    @Published
    var messagesLoaded: Bool = false

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
            .sink { [weak self] incoming in
                guard let strongSelf = self else { return }
                strongSelf.objectWillChange.send()

                strongSelf.messagesLoaded = true

                var incomingIDs: [String] = []
                incoming.forEach { message in
                    incomingIDs.append(message.id)
                    if strongSelf.messageItems[message.id] == nil {
                        strongSelf.messageItems[message.id] =
                            MessageCenterListItemViewModel(
                                message: message
                            )
                    }
                }

                Set(strongSelf.messageItems.keys)
                    .subtracting(incomingIDs)
                    .forEach {
                        strongSelf.messageItems.removeValue(forKey: $0)
                    }
                strongSelf.messageIDs = incomingIDs
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
