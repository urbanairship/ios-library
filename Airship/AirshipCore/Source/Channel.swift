/* Copyright Airship and Contributors */

import Foundation

/**
 * This singleton provides an interface to the channel functionality.
 */
@objc(UAChannel)
public class Channel : NSObject, Component, ChannelProtocol {


    private static let tagsDataStoreKey = "com.urbanairship.channel.tags";
    
    /**
     * Notification event when the channel is created.
     */
    @objc
    public static let channelCreatedEvent = NSNotification.Name("com.urbanairship.channel.channel_created")
    
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
    public static let channelUpdatedEvent = NSNotification.Name("com.urbanairship.channel.channel_updated")
    
    /**
     * Notification event when channel registration failed.
     */
    @objc
    public static let channelRegistrationFailedEvent = NSNotification.Name("com.urbanairship.channel.registration_failed")
    
    /**
     * Notification event when the audience is updated.
     * - NOTE: For internal use only. :nodoc:
     */
    @objc
    public static let audienceUpdatedEvent = NSNotification.Name("com.urbanairship.channel.audience_updated")
    
    /**
     * Tags event key for audienceUpdatedEvent.
     * - NOTE: For internal use only. :nodoc:
     */
    @objc
    public static let audienceTagsKey = "tags"
    
    /**
     * Attributes event key for audienceUpdatedEvent.
     * - NOTE: For internal use only. :nodoc:
     */
    @objc
    public static let audienceAttributesKey = "attributes"

    // NOTE: For internal use only. :nodoc:
    @objc
    public static let legacyTagsSettingsKey = "UAPushTags"

    private let dataStore: PreferenceDataStore
    private let config: RuntimeConfig
    private let privacyManager: PrivacyManager
    private let localeManager: LocaleManagerProtocol
    private var audienceManager: ChannelAudienceManagerProtocol
    private let channelRegistrar: ChannelRegistrarProtocol
    private let notificationCenter: NotificationCenter
    private let appStateTracker: AppStateTracker
    private let tagsLock = Lock()

    private var shouldPerformChannelRegistrationOnForeground = false
    private var extensionBlocks: [((ChannelRegistrationPayload, @escaping (ChannelRegistrationPayload) -> Void) -> Void)] = []

    private var isChannelCreationEnabled: Bool

