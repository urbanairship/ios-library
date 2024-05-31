/* Copyright Airship and Contributors */

@preconcurrency
import Combine
import Foundation


/// Airship contact. A contact is distinct from a channel and  represents a "user"
/// within Airship. Contacts may be named and have channels associated with it.
@objc(UAContact)
public final class AirshipContact: NSObject, AirshipContactProtocol, @unchecked Sendable {
    public var contactChannelUpdates: AsyncStream<[ContactChannel]> {
        get async throws {
            guard self.privacyManager.isEnabled(.contacts) else {
                throw AirshipErrors.error(
                    "Contacts disabled. Enable to fetch channels list."
                )
            }

            let contactID = await getStableContactID()
            return try await self.contactChannelsProvider.contactUpdates(
                contactID: contactID
            )
        }
    }

    public var contactChannelPublisher: AnyPublisher<[ContactChannel], Never> {
        get async throws {
            let updates = try await self.contactChannelUpdates
            let subject = CurrentValueSubject<[ContactChannel]?, Never>(nil)

            Task { [weak subject] in
                for await update in updates {
                    subject?.send(update)
                }
            }

            return subject.compactMap { $0 }.eraseToAnyPublisher()
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
    private let privacyManager: AirshipPrivacyManager
    private let subscriptionListAPIClient: ContactSubscriptionListAPIClientProtocol
    private let contactChannelsProvider: ContactChannelsProviderProtocol
    private let date: AirshipDateProtocol
    private let audienceOverridesProvider: AudienceOverridesProvider
    private let contactManager: ContactManagerProtocol
    private var smsValidator: SMSValidatorProtocol
    private let cachedSubscriptionLists: CachedValue<(String, [String: [ChannelScope]])>
    private var setupTask: Task<Void, Never>? = nil
    private var subscriptions: Set<AnyCancellable> = Set()
    private let fetchSubscriptionListQueue: AirshipSerialQueue = AirshipSerialQueue()
    private let serialQueue: AirshipAsyncSerialQueue

    /// Publishes all edits made to the subscription lists through the  SDK
    public var smsValidatorDelegate: SMSValidatorDelegate? {
        set {
            self.smsValidator.delegate = newValue
        }

        get {
            self.smsValidator.delegate
        }
    }

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
    
    private let conflictEventSubject = PassthroughSubject<ContactConflictEvent, Never>()
    public var conflictEventPublisher: AnyPublisher<ContactConflictEvent, Never> {
        conflictEventSubject.eraseToAnyPublisher()
    }

    private let contactIDUpdatesSubject = CurrentValueSubject<ContactIDInfo?, Never>(nil)
    var contactIDUpdates: AnyPublisher<ContactIDInfo, Never> {
        return self.contactIDUpdatesSubject
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private let namedUserUpdateSubject = CurrentValueSubject<NamedUserIDEvent?, Never>(nil)
    public var namedUserIDPublisher: AnyPublisher<String?, Never> {
        namedUserUpdateSubject
            .compactMap { $0 }
            .map { $0.identifier }
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
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        channel: InternalAirshipChannelProtocol,
        privacyManager: AirshipPrivacyManager,
        subscriptionListAPIClient: ContactSubscriptionListAPIClientProtocol,
        contactChannelsProvider: ContactChannelsProviderProtocol,
        date: AirshipDateProtocol = AirshipDate.shared,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        audienceOverridesProvider: AudienceOverridesProvider,
        contactManager: ContactManagerProtocol,
        smsValidator: SMSValidatorProtocol,
        serialQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue(priority: .high)
    ) {

        self.dataStore = dataStore
        self.config = config
        self.privacyManager = privacyManager
        self.subscriptionListAPIClient = subscriptionListAPIClient
        self.contactChannelsProvider = contactChannelsProvider
        self.audienceOverridesProvider = audienceOverridesProvider
        self.date = date
        self.contactManager = contactManager
        self.smsValidator = smsValidator
        self.serialQueue = serialQueue

        self.cachedSubscriptionLists = CachedValue(date: date)

        super.init()
        
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
            var payload = payload

            if (channel.identifier != nil) {
                payload.channel.contactID = await self?.getStableVerifiedContactID()
            } else {
                payload.channel.contactID = await self?.contactID
            }

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
        Task { [weak self] in
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
            contactChannelsProvider: ContactChannelsProvider(
                audienceOverrides: audienceOverridesProvider,
                apiClient: ContactChannelsAPIClient(config: config)
            ),
            audienceOverridesProvider: audienceOverridesProvider,
            contactManager: ContactManager(
                dataStore: dataStore,
                channel: channel,
                localeManager: localeManager,
                apiClient: ContactAPIClient(config: config)
            ), 
            smsValidator: SMSValidator(apiClient: SMSValidatorAPIClient(config: config))
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
            AirshipLogger.trace("Contacts are disabled, ignoring reset request")
            return
        }
        self.addOperation(.reset)
    }

    /// Can be called after the app performs a remote named user association for the channel instead
    /// of using `identify` or `reset` through the SDK. When called, the SDK will refresh the contact
    /// data. Applications should only call this method when the user login has changed.
    @objc
    public func notifyRemoteLogin() {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.trace("Contacts are disabled, ignoring notifyRemoteLogin request")
            return
        }
        self.addOperation(.verify(self.date.now, required: true))
    }

    /// Begins a tag groups editing session.
    /// - Returns: A TagGroupsEditor
    @objc
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
    @objc
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

    /**
     * Validates MSISDN
     * - Parameters:
     *   - msisdn: The mobile phone number to validate.
     *   - sender: The identifier given to the sender of the SMS message.
     *   - Returns: Async boolean indicating validity of msisdn
     */
    public func validateSMS(
        _ msisdn: String,
        sender: String
    ) async throws -> Bool {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn(
                "Contacts disabled. Enable to validate SMS."
            )
            throw AirshipErrors.error(
                "Validation of SMS requires contacts to be enabled."
            )
        }

        return try await self.smsValidator.validateSMS(msisdn:msisdn, sender: sender)
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
            namedUserID: info.namedUserID)
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

    @objc(fetchSubscriptionListsWithCompletionHandler:)
    public func _fetchSubscriptionLists() async throws ->  [String: ChannelScopes] {
        let lists = try await self.fetchSubscriptionLists()
        return AudienceUtils.wrap(lists)
    }

    public func fetchSubscriptionLists() async throws -> [String: [ChannelScope]] {
        let contactID = await getStableContactID()
        var subscriptions = try await self.resolveSubscriptionLists(contactID)

        let overrides = await self.audienceOverridesProvider.contactOverrides(contactID: contactID)

        subscriptions = AudienceUtils.applySubscriptionListsUpdates(
            subscriptions,
            updates: overrides.subscriptionLists
        )

        return subscriptions
    }

    private func resolveSubscriptionLists(
        _ contactID: String
    ) async throws -> [String: [ChannelScope]] {

        return try await self.fetchSubscriptionListQueue.run {
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
                expiresIn: Self.maxSubscriptionListCacheAge
            )
            return lists
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

        let lastActive = self.date.now.timeIntervalSince(self.lastResolveDate)

        if (lastActive >= self.foregroundInterval) {
            self.lastResolveDate = self.date.now
            self.addOperation(.resolve)
        }
    }

    @objc
    private func channelCreated(notification: NSNotification) {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        let existing = notification.userInfo?[AirshipNotifications.ChannelCreated.isExistingChannelKey] as? Bool

        if existing == true && self.config.clearNamedUserOnAppRestore {
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
    var contactIDInfo: ContactIDInfo? {
        get async {
            return await self.contactManager.currentContactIDInfo()
        }
    }


    var authTokenProvider: AuthTokenProvider {
        return self.contactManager
    }

    var contactID: String? {
        get async {
            return await self.contactManager.currentContactIDInfo()?.contactID
        }
    }
}



extension AirshipContact: AirshipComponent {}


public extension AirshipNotifications {

    /// NSNotification info when a conflict event is emitted.
    @objc(UAirshipNotificationContactConflict)
    final class ContactConflict: NSObject {

        /// NSNotification name.
        @objc
        public static let name = NSNotification.Name(
            "com.urbanairship.contact_conflict"
        )

        /// NSNotification userInfo key to get the `ContactConflictEvent`.
        @objc
        public static let eventKey = "event"
    }
}

fileprivate struct NamedUserIDEvent {
    let identifier: String?
}
