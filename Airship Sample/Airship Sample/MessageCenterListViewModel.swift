
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

        var filteredOut = false

        self.messageCenter?.messagePublisher
            .receive(on: RunLoop.main)
            .sink { incoming in
                self.objectWillChange.send()

                var incomingIDs = [String]()
                incoming.forEach {
                    if (!filteredOut && $0.messageID == "-ScgkCTyEe2pOwJCmdS4LA") {
                        filteredOut = true
                    } else {
                        incomingIDs.append($0.messageID)
                        if let existing = self.messageItems[$0.messageID] {
                            if (existing.unread != $0.unread) {
                                existing.markRead()
                            }
                        } else {
                            let item = MessageCenterListItemViewModel(
                                message: $0
                            )
                            self.messageItems[$0.messageID] = item
                        }
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
        let _ = await self.messageCenter?.refreshMessages()
    }

    func markRead(messages: Set<String>) {
        self.messageCenter?.markRead(messages: messages)
    }

    func delete(messages: Set<String>) {
        self.messageCenter?.delete(messages: messages)
    }

}