    /// The channel identifier.
    public var identifier: String? {
        get {
            return self.channelRegistrar.channelID
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    public var pendingAttributeUpdates : [AttributeUpdate] {
        get {
            return self.audienceManager.pendingAttributeUpdates
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    public var pendingTagGroupUpdates : [TagGroupUpdate] {
        get {
            return self.audienceManager.pendingTagGroupUpdates
        }
    }

    /// The channel tags.
    public var tags: [String] {
        get {
            guard (self.privacyManager.isEnabled(.tagsAndAttributes)) else {
                return []
            }
            
            var result: [String]?
            tagsLock.sync {
                result = self.dataStore.array(forKey: Channel.tagsDataStoreKey) as? [String]
            }
            return result ?? []
        }
        
        set {
            guard (self.privacyManager.isEnabled(.tagsAndAttributes)) else {
                AirshipLogger.warn("Unable to modify channel tags \(tags) when data collection is disabled.")
                return;
            }
            
            tagsLock.sync {
                let normalized = AudienceUtils.normalizeTags(newValue)
                self.dataStore.setValue(normalized, forKey: Channel.tagsDataStoreKey)
            }

            self.updateRegistration()
        }
    }

    /// Allows setting tags from the device. Tags can be set from either the server or the device, but not both (without synchronizing the data),
    /// so use this flag to explicitly enable or disable the device-side flags.
    /// Set this to `false` to prevent the device from sending any tag information to the server when using server-side tagging. Defaults to `true`.
    public var isChannelTagRegistrationEnabled = true

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
    
    // NOTE: For internal use only. :nodoc:
    static let supplier : () -> (ChannelProtocol) = {
        return Airship.requireComponent(ofType: ChannelProtocol.self)
    }
    
    /// The shared Channel instance.
    /// - Returns The shared Channel instance.
    @objc
    public static var shared: Channel {
        return Airship.channel
    }

    init(dataStore: PreferenceDataStore,
         config: RuntimeConfig,
         privacyManager: PrivacyManager,
         localeManager: LocaleManagerProtocol,
         audienceManager: ChannelAudienceManagerProtocol,
         channelRegistrar: ChannelRegistrarProtocol,
         notificationCenter: NotificationCenter,
         appStateTracker:AppStateTracker) {
        
        self.dataStore = dataStore
        self.config = config
        self.privacyManager = privacyManager
        self.localeManager = localeManager
        self.audienceManager = audienceManager
        self.channelRegistrar = channelRegistrar
        self.notificationCenter = notificationCenter
        self.appStateTracker = appStateTracker
        
        // Check config to see if user wants to delay channel creation
        // If channel ID exists or channel creation delay is disabled then channelCreationEnabled
        if (self.channelRegistrar.channelID != nil || !config.isChannelCreationDelayEnabled) {
            self.isChannelCreationEnabled = true
        } else {
            AirshipLogger.debug("Channelc creation disabled.")
            self.isChannelCreationEnabled = false
        }
        
        self.disableHelper = ComponentDisableHelper(dataStore: dataStore,
                                                    className: "UAChannel")

        super.init()

        self.migrateTags()
        
        self.disableHelper.onChange = { [weak self] in
            self?.onComponentEnableChange()
        }
    
        self.channelRegistrar.delegate = self
        self.audienceManager.channelID = self.channelRegistrar.channelID

        self.audienceManager.enabled = self.isComponentEnabled
        
        if let identifier = self.identifier {
            AirshipLogger.importantInfo("Channel ID \(identifier)")
        }

        self.observeNotificationCenterEvents()
        self.updateRegistration()

    }
    
    // NOTE: For internal use only. :nodoc:
    @objc
    convenience public init(dataStore: PreferenceDataStore,
                            config: RuntimeConfig,
                            privacyManager: PrivacyManager,
                            localeManager: LocaleManagerProtocol) {
        self.init(dataStore:dataStore,
                  config: config,
                  privacyManager: privacyManager,
                  localeManager: localeManager,
                  audienceManager: ChannelAudienceManager(dataStore: dataStore, config: config, privacyManager: privacyManager),
                  channelRegistrar: ChannelRegistrar(config: config, dataStore: dataStore),
                  notificationCenter: NotificationCenter.default,
                  appStateTracker:AppStateTracker.shared)
    }

    private func migrateTags() {
        guard self.dataStore.keyExists(Channel.legacyTagsSettingsKey) else {
            // Nothing to migrate
            return
        }

        // Normalize tags for older SDK versions, and migrate to UAChannel as necessary
        if let existingPushTags = self.dataStore.object(forKey: Channel.legacyTagsSettingsKey) as? [String] {
            let existingChannelTags = self.tags
            if existingChannelTags.count > 0 {
                let combinedTagsSet = Set(existingPushTags).union(Set(existingChannelTags))
                self.tags = Array(combinedTagsSet)
            } else {
                self.tags = existingPushTags
            }
        }

        self.dataStore.removeObject(forKey: Channel.legacyTagsSettingsKey)
    }
    
    private func observeNotificationCenterEvents() {
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidTransitionToForeground),
                                       name: AppStateTracker.didTransitionToForeground,
                                       object: nil)
        
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidTransitionToForeground),
                                       name: LocaleManager.localeUpdatedEvent,
                                       object: nil)
        
        notificationCenter.addObserver(self,
                                       selector: #selector(remoteConfigUpdated),
                                       name: RuntimeConfig.configUpdatedEvent,
                                       object: nil)

        notificationCenter.addObserver(self,
                                       selector: #selector(onEnableFeaturesChanged),
                                       name: PrivacyManager.changeEvent,
                                       object: nil)
        
        
        notificationCenter.addObserver(self,
                                       selector: #selector(localeUpdates),
                                       name: LocaleManager.localeUpdatedEvent,
                                       object: nil)
    }
    
    @objc
    private func localeUpdates() {
        self.updateRegistration()
    }
    
