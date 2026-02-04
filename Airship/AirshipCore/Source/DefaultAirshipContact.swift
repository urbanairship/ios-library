/* Copyright Airship and Contributors */

@preconcurrency
public import Combine
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Airship contact. A contact is distinct from a channel and  represents a "user"
/// within Airship. Contacts may be named and have channels associated with it.
public final class DefaultAirshipContact: AirshipContact, @unchecked Sendable {
    static let refreshContactPushPayloadKey = "com.urbanairship.contact.update"

    public var contactChannelUpdates: AsyncStream<ContactChannelsResult> {
        get {
            return self.contactChannelsProvider.contactChannels(
                stableContactIDUpdates: self.stableContactIDUpdates
            )
        }
    }

    public var contactChannelPublisher: AnyPublisher<ContactChannelsResult, Never> {
        get {
            let updates = self.contactChannelUpdates
            let subject = CurrentValueSubject<ContactChannelsResult?, Never>(nil)

            Task { @Sendable [weak subject] in
                for await update in updates {
                    subject?.send(update)
                }
            }

            return subject.compactMap { $0 }.eraseToAnyPublisher()
        }
    }

    private var stableContactIDUpdates: AsyncStream<String> {
        AsyncStream { [contactIDUpdates] continuation in
            let cancellable: AnyCancellable = contactIDUpdates
                .filter { $0.isStable }
                .map { $0.contactID }
                .removeDuplicates()
                .sink { value in
                    continuation.yield(value)
                }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    private static let resolveDateKey = "Contact.resolveDate"
    static let legacyPendingTagGroupsKey = "com.urbanairship.tag_groups.pending_channel_tag_groups_mutations"
    static let legacyPendingAttributesKey = "com.urbanairship.named_user_attributes.registrar_persistent_queue_key"
    static let legacyNamedUserKey = "UANamedUserID"


    // Interval for how often we emit a resolve operation on foreground
    static let defaultForegroundResolveInterval: TimeInterval = 3600.0 // 1 hour

    // Max age of a contact ID update that we consider verified for CRA
    static let defaultVerifiedContactIDAge: TimeInterval = 600.0 // 10 mins

    // Subscription list cache age
    private static let maxSubscriptionListCacheAge: TimeInterval = 600.0 // 10 mins

    public static let maxNamedUserIDLength = 128

    private let dataStore: PreferenceDataStore
    private let config: RuntimeConfig
    private let privacyManager: any AirshipPrivacyManager
    private let contactChannelsProvider: any ContactChannelsProviderProtocol
    private let subscriptionListProvider: any SubscriptionListProviderProtocol
    private let date: any AirshipDateProtocol
    private let audienceOverridesProvider: any AudienceOverridesProvider
    private let contactManager: any ContactManagerProtocol
    private let cachedSubscriptionLists: CachedValue<(String, [String: [ChannelScope]])>
    private var setupTask: Task<Void, Never>? = nil
    private var subscriptions: Set<AnyCancellable> = Set()
    private let serialQueue: AirshipAsyncSerialQueue

    private var lastResolveDate: Date {
         get {
             let date = self.dataStore.object(forKey: DefaultAirshipContact.resolveDateKey) as? Date
             return date ?? Date.distantPast
         }
         set {
             self.dataStore.setObject(newValue, forKey: DefaultAirshipContact.resolveDateKey)
         }
     }

    private let subscriptionListEditsSubject: PassthroughSubject<ScopedSubscriptionListEdit, Never> = PassthroughSubject<ScopedSubscriptionListEdit, Never>()

    /// Publishes all edits made to the subscription lists through the  SDK
    public var subscriptionListEdits: AnyPublisher<ScopedSubscriptionListEdit, Never> {
        subscriptionListEditsSubject.eraseToAnyPublisher()
    }

    private let conflictEventSubject: PassthroughSubject<ContactConflictEvent, Never> = PassthroughSubject<ContactConflictEvent, Never>()
    public var conflictEventPublisher: AnyPublisher<ContactConflictEvent, Never> {
        conflictEventSubject.eraseToAnyPublisher()
    }

    private let contactIDUpdatesSubject: CurrentValueSubject<ContactIDInfo?, Never> = CurrentValueSubject<ContactIDInfo?, Never>(nil)
    var contactIDUpdates: AnyPublisher<ContactIDInfo, Never> {
        return self.contactIDUpdatesSubject
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private let namedUserUpdateSubject: CurrentValueSubject<NamedUserIDEvent?, Never> = CurrentValueSubject<NamedUserIDEvent?, Never>(nil)
    public var namedUserIDPublisher: AnyPublisher<String?, Never> {
        namedUserUpdateSubject
            .compactMap { $0 }
            .map { $0.identifier }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var namedUserID: String? {
        get async {
            return await self.contactManager.currentNamedUserID()
        }
    }

    private var foregroundInterval: TimeInterval {
        let interval = self.config.remoteConfig.contactConfig?.foregroundInterval
        return interval ?? Self.defaultForegroundResolveInterval
    }

    private var verifiedContactIDMaxAge: TimeInterval {
        let age = self.config.remoteConfig.contactConfig?.channelRegistrationMaxResolveAge
        return age ?? Self.defaultVerifiedContactIDAge
    }

    /**
     * Internal only
     * :nodoc:
     */
    @MainActor
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        channel: any InternalAirshipChannel,
        privacyManager: any AirshipPrivacyManager,
        contactChannelsProvider: any ContactChannelsProviderProtocol,
        subscriptionListProvider: any SubscriptionListProviderProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        audienceOverridesProvider: any AudienceOverridesProvider,
        contactManager: any ContactManagerProtocol,
        serialQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue(priority: .high)
    ) {

        self.dataStore = dataStore
        self.config = config
        self.privacyManager = privacyManager
        self.contactChannelsProvider = contactChannelsProvider
        self.audienceOverridesProvider = audienceOverridesProvider
        self.date = date
        self.contactManager = contactManager
        self.serialQueue = serialQueue
        self.subscriptionListProvider = subscriptionListProvider
        self.cachedSubscriptionLists = CachedValue(date: date)

        self.setupTask = Task {
            await self.migrateNamedUser()

            await audienceOverridesProvider.setPendingContactOverridesProvider { contactID in

                // Audience overrides will take any pending operations and updated operations. Since
                // pending operations are added through the serialQueue to ensure order, some might still
                // be in the queue. To avoid ignoring any of those, wait for current operations on the queue
                // to finish
                await self.serialQueue.waitForCurrentOperations()


                return await contactManager.pendingAudienceOverrides(contactID: contactID)
            }

            await audienceOverridesProvider.setStableContactIDProvider {
                return await self.getStableContactID()
            }

            await contactManager.onAudienceUpdated { update in
                await audienceOverridesProvider.contactUpdated(
                    contactID: update.contactID,
                    tags: update.tags,
                    attributes: update.attributes,
                    subscriptionLists: update.subscriptionLists,
                    channels: update.contactChannels
                )
            }

            await self.contactManager.setEnabled(enabled: true)
        }

        self.serialQueue.enqueue {
            await self.setupTask?.value
        }

        // Whenever the contact ID changes, ignoring stableness, notify the channel
        self.contactIDUpdatesSubject
            .receive(on: RunLoop.main)
            .map { $0?.contactID }
            .removeDuplicates()
            .sink { _ in
                channel.clearSubscriptionListsCache()
                channel.updateRegistration()
            }.store(in: &self.subscriptions)

        // For obj-c compatibility
        self.conflictEventPublisher
            .receive(on: RunLoop.main)
            .sink { event in
                notificationCenter.post(
                    name: AirshipNotifications.ContactConflict.name,
                    object: nil,
                    userInfo: [
                        AirshipNotifications.ContactConflict.eventKey: event
                    ]
                )
            }.store(in: &self.subscriptions)


        channel.addRegistrationExtender { [weak self] payload in
            await self?.setupTask?.value
            if await self?.contactID == nil {
                await self?.contactManager.generateDefaultContactIDIfNotSet()
            }

            if (channel.identifier != nil) {
                payload.channel.contactID = await self?.getStableVerifiedContactID()
            } else {
                payload.channel.contactID = await self?.contactID
            }
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
            name: AirshipNotifications.ChannelCreated.name,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(checkPrivacyManager),
            name: AirshipNotifications.PrivacyManagerUpdated.name,
            object: nil
        )

        self.checkPrivacyManager()
    }


    public func airshipReady() {
        Task { @MainActor [weak self] in
            if let self = self {
                let contactInfo = await self.contactManager.currentContactIDInfo()
                self.contactIDUpdatesSubject.send(contactInfo)

                let namedUserID = await self.contactManager.currentNamedUserID()
                self.namedUserUpdateSubject.send(NamedUserIDEvent(identifier: namedUserID))
            }

            guard let updates = await self?.contactManager.contactUpdates else {
                return
            }

            for await update in updates {
                guard let self else {
                    return
                }

                switch (update) {
                case .conflict(let event):
                    self.conflictEventSubject.send(event)
                case .contactIDUpdate(let update):
                    self.contactIDUpdatesSubject.send(update)
                case .namedUserUpdate(let namedUserID):
                    self.namedUserUpdateSubject.send(NamedUserIDEvent(identifier: namedUserID))
                }
            }
        }
    }

    /**
     * Internal only
     * :nodoc:
     */
    @MainActor
    convenience init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        channel: any InternalAirshipChannel,
        privacyManager: any AirshipPrivacyManager,
        audienceOverridesProvider: any AudienceOverridesProvider,
        localeManager: any AirshipLocaleManager
    ) {
        self.init(
            dataStore: dataStore,
            config: config,
            channel: channel,
            privacyManager: privacyManager,
            contactChannelsProvider: ContactChannelsProvider(
                audienceOverrides: audienceOverridesProvider,
                apiClient: ContactChannelsAPIClient(config: config),
                privacyManager: privacyManager
            ),
            subscriptionListProvider: SubscriptionListProvider(
                audienceOverrides: audienceOverridesProvider,
                apiClient: ContactSubscriptionListAPIClient(config: config),
                privacyManager: privacyManager),
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
    @inline(never)
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
    @inline(never)
    public func reset() {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.trace("Contacts are disabled, ignoring reset request")
            return
        }
        self.addOperation(.reset)
    }

    /// Can be called after the app performs a remote named user association for the channel instead
    /// of using `identify` or `reset` through the SDK. When called, the SDK will refresh the contact
    /// data. Applications should only call this method when the user login has changed.
    @inline(never)
    public func notifyRemoteLogin() {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.trace("Contacts are disabled, ignoring notifyRemoteLogin request")
            return
        }
        self.addOperation(.verify(self.date.now, required: true))
    }

    /// Begins a tag groups editing session.
    /// - Returns: A TagGroupsEditor
    public func editTagGroups() -> TagGroupsEditor {
        return TagGroupsEditor { updates in
            guard !updates.isEmpty else {
                AirshipLogger.trace("Empty tag group updates, ignoring")
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

            self.notifyOverridesChanged()
        }
    }

    private func notifyOverridesChanged() {
        Task { [weak audienceOverridesProvider] in
            await audienceOverridesProvider?.notifyPendingChanged()
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
    public func editAttributes() -> AttributesEditor {
        return AttributesEditor { updates in
            guard !updates.isEmpty else {
                AirshipLogger.trace("Empty attribute updates, ignoring")
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
            self.notifyOverridesChanged()
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
        self.notifyOverridesChanged()
    }

    /**
     * Associates a SMS channel to the contact.
     * - Parameters:
     *   - msisdn: The SMS Mobile Station International Subscriber Directory Number..
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
        self.notifyOverridesChanged()
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
     *   - options: The SMS/email channel options
     */
    public func associateChannel(
        _ channelID: String,
        type: ChannelType
    ) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn(
                "Contacts disabled. Enable to associate channel."
            )
            return
        }

        self.addOperation(
            .associateChannel(
                channelID: channelID,
                channelType: type
            )
        )
    }

    /**
     * Resends an opt-in message
     * - Parameters:
     *   - channelID: The channel ID.
     *   - type: The channel type.
     *   - options: The SMS/email channel options
     */
    public func resend(_ channel: ContactChannel) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn(
                "Contacts disabled. Enable to re-send double opt in to channel."
            )
            return
        }

        self.addOperation(.resend(channel: channel))
    }

    /**
     * Disassociates a channel
     * - Parameters:
     *   - channel: The channel to disassociate.
     */
    public func disassociateChannel(_ channel: ContactChannel) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn(
                "Contacts disabled. Enable to disassociate channel."
            )
            return
        }

        self.addOperation(.disassociateChannel(channel: channel))

        Task { [weak audienceOverridesProvider] in
            await audienceOverridesProvider?.notifyPendingChanged()
        }
    }

    /// Begins a subscription list editing session
    /// - Returns: A Scoped subscription list editor
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

            Task { @MainActor in
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
            }

            self.addOperation(.update(subscriptionListsUpdates: updates))
        }
    }

    /// Begins a subscription list editing session
    /// - Parameter editorBlock: A scoped subscription list editor block.
    /// - Returns: A ScopedSubscriptionListEditor
    public func editSubscriptionLists(
        _ editorBlock: (ScopedSubscriptionListEditor) -> Void
    ) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }


    private func waitForContactIDInfo(filter: @Sendable @escaping (ContactIDInfo) -> Bool) async -> ContactIDInfo {
        // Stableness is determined by a reset or identify operation.  Since
        // pending operations are added through the serialQueue to ensure order, some might still
        // be in the queue. To avoid ignoring any of those, wait for current operations on the queue
        // to finish
        await self.serialQueue.waitForCurrentOperations()

        var subscription: AnyCancellable?
        let result: ContactIDInfo = await withCheckedContinuation { continuation in
            subscription = self.contactIDUpdates
                .first { update in
                    filter(update)
                }
                .sink { update in
                    continuation.resume(returning: update)
                }
        }
        subscription?.cancel()
        return result
    }

    public func getStableContactID() async -> String {
        return await waitForContactIDInfo { update in
            update.isStable
        }.contactID
    }

    public func getStableContactInfo() async -> StableContactInfo {
        let info = await waitForContactIDInfo(filter: { $0.isStable })
        return StableContactInfo(
            contactID: info.contactID,
            namedUserID: info.namedUserID
        )
    }

    private func getStableVerifiedContactID() async -> String {
        let now = self.date.now

        let stableIDInfo = await waitForContactIDInfo { update in
            update.isStable
        }

        let secondsSinceLastResolve = now.timeIntervalSince(stableIDInfo.resolveDate)
        guard secondsSinceLastResolve >= self.verifiedContactIDMaxAge else {
            return stableIDInfo.contactID
        }

        addOperation(.verify(now))
        return await waitForContactIDInfo { update in
            update.isStable && update.resolveDate >= now
        }.contactID
    }

    public func fetchSubscriptionLists() async throws -> [String: [ChannelScope]] {
        let contactID = await getStableContactID()
        return try await subscriptionListProvider.fetch(contactID: contactID)
    }

    @objc
    private func checkPrivacyManager() {
        self.serialQueue.enqueue {
            if self.privacyManager.isAnyFeatureEnabled() {
                await self.contactManager.generateDefaultContactIDIfNotSet()
            }

            guard self.privacyManager.isEnabled(.contacts) else {
                await self.contactManager.resetIfNeeded()
                return
            }
        }
    }

    @objc
    private func didBecomeActive() {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        let lastActive = self.date.now.timeIntervalSince(self.lastResolveDate)

        if (lastActive >= self.foregroundInterval) {
            self.lastResolveDate = self.date.now
            self.addOperation(.resolve)
        }

        self.contactChannelsProvider.refreshAsync()
    }

    @objc
    private func channelCreated(notification: NSNotification) {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        let existing = notification.userInfo?[AirshipNotifications.ChannelCreated.isExistingChannelKey] as? Bool

        if existing == true && self.config.airshipConfig.clearNamedUserOnAppRestore {
            self.addOperation(.reset)
        } else {
            self.addOperation(.resolve)
        }
    }

    private func addOperation(_ operation: ContactOperation) {
        self.serialQueue.enqueue {
            AirshipLogger.trace("Adding contact operation \(operation.type)")
            await self.contactManager.addOperation(operation)
        }
    }

    private func migrateNamedUser() async {
        defer {
            self.dataStore.removeObject(forKey: DefaultAirshipContact.legacyNamedUserKey)
            self.dataStore.removeObject(
                forKey: DefaultAirshipContact.legacyPendingTagGroupsKey
            )
            self.dataStore.removeObject(
                forKey: DefaultAirshipContact.legacyPendingAttributesKey
            )
        }

        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        guard
            let legacyNamedUserID = try? self.dataStore.string(
                forKey: DefaultAirshipContact.legacyNamedUserKey
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
                forKey: DefaultAirshipContact.legacyPendingTagGroupsKey
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
                forKey: DefaultAirshipContact.legacyPendingAttributesKey
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
                trimmedID.count <= DefaultAirshipContact.maxNamedUserIDLength
            else {
                throw AirshipErrors.error("Invalid named user ID \(trimmedID). IDs must be between 1 and \(DefaultAirshipContact.maxNamedUserIDLength) characters.")
            }

            return trimmedID
        }
    }
}

