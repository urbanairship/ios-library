/* Copyright Airship and Contributors */

@preconcurrency import Combine
import Foundation

protocol ChannelAudienceManagerProtocol: AnyObject, Sendable {
    var channelID: String? { get set }

    var enabled: Bool { get set }

    var subscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never> { get }
    
    func addLiveActivityUpdate(_ update: LiveActivityUpdate)

    func editSubscriptionLists() -> SubscriptionListEditor

    func editTagGroups(allowDeviceGroup: Bool) -> TagGroupsEditor

    func editAttributes() -> AttributesEditor

    func fetchSubscriptionLists() async throws -> [String]

    func clearSubscriptionListCache()

    var liveActivityUpdates: AsyncStream<[LiveActivityUpdate]> { get }
}

/// NOTE: For internal use only. :nodoc:
final class ChannelAudienceManager: ChannelAudienceManagerProtocol {
    static let updateTaskID = "ChannelAudienceManager.update"
    static let updatesKey = "UAChannel.audienceUpdates"

    static let legacyPendingTagGroupsKey =
        "com.urbanairship.tag_groups.pending_channel_tag_groups_mutations"
    static let legacyPendingAttributesKey =
        "com.urbanairship.channel_attributes.registrar_persistent_queue_key"

    static let maxCacheTime: TimeInterval = 600  // 10 minutes

    private let dataStore: PreferenceDataStore
    private let privacyManager: AirshipPrivacyManager
    private let workManager: any AirshipWorkManagerProtocol
    private let subscriptionListProvider: any ChannelSubscriptionListProviderProtocol
    private let updateClient: any ChannelBulkUpdateAPIClientProtocol
    private let audienceOverridesProvider: any AudienceOverridesProvider

    private let date: any AirshipDateProtocol
    private let updateLock = AirshipLock()

    private let cachedSubscriptionLists: CachedValue<[String]>

    private let subscriptionListEditsSubject = PassthroughSubject<
        SubscriptionListEdit, Never
    >()

    var subscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never> {
        self.subscriptionListEditsSubject.eraseToAnyPublisher()
    }

    private let _channelID: AirshipAtomicValue<String?> = AirshipAtomicValue(nil)
    var channelID: String? {
        get {
            _channelID.value
        }
        set {
            if (_channelID.setValue(newValue)) {
                self.enqueueTask()
            }
        }
    }

    private let _enabled: AirshipAtomicValue<Bool> = AirshipAtomicValue(false)
    var enabled: Bool {
        get {
            _enabled.value
        }
        set {
            if (_enabled.setValue(newValue)) {
                self.enqueueTask()
            }
        }
    }

    let liveActivityUpdates: AsyncStream<[LiveActivityUpdate]>
    private let liveActivityUpdatesContinuation: AsyncStream<[LiveActivityUpdate]>.Continuation

    init(
        dataStore: PreferenceDataStore,
        workManager: any AirshipWorkManagerProtocol,
        subscriptionListProvider: any ChannelSubscriptionListProviderProtocol,
        updateClient: any ChannelBulkUpdateAPIClientProtocol,
        privacyManager: AirshipPrivacyManager,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        date: any AirshipDateProtocol = AirshipDate.shared,
        audienceOverridesProvider: any AudienceOverridesProvider
    ) {
        self.dataStore = dataStore
        self.workManager = workManager
        self.privacyManager = privacyManager
        self.subscriptionListProvider = subscriptionListProvider
        self.updateClient = updateClient
        self.date = date
        self.cachedSubscriptionLists = CachedValue(date: date)
        self.audienceOverridesProvider = audienceOverridesProvider
        (self.liveActivityUpdates, self.liveActivityUpdatesContinuation) = AsyncStream<[LiveActivityUpdate]>.airshipMakeStreamWithContinuation()

        self.workManager.registerWorker(
            ChannelAudienceManager.updateTaskID
        ) { [weak self] _ in
            return try await self?.handleUpdateTask() ?? .success
        }

        self.workManager.autoDispatchWorkRequestOnBackground(
            AirshipWorkRequest(workID: ChannelAudienceManager.updateTaskID)
        )

        self.migrateMutations()

        notificationCenter.addObserver(
            self,
            selector: #selector(checkPrivacyManager),
            name: AirshipNotifications.PrivacyManagerUpdated.name,
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
        audienceOverridesProvider: any AudienceOverridesProvider
    ) {
        self.init(
            dataStore: dataStore,
            workManager: AirshipWorkManager.shared,
            subscriptionListProvider: ChannelSubscriptionListProvider(
                audienceOverrides: audienceOverridesProvider,
                apiClient: SubscriptionListAPIClient(config: config)),
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

            Task { @MainActor in
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

        return try await subscriptionListProvider.fetch(channelID: channelID)
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

        if (!update.liveActivityUpdates.isEmpty) {
            self.liveActivityUpdatesContinuation.yield(update.liveActivityUpdates)
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
                result = try? JSONDecoder().decode(
                    [AudienceUpdate].self,
                    from: data
                )
            }
        }
        return result ?? []
    }

    private func storeUpdates(_ operations: [AudienceUpdate]) {
        updateLock.sync {
            if let data = try? JSONEncoder().encode(operations) {
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