    @objc
    private func remoteConfigUpdated() {
        if (self.isChannelCreationEnabled && self.identifier != nil) {
            self.channelRegistrar.performFullRegistration()
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    private func onComponentEnableChange() {
        if (self.isComponentEnabled) {
            self.updateRegistration()
        }
        self.audienceManager.enabled = self.isComponentEnabled
    }
    
    @objc
    private func onEnableFeaturesChanged() {
        if (!self.privacyManager.isEnabled(.tagsAndAttributes)) {
            self.dataStore.removeObject(forKey: Channel.tagsDataStoreKey)
        }
        
        self.updateRegistration()
    }
    
    @objc
    private func applicationDidTransitionToForeground() {
        if (self.privacyManager.isAnyFeatureEnabled()) {
            AirshipLogger.trace("Application did become active. Updating registration.")
            self.updateRegistration()
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    @objc
    public func addRegistrationExtender(_ extender: @escaping(ChannelRegistrationPayload, (@escaping (ChannelRegistrationPayload) -> Void)) -> Void) {
        self.extensionBlocks.append(extender)
    }
    
    /// Begins a tag editing session
    /// - Returns: A TagEditor
    @objc
    public func editTags() -> TagEditor {
        return TagEditor() { tagApplicator in
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
        return self.audienceManager.editTagGroups(allowDeviceGroup: allowDeviceTags)
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
    public func editSubscriptionLists(_ editorBlock: (SubscriptionListEditor) -> Void) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }

    /// Fetches subscription lists.
    /// - Parameter completionHandler: A completion handler.
    /// - Returns: A Disposable.
    @discardableResult
    @objc
    public func fetchSubscriptionLists(completionHandler: @escaping ([String]?, Error?) -> Void) -> Disposable {
        return audienceManager.fetchSubscriptionLists(completionHandler: completionHandler)
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
        editTags() { editor in
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
        editTags() { editor in
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
        editTags() { editor in
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
        editTags() { editor in
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
        editTagGroups(){ editor in
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
        editTagGroups(){ editor in
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
        editTagGroups(){ editor in
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
        editAttributes() { editor in
            mutations.applyMutations(editor: editor)
        }
    }
    
    /**
     * Enables channel creation if channelCreationDelayEnabled was set to `YES` in the config.
     */
    @objc(enableChannelCreation)
    public func enableChannelCreation() {
        if (!self.isChannelCreationEnabled) {
            self.isChannelCreationEnabled = true
            self.updateRegistration()
        }
    }

    public func updateRegistration() {
        updateRegistration(forcefully: false)
    }
    
    /// - Note: For internal use only. :nodoc:
    public func updateRegistration(forcefully: Bool) {
        guard self.isComponentEnabled else {
            return
        }
        
        guard self.isChannelCreationEnabled else {
            AirshipLogger.debug("Channel creation is currently disabled, unable to update")
            return
        }
        
        guard self.identifier != nil || self.privacyManager.isAnyFeatureEnabled() else {
            AirshipLogger.trace("Skipping channel create. All features are disabled.")
            return
        }

        self.channelRegistrar.register(forcefully: forcefully)
    }
}

/// - Note: for internal use only.  :nodoc:
extension Channel : PushableComponent {
    
    #if !os(watchOS)
    public func receivedRemoteNotification(_ notification: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if (self.identifier == nil) {
            updateRegistration()
        }
        completionHandler(.noData)
    }
    #else
    public func receivedRemoteNotification(_ notification: [AnyHashable : Any], completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        if (self.identifier == nil) {
            updateRegistration()
        }
        completionHandler(.noData)
    }
    #endif
}

/// - Note: for internal use only.  :nodoc:
extension Channel : ChannelRegistrarDelegate {
    
    public func createChannelPayload(completionHandler: @escaping (ChannelRegistrationPayload) -> ()) {
        let payload = ChannelRegistrationPayload()
        
        if (self.appStateTracker.state == .active) {
            payload.channel.isActive = true
        }
        
        if (self.isChannelTagRegistrationEnabled) {
            payload.channel.tags = self.tags
            payload.channel.setTags = true
        } else {
            payload.channel.setTags = false
        }
        
        if (self.privacyManager.isEnabled(.analytics)) {
            payload.channel.deviceModel = Utils.deviceModelName()
            payload.channel.carrier = Utils.carrierName()
            payload.channel.appVersion = Utils.bundleShortVersionString()
            #if !os(watchOS)
            payload.channel.deviceOS = UIDevice.current.systemVersion
            #endif
        }

        if (self.privacyManager.isAnyFeatureEnabled()) {
            let currentLocale = self.localeManager.currentLocale
            payload.channel.language = currentLocale.languageCode
            payload.channel.country = currentLocale.regionCode
            payload.channel.timeZone = TimeZone.current.identifier
            payload.channel.sdkVersion = AirshipVersion.get()
            
            Channel.extendPayload(payload,
                                  extenders: self.extensionBlocks,
                                  completionHandler: completionHandler)
        } else {
            completionHandler(payload);
        }
    }
    
    public func registrationFailed() {
        AirshipLogger.info("Channel registration failed")
        UADispatcher.main.dispatchAsync {
            self.notificationCenter.post(name: Channel.channelRegistrationFailedEvent,
                                         object: self,
                                         userInfo: nil)
        }
    }
    
    public func registrationSucceeded() {
        AirshipLogger.info("Channel registration updated successfully.")
        UADispatcher.main.dispatchAsync {
            self.notificationCenter.post(name: Channel.channelUpdatedEvent,
                                         object: self,
                                         userInfo: [Channel.channelIdentifierKey : self.identifier ?? ""])
        }
    }
    
    public func channelCreated(channelID: String, existing: Bool) {
        AirshipLogger.importantInfo("Channel ID: \(channelID)")
        self.audienceManager.channelID = channelID
        UADispatcher.main.dispatchAsync {
            self.notificationCenter.post(name: Channel.channelCreatedEvent,
                                         object: self,
                                         userInfo: [
                                            Channel.channelIdentifierKey: channelID,
                                            Channel.channelExistingKey: existing
                                         ])
        }
    }
    
    
    class func extendPayload(_ payload: ChannelRegistrationPayload,
                             extenders: [((ChannelRegistrationPayload, @escaping (ChannelRegistrationPayload) -> Void) -> Void)],
                             completionHandler: @escaping (ChannelRegistrationPayload) -> Void) {
        
        guard extenders.count > 0 else {
            completionHandler(payload)
            return
        }
        
        var remaining = extenders
        let next = remaining.removeFirst()
        
        UADispatcher.main.dispatchAsync {
            next(payload) { payload in
                extendPayload(payload, extenders: remaining, completionHandler: completionHandler)
            }
        }
    }
}


extension Channel : InternalChannelProtocol {
    func processContactSubscriptionUpdates(_ updates: [SubscriptionListUpdate]) {
        self.audienceManager.processContactSubscriptionUpdates(updates)
    }
}
