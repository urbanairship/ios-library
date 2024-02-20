/* Copyright Airship and Contributors */

import Combine
import Foundation

/// This singleton provides an interface to the channel functionality.
@objc(UAChannel)
public final class AirshipChannel: NSObject, AirshipChannelProtocol, @unchecked Sendable {

    private static let tagsDataStoreKey = "com.urbanairship.channel.tags"

    /**
     * Notification event when the channel is created.
     */
    @objc
    public static let channelCreatedEvent = NSNotification.Name(
        "com.urbanairship.channel.channel_created"
    )

    /**
     * Channel ID key for channelCreatedEvent and channelUpdatedEvent.
     */
    @objc
    public static let channelIdentifierKey = "channel_identifier"

    /**
     * Channel existing key for channelCreatedEvent.
     */
    @objc
    public static let channelExistingKey = "channel_existing"

    /**
     * Notification event when the channel is updated.
     */
    @objc
    public static let channelUpdatedEvent = NSNotification.Name(
        "com.urbanairship.channel.channel_updated"
    )


    /// NOTE: For internal use only. :nodoc:
    @objc
    public static let legacyTagsSettingsKey = "UAPushTags"

    private let dataStore: PreferenceDataStore
    private let config: RuntimeConfig
    private let privacyManager: AirshipPrivacyManager
    private let localeManager: AirshipLocaleManagerProtocol
    private let audienceManager: ChannelAudienceManagerProtocol
    private let channelRegistrar: ChannelRegistrarProtocol
    private let notificationCenter: AirshipNotificationCenter
    private let appStateTracker: AppStateTrackerProtocol
    private let tagsLock = AirshipLock()
    private let subscription: AirshipUnsafeSendableWrapper<AnyCancellable?> = AirshipUnsafeSendableWrapper(nil)

    #if canImport(ActivityKit)
    private let liveActivityRegistry: LiveActivityRegistry
    #endif

    private var shouldPerformChannelRegistrationOnForeground = false

    private var isChannelCreationEnabled: Bool


    /// The channel identifier.
    public var identifier: String? {
        return self.channelRegistrar.channelID
    }

    /// The channel tags.
    public var tags: [String] {
        get {
            guard self.privacyManager.isEnabled(.tagsAndAttributes) else {
                return []
            }

            var result: [String]?
            tagsLock.sync {
                result =
                    self.dataStore.array(forKey: AirshipChannel.tagsDataStoreKey)
                    as? [String]
            }
            return result ?? []
        }

        set {
            guard self.privacyManager.isEnabled(.tagsAndAttributes) else {
                AirshipLogger.warn(
                    "Unable to modify channel tags \(tags) when data collection is disabled."
                )
                return
            }

            tagsLock.sync {
                let normalized = AudienceUtils.normalizeTags(newValue)
                self.dataStore.setObject(
                    normalized,
                    forKey: AirshipChannel.tagsDataStoreKey
                )
            }

            self.updateRegistration()
        }
    }

    /// Allows setting tags from the device. Tags can be set from either the server or the device, but not both (without synchronizing the data),
    /// so use this flag to explicitly enable or disable the device-side flags.
    /// Set this to `false` to prevent the device from sending any tag information to the server when using server-side tagging. Defaults to `true`.
    public var isChannelTagRegistrationEnabled = true

    /// The shared Channel instance.
    /// - Returns The shared Channel instance.
    @objc
    public static var shared: AirshipChannel {
        return Airship.channel
    }

