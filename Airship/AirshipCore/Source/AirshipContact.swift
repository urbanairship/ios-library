/* Copyright Airship and Contributors */

import Combine
import Foundation


/// Airship contact. A contact is distinct from a channel and  represents a "user"
/// within Airship. Contacts may be named and have channels associated with it.
@objc(UAContact)
public final class AirshipContact: NSObject, Component, AirshipContactProtocol, @unchecked Sendable {
    private static let resolveDateKey = "Contact.resolveDate"
    static let legacyPendingTagGroupsKey = "com.urbanairship.tag_groups.pending_channel_tag_groups_mutations"
    static let legacyPendingAttributesKey = "com.urbanairship.named_user_attributes.registrar_persistent_queue_key"
    static let legacyNamedUserKey = "UANamedUserID"
    private static let foregroundResolveInterval: TimeInterval = 24 * 60 * 60  // 24 hours
    private static let maxSubscriptionListCacheAge: TimeInterval = 600

    @objc
    public static let contactConflictEvent = NSNotification.Name(
        "com.urbanairship.contact_conflict"
    )

    @objc
    public static let contactConflictEventKey = "event"

    @objc
    public static let maxNamedUserIDLength = 128

    private let dataStore: PreferenceDataStore
    private let config: RuntimeConfig
    private let privacyManager: AirshipPrivacyManager
    private let subscriptionListAPIClient: ContactSubscriptionListAPIClientProtocol
    private let date: AirshipDateProtocol
    private let audienceOverridesProvider: AudienceOverridesProvider
    private let contactManager: ContactManagerProtocol
    private let cachedSubscriptionLists: CachedValue<(String, [String: [ChannelScope]])>
    private var setupTask: Task<Void, Never>? = nil
    private var subscriptions: Set<AnyCancellable> = Set()
    private let fetchSubscriptinListQueue: SerialQueue = SerialQueue()
    private let serialQueue: AsyncSerialQueue

    private var lastResolveDate: Date {
         get {
             let date = self.dataStore.object(forKey: AirshipContact.resolveDateKey) as? Date
             return date ?? Date.distantPast
         }
         set {
             self.dataStore.setObject(newValue, forKey: AirshipContact.resolveDateKey)
         }
     }

    private let subscriptionListEditsSubject = PassthroughSubject<ScopedSubscriptionListEdit, Never>()

    /// Publishes all edits made to the subscription lists through the  SDK
    public var subscriptionListEdits: AnyPublisher<ScopedSubscriptionListEdit, Never> {
        subscriptionListEditsSubject.eraseToAnyPublisher()
    }

    private let conflictEventsSubject = PassthroughSubject<ContactConflictEvent, Never>()
    public var conflictEvents: AnyPublisher<ContactConflictEvent, Never> {
        conflictEventsSubject.eraseToAnyPublisher()
    }

    private let contactIDUpdatesSubject = PassthroughSubject<ContactIDInfo?, Never>()
    private var contactIDUpdates: AnyPublisher<ContactIDInfo, Never> {
        let contactManager = self.contactManager
        return self.contactIDUpdatesSubject
            .prepend(Future { promise in
                Task.detached {
                    await promise(.success(contactManager.currentContactIDInfo()))
                }
            })
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private let namedUserUpdatesSubject = PassthroughSubject<String?, Never>()
    public var namedUserUpdates: AnyPublisher<String?, Never> {
        namedUserUpdatesSubject
            .prepend(Future { promise in
                Task {
                    await promise(.success(self.contactManager.currentNamedUserID()))
                }
            })
            .removeDuplicates()
            .eraseToAnyPublisher()
    }



    public func _getNamedUserID() async -> String? {
        return await self.namedUserID
    }

    public var namedUserID: String? {
        get async {
            return await self.contactManager.currentNamedUserID()
        }
    }

    private let disableHelper: ComponentDisableHelper

    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }

    /// The shared Contact instance.
    @objc
    public static var shared: AirshipContact {
        return Airship.contact
    }

