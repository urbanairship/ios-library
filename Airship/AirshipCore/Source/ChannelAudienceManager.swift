/* Copyright Airship and Contributors */

import Combine
import Foundation

protocol ChannelAudienceManagerProtocol {
    var channelID: String? { get set }

    var enabled: Bool { get set }

    var subscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never> { get }
    
    func addLiveActivityUpdate(_ update: LiveActivityUpdate)

    func editSubscriptionLists() -> SubscriptionListEditor

    func editTagGroups(allowDeviceGroup: Bool) -> TagGroupsEditor

    func editAttributes() -> AttributesEditor

    func fetchSubscriptionLists() async throws -> [String]

    func clearSubscriptionListCache()
}

// NOTE: For internal use only. :nodoc:
class ChannelAudienceManager: ChannelAudienceManagerProtocol {
    static let updateTaskID = "ChannelAudienceManager.update"
    static let updatesKey = "UAChannel.audienceUpdates"

    static let legacyPendingTagGroupsKey =
        "com.urbanairship.tag_groups.pending_channel_tag_groups_mutations"
    static let legacyPendingAttributesKey =
        "com.urbanairship.channel_attributes.registrar_persistent_queue_key"

    static let maxCacheTime: TimeInterval = 600  // 10 minutes

    private let dataStore: PreferenceDataStore
    private let privacyManager: AirshipPrivacyManager
    private let workManager: AirshipWorkManagerProtocol
    private let subscriptionListClient: SubscriptionListAPIClientProtocol
    private let updateClient: ChannelBulkUpdateAPIClientProtocol
    private let audienceOverridesProvider: AudienceOverridesProvider

    private let date: AirshipDateProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let updateLock = AirshipLock()

    private let cachedSubscriptionLists: CachedValue<[String]>

    private let subscriptionListEditsSubject = PassthroughSubject<
        SubscriptionListEdit, Never
    >()

    var subscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never> {
        self.subscriptionListEditsSubject.eraseToAnyPublisher()
    }

    var channelID: String? {
        didSet {
            self.enqueueTask()
        }
    }

    var enabled: Bool = false {
        didSet {
            self.enqueueTask()
        }
    }

    init(
        dataStore: PreferenceDataStore,
        workManager: AirshipWorkManagerProtocol,
        subscriptionListClient: SubscriptionListAPIClientProtocol,
        updateClient: ChannelBulkUpdateAPIClientProtocol,
        privacyManager: AirshipPrivacyManager,
        notificationCenter: NotificationCenter =  NotificationCenter.default,
        date: AirshipDateProtocol = AirshipDate.shared,
        audienceOverridesProvider: AudienceOverridesProvider
    ) {
        self.dataStore = dataStore
        self.workManager = workManager
        self.privacyManager = privacyManager
        self.subscriptionListClient = subscriptionListClient
        self.updateClient = updateClient
        self.date = date
        self.cachedSubscriptionLists = CachedValue(date: date)
        self.audienceOverridesProvider = audienceOverridesProvider

        self.workManager.registerWorker(
            ChannelAudienceManager.updateTaskID,
            type: .serial
        ) { [weak self] _ in
            return try await self?.handleUpdateTask() ?? .success
        }

        self.migrateMutations()

        notificationCenter.addObserver(
            self,
            selector: #selector(checkPrivacyManager),
            name: AirshipPrivacyManager.changeEvent,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(enqueueTask),
            name: RuntimeConfig.configUpdatedEvent,
            object: nil
        )

        self.checkPrivacyManager()

        Task {
            await self.audienceOverridesProvider.setPendingChannelOverridesProvider { channelID in
                return self.pendingOverrides(channelID: channelID)
            }
        }
    }