    @MainActor
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        privacyManager: AirshipPrivacyManager,
        localeManager: AirshipLocaleManagerProtocol,
        audienceManager: ChannelAudienceManagerProtocol,
        channelRegistrar: ChannelRegistrarProtocol,
        notificationCenter: AirshipNotificationCenter,
        appStateTracker: AppStateTrackerProtocol
    ) {

        self.dataStore = dataStore
        self.config = config
        self.privacyManager = privacyManager
        self.localeManager = localeManager
        self.audienceManager = audienceManager
        self.channelRegistrar = channelRegistrar
        self.notificationCenter = notificationCenter
        self.appStateTracker = appStateTracker

        #if canImport(ActivityKit)
        self.liveActivityRegistry = LiveActivityRegistry(
            dataStore: dataStore
        )
        #endif

        // Check config to see if user wants to delay channel creation
        // If channel ID exists or channel creation delay is disabled then channelCreationEnabled
        if self.channelRegistrar.channelID != nil
            || !config.isChannelCreationDelayEnabled
        {
            self.isChannelCreationEnabled = true
        } else {
            AirshipLogger.debug("Channel creation disabled.")
            self.isChannelCreationEnabled = false
        }

        super.init()

        self.migrateTags()


        self.subscription.value = self.channelRegistrar.updatesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] update in
                self?.processChannelUpdate(update)
            }

        self.channelRegistrar.addChannelRegistrationExtender(
            extender: self.extendPayload
        )

        self.audienceManager.channelID = self.channelRegistrar.channelID

        if let identifier = self.identifier {
            AirshipLogger.importantInfo("Channel ID \(identifier)")
        }

        self.observeNotificationCenterEvents()
        self.updateRegistration()


        #if canImport(ActivityKit)
        Task {
            for await update in self.liveActivityRegistry.updates {
                self.audienceManager.addLiveActivityUpdate(update)
            }
        }

        Task {
            for await updates in self.audienceManager.liveActivityUpdates {
                await self.liveActivityRegistry.updatesProcessed(updates: updates)
            }
        }
        #endif
    }

    @MainActor
    convenience init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        privacyManager: AirshipPrivacyManager,
        localeManager: AirshipLocaleManagerProtocol,
        audienceOverridesProvider: AudienceOverridesProvider
    ) {
        self.init(
            dataStore: dataStore,
            config: config,
            privacyManager: privacyManager,
            localeManager: localeManager,
            audienceManager: ChannelAudienceManager(
                dataStore: dataStore,
                config: config,
                privacyManager: privacyManager,
                audienceOverridesProvider: audienceOverridesProvider
            ),
            channelRegistrar: ChannelRegistrar(
                config: config,
                dataStore: dataStore
            ),
            notificationCenter: AirshipNotificationCenter.shared,
            appStateTracker: AppStateTracker.shared
        )
    }

    private func migrateTags() {
        guard self.dataStore.keyExists(AirshipChannel.legacyTagsSettingsKey) else {
            // Nothing to migrate
            return
        }

        // Normalize tags for older SDK versions, and migrate to UAChannel as necessary
        if let existingPushTags = self.dataStore.object(
            forKey: AirshipChannel.legacyTagsSettingsKey
        ) as? [String] {
            let existingChannelTags = self.tags
            if existingChannelTags.count > 0 {
                let combinedTagsSet = Set(existingPushTags)
                    .union(
                        Set(existingChannelTags)
                    )
                self.tags = Array(combinedTagsSet)
            } else {
                self.tags = existingPushTags
            }
        }

        self.dataStore.removeObject(forKey: AirshipChannel.legacyTagsSettingsKey)
    }

    private func observeNotificationCenterEvents() {
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTransitionToForeground),
            name: AppStateTracker.didTransitionToForeground
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(remoteConfigUpdated),
            name: RuntimeConfig.configUpdatedEvent
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(onEnableFeaturesChanged),
            name: AirshipPrivacyManager.changeEvent
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(localeUpdates),
            name: AirshipLocaleManager.localeUpdatedEvent
        )
    }

    @objc
    private func localeUpdates() {
        self.updateRegistration()
    }

    @objc
    private func remoteConfigUpdated() {
        guard self.isRegistrationAllowed else {
            return
        }

        self.updateRegistration(forcefully: true)
    }

    @objc
    private func onEnableFeaturesChanged() {
        if !self.privacyManager.isEnabled(.tagsAndAttributes) {
            self.dataStore.removeObject(forKey: AirshipChannel.tagsDataStoreKey)
        }

        self.updateRegistration()
    }

    @objc
    private func applicationDidTransitionToForeground() {
        if self.privacyManager.isAnyFeatureEnabled() {
            AirshipLogger.trace(
                "Application did become active. Updating registration."
            )
            self.updateRegistration()
        }
    }

    /// NOTE: For internal use only. :nodoc:
    public func addRegistrationExtender(
        _ extender: @escaping (ChannelRegistrationPayload) -> ChannelRegistrationPayload
    ) {
        self.channelRegistrar.addChannelRegistrationExtender(
            extender: extender
        )
    }

    /// Begins a tag editing session
    /// - Returns: A TagEditor
    @objc
    public func editTags() -> TagEditor {
        return TagEditor { tagApplicator in
            self.tagsLock.sync {
                self.tags = tagApplicator(self.tags)
            }
        }
    }

    /// Begins a tag editing session
    /// - Parameter editorBlock: A tag editor block.
    /// - Returns: A TagEditor
    @objc
    public func editTags(_ editorBlock: (TagEditor) -> Void) {
        let editor = editTags()
        editorBlock(editor)
        editor.apply()
    }

    /// Begins a tag group editing session
    /// - Returns: A TagGroupsEditor
    @objc
    public func editTagGroups() -> TagGroupsEditor {
        let allowDeviceTags = !self.isChannelTagRegistrationEnabled
        return self.audienceManager.editTagGroups(
            allowDeviceGroup: allowDeviceTags
        )
    }

    /// Begins a tag group editing session
    /// - Parameter editorBlock: A tag group editor block.
    /// - Returns: A TagGroupsEditor
    @objc
    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }

    /// Begins a subscription list editing session
    /// - Returns: A SubscriptionListEditor
    @objc
    public func editSubscriptionLists() -> SubscriptionListEditor {
        return self.audienceManager.editSubscriptionLists()
    }

    /// Begins a subscription list editing session
    /// - Parameter editorBlock: A subscription list editor block.
    /// - Returns: A SubscriptionListEditor
    @objc
    public func editSubscriptionLists(
        _ editorBlock: (SubscriptionListEditor) -> Void
    ) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }


    /// Fetches subscription lists.
    /// - Returns: Subscriptions lists.
    @objc
    public func fetchSubscriptionLists() async throws -> [String] {
        return try await self.audienceManager.fetchSubscriptionLists()
    }

    /// Publishes edits made to the subscription lists through the SDK
    public var subscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never>
    {
        audienceManager.subscriptionListEdits
    }

    /// Begins an attributes editing session
    /// - Returns: An AttributesEditor
    @objc
    public func editAttributes() -> AttributesEditor {
        return self.audienceManager.editAttributes()
    }

    /// Begins an attributes editing session
    /// - Parameter editorBlock An attributes editor block.
    /// - Returns: An AttributesEditor
    @objc
    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    /**
     * Adds a device tag.
     *  - Parameters:
     *      - tag: The tag.
     */
    @available(*, deprecated, message: "Use editTags instead.")
    @objc(addTag:)
    public func addTag(_ tag: String) {
        editTags { editor in
            editor.add(tag)
        }
    }

    /**
     * Adds a list of device tags.
     *  - Parameters:
     *      - tags: The tags.
     */
    @available(*, deprecated, message: "Use editTags instead.")
    @objc(addTags:)
    public func addTags(_ tags: [String]) {
        editTags { editor in
            editor.add(tags)
        }
    }

    /**
     * Removes a device tag.
     *  - Parameters:
     *      - tag: The tag.
     */
    @available(*, deprecated, message: "Use editTags instead.")
    @objc(removeTag:)
    public func removeTag(_ tag: String) {
        editTags { editor in
            editor.remove(tag)
        }
    }

    /**
     * Removes a list of device tags.
     *  - Parameters:
     *      - tags: The tag.
     */
    @available(*, deprecated, message: "Use editTags instead.")
    @objc(removeTags:)
    public func removeTags(_ tags: [String]) {
        editTags { editor in
            editor.remove(tags)
        }
    }

    /**
     * Adds a list of tags to a group.
     *  - Parameters:
     *      - tags: The tags.
     *      - group: The tag group.
     */
    @available(*, deprecated, message: "Use editTagGroups instead.")
    @objc(addTags:group:)
    public func addTags(_ tags: [String], group: String) {
        editTagGroups { editor in
            editor.add(tags, group: group)
        }
    }

    /**
     * Removes a list of tags from a group.
     *  - Parameters:
     *      - tags: The tags.
     *      - group: The tag group.
     */
    @available(*, deprecated, message: "Use editTagGroups instead.")
    @objc(removeTags:group:)
    public func removeTags(_ tags: [String], group: String) {
        editTagGroups { editor in
            editor.remove(tags, group: group)
        }
    }

    /**
     * Sets a list of tags to a group.
     *  - Parameters:
     *      - tags: The tags.
     *      - group: The tag group.
     */
    @available(*, deprecated, message: "Use editTagGroups instead.")
    @objc(setTags:group:)
    public func setTags(_ tags: [String], group: String) {
        editTagGroups { editor in
            editor.set(tags, group: group)
        }
    }

    /**
     * Applies attribute mutations.
     *  - Parameters:
     *      - mutations: The mutations.
     */
    @available(*, deprecated, message: "Use editAttributes instead.")
    @objc(applyAttributeMutations:)
    public func apply(_ mutations: AttributeMutations) {
        editAttributes { editor in
            mutations.applyMutations(editor: editor)
        }
    }

    /**
     * Enables channel creation if channelCreationDelayEnabled was set to `YES` in the config.
     */
    @objc(enableChannelCreation)
    public func enableChannelCreation() {
        if !self.isChannelCreationEnabled {
            self.isChannelCreationEnabled = true
            self.updateRegistration()
        }
    }

    public func updateRegistration() {
        updateRegistration(forcefully: false)
    }

    private var isRegistrationAllowed: Bool {
        guard self.isChannelCreationEnabled else {
            AirshipLogger.debug(
                "Channel creation is currently disabled, unable to update"
            )
            return false
        }

        guard
            self.identifier != nil || self.privacyManager.isAnyFeatureEnabled()
        else {
            AirshipLogger.trace(
                "Skipping channel create. All features are disabled."
            )
            return false
        }

        return true
    }

    /// - Note: For internal use only. :nodoc:
    public func updateRegistration(forcefully: Bool) {
        guard self.isRegistrationAllowed else {
            return
        }

        self.channelRegistrar.register(forcefully: forcefully)
    }
}