extension DefaultAirshipContact : InternalAirshipContact {
    var contactIDInfo: ContactIDInfo? {
        get async {
            return await self.contactManager.currentContactIDInfo()
        }
    }


    var authTokenProvider: any AuthTokenProvider {
        return self.contactManager
    }

    var contactID: String? {
        get async {
            return await self.contactManager.currentContactIDInfo()?.contactID
        }
    }
}

extension DefaultAirshipContact: AirshipPushableComponent {
    public func receivedRemoteNotification(_ notification: AirshipJSON) async -> UABackgroundFetchResult {
        guard
            let userInfo = notification.unwrapAsUserInfo(),
            userInfo[Self.refreshContactPushPayloadKey] != nil else {
            return .noData
        }

        self.contactChannelsProvider.refreshAsync()
        return .newData
    }

#if !os(tvOS)
    public func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        // no-op
    }
#endif

}



extension DefaultAirshipContact: AirshipComponent {}


public extension AirshipNotifications {

    /// NSNotification info when a conflict event is emitted.
    final class ContactConflict {

        /// NSNotification name.
        public static let name = NSNotification.Name(
            "com.urbanairship.contact_conflict"
        )

        /// NSNotification userInfo key to get the `ContactConflictEvent`.
        public static let eventKey = "event"
    }
}

fileprivate struct NamedUserIDEvent {
    let identifier: String?
}