    convenience init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        privacyManager: AirshipPrivacyManager,
        audienceOverridesProvider: AudienceOverridesProvider
    ) {
        self.init(
            dataStore: dataStore,
            workManager: AirshipWorkManager.shared,
            subscriptionListClient: SubscriptionListAPIClient(config: config),
            updateClient: ChannelBulkUpdateAPIClient(config: config),
            privacyManager: privacyManager,
            audienceOverridesProvider: audienceOverridesProvider
        )
    }

    func editSubscriptionLists() -> SubscriptionListEditor {
        return SubscriptionListEditor { updates in
            guard !updates.isEmpty else {
                return
            }

            guard self.privacyManager.isEnabled(.tagsAndAttributes) else {
                AirshipLogger.warn(
                    "Tags and attributes are disabled. Enable to apply subscription list edits."
                )
                return
            }

            self.addUpdate(
                AudienceUpdate(subscriptionListUpdates: updates)
            )

            updates.forEach {
                switch $0.type {
                case .subscribe:
                    self.subscriptionListEditsSubject.send(
                        .subscribe($0.listId)
                    )
                case .unsubscribe:
                    self.subscriptionListEditsSubject.send(
                        .unsubscribe($0.listId)
                    )
                }
            }
            self.enqueueTask()
        }
    }

    func editTagGroups(allowDeviceGroup: Bool) -> TagGroupsEditor {
        return TagGroupsEditor(allowDeviceTagGroup: allowDeviceGroup) {
            updates in
            guard !updates.isEmpty else {
                return
            }

            guard self.privacyManager.isEnabled(.tagsAndAttributes) else {
                AirshipLogger.warn(
                    "Tags and attributes are disabled. Enable to apply tag group edits."
                )
                return
            }

            self.addUpdate(
                AudienceUpdate(tagGroupUpdates: updates)
            )
            self.enqueueTask()
        }
    }

    func editAttributes() -> AttributesEditor {
        return AttributesEditor { updates in
            guard !updates.isEmpty else {
                return
            }

            guard self.privacyManager.isEnabled(.tagsAndAttributes) else {
                AirshipLogger.warn(
                    "Tags and attributes are disabled. Enable to apply attribute edits."
                )
                return
            }

            self.addUpdate(
                AudienceUpdate(attributeUpdates: updates)
            )
            self.enqueueTask()
        }
    }

    func fetchSubscriptionLists() async throws -> [String] {
        guard let channelID = self.channelID else {
            throw AirshipErrors.error("Channel not created yet")
        }

        var listIDs = try await self.resolveSubscriptionLists(
            channelID: channelID
        )

        let overrides = await self.audienceOverridesProvider.channelOverrides(
            channelID: channelID
        )

        listIDs = self.applySubscriptionListUpdates(
            listIDs,
            updates: overrides.subscriptionLists
        )

        return listIDs
    }

    func pendingOverrides(channelID: String) -> ChannelAudienceOverrides {
        guard self.channelID == channelID else {
            return ChannelAudienceOverrides()
        }

        var tags: [TagGroupUpdate] = []
        var attributes: [AttributeUpdate] = []
        var subscriptionLists: [SubscriptionListUpdate] = []

        self.updateLock.sync {
            self.getUpdates().forEach { update in
                attributes += update.attributeUpdates
                tags += update.tagGroupUpdates
                subscriptionLists += update.subscriptionListUpdates
            }
        }

        return ChannelAudienceOverrides(
            tags: tags,
            attributes: attributes,
            subscriptionLists: subscriptionLists
        )
    }

    private func resolveSubscriptionLists(
        channelID: String
    ) async throws -> [String] {
        if let cached = self.cachedSubscriptionLists.value {
            return cached
        }

        let response = try await self.subscriptionListClient.get(
            channelID: channelID
        )

        guard response.isSuccess, let lists = response.result else {
            throw AirshipErrors.error(
                "Failed to fetch subscription lists with status: \(response.statusCode)"
            )
        }

        self.cachedSubscriptionLists.set(
            value: lists,
            expiresIn: ChannelAudienceManager.maxCacheTime
        )


        return lists
    }

    private func applySubscriptionListUpdates(
        _ ids: [String],
        updates: [SubscriptionListUpdate]
    ) -> [String] {
        guard !updates.isEmpty else {
            return ids
        }

        var result = ids
        updates.forEach { update in
            switch update.type {
            case .subscribe:
                if !result.contains(update.listId) {
                    result.append(update.listId)
                }
            case .unsubscribe:
                result.removeAll(where: { $0 == update.listId })
            }
        }

        return result
    }
    @objc
    private func checkPrivacyManager() {
        if !self.privacyManager.isEnabled(.tagsAndAttributes) {
            updateLock.sync {
                self.dataStore.removeObject(
                    forKey: ChannelAudienceManager.updatesKey
                )
            }
        }
    }

    @objc
    private func enqueueTask() {
        if self.enabled && self.channelID != nil {
            self.workManager.dispatchWorkRequest(
                AirshipWorkRequest(
                    workID: ChannelAudienceManager.updateTaskID,
                    requiresNetwork: true
                )
            )
        }
    }

    private func handleUpdateTask() async throws -> AirshipWorkResult {
        guard self.enabled,
              let channelID = self.channelID,
              let update = self.prepareNextUpdate()
        else {
            return .success
        }

        let response = try await self.updateClient.update(
            update,
            channelID: channelID
        )


        AirshipLogger.debug(
            "Update finished with response: \(response)"
        )

        guard response.isSuccess else {
            return response.isServerError ? .failure : .success
        }


        await self.audienceOverridesProvider.channelUpdated(
            channelID: channelID,
            tags: update.tagGroupUpdates,
            attributes: update.attributeUpdates,
            subscriptionLists: update.subscriptionListUpdates
        )

        self.popFirstUpdate()
        self.enqueueTask()

        return .success
    }

    private func addUpdate(_ update: AudienceUpdate) {
        guard !update.isEmpty else { return }
        self.updateLock.sync {
            var updates = getUpdates()
            updates.append(update)
            self.storeUpdates(updates)
        }
    }

    func addLiveActivityUpdate(_ update: LiveActivityUpdate) {
        AirshipLogger.debug("Live activity update: \(update)")
        self.addUpdate(
            AudienceUpdate(liveActivityUpdates: [update])
        )
        self.enqueueTask()
    }

    private func getUpdates() -> [AudienceUpdate] {
        var result: [AudienceUpdate]?
        updateLock.sync {
            if let data = self.dataStore.data(
                forKey: ChannelAudienceManager.updatesKey
            ) {
                result = try? self.decoder.decode(
                    [AudienceUpdate].self,
                    from: data
                )
            }
        }
        return result ?? []
    }

    private func storeUpdates(_ operations: [AudienceUpdate]) {
        updateLock.sync {
            if let data = try? self.encoder.encode(operations) {
                self.dataStore.setObject(
                    data,
                    forKey: ChannelAudienceManager.updatesKey
                )
            }
        }
    }

    private func popFirstUpdate() {
        updateLock.sync {
            var updates = getUpdates()
            if !updates.isEmpty {
                updates.removeFirst()
                storeUpdates(updates)
            }
        }
    }

    private func prepareNextUpdate() -> AudienceUpdate? {
        var nextUpdate: AudienceUpdate? = nil
        updateLock.sync {
            let updates = self.getUpdates()
            if let collapsed = AudienceUpdate.collapse(updates) {
                self.storeUpdates([collapsed])
                nextUpdate = collapsed
            } else {
                self.storeUpdates([])
            }
        }

        if !self.privacyManager.isEnabled(.tagsAndAttributes) {
            nextUpdate?.attributeUpdates = []
            nextUpdate?.tagGroupUpdates = []
            nextUpdate?.attributeUpdates = []
        }

        guard nextUpdate?.isEmpty == false else {
            return nil
        }

        return nextUpdate
    }

    func migrateMutations() {
        defer {
            self.dataStore.removeObject(
                forKey: ChannelAudienceManager.legacyPendingTagGroupsKey
            )
            self.dataStore.removeObject(
                forKey: ChannelAudienceManager.legacyPendingAttributesKey
            )
        }

        if self.privacyManager.isEnabled(.tagsAndAttributes) {
            var pendingTagUpdates: [TagGroupUpdate]?
            var pendingAttributeUpdates: [AttributeUpdate]?

            if let pendingTagGroupsData = self.dataStore.data(
                forKey: ChannelAudienceManager.legacyPendingTagGroupsKey
            ) {

                let classes = [NSArray.self, TagGroupsMutation.self]
                let pendingTagGroups = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClasses: classes,
                    from: pendingTagGroupsData
                )

                if let pendingTagGroups = pendingTagGroups
                    as? [TagGroupsMutation]
                {
                    pendingTagUpdates =
                        pendingTagGroups.map { $0.tagGroupUpdates }
                        .reduce([], +)
                }
            }

            if let pendingAttributesData = self.dataStore.data(
                forKey: ChannelAudienceManager.legacyPendingAttributesKey
            ) {

                let classes = [NSArray.self, AttributePendingMutations.self]
                let pendingAttributes = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClasses: classes,
                    from: pendingAttributesData
                )

                if let pendingAttributes = pendingAttributes
                    as? [AttributePendingMutations]
                {
                    pendingAttributeUpdates =
                        pendingAttributes.map {
                            $0.attributeUpdates
                        }
                        .reduce([], +)
                }
            }

            let update = AudienceUpdate(
                tagGroupUpdates: pendingTagUpdates ?? [],
                attributeUpdates: pendingAttributeUpdates ?? []
            )
            addUpdate(update)
        }
    }

    func clearSubscriptionListCache() {
        self.cachedSubscriptionLists.expire()
    }
}