/// - Note: for internal use only.  :nodoc:
extension AirshipChannel: AirshipPushableComponent {

    #if !os(watchOS)
    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if self.identifier == nil {
            updateRegistration()
        }
        completionHandler(.noData)
    }
    #else
    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    ) {
        if self.identifier == nil {
            updateRegistration()
        }
        completionHandler(.noData)
    }
    #endif

    private func processChannelUpdate(_ update: ChannelRegistrationUpdate) {
        switch(update) {
        case .created(let channelID, let isExisting):
            AirshipLogger.importantInfo("Channel ID: \(channelID)")
            self.audienceManager.channelID = channelID
            self.notificationCenter.post(
                name: AirshipChannel.channelCreatedEvent,
                object: self,
                userInfo: [
                    AirshipChannel.channelIdentifierKey: channelID,
                    AirshipChannel.channelExistingKey: isExisting,
                ]
            )
        case .updated(let channelID):
            AirshipLogger.info("Channel updated.")
            self.notificationCenter.post(
                name: AirshipChannel.channelUpdatedEvent,
                object: self,
                userInfo: [AirshipChannel.channelIdentifierKey: channelID]
            )
        }
    }

    private func extendPayload(
        payload: ChannelRegistrationPayload
    ) async -> ChannelRegistrationPayload {
        var payload = payload

        if await self.appStateTracker.state == .active {
            payload.channel.isActive = true
        }

        if self.isChannelTagRegistrationEnabled {
            payload.channel.tags = self.tags
            payload.channel.setTags = true
        } else {
            payload.channel.setTags = false
        }

        if self.privacyManager.isEnabled(.analytics) {
            payload.channel.deviceModel = AirshipUtils.deviceModelName()
            payload.channel.carrier = AirshipUtils.carrierName()
            payload.channel.appVersion = AirshipUtils.bundleShortVersionString()
#if !os(watchOS)
            payload.channel.deviceOS = await UIDevice.current.systemVersion
#endif
        }

        if self.privacyManager.isAnyFeatureEnabled() {
            let currentLocale = self.localeManager.currentLocale
            payload.channel.language = currentLocale.getLanguageCode()
            payload.channel.country = currentLocale.getRegionCode()
            payload.channel.timeZone = TimeZone.current.identifier
            payload.channel.sdkVersion = AirshipVersion.version
        }

        return payload
    }
}

