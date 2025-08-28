

protocol AudienceOverridesProvider: Actor {
    func setStableContactIDProvider(
        _ provider: @escaping @Sendable () async -> String
    )

    func setPendingChannelOverridesProvider(
        _ provider: @escaping @Sendable (String) async -> ChannelAudienceOverrides?
    )

    func setPendingContactOverridesProvider(
        _ provider: @escaping @Sendable (String) async -> ContactAudienceOverrides?
    )
    
    func contactUpdated(
        contactID: String,
        tags: [TagGroupUpdate]?,
        attributes: [AttributeUpdate]?,
        subscriptionLists: [ScopedSubscriptionListUpdate]?,
        channels: [ContactChannelUpdate]?
    ) async

    func channelUpdated(
        channelID: String,
        tags: [TagGroupUpdate]?,
        attributes: [AttributeUpdate]?,
        subscriptionLists: [SubscriptionListUpdate]?
    ) async

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

    func notifyPendingChanged() async

    func contactOverrideUpdates(
        contactID: String?
    ) async -> AsyncStream<ContactAudienceOverrides>
}

actor DefaultAudienceOverridesProvider: AudienceOverridesProvider {
    
    private let updates: CachedList<UpdateRecord>
    private var pendingChannelOverridesProvider: (@Sendable (String) async -> ChannelAudienceOverrides?)? = nil
    private var pendingContactOverridesProvider: (@Sendable (String) async -> ContactAudienceOverrides?)? = nil
    private var stableContactIDProvider: (@Sendable () async -> String)? = nil
    private let overridesUpdates: AirshipAsyncChannel<Bool> = AirshipAsyncChannel()

    private static let maxRecordAge: TimeInterval = 600 // 10 minutes

    init(date: any AirshipDateProtocol = AirshipDate.shared) {
        self.updates = CachedList(date: date)
    }

    func setPendingChannelOverridesProvider(
        _ provider: @escaping @Sendable (String) async -> ChannelAudienceOverrides?
    ) {
        self.pendingChannelOverridesProvider = provider
    }

    func setPendingContactOverridesProvider(
        _ provider: @escaping @Sendable (String) async -> ContactAudienceOverrides?
    ) {
        self.pendingContactOverridesProvider = provider
    }

    func setStableContactIDProvider(
        _ provider: @escaping @Sendable () async -> String
    )  {
        self.stableContactIDProvider = provider
    }

    func pendingOverrides(channelID: String) async -> ChannelAudienceOverrides? {
        return await self.pendingChannelOverridesProvider?(channelID)
    }

    func pendingOverrides(contactID: String) async -> ContactAudienceOverrides? {
        return await self.pendingContactOverridesProvider?(contactID)
    }

    func contactUpdated(
        contactID: String,
        tags: [TagGroupUpdate]?,
        attributes: [AttributeUpdate]?,
        subscriptionLists: [ScopedSubscriptionListUpdate]?,
        channels: [ContactChannelUpdate]?
    ) async {
        self.updates.append(
            UpdateRecord(
                recordType: .contact(contactID),
                tags: tags,
                attributes: attributes,
                subscriptionLists: nil,
                scopedSubscriptionLists: subscriptionLists,
                channels: channels
            ),
            expiresIn: DefaultAudienceOverridesProvider.maxRecordAge
        )

        await self.notifyPendingChanged()
    }

    func channelUpdated(
        channelID: String,
        tags: [TagGroupUpdate]?,
        attributes: [AttributeUpdate]?,
        subscriptionLists: [SubscriptionListUpdate]?
    ) async {
        self.updates.append(
            UpdateRecord(
                recordType: .channel(channelID),
                tags: tags,
                attributes: attributes,
                subscriptionLists: subscriptionLists,
                scopedSubscriptionLists: nil,
                channels: nil
            ),
            expiresIn: DefaultAudienceOverridesProvider.maxRecordAge
        )

        await self.notifyPendingChanged()
    }

    func convertAppScopes(scoped: [ScopedSubscriptionListUpdate]) -> [SubscriptionListUpdate] {
        return scoped.compactMap { update in
            if (update.scope == .app) {
                return SubscriptionListUpdate(listId: update.listId, type: update.type)
            } else {
                return nil
            }
        }
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
        var pendingContact: ContactAudienceOverrides?
        if let contactID = contactID {
            pendingContact = await self.pendingOverrides(contactID: contactID)
        }

        var tags: [TagGroupUpdate]  = []
        var attributes: [AttributeUpdate] = []
        var subscriptionLists: [SubscriptionListUpdate] = []


        /// Apply updates first
        self.updates.values.forEach { update  in
            switch (update.recordType) {
            case .contact(let identifier):
                if let contactID = contactID, contactID == identifier {
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
                        subscriptionLists += convertAppScopes(scoped: updateScopedSubscriptionLists)
                    }
                }
            case .channel(let identifier):
                if channelID == identifier {
                    if let updateTags = update.tags {
                        tags += updateTags
                    }

                    if let updateAttributes = update.attributes {
                        attributes += updateAttributes
                    }

                    if let updateSubscriptionLists = update.subscriptionLists {
                        subscriptionLists += updateSubscriptionLists
                    }
                }
            }
        }

        // Pending channel
        if let pendingChannel = pendingChannel {
            tags += pendingChannel.tags
            attributes += pendingChannel.attributes
            subscriptionLists += pendingChannel.subscriptionLists
        }

        // Pending contact
        if let pendingContact = pendingContact {
            tags += pendingContact.tags
            attributes += pendingContact.attributes
            subscriptionLists += convertAppScopes(scoped: pendingContact.subscriptionLists)
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
        guard let contactID = contactID else {
            return ContactAudienceOverrides()
        }

        let pendingContactOverrides = await self.pendingOverrides(contactID: contactID)
        var tags: [TagGroupUpdate]  = []
        var attributes: [AttributeUpdate] = []
        var scopedSubscriptionLists: [ScopedSubscriptionListUpdate] = []
        var channels: [ContactChannelUpdate] = []

        // Contact updates
        self.updates.values.forEach { update in
            if case let .contact(identifier) = update.recordType, identifier == contactID {
                if let updateTags = update.tags {
                    tags += updateTags
                }

                if let updateAttributes = update.attributes {
                    attributes += updateAttributes
                }

                if let updateScopedSubscriptionLists = update.scopedSubscriptionLists {
                    scopedSubscriptionLists += updateScopedSubscriptionLists
                }

                if let updateChannel = update.channels {
                    channels += updateChannel
                }
            }
        }

        // Pending contact
        if let pendingContactOverrides = pendingContactOverrides {
            tags += pendingContactOverrides.tags
            attributes += pendingContactOverrides.attributes
            scopedSubscriptionLists += pendingContactOverrides.subscriptionLists
            channels += pendingContactOverrides.channels
        }

        return ContactAudienceOverrides(
            tags: tags,
            attributes: attributes,
            subscriptionLists: scopedSubscriptionLists,
            channels: channels
        )
    }

    func contactOverrideUpdates(
        contactID: String?
    ) async -> AsyncStream<ContactAudienceOverrides> {
        let updates = await self.overridesUpdates.makeStream(
            bufferPolicy: .bufferingNewest(1)
        )

        let initial: ContactAudienceOverrides = await self.contactOverrides(contactID: contactID)

        return AsyncStream { [weak self] continuation in
            continuation.yield(initial)

            let task = Task { [weak self] in
                for await _ in updates {
                    let overrides = await self?.contactOverrides(contactID: contactID)
                    guard !Task.isCancelled, let overrides else {
                        return
                    }
                    continuation.yield(overrides)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }


    func notifyPendingChanged() async {
        await self.overridesUpdates.send(true)
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
        let channels: [ContactChannelUpdate]?
    }

    fileprivate struct ContactRecord: Sendable {
        let contactID: String
        let tags: [TagGroupUpdate]
        let attributes: [AttributeUpdate]
        let subscriptionLists: [ScopedSubscriptionListUpdate]
        let channels: [ContactChannelUpdate]
    }
}


struct ContactAudienceOverrides: Sendable {
    let tags: [TagGroupUpdate]
    let attributes: [AttributeUpdate]
    let subscriptionLists: [ScopedSubscriptionListUpdate]
    let channels: [ContactChannelUpdate]

    init(tags: [TagGroupUpdate] = [], attributes: [AttributeUpdate] = [], subscriptionLists: [ScopedSubscriptionListUpdate] = [], channels: [ContactChannelUpdate] = []) {
        self.tags = tags
        self.attributes = attributes
        self.subscriptionLists = subscriptionLists
        self.channels = channels
    }
}

struct ChannelAudienceOverrides: Sendable, Equatable {
    let tags: [TagGroupUpdate]
    let attributes: [AttributeUpdate]
    let subscriptionLists: [SubscriptionListUpdate]

    init(tags: [TagGroupUpdate] = [], attributes: [AttributeUpdate] = [], subscriptionLists: [SubscriptionListUpdate] = []) {
        self.tags = tags
        self.attributes = attributes
        self.subscriptionLists = subscriptionLists
    }
}