internal struct AudienceUpdate: Codable {
    var subscriptionListUpdates: [SubscriptionListUpdate]
    var tagGroupUpdates: [TagGroupUpdate]
    var attributeUpdates: [AttributeUpdate]
    var liveActivityUpdates: [LiveActivityUpdate]

    init(
        subscriptionListUpdates: [SubscriptionListUpdate] = [],
        tagGroupUpdates: [TagGroupUpdate] = [],
        attributeUpdates: [AttributeUpdate] = [],
        liveActivityUpdates: [LiveActivityUpdate] = []
    ) {
        self.subscriptionListUpdates = subscriptionListUpdates
        self.tagGroupUpdates = tagGroupUpdates
        self.attributeUpdates = attributeUpdates
        self.liveActivityUpdates = liveActivityUpdates
    }

    var isEmpty: Bool {
        return subscriptionListUpdates.isEmpty && tagGroupUpdates.isEmpty
            && attributeUpdates.isEmpty && liveActivityUpdates.isEmpty
    }

    static func collapse(_ updates: [AudienceUpdate]) -> AudienceUpdate? {
        var subscriptionListUpdates: [SubscriptionListUpdate] = []
        var tagGroupUpdates: [TagGroupUpdate] = []
        var attributeUpdates: [AttributeUpdate] = []
        var liveActivityUpdates: [LiveActivityUpdate] = []

        updates.forEach { update in
            subscriptionListUpdates.append(
                contentsOf: update.subscriptionListUpdates
            )
            tagGroupUpdates.append(contentsOf: update.tagGroupUpdates)
            attributeUpdates.append(contentsOf: update.attributeUpdates)
            liveActivityUpdates.append(contentsOf: update.liveActivityUpdates)
        }

        let collapsed = AudienceUpdate(
            subscriptionListUpdates: AudienceUtils.collapse(
                subscriptionListUpdates
            ),
            tagGroupUpdates: AudienceUtils.collapse(tagGroupUpdates),
            attributeUpdates: AudienceUtils.collapse(attributeUpdates),
            liveActivityUpdates: AudienceUtils.normalize(liveActivityUpdates)
        )

        return collapsed.isEmpty ? nil : collapsed
    }
}