extension AirshipChannel: InternalAirshipChannelProtocol {
    public func addRegistrationExtender(
        _ extender: @escaping (ChannelRegistrationPayload) async -> ChannelRegistrationPayload
    ) {
        self.channelRegistrar.addChannelRegistrationExtender(
            extender: extender
        )
    }

    public func clearSubscriptionListsCache() {
        self.audienceManager.clearSubscriptionListCache()
    }
}

#if canImport(ActivityKit)
import ActivityKit
@available(iOS 16.1, *)
extension AirshipChannel {

    /// Gets an AsyncSequence of `LiveActivityRegistrationStatus` updates for a given live acitvity name.
    /// - Parameters:
    ///     - name: The live activity name
    /// - Returns A `LiveActivityRegistrationStatusUpdates`
    @available(iOS 16.1, *)
    public func liveActivityRegistrationStatusUpdates(
        name: String
    ) -> LiveActivityRegistrationStatusUpdates {

        self.liveActivityRegistry.registrationUpdates(name: name, id: nil)
    }

    /// Gets an AsyncSequence of `LiveActivityRegistrationStatus` updates for a given live acitvity ID.
    /// - Parameters:
    ///     - activity: The live activity
    /// - Returns A `LiveActivityRegistrationStatusUpdates`
    @available(iOS 16.1, *)
    public func liveActivityRegistrationStatusUpdates<T: ActivityAttributes>(
        activity: Activity<T>
    ) -> LiveActivityRegistrationStatusUpdates {
        self.liveActivityRegistry.registrationUpdates(name: nil, id: activity.id)
    }

