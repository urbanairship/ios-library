import Foundation

protocol AudienceOverridesProvider: Actor {
    func setStableContactIDProvider(
        _ provider: @escaping @Sendable () async -> String?
    )

    func setPendingChannelOverridesProvider(
        _ provider: @escaping @Sendable (String) async -> ChannelAudienceOverrides?
    )

    func setPendingContactOverridesProvider(
        _ provider: @escaping @Sendable (String?) async -> ContactAudienceOverrides?
    )
    
    func contactUpdaed(
        contactID: String,
        tags: [TagGroupUpdate]?,
        attributes: [AttributeUpdate]?,
        subscriptionLists: [ScopedSubscriptionListUpdate]?
    )

    func channelUpdated(
        channelID: String,
        tags: [TagGroupUpdate]?,
        attributes: [AttributeUpdate]?,
        subscriptionLists: [SubscriptionListUpdate]?
    )

    func channelOverrides(
        channelID: String,
        contactID: String?
    ) async -> ChannelAudienceOverrides

    func channelOverrides(
        channelID: String
    ) async -> ChannelAudienceOverrides

    func contactOverrides(
        contactID: String?
    ) async -> ContactAudienceOverrides

    func contactOverrides() async -> ContactAudienceOverrides
}

actor DefaultAudienceOverridesProvider: AudienceOverridesProvider {
    private let updates: CachedList<UpdateRecord>
    private var pendingChannelOverridesProvider: (@Sendable (String) async -> ChannelAudienceOverrides?)? = nil
    private var pendingContactOverridesProvider: (@Sendable (String?) async -> ContactAudienceOverrides?)? = nil
    private var stableContactIDProvider: (@Sendable () async -> String?)? = nil


    private static let maxRecordAge: TimeInterval = 600 // 10 minutes

    init(date: AirshipDateProtocol = AirshipDate.shared) {
        self.updates = CachedList(date: date)
    }

    func setPendingChannelOverridesProvider(
        _ provider: @escaping @Sendable (String) async -> ChannelAudienceOverrides?
    ) {
        self.pendingChannelOverridesProvider = provider
    }

    func setPendingContactOverridesProvider(
        _ provider: @escaping @Sendable (String?) async -> ContactAudienceOverrides?
    ) {
        self.pendingContactOverridesProvider = provider
    }

    func setStableContactIDProvider(
        _ provider: @escaping @Sendable () async -> String?
    )  {
        self.stableContactIDProvider = provider
    }

    func pendingOverrides(channelID: String) async -> ChannelAudienceOverrides? {
        return await self.pendingChannelOverridesProvider?(channelID)
    }

    func pendingOverrides(contactID: String?) async -> ContactAudienceOverrides? {
        return await self.pendingContactOverridesProvider?(contactID)
    }

    func contactUpdaed(
        contactID: String,
        tags: [TagGroupUpdate]?,
        attributes: [AttributeUpdate]?,
        subscriptionLists: [ScopedSubscriptionListUpdate]?
    ) {
        self.updates.append(
            UpdateRecord(
                recordType: .contact(contactID),
                tags: tags,
                attributes: attributes,
                subscriptionLists: nil,
                scopedSubscriptionLists: subscriptionLists
            ),
            expiresIn: DefaultAudienceOverridesProvider.maxRecordAge
        )
    }

    func channelUpdated(
        channelID: String,
        tags: [TagGroupUpdate]?,
        attributes: [AttributeUpdate]?,
        subscriptionLists: [SubscriptionListUpdate]?
    ) {
        self.updates.append(
            UpdateRecord(
                recordType: .channel(channelID),
                tags: tags,
                attributes: attributes,
                subscriptionLists: subscriptionLists,
                scopedSubscriptionLists: nil
            ),
            expiresIn: DefaultAudienceOverridesProvider.maxRecordAge
        )
    }


    func channelOverrides(
        channelID: String
    ) async -> ChannelAudienceOverrides {
        return await channelOverrides(
            channelID: channelID,
            contactID: nil
        )
    }

    func channelOverrides(
        channelID: String,
        contactID: String?
    ) async -> ChannelAudienceOverrides {
        let contactID = await resolveContactID(contactID: contactID)
        let pendingChannel = await self.pendingOverrides(channelID: channelID)
        let pendingContact = await self.pendingOverrides(contactID: contactID)

        var tags: [TagGroupUpdate]  = []
        var attributes: [AttributeUpdate] = []
        var subscriptionLists: [SubscriptionListUpdate] = []
        var scopedSubscriptionLists: [ScopedSubscriptionListUpdate] = []


        self.updates.values.filter { update  in
            switch (update.recordType) {
            case .contact(let identifier):
                if let contactID = contactID, contactID != identifier {
                    return false
                }
            case .channel(let identifier):
                if channelID != identifier {
                    return false
                }
            }

            return true
        }.forEach { update in
            if let updateTags = update.tags {
                tags += updateTags
            }

            if let updateAttributes = update.attributes {
                attributes += updateAttributes
            }

            if let updateSubscriptionLists = update.subscriptionLists {
                subscriptionLists += updateSubscriptionLists
            }

            if let updateScopedSubscriptionLists = update.scopedSubscriptionLists {
                scopedSubscriptionLists += updateScopedSubscriptionLists
            }
        }

        if let pendingChannel = pendingChannel {
            tags += pendingChannel.tags
            attributes += pendingChannel.attributes
            subscriptionLists += pendingChannel.subscriptionLists
        }

        if let pendingContact = pendingContact {
            tags += pendingContact.tags
            attributes += pendingContact.attributes
            scopedSubscriptionLists += pendingContact.subscriptionLists
        }

        subscriptionLists += scopedSubscriptionLists.compactMap { update in
            if (update.scope == .app) {
                return SubscriptionListUpdate(listId: update.listId, type: update.type)
            } else {
                return nil
            }
        }

        return ChannelAudienceOverrides(
            tags: tags,
            attributes: attributes,
            subscriptionLists: subscriptionLists
        )
    }


    func contactOverrides() async -> ContactAudienceOverrides {
        return await contactOverrides(contactID: nil)
    }

    func contactOverrides(
        contactID: String?
    ) async -> ContactAudienceOverrides {
        let contactID = await resolveContactID(contactID: contactID)
        let pendingContactOverrides = await self.pendingOverrides(contactID: contactID)
        var tags: [TagGroupUpdate]  = []
        var attributes: [AttributeUpdate] = []
        var scopedSubscriptionLists: [ScopedSubscriptionListUpdate] = []

        self.updates.values.filter { update  in
            switch (update.recordType) {
            case .contact(let identifier):
                if let contactID = contactID, contactID != identifier {
                    return false
                }
            case .channel(_):
                return false
            }

            return true
        }.forEach { update in
            if let updateTags = update.tags {
                tags += updateTags
            }

            if let updateAttributes = update.attributes {
                attributes += updateAttributes
            }

            if let updateScopedSubscriptionLists = update.scopedSubscriptionLists {
                scopedSubscriptionLists += updateScopedSubscriptionLists
            }
        }

        if let pendingContactOverrides = pendingContactOverrides {
            tags += pendingContactOverrides.tags
            attributes += pendingContactOverrides.attributes
            scopedSubscriptionLists += pendingContactOverrides.subscriptionLists
        }

        return ContactAudienceOverrides(
            tags: tags,
            attributes: attributes,
            subscriptionLists: scopedSubscriptionLists
        )
    }

    private func resolveContactID(contactID: String?) async -> String? {
        guard let contactID = contactID else {
            return await self.stableContactIDProvider?()
        }
        return contactID
    }

    


    fileprivate struct UpdateRecord {
        enum RecordType {
            case channel(String)
            case contact(String)
        }

        let recordType: RecordType
        let tags: [TagGroupUpdate]?
        let attributes: [AttributeUpdate]?
        let subscriptionLists: [SubscriptionListUpdate]?
        let scopedSubscriptionLists: [ScopedSubscriptionListUpdate]?
    }

    fileprivate struct ContactRecord: Sendable {
        let contactID: String
        let tags: [TagGroupUpdate]
        let attributes: [AttributeUpdate]
        let subscriptionLists: [ScopedSubscriptionListUpdate]
    }
}


struct ContactAudienceOverrides: Sendable {
    let tags: [TagGroupUpdate]
    let attributes: [AttributeUpdate]
    let subscriptionLists: [ScopedSubscriptionListUpdate]

    init(tags: [TagGroupUpdate] = [], attributes: [AttributeUpdate] = [], subscriptionLists: [ScopedSubscriptionListUpdate] = []) {
        self.tags = tags
        self.attributes = attributes
        self.subscriptionLists = subscriptionLists
    }
}

struct ChannelAudienceOverrides: Sendable {
    let tags: [TagGroupUpdate]
    let attributes: [AttributeUpdate]
    let subscriptionLists: [SubscriptionListUpdate]

    init(tags: [TagGroupUpdate] = [], attributes: [AttributeUpdate] = [], subscriptionLists: [SubscriptionListUpdate] = []) {
        self.tags = tags
        self.attributes = attributes
        self.subscriptionLists = subscriptionLists
    }
}



