/* Copyright Airship and Contributors */

import Foundation
import Testing

@_spi(AirshipInternal) import AirshipBasement
@_spi(AirshipPreview) @testable import AirshipMessageCenter

@MainActor
struct MessageCenterStoriesViewAccessibilityTest {

    @Test
    func testAccessibilityLabelResolvesLocalizedFormat() {
        let message = Self.makeMessage(title: "Sale ends soon", unread: true)
        let label = MessageCenterStoriesView.accessibilityLabel(for: message)

        // If the localized string failed to resolve, the raw key would come
        // back with no title substituted.
        #expect(label.contains("Sale ends soon"))
        #expect(!label.contains("ua_message"))
    }

    @Test
    func testReadAndUnreadStoriesAnnounceDifferently() {
        let unread = Self.makeMessage(title: "Same title", unread: true)
        let read = Self.makeMessage(title: "Same title", unread: false)

        let unreadLabel = MessageCenterStoriesView.accessibilityLabel(for: unread)
        let readLabel = MessageCenterStoriesView.accessibilityLabel(for: read)

        #expect(unreadLabel != readLabel)
        #expect(unreadLabel.contains("Same title"))
        #expect(readLabel.contains("Same title"))
    }

    private static func makeMessage(title: String, unread: Bool) -> MessageCenterMessage {
        let url = URL(string: "https://example.com")!
        return MessageCenterMessage(
            title: title,
            id: UUID().uuidString,
            contentType: .html,
            extra: [:],
            bodyURL: url,
            expirationDate: nil,
            messageReporting: nil,
            unread: unread,
            sentDate: Date(),
            messageURL: url,
            rawMessageObject: [:]
        )
    }
}
