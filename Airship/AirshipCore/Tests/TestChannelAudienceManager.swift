import Combine
import Foundation

@testable import AirshipCore

public class TestChannelAudienceManager: ChannelAudienceManagerProtocol
{



    public let subscriptionListEditsSubject = PassthroughSubject<
        SubscriptionListEdit, Never
    >()
    public var subscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never>
    {
        self.subscriptionListEditsSubject.eraseToAnyPublisher()
    }

    public var contactUpdates: [SubscriptionListUpdate] = []

    public var pendingAttributeUpdates: [AttributeUpdate] = []

    public var pendingTagGroupUpdates: [TagGroupUpdate] = []

    public var channelID: String? = nil

    public var enabled: Bool = false

    @objc
    public var tagGroupEditor: TagGroupsEditor?

    @objc
    public var attributeEditor: AttributesEditor?

    @objc
    public var subcriptionListEditor: SubscriptionListEditor?

    public var fetchSubscriptionListCallback:
        (() async throws -> [String])?

    public func editSubscriptionLists() -> SubscriptionListEditor {
        return subcriptionListEditor!
    }

    public func editTagGroups(allowDeviceGroup: Bool) -> TagGroupsEditor {
        return tagGroupEditor!
    }

    public func editAttributes() -> AttributesEditor {
        return attributeEditor!
    }


    public func fetchSubscriptionLists() async throws -> [String] {
        return try await fetchSubscriptionListCallback!()
    }

    public func processContactSubscriptionUpdates(
        _ updates: [SubscriptionListUpdate]
    ) {
        self.contactUpdates.append(contentsOf: updates)
    }

    public func addLiveActivityUpdate(_ update: LiveActivityUpdate) {
    }
}
