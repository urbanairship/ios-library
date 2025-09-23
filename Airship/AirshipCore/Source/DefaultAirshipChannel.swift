/* Copyright Airship and Contributors */

@preconcurrency
import Combine
import Foundation

#if canImport(UIKit)
import UIKit
#endif


/// This singleton provides an interface to the channel functionality.
final class DefaultAirshipChannel: AirshipChannel, Sendable {
    private static let tagsDataStoreKey = "com.urbanairship.channel.tags"
    private static let legacyTagsSettingsKey = "UAPushTags"

    private let dataStore: PreferenceDataStore
    private let config: RuntimeConfig
    private let privacyManager: any AirshipPrivacyManager
    private let permissionsManager: any AirshipPermissionsManager
    private let localeManager: any AirshipLocaleManager
    private let audienceManager: any ChannelAudienceManagerProtocol
    private let channelRegistrar: any ChannelRegistrarProtocol
    private let notificationCenter: AirshipNotificationCenter
    private let appStateTracker: any AppStateTrackerProtocol
    private let tagsLock = AirshipLock()
    private let subscription: AirshipUnsafeSendableWrapper<AnyCancellable?> = AirshipUnsafeSendableWrapper(nil)

    private let liveActivityQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()

    @MainActor
    private var extenders: [@Sendable (inout ChannelRegistrationPayload) async -> Void] = []

    #if canImport(ActivityKit)
    private let liveActivityRegistry: LiveActivityRegistry
    #endif

    private let isChannelCreationEnabled: AirshipAtomicValue<Bool>

    public var identifier: String? {
        return self.channelRegistrar.channelID
    }

