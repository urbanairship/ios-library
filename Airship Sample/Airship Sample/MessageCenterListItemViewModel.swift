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

    init(message: InboxMessage) {
        self.title = message.title
        self.subtitle = message.subtitle
        self.listIcon = message.listIcon
        self.messageID = message.messageID
        self.messageSent = message.messageSent
        self.unread = message.unread
    }

    func markRead() {
        guard self.unread else { return }
        self.unread = false

        if Airship.isFlying {
            MessageCenter.shared!.markRead(messages: [messageID])
        }

    }
}

fileprivate extension InboxMessage {
    var listIcon: String? {
        let icons = self.rawMessageObject["icons"] as? [String: String]
        return icons?["list_icon"]
    }

    var subtitle: String? {
        return self.extra["com.urbanairship.listing.field1"] as? String
    }
}