    /**
     * Internal only
     * :nodoc:
     */
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        channel: InternalAirshipChannelProtocol,
        privacyManager: AirshipPrivacyManager,
        subscriptionListAPIClient: ContactSubscriptionListAPIClientProtocol,
        date: AirshipDateProtocol = AirshipDate.shared,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        audienceOverridesProvider: AudienceOverridesProvider,
        contactManager: ContactManagerProtocol,
        serialQueue: AsyncSerialQueue = AsyncSerialQueue(priority: .high)
    ) {

        self.dataStore = dataStore
        self.config = config
        self.privacyManager = privacyManager
        self.subscriptionListAPIClient = subscriptionListAPIClient
        self.audienceOverridesProvider = audienceOverridesProvider
        self.date = date
        self.contactManager = contactManager
        self.serialQueue = serialQueue

        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "Contact"
        )

        self.cachedSubscriptionLists = CachedValue(date: date)

        super.init()

        self.setupTask = Task.detached(priority: .high) {
            await self.migrateNamedUser()

            await audienceOverridesProvider.setPendingContactOverridesProvider { contactID in
                return await contactManager.pendingAudienceOverrides(contactID: contactID)
            }

            await audienceOverridesProvider.setStableContactIDProvider {
                return await self.getStableContactID()
            }

            await contactManager.onAudienceUpdated { update in
                await audienceOverridesProvider.contactUpdaed(
                    contactID: update.contactID,
                    tags: update.tags,
                    attributes: update.attributes,
                    subscriptionLists: update.subscriptionLists
                )
            }

            await contactManager.setEnabled(enabled: self.isComponentEnabled)
        }
        
        self.serialQueue.enqueue {
            await self.setupTask?.value
        }

        // Whenever the contact ID changes, ignoring stableness, notify the channnel
        self.contactIDUpdatesSubject
            .receive(on: RunLoop.main)
            .map { $0?.contactID }
            .removeDuplicates()
            .sink { _ in
                channel.clearSubscriptionListsCache()
                channel.updateRegistration()
            }.store(in: &self.subscriptions)

        // For obj-c compatibility
        self.conflictEvents
            .receive(on: RunLoop.main)
            .sink { event in
                notificationCenter.post(
                    name: AirshipContact.contactConflictEvent,
                    object: nil,
                    userInfo: [
                        AirshipContact.contactConflictEventKey: event
                    ]
                )
            }.store(in: &self.subscriptions)


        self.disableHelper.onChange = { [weak self] in
            self?.onComponentEnableChange()
        }

        channel.addRegistrationExtender { [weak self] payload in
            await self?.setupTask?.value
            var payload = payload
            payload.channel.contactID = await self?.contactID
            return payload
        }

        notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(channelCreated),
            name: AirshipChannel.channelCreatedEvent,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(checkPrivacyManager),
            name: AirshipPrivacyManager.changeEvent,
            object: nil
        )

        self.checkPrivacyManager()
    }


    public func airshipReady() {
        Task {
            for await update in await self.contactManager.contactUpdates {
                switch (update) {
                case .conflict(let event):
                    self.conflictEventsSubject.send(event)
                case .contactIDUpdate(let update):
                    self.contactIDUpdatesSubject.send(update)
                case .namedUserUpdate(let namedUserID):
                    self.namedUserUpdatesSubject.send(namedUserID)
                }
            }
        }
    }

    /**
     * Internal only
     * :nodoc:
     */
    convenience init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        channel: AirshipChannel,
        privacyManager: AirshipPrivacyManager,
        audienceOverridesProvider: AudienceOverridesProvider,
        localeManager: AirshipLocaleManagerProtocol
    ) {
        self.init(
            dataStore: dataStore,
            config: config,
            channel: channel,
            privacyManager: privacyManager,
            subscriptionListAPIClient: ContactSubscriptionListAPIClient(config: config),
            audienceOverridesProvider: audienceOverridesProvider,
            contactManager: ContactManager(
                dataStore: dataStore,
                channel: channel,
                localeManager: localeManager,
                apiClient: ContactAPIClient(config: config)
            )
        )
    }

    /// Identifies the contact.
    /// - Parameter namedUserID: The named user ID.
    @objc
    public func identify(_ namedUserID: String) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn("Contacts disabled. Enable to identify user.")
            return
        }

        do {
            self.addOperation(
                .identify(
                    try namedUserID.normalizedNamedUserID
                )
            )
        } catch {
            AirshipLogger.error("Unable to set named user \(error)")
        }
    }

    /// Resets the contact.
    @objc
    public func reset() {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }
        self.addOperation(.reset)
    }

    /// Begins a tag groups editing session.
    /// - Returns: A TagGroupsEditor
    @objc
    public func editTagGroups() -> TagGroupsEditor {
        return TagGroupsEditor { updates in
            guard !updates.isEmpty else {
                return
            }

            guard
                self.privacyManager.isEnabled([.contacts, .tagsAndAttributes])
            else {
                AirshipLogger.warn(
                    "Contacts or tags are disabled. Enable to apply tag edits."
                )
                return
            }

            self.addOperation(.update(tagUpdates: updates))
        }
    }

    /// Begins a tag groups editing session.
    /// - Parameter editorBlock: A tag groups editor block.
    /// - Returns: A TagGroupsEditor
    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }

    /// Begins an attribute editing session.
    /// - Returns: An AttributesEditor
    @objc
    public func editAttributes() -> AttributesEditor {
        return AttributesEditor { updates in
            guard !updates.isEmpty else {
                return
            }

            guard
                self.privacyManager.isEnabled([.contacts, .tagsAndAttributes])
            else {
                AirshipLogger.warn(
                    "Contacts or tags are disabled. Enable to apply attribute edits."
                )
                return
            }

            self.addOperation(
                .update(attributeUpdates: updates)
            )
        }
    }

    /// Begins an attribute editing session.
    /// - Parameter editorBlock: An attributes editor block.
    /// - Returns: An AttributesEditor
    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    /**
     * Associates an Email channel to the contact.
     * - Parameters:
     *   - address: The email address.
     *   - options: The email channel registration options.
     */
    public func registerEmail(
        _ address: String,
        options: EmailRegistrationOptions
    ) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn(
                "Contacts disabled. Enable to associate Email channel."
            )
            return
        }

        self.addOperation(.registerEmail(address: address, options: options))
    }

    /**
     * Associates a SMS channel to the contact.
     * - Parameters:
     *   - msisdn: The SMS msisdn.
     *   - options: The SMS channel registration options.
     */
    public func registerSMS(_ msisdn: String, options: SMSRegistrationOptions) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn(
                "Contacts disabled. Enable to associate SMS channel."
            )
            return
        }

        self.addOperation(.registerSMS(msisdn: msisdn, options: options))
    }

    /// Associates an open channel to the contact.
    /// - Parameter address: The open channel address.
    /// - Parameter options: The open channel registration options.
    public func registerOpen(
        _ address: String,
        options: OpenRegistrationOptions
    ) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn(
                "Contacts disabled. Enable to associate Open channel."
            )
            return
        }

        self.addOperation(.registerOpen(address: address, options: options))
    }

    /**
     * Associates a channel to the contact.
     * - Parameters:
     *   - channelID: The channel ID.
     *   - type: The channel type.
     */
    @objc
    public func associateChannel(_ channelID: String, type: ChannelType) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn(
                "Contacts disabled. Enable to associate channel."
            )
            return
        }


        self.addOperation(.associateChannel(channelID: channelID, channelType: type))
    }

    /// Begins a subscription list editing session
    /// - Returns: A Scoped subscription list editor
    @objc
    public func editSubscriptionLists() -> ScopedSubscriptionListEditor {
        return ScopedSubscriptionListEditor(date: self.date) { updates in
            guard !updates.isEmpty else {
                return
            }

            guard
                self.privacyManager.isEnabled([.contacts, .tagsAndAttributes])
            else {
                AirshipLogger.warn(
                    "Contacts or tags are disabled. Enable to apply subscription lists edits."
                )
                return
            }

            updates.forEach {
                switch $0.type {
                case .subscribe:
                    self.subscriptionListEditsSubject.send(
                        .subscribe($0.listId, $0.scope)
                    )
                case .unsubscribe:
                    self.subscriptionListEditsSubject.send(
                        .unsubscribe($0.listId, $0.scope)
                    )
                }
            }

            self.addOperation(.update(subscriptionListsUpdates: updates))
        }
    }

    /// Begins a subscription list editing session
    /// - Parameter editorBlock: A scoped subscription list editor block.
    /// - Returns: A ScopedSubscriptionListEditor
    @objc
    public func editSubscriptionLists(
        _ editorBlock: (ScopedSubscriptionListEditor) -> Void
    ) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }

    private func getStableContactID() async -> String {
        // Stableness is determined by a reset or identify operation.  Since
        // pending operations are added throught the serialQueue to ensure order, some might still
        // be in the queue. To avoid ignoring any of those, wait for current operations on the queue
        // to finish
        await self.serialQueue.waitForCurrentOperations()

        var subscription: AnyCancellable?
        let result: String = await withCheckedContinuation { continuation in
            subscription = self.contactIDUpdates
                .first { update in
                    update.isStable
                }
                .sink { update in
                    continuation.resume(returning: update.contactID)
                }
        }
        subscription?.cancel()
        return result
    }

    @objc(fetchSubscriptionListsWithCompletionHandler:)
    public func _fetchSubscriptionLists() async throws ->  [String: ChannelScopes] {
        let lists = try await self.fetchSubscriptionLists()
        return AudienceUtils.wrap(lists)
    }

    public func fetchSubscriptionLists() async throws -> [String: [ChannelScope]] {
        let contactID = await getStableContactID()
        var subscriptions = try await self.resolveSubscriptionLists(contactID)

        // Audience overrides will take any pending operations and updated operations. Since
        // pending operations are added throught the serialQueue to ensure order, some might still
        // be in the queue. To avoid ignoring any of those, wait for current operations on the queue
        // to finish
        await self.serialQueue.waitForCurrentOperations()
        let overrides = await self.audienceOverridesProvider.contactOverrides(contactID: contactID)

        subscriptions = AudienceUtils.applySubscriptionListsUpdates(
            subscriptions,
            updates: overrides.subscriptionLists
        )

        return subscriptions
    }

    private func resolveSubscriptionLists(
        _ contactID: String
    ) async throws -> [String:[ChannelScope]] {
        return try await self.fetchSubscriptinListQueue.run {
            if let cached = self.cachedSubscriptionLists.value,
                cached.0 == contactID {
                return cached.1
            }

            let response = try await self.subscriptionListAPIClient.fetchSubscriptionLists(
                contactID: contactID
            )

            guard response.isSuccess, let lists = response.result else {
                throw AirshipErrors.error("Failed to fetch subscription lists")
            }

            AirshipLogger.debug("Fetched lists finished with response: \(response)")
            self.cachedSubscriptionLists.set(
                value: (contactID, lists),
                expiresIn: AirshipContact.maxSubscriptionListCacheAge
            )
            return lists
        }
    }

    /**
     * :nodoc:
     */
    private func onComponentEnableChange() {
        self.serialQueue.enqueue {
            await self.contactManager.setEnabled(
                enabled: self.isComponentEnabled
            )
        }
    }

    @objc
    private func checkPrivacyManager() {
        self.serialQueue.enqueue {
            guard !self.privacyManager.isEnabled(.contacts) else {
                await self.contactManager.generateDefaultContactIDIfNotSet()
                return
            }

            await self.contactManager.addOperation(.reset)
        }
    }

    @objc
    private func didBecomeActive() {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        if (self.date.now.timeIntervalSince(self.lastResolveDate) >= AirshipContact.foregroundResolveInterval) {
            self.lastResolveDate = self.date.now
            self.addOperation(.resolve)
        }
    }

    @objc
    private func channelCreated(notification: NSNotification) {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        let existing =
            notification.userInfo?[AirshipChannel.channelExistingKey] as? Bool


        if existing == true && self.config.clearNamedUserOnAppRestore {
            self.addOperation(.reset)
        } else {
            self.addOperation(.resolve)
        }
    }

    private func addOperation(_ operation: ContactOperation) {
        self.serialQueue.enqueue {
            await self.contactManager.addOperation(operation)
        }
    }

    private func migrateNamedUser() async {
        defer {
            self.dataStore.removeObject(forKey: AirshipContact.legacyNamedUserKey)
            self.dataStore.removeObject(
                forKey: AirshipContact.legacyPendingTagGroupsKey
            )
            self.dataStore.removeObject(
                forKey: AirshipContact.legacyPendingAttributesKey
            )
        }

        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        guard
            let legacyNamedUserID = try? self.dataStore.string(
                forKey: AirshipContact.legacyNamedUserKey
            )?.normalizedNamedUserID
        else {
            await self.contactManager.generateDefaultContactIDIfNotSet()
            return
        }

        if await self.contactManager.currentContactIDInfo() == nil {
            // Need to call through to contact manager directly to ensure operation order
            await self.contactManager.addOperation(.identify(legacyNamedUserID))
        }

        if self.privacyManager.isEnabled(.tagsAndAttributes) {
            var pendingTagUpdates: [TagGroupUpdate]?
            var pendingAttributeUpdates: [AttributeUpdate]?

            if let pendingTagGroupsData = self.dataStore.data(
                forKey: AirshipContact.legacyPendingTagGroupsKey
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
                forKey: AirshipContact.legacyPendingAttributesKey
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

            if !(pendingTagUpdates?.isEmpty ?? true
                && pendingAttributeUpdates?.isEmpty ?? true)
            {
                // Need to call through to contact manager directly to ensure operation order
                await self.contactManager.addOperation(
                    .update(
                        tagUpdates: pendingTagUpdates,
                        attributeUpdates: pendingAttributeUpdates
                    )
                )
            }
        }
    }
}

extension String {
    var normalizedNamedUserID: String {
        get throws {
            let trimmedID = self.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard
                trimmedID.count > 0,
                trimmedID.count <= AirshipContact.maxNamedUserIDLength
            else {
                throw AirshipErrors.error("Invalid named user ID \(trimmedID). IDs must be between 1 and \(AirshipContact.maxNamedUserIDLength) characters.")
            }

            return trimmedID
        }
    }
}

extension AirshipContact : InternalAirshipContactProtocol {

    var authTokenProvider: AuthTokenProvider {
        return self.contactManager
    }

    var contactID: String? {
        get async {
            return await self.contactManager.currentContactIDInfo()?.contactID
        }
    }
}