    public var identifierUpdates: AsyncStream<String> {
        return AsyncStream<String> { [weak self] continuation in
            let task = Task { [weak self] in
                guard let stream = await self?.channelRegistrar.registrationUpdates.makeStream() else {
                    return
                }

                var current = self?.channelRegistrar.channelID
                if let current {
                    continuation.yield(current)
                }

                for await update in stream {
                    let channelID =  switch update {
                    case .created(let channelID, _): channelID
                    case .updated(channelID: let channelID): channelID
                    }
                    if current != channelID {
                        current = channelID
                        continuation.yield(channelID)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
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
                    self.dataStore.array(forKey: DefaultAirshipChannel.tagsDataStoreKey)
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
                    forKey: DefaultAirshipChannel.tagsDataStoreKey
                )
            }

            self.updateRegistration()
        }
    }

    private let isChannelTagRegistrationEnabledContainer = AirshipAtomicValue(true)
    public var isChannelTagRegistrationEnabled: Bool {
        get { return isChannelTagRegistrationEnabledContainer.value }
        set { isChannelTagRegistrationEnabledContainer.value = newValue }
    }

    @MainActor
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        privacyManager: any AirshipPrivacyManager,
        permissionsManager: any AirshipPermissionsManager,
        localeManager: any AirshipLocaleManager,
        audienceManager: any ChannelAudienceManagerProtocol,
        channelRegistrar: any ChannelRegistrarProtocol,
        notificationCenter: AirshipNotificationCenter,
        appStateTracker: any AppStateTrackerProtocol
    ) {

        self.dataStore = dataStore
        self.config = config
        self.privacyManager = privacyManager
        self.permissionsManager = permissionsManager
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
            || !config.airshipConfig.isChannelCreationDelayEnabled
        {
            self.isChannelCreationEnabled = .init(true)
        } else {
            AirshipLogger.debug("Channel creation disabled.")
            self.isChannelCreationEnabled = .init(false)
        }

        self.migrateTags()

        Task { @MainActor [weak self, weak channelRegistrar] in
            guard let stream = await channelRegistrar?.registrationUpdates.makeStream() else {
                return
            }

            for await update in stream {
                self?.processChannelUpdate(update)
            }
        }

        self.channelRegistrar.payloadCreateBlock = { [weak self] in
            return await self?.makePayload()
        }

        self.audienceManager.channelID = self.channelRegistrar.channelID
        self.audienceManager.enabled = true
        
        if let identifier = self.identifier {
            AirshipLogger.importantInfo("Channel ID \(identifier)")
        }

        self.observeNotificationCenterEvents()
        self.updateRegistration()



        #if canImport(ActivityKit)
        Task {
            for await update in self.liveActivityRegistry.updates {
                guard privacyManager.isEnabled(.push) || update.action == .remove else {
                    AirshipLogger.error("Unable tot track set operation, push is disabled \(update)")
                    return
                }
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
        privacyManager: any AirshipPrivacyManager,
        permissionsManager: any AirshipPermissionsManager,
        localeManager: any AirshipLocaleManager,
        audienceOverridesProvider: any AudienceOverridesProvider
    ) {
        self.init(
            dataStore: dataStore,
            config: config,
            privacyManager: privacyManager,
            permissionsManager: permissionsManager,
            localeManager: localeManager,
            audienceManager: ChannelAudienceManager(
                dataStore: dataStore,
                config: config,
                privacyManager: privacyManager,
                audienceOverridesProvider: audienceOverridesProvider
            ),
            channelRegistrar: ChannelRegistrar(
                config: config,
                dataStore: dataStore,
                privacyManager: privacyManager
            ),
            notificationCenter: AirshipNotificationCenter.shared,
            appStateTracker: AppStateTracker.shared
        )
    }

    private func migrateTags() {
        guard self.dataStore.keyExists(DefaultAirshipChannel.legacyTagsSettingsKey) else {
            // Nothing to migrate
            return
        }

        // Normalize tags for older SDK versions, and migrate to UAChannel as necessary
        if let existingPushTags = self.dataStore.object(
            forKey: DefaultAirshipChannel.legacyTagsSettingsKey
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

        self.dataStore.removeObject(forKey: DefaultAirshipChannel.legacyTagsSettingsKey)
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
            name: AirshipNotifications.PrivacyManagerUpdated.name
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(localeUpdates),
            name: AirshipNotifications.LocaleUpdated.name
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
            self.dataStore.removeObject(forKey: DefaultAirshipChannel.tagsDataStoreKey)
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

    public func editTags() -> TagEditor {
        return TagEditor { tagApplicator in
            self.tagsLock.sync {
                self.tags = tagApplicator(self.tags)
            }
        }
    }

    public func editTags(_ editorBlock: (TagEditor) -> Void) {
        let editor = editTags()
        editorBlock(editor)
        editor.apply()
    }

    public func editTagGroups() -> TagGroupsEditor {
        let allowDeviceTags = !self.isChannelTagRegistrationEnabled
        return self.audienceManager.editTagGroups(
            allowDeviceGroup: allowDeviceTags
        )
    }

    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }

    public func editSubscriptionLists() -> SubscriptionListEditor {
        return self.audienceManager.editSubscriptionLists()
    }

    public func editSubscriptionLists(
        _ editorBlock: (SubscriptionListEditor) -> Void
    ) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }

    public func fetchSubscriptionLists() async throws -> [String] {
        return try await self.audienceManager.fetchSubscriptionLists()
    }

    public var subscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never>
    {
        audienceManager.subscriptionListEdits
    }

    public func editAttributes() -> AttributesEditor {
        return self.audienceManager.editAttributes()
    }

    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    public func enableChannelCreation() {
        if !self.isChannelCreationEnabled.value {
            self.isChannelCreationEnabled.value = true
            self.updateRegistration()
        }
    }

    public func updateRegistration() {
        updateRegistration(forcefully: false)
    }

    private var isRegistrationAllowed: Bool {
        guard self.isChannelCreationEnabled.value else {
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

    public func updateRegistration(forcefully: Bool) {
        guard self.isRegistrationAllowed else {
            return
        }

        self.channelRegistrar.register(forcefully: forcefully)
    }
}

/// - Note: for internal use only.  :nodoc:
extension DefaultAirshipChannel: AirshipPushableComponent {
    func receivedRemoteNotification(_ notification: AirshipJSON) async -> UABackgroundFetchResult {
        if self.identifier == nil {
            updateRegistration()
        }
        return .noData
    }

#if !os(tvOS)
    func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        // no-op
    }
#endif

    private func processChannelUpdate(_ update: ChannelRegistrationUpdate) {
        switch(update) {
        case .created(let channelID, let isExisting):
            AirshipLogger.importantInfo("Channel ID: \(channelID)")
            self.audienceManager.channelID = channelID
            self.notificationCenter.post(
                name: AirshipNotifications.ChannelCreated.name,
                object: nil,
                userInfo: [
                    AirshipNotifications.ChannelCreated.channelIDKey: channelID,
                    AirshipNotifications.ChannelCreated.isExistingChannelKey: isExisting,
                ]
            )
        case .updated(_):
            AirshipLogger.info("Channel updated.")
        }
    }

    private func makePayload() async -> ChannelRegistrationPayload {
        var payload = ChannelRegistrationPayload()

        guard privacyManager.isAnyFeatureEnabled() else {
            payload.channel.tags = []
            payload.channel.setTags = true
            payload.channel.isOptedIn = false
            payload.channel.isBackgroundEnabled = false
            return payload
        }

        for extender in await self.extenders {
            await extender(&payload)
        }
        
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
        
        if self.privacyManager.isEnabled(.tagsAndAttributes) {
            var permissions: [String: String] = [:]
            
            for permission in self.permissionsManager.configuredPermissions {
                let status = await self.permissionsManager.checkPermissionStatus(
                    permission
                )
                if status != .notDetermined {
                    permissions[permission.rawValue] = status.rawValue
                }
            }
            payload.channel.permissions = permissions
        }

        return payload
    }
}

extension DefaultAirshipChannel: InternalAirshipChannel {
    @MainActor
    public func addRegistrationExtender(
        _ extender: @Sendable @escaping (inout ChannelRegistrationPayload) async -> Void
    ) {
        self.extenders.append(extender)
    }

    public func clearSubscriptionListsCache() {
        self.audienceManager.clearSubscriptionListCache()
    }
}

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
@available(iOS 16.1, *)
extension DefaultAirshipChannel {

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
        guard privacyManager.isEnabled(.push) else {
            AirshipLogger.error("Push is not enabled, unable to track live activity.")
            return
        }

        let liveActivity = LiveActivity(activity: activity)
        liveActivityQueue.enqueue { [liveActivityRegistry] in
            await liveActivityRegistry.addLiveActivity(liveActivity, name: name)
        }
    }

    /// Called to restore live activity tracking. This method needs to be called exactly once
    /// during `application(_:didFinishLaunchingWithOptions:)` right
    /// after takeOff. Any activities not restored will stop being tracked by Airship.
    /// - Parameters:
    ///     - callback: Callback with the restorer.
    public func restoreLiveActivityTracking(
        callback: @escaping @Sendable (any LiveActivityRestorer) async -> Void
    ) {
        liveActivityQueue.enqueue { [liveActivityRegistry] in
            let restorer = AirshipLiveActivityRestorer()
            await callback(restorer)
            await restorer.apply(registry: liveActivityRegistry)
        }
    }
}

#endif

extension DefaultAirshipChannel: AirshipComponent {}


public extension AirshipNotifications {

    /// NSNotification info when the channel is created.
    final class ChannelCreated {

        /// NSNotification name.
        public static let name = NSNotification.Name(
            "com.urbanairship.channel.channel_created"
        )

        /// NSNotification userInfo key to get the channel ID.
        public static let channelIDKey = "channel_identifier"

        /// NSNotification userInfo key to get a boolean if the channel is existing or not.
        public static let isExistingChannelKey = "channel_existing"
    }

}