    /// Tracks a live activity with Airship for the given name.
    /// Airship will monitor the push token and status and automatically
    /// add and remove it from the channel for the App. If an activity is already
    /// tracked with the given name it will be replaced with the new activity.
    ///
    /// The name will be used to send updates through Airship. It can be unique
    /// for the device or shared across many devices.
    ///
    /// - Parameters:
    ///     - activity: The live activity
    ///     - name: The name of the activity
    public func trackLiveActivity<T: ActivityAttributes>(
        _ activity: Activity<T>,
        name: String
    ) {
        let liveActivity = LiveActivity(activity: activity)

        Task {
            await liveActivityRegistry.addLiveActivity(liveActivity, name: name)
        }

    }

    /// Called to restore live activity tracking. This method needs to be called exactly once
    /// during `application(_:didFinishLaunchingWithOptions:)` right
    /// after takeOff. Any activities not restored will stop being tracked by Airship.
    /// - Parameters:
    ///     - callback: Callback with the restorer.
    public func restoreLiveActivityTracking(
        callback: @escaping @Sendable (LiveActivityRestorer) async -> Void
    ) {
        let restorer = AirshipLiveActivityRestorer(
            registry: self.liveActivityRegistry
        )
        Task {
            await callback(restorer)
            await self.liveActivityRegistry.clearUntracked()
        }
    }
}

#endif

extension AirshipChannel: AirshipComponent {}
