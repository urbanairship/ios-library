/* Copyright Urban Airship and Contributors */

import Foundation
import AirshipMessageCenter
import AirshipCore

class MessageCenterListItemViewModel: ObservableObject {
    let title: String
    let subtitle: String?
    let listIcon: String?
    let messageID: String
    let messageSent: Date

    @Published
    private(set) var unread: Bool

    init(message: MessageCenterMessage) {
        self.title = message.title
        self.subtitle = message.subtitle
        self.listIcon = message.listIcon
        self.messageID = message.id
        self.messageSent = message.sentDate
        self.unread = message.unread
    }


    @MainActor
    func markRead() async {
        guard self.unread else { return }
        self.unread = false

        if Airship.isFlying {
            await MessageCenter.shared.inbox.markRead(
                messageIDs: [messageID]
            )
        }

    }
}
