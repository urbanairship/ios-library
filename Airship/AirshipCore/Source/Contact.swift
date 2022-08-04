/* Copyright Airship and Contributors */

import Foundation


/**
 * Airship contact. A contact is distinct from a channel and  represents a "user"
 * within Airship. Contacts may be named and have channels associated with it.
 */
@objc(UAContactProtocol)
public protocol ContactProtocol {
    
    /**
     * The current named user ID.
     */
    @objc
    var namedUserID: String? { get }
    
    // NOTE: For internal use only. :nodoc:
    @objc
    var pendingAttributeUpdates : [AttributeUpdate] { get }

    // NOTE: For internal use only. :nodoc:
    @objc
    var pendingTagGroupUpdates : [TagGroupUpdate] { get }
        
    /**
     * Associates the contact with the given named user identifier.
     * - Parameters:
     *   - namedUserID: The named user ID.
     */
    @objc
    func identify(_ namedUserID: String)

    /**
     * Disassociate the channel from its current contact, and create a new
     * un-named contact.
     */
    @objc
    func reset()
        
    /**
     * Edits tags.
     * - Returns: A tag groups editor.
     */
    @objc
    func editTagGroups() -> TagGroupsEditor
    
    /**
     * Edits tags.
     * - Parameters:
     *   - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void)
        
    /**
     * Edits attributes.
     * - Returns: An attributes editor.
     */
    @objc
    func editAttributes() -> AttributesEditor
    
    /**
     * Edits  attributes.
     * - Parameters:
     *   - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editAttributes(_ editorBlock: (AttributesEditor) -> Void)
    
    /**
     * Associates an Email channel to the contact.
     * - Parameters:
     *   - address: The email address.
     *   - options: The email channel registration options.
     */
    @objc
    func registerEmail(_ address: String, options: EmailRegistrationOptions)
    
    /**
     * Associates a SMS channel to the contact.
     * - Parameters:
     *   - msisdn: The SMS msisdn.
     *   - options: The SMS channel registration options.
     */
    @objc
    func registerSMS(_ msisdn: String, options: SMSRegistrationOptions)
    
    /**
     * Associates an Open channel to the contact.
     * - Parameters:
     *   - address: The open channel address.
     *   - options: The open channel registration options.
     */
    @objc
    func registerOpen(_ address: String, options: OpenRegistrationOptions)
    
    /**
     * Associates a channel to the contact.
     * - Parameters:
     *   - channelID: The channel ID.
     *   - type: The channel type.
     */
    @objc
    func associateChannel(_ channelID: String, type: ChannelType)

    /// Begins a subscription list editing session
    /// - Returns: A Scoped subscription list editor
    @objc
    func editSubscriptionLists() -> ScopedSubscriptionListEditor

    /// Begins a subscription list editing session
    /// - Parameter editorBlock: A scoped subscription list editor block.
    @objc
    func editSubscriptionLists(_ editorBlock: (ScopedSubscriptionListEditor) -> Void)

    /// Fetches subscription lists.
    /// - Parameter completionHandler: A completion handler.
    /// - Returns: A Disposable.
    @discardableResult
    func fetchSubscriptionLists(completionHandler: @escaping ([String: ChannelScopes]?, Error?) -> Void) -> Disposable
}

/**
 * Airship contact. A contact is distinct from a channel and  represents a "user"
 * within Airship. Contacts may be named and have channels associated with it.
 */
@objc(UAContact)
public class Contact : NSObject, Component, ContactProtocol {

    // NOTE: For internal use only. :nodoc:
    static let supplier : () -> (ContactProtocol) = {
        return Airship.requireComponent(ofType: ContactProtocol.self)
    }
    
    static let updateTaskID = "Contact.update"
    static let operationsKey = "Contact.operations"
    static let contactInfoKey = "Contact.contactInfo"
    static let anonContactDataKey = "Contact.anonContactData"
    static let resolveDateKey = "Contact.resolveDate"

    static let identityRateLimitID = "Contact.identityRateLimitID"
    static let updateRateLimitID = "Contact.updateRateLimitID"

    static let legacyPendingTagGroupsKey = "com.urbanairship.tag_groups.pending_channel_tag_groups_mutations"
    static let legacyPendingAttributesKey = "com.urbanairship.named_user_attributes.registrar_persistent_queue_key"
    static let legacyNamedUserKey = "UANamedUserID"

    static let foregroundResolveInterval : TimeInterval = 24 * 60 * 60 // 24 hours
    
    @objc
    public static let contactChangedEvent = NSNotification.Name("com.urbanairship.contact_changed")
    
    @objc
    public static let audienceUpdatedEvent = NSNotification.Name("com.urbanairship.audience_updated")

    @objc
    public static let tagsKey = "tag_updates"

    @objc
    public static let attributesKey = "attribute_updates"

    @objc
    public static let maxNamedUserIDLength = 128

    private let dataStore: PreferenceDataStore
    private let config: RuntimeConfig
    private let privacyManager: PrivacyManager
    private let channel: InternalChannelProtocol
    private let contactAPIClient: ContactsAPIClientProtocol
    private let taskManager: TaskManagerProtocol
    private let dispatcher = UADispatcher.serial(.utility)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let date : AirshipDate
    private let notificationCenter: NotificationCenter
    private let cachedSubscriptionLists: CachedValue<(String, [String: [ChannelScope]])>
    private let cachedSubscriptionListsHistory: CachedList<(String, ScopedSubscriptionListUpdate)>
    private let rateLimiter = RateLimiter()

    /// A delegate to receive callbacks where there is a contact conflict.
    @objc
    public weak var conflictDelegate: ContactConflictDelegate?

    /// The current named user ID.
    @objc
    public var namedUserID : String? {
        get {
            var namedUserID : String? = nil
            operationLock.sync {
                if let lastIdentifyOperation = self.getOperations().reversed().first(where: { $0.type == .reset || $0.type == .identify }) {
                    if (lastIdentifyOperation.type == .reset) {
                        namedUserID = nil
                    } else {
                        namedUserID = (lastIdentifyOperation.payload as? IdentifyPayload)?.identifier
                    }
                } else {
                    namedUserID = self.lastContactInfo?.namedUserID
                }
            }
            return namedUserID
        }
    }
    
    private var lastContactInfo: ContactInfo? {
        get {
            if let data = self.dataStore.data(forKey: Contact.contactInfoKey) {
                return try? self.decoder.decode(ContactInfo.self, from: data)
            } else {
                return nil
            }
        }
        set {
            if let data = try? self.encoder.encode(newValue) {
                self.dataStore.setValue(data, forKey: Contact.contactInfoKey)
            }
        }
    }
    
    private var currentContactID: String? {
        guard let lastContactInfo = lastContactInfo else {
            return nil
        }
        
        var contactID : String? = lastContactInfo.contactID
        operationLock.sync {
            let containsIdentifyOperation = self.getOperations()
                .contains(where: {
                    if ($0.type == .reset) {
                        return true
                    }
                    
                    if ($0.type == .identify && lastContactInfo.namedUserID != ($0.payload as? IdentifyPayload)?.identifier) {
                        return true
                    }

                    return false
                })
            
            if (containsIdentifyOperation) {
                contactID = nil
            }
            
        }
        
        return contactID
        
    }
    
    private var anonContactData: InternalContactData? {
        get {
            if let data = self.dataStore.data(forKey: Contact.anonContactDataKey) {
                return try? self.decoder.decode(InternalContactData.self, from: data)
            } else {
                return nil
            }
        }
        set {
            if let data = try? self.encoder.encode(newValue) {
                self.dataStore.setValue(data, forKey: Contact.anonContactDataKey)
            }
        }
    }
    
    private var lastResolveDate: Date {
        get {
            let date = self.dataStore.object(forKey: Contact.resolveDateKey) as? Date
            return date ?? Date.distantPast
        }
        set {
            self.dataStore.setValue(newValue, forKey: Contact.resolveDateKey)
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    @objc
    public var pendingAttributeUpdates : [AttributeUpdate] {
        get {
            var updates : [AttributeUpdate]!
            operationLock.sync {
                updates = getOperations().compactMap() { (operation: ContactOperation) -> [AttributeUpdate]? in
                    if (operation.type == .update) {
                        let payload = operation.payload as? UpdatePayload
                        return payload?.attrubuteUpdates
                    } else {
                        return nil
                    }
                }.reduce([], +)
            }
            return updates
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    @objc
    public var pendingTagGroupUpdates : [TagGroupUpdate] {
        get {
            var updates : [TagGroupUpdate]!
            operationLock.sync {
                updates = getOperations().compactMap() { (operation: ContactOperation) -> [TagGroupUpdate]? in
                    if (operation.type == .update) {
                        let payload = operation.payload as? UpdatePayload
                        return payload?.tagUpdates
                    } else {
                        return nil
                    }
                }.reduce([], +)
            }
            return updates
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    var pendingSubscriptionListUpdates : [ScopedSubscriptionListUpdate] {
       get {
           var updates : [ScopedSubscriptionListUpdate]!
           operationLock.sync {
               updates = getOperations().compactMap() { (operation: ContactOperation) -> [ScopedSubscriptionListUpdate]? in
                   if (operation.type == .update) {
                       let payload = operation.payload as? UpdatePayload
                       return payload?.subscriptionListsUpdates
                   } else {
                       return nil
                   }
               }.reduce([], +)
           }
           return updates
       }
   }
    
    private var isContactIDRefreshed = false
    private var operationLock = Lock()
 
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
    public static var shared: Contact {
        return Airship.contact
    }

    /**
     * Internal only
     * :nodoc:
     */
    init(dataStore: PreferenceDataStore,
         config: RuntimeConfig,
         channel: InternalChannelProtocol,
         privacyManager: PrivacyManager,
         contactAPIClient: ContactsAPIClientProtocol,
         taskManager: TaskManagerProtocol,
         notificationCenter: NotificationCenter = NotificationCenter.default,
         date: AirshipDate = AirshipDate()) {
        
        self.dataStore = dataStore
        self.config = config
        self.channel = channel
        self.privacyManager = privacyManager
        self.contactAPIClient = contactAPIClient
        self.taskManager = taskManager
        self.date = date
        self.notificationCenter = notificationCenter
        
        self.disableHelper = ComponentDisableHelper(dataStore: dataStore,
                                                    className: "Contact")
        
        self.cachedSubscriptionLists = CachedValue(date: date, maxCacheAge: 600)
        self.cachedSubscriptionListsHistory = CachedList(date: date, maxCacheAge: 600)
        super.init()

        
        self.disableHelper.onChange = { [weak self] in
            self?.onComponentEnableChange()
        }
                
        self.taskManager.register(taskID: Contact.updateTaskID, dispatcher: self.dispatcher) { [weak self] task in
            self?.handleUpdateTask(task: task)
        }

        do {
            try self.taskManager.setRateLimit(Contact.identityRateLimitID, rate: 1, timeInterval: 5.0)
            try self.taskManager.setRateLimit(Contact.updateRateLimitID, rate: 1, timeInterval: 0.5)
        } catch {
            AirshipLogger.error("Failed to create rate limits")
        }

        self.channel.addRegistrationExtender { [weak self] payload, completionHandler in
            payload.channel.contactID = self?.lastContactInfo?.contactID
            completionHandler(payload)
        }
        
        migrateNamedUser()
        
        self.notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil)

        self.notificationCenter.addObserver(
            self,
            selector: #selector(channelCreated),
            name: Channel.channelCreatedEvent,
            object: nil)
        
        self.notificationCenter.addObserver(
            self,
            selector: #selector(checkPrivacyManager),
            name: PrivacyManager.changeEvent,
            object: nil)
        
        self.checkPrivacyManager()
        self.enqueueTask()

        self.notifyChannelSubscriptionListUpdates(self.pendingSubscriptionListUpdates)
    }
    
    /**
     * Internal only
     * :nodoc:
     */
    @objc
    public convenience init(dataStore: PreferenceDataStore,
                            config: RuntimeConfig,
                            channel: Channel,
                            privacyManager: PrivacyManager) {
        self.init(dataStore: dataStore,
                  config: config,
                  channel: channel,
                  privacyManager: privacyManager,
                  contactAPIClient: ContactAPIClient(config: config),
                  taskManager: TaskManager.shared)
    }

    /// Identifies the contact.
    /// - Parameter namedUserID: The named user ID.
    @objc
    public func identify(_ namedUserID: String) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn("Contacts disabled. Enable to identify user.")
            return
        }
        
        let trimmedID = namedUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedID.count > 0 && trimmedID.count <= Contact.maxNamedUserIDLength else {
            AirshipLogger.error("Unable to set named user \(namedUserID). IDs must be between 1 and \(Contact.maxNamedUserIDLength) characters.")
            return
        }
        
        self.addOperation(ContactOperation.identify(identifier: namedUserID))
        self.enqueueTask()
    }

    /// Resets the contact.
    @objc
    public func reset() {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        self.addOperation(ContactOperation.reset())
        self.enqueueTask()
    }

    /// Begins a tag groups editing session.
    /// - Returns: A TagGroupsEditor
    @objc
    public func editTagGroups() -> TagGroupsEditor {
        return TagGroupsEditor { updates in
            guard !updates.isEmpty else {
                return
            }
            
            guard self.privacyManager.isEnabled([.contacts, .tagsAndAttributes]) else {
                AirshipLogger.warn("Contacts or tags are disabled. Enable to apply tag edits.")
                return
            }
            
            self.addOperation(ContactOperation.resolve())
            self.addOperation(ContactOperation.update(tagUpdates: updates))
            self.enqueueTask()
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
            
            guard self.privacyManager.isEnabled([.contacts, .tagsAndAttributes]) else {
                AirshipLogger.warn("Contacts or tags are disabled. Enable to apply attribute edits.")
                return
            }
            
            self.addOperation(ContactOperation.resolve())
            self.addOperation(ContactOperation.update(attributeUpdates: updates))
            self.enqueueTask()
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
    public func registerEmail(_ address: String, options: EmailRegistrationOptions) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn("Contacts disabled. Enable to associate Email channel.")
            return
        }
        
        self.addOperation(ContactOperation.resolve())
        self.addOperation(ContactOperation.registerEmail(address, options: options))
        self.enqueueTask()
    }
    
    /**
     * Associates a SMS channel to the contact.
     * - Parameters:
     *   - msisdn: The SMS msisdn.
     *   - options: The SMS channel registration options.
     */
    public func registerSMS(_ msisdn: String, options: SMSRegistrationOptions) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn("Contacts disabled. Enable to associate SMS channel.")
            return
        }
        
        self.addOperation(ContactOperation.resolve())
        self.addOperation(ContactOperation.registerSMS(msisdn, options: options))
        self.enqueueTask()
    }
    
    /// Associates an open channel to the contact.
    /// - Parameter address: The open channel address.
    /// - Parameter options: The open channel registration options.
    public func registerOpen(_ address: String, options: OpenRegistrationOptions) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn("Contacts disabled. Enable to associate Open channel.")
            return
        }
        
        self.addOperation(ContactOperation.resolve())
        self.addOperation(ContactOperation.registerOpen(address, options: options))
        self.enqueueTask()
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
            AirshipLogger.warn("Contacts disabled. Enable to associate channel.")
            return
        }
        
        self.addOperation(ContactOperation.resolve())
        self.addOperation(ContactOperation.associateChannel(channelID, type: type))
        self.enqueueTask()
    }

    /// Begins a subscription list editing session
    /// - Returns: A Scoped subscription list editor
    @objc
    public func editSubscriptionLists() -> ScopedSubscriptionListEditor {
        return ScopedSubscriptionListEditor(date: self.date) { updates in
            guard !updates.isEmpty else {
                return
            }
            
            guard self.privacyManager.isEnabled([.contacts, .tagsAndAttributes]) else {
                AirshipLogger.warn("Contacts or tags are disabled. Enable to apply subscription lists edits.")
                return
            }

            self.notifyChannelSubscriptionListUpdates(updates)

            self.addOperation(ContactOperation.resolve())
            self.addOperation(ContactOperation.update(subscriptionListsUpdates: updates))
            self.enqueueTask()
        }
    }

    /// Begins a subscription list editing session
    /// - Parameter editorBlock: A scoped subscription list editor block.
    /// - Returns: A ScopedSubscriptionListEditor
    @objc
    public func editSubscriptionLists(_ editorBlock: (ScopedSubscriptionListEditor) -> Void) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }

    /// Fetches subscription lists.
    /// - Parameter completionHandler: A completion handler.
    /// - Returns: A Disposable.
    @discardableResult
    public func fetchSubscriptionLists(completionHandler: @escaping ([String: ChannelScopes]?, Error?) -> Void) -> Disposable {
        
        var callback: (([String: ChannelScopes]?, Error?) -> Void)? = completionHandler
        let disposable = Disposable() {
            callback = nil
        }
        
        self.dispatcher.dispatchAsync {
            guard let contactID = self.currentContactID else {
                callback?(nil, AirshipErrors.error("Contact not resolved"))
                return
            }
           
            do {
                var subscriptions = try self.resolveSubscriptionLists(contactID)

                // Local history
                let localHistory = self.cachedSubscriptionListsHistory.values.compactMap { cached in
                    cached.0 == contactID ? cached.1 : nil
                }
                subscriptions = AudienceUtils.applySubscriptionListsUpdates(subscriptions,
                                                                          updates: localHistory)

                // Pending
                subscriptions = AudienceUtils.applySubscriptionListsUpdates(subscriptions,
                                                                            updates: self.pendingSubscriptionListUpdates)

                callback?(AudienceUtils.wrap(subscriptions), nil)
            } catch {
                callback?(nil, error)
            }
        }
        
        return disposable
    }
    

    private func resolveSubscriptionLists(_ contactID: String) throws -> [String: [ChannelScope]] {
        if let cached = self.cachedSubscriptionLists.value, cached.0 == contactID {
            return cached.1
        }
        
        var fetchResponse: (ContactSubscriptionListFetchResponse?, Error?)
        let semaphore = Semaphore()
        self.contactAPIClient.fetchSubscriptionLists(contactID) { response, error in
            fetchResponse = (response, error)
            semaphore.signal()
        }
        
        semaphore.wait()
        
        guard let response = fetchResponse.0 else {
            if let error = fetchResponse.1 {
                AirshipLogger.debug("Fetched lists failed with error: \(error)")
            } else {
                AirshipLogger.debug("Fetched lists failed")
            }

            throw AirshipErrors.error("Failed to fetch subscriptoin lists failed")
        }
        
        guard response.isSuccess, let scopedLists = response.result else {
            throw AirshipErrors.error("Failed to fetch subscriptoin lists with status: \(response.status)")
        }
        
        AirshipLogger.debug("Fetched lists finished with response: \(response)")
        self.cachedSubscriptionLists.value = (contactID, scopedLists)
        return scopedLists
    }
    
    /**
     * :nodoc:
     */
    private func onComponentEnableChange() {
        self.enqueueTask()
    }
    
    @objc
    func checkPrivacyManager() {
        guard !self.privacyManager.isEnabled(.contacts) else {
            return
        }
        
        guard let contactInfo = self.lastContactInfo else {
            return
        }
        
        if (contactInfo.isAnonymous == false || self.anonContactData != nil) {
            self.addOperation(ContactOperation.reset())
            self.enqueueTask()
        }
    }
    
    @objc
    private func didBecomeActive() {
        if (self.date.now.timeIntervalSince(self.lastResolveDate) >= Contact.foregroundResolveInterval) {
            resolveContact()
        }
    }
    
    @objc
    private func channelCreated(notification: NSNotification) {
        let existing = notification.userInfo?[Channel.channelExistingKey] as? Bool
        
        if (existing == true && self.config.clearNamedUserOnAppRestore) {
            self.reset()
        } else {
            self.resolveContact()
        }
    }
    
    private func resolveContact() {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }
        
        self.isContactIDRefreshed = false
        self.addOperation(ContactOperation.resolve())
        self.enqueueTask()
    }

    private func enqueueTask() {
        guard self.channel.identifier != nil,
              self.isComponentEnabled,
              let next = self.prepareNextOperation() else {
            return
        }

        var rateLimitIDs = [Contact.updateRateLimitID]

        switch(next.type) {
        case .resolve: fallthrough
        case .identify: fallthrough
        case .reset:
            rateLimitIDs.append(Contact.identityRateLimitID)
        default: break
        }

        self.taskManager.enqueueRequest(taskID: Contact.updateTaskID,
                                        rateLimitIDs: rateLimitIDs,
                                        options: .defaultOptions)
    }
    
    private func handleUpdateTask(task: AirshipTask) {
        guard let channelID = self.channel.identifier else {
            task.taskCompleted()
            return
        }
        
        guard let operation = prepareNextOperation() else {
            task.taskCompleted()
            return
        }

        let disposable = self.performOperation(operation: operation, channelID: channelID) { response in
            if let response = response {
                if (response.isServerError) {
                    // retry
                    task.taskFailed()
                } else {
                    self.removeFirstOperation()
                    task.taskCompleted()
                    self.enqueueTask()
                }
            } else {
                // retry
                task.taskFailed()
            }
        }
        
        task.expirationHandler = {
            disposable?.dispose()
        }
    }
    
    private func performOperation(operation: ContactOperation, channelID: String, completionHandler: @escaping (HTTPResponse?) -> Void) -> Disposable? {
        switch(operation.type) {
        case .update:
            guard let contactInfo = self.lastContactInfo, let updatePayload = operation.payload as? UpdatePayload else {
                self.removeFirstOperation()
                completionHandler(nil)
                return nil
            }
            
            if let updates = updatePayload.subscriptionListsUpdates {
                for update in updates {
                    self.cachedSubscriptionListsHistory.append((contactInfo.contactID, update))
                }
            }
            
            return self.contactAPIClient.update(identifier: contactInfo.contactID,
                                                tagGroupUpdates: updatePayload.tagUpdates,
                                                attributeUpdates: updatePayload.attrubuteUpdates,
                                                subscriptionListUpdates: updatePayload.subscriptionListsUpdates) { response, error in
                Contact.logOperationResult(operation: operation, response: response, error: error)
                if (response?.isSuccess == true) {
                    if (contactInfo.isAnonymous) {
                        self.updateAnonData(updates: updatePayload)
                    }
                    
                    let payload : [String : Any] = [
                        Contact.tagsKey : updatePayload.tagUpdates ?? [],
                        Contact.attributesKey : updatePayload.attrubuteUpdates ?? []
                    ]
                    self.notificationCenter.post(name: Contact.audienceUpdatedEvent, object: payload)
                }
                completionHandler(response)
            }
            
        case .identify:
            guard let identifyPayload = operation.payload as? IdentifyPayload else {
                self.removeFirstOperation()
                completionHandler(nil)
                return nil
            }
            var contactID: String? = nil
            if (self.lastContactInfo?.isAnonymous ?? false) {
                contactID = self.lastContactInfo?.contactID
            }
            
            return self.contactAPIClient.identify(channelID: channelID, namedUserID: identifyPayload.identifier, contactID: contactID) { response, error in
                Contact.logOperationResult(operation: operation, response: response, error: error)
                self.processContactResponse(response, namedUserID: identifyPayload.identifier)
                completionHandler(response)
            }
            
        case .reset:
            return self.contactAPIClient.reset(channelID: channelID) { response, error in
                Contact.logOperationResult(operation: operation, response: response, error: error)
                self.processContactResponse(response)
                completionHandler(response)
            }

        case .resolve:
            return self.contactAPIClient.resolve(channelID: channelID) { response, error in
                Contact.logOperationResult(operation: operation, response: response, error: error)
                self.processContactResponse(response)
                
                if (response?.isSuccess == true) {
                    self.lastResolveDate = self.date.now
                }
                
                completionHandler(response)
            }
            
        case .registerEmail:
            guard let contactInfo = self.lastContactInfo, let registerPayload = operation.payload as? RegisterEmailPayload else {
                self.removeFirstOperation()
                completionHandler(nil)
                return nil
            }
            
            return self.contactAPIClient.registerEmail(identifier: contactInfo.contactID, address: registerPayload.address, options: registerPayload.options) { response, error in
                Contact.logOperationResult(operation: operation, response: response, error: error)
                self.processChannelRegistration(response)
                completionHandler(response)
            }
            
        case .registerSMS:
            guard let contactInfo = self.lastContactInfo, let registerPayload = operation.payload as? RegisterSMSPayload else {
                self.removeFirstOperation()
                completionHandler(nil)
                return nil
            }
            
            return self.contactAPIClient.registerSMS(identifier: contactInfo.contactID, msisdn: registerPayload.msisdn, options: registerPayload.options) { response, error in
                Contact.logOperationResult(operation: operation, response: response, error: error)
                self.processChannelRegistration(response)
                completionHandler(response)
            }
            
        case .registerOpen:
            guard let contactInfo = self.lastContactInfo, let registerPayload = operation.payload as? RegisterOpenPayload else {
                self.removeFirstOperation()
                completionHandler(nil)
                return nil
            }
            
            return self.contactAPIClient.registerOpen(identifier: contactInfo.contactID, address: registerPayload.address, options: registerPayload.options) { response, error in
                Contact.logOperationResult(operation: operation, response: response, error: error)
                self.processChannelRegistration(response)
                completionHandler(response)
            }
            
        case .associateChannel:
            guard let contactInfo = self.lastContactInfo, let payload = operation.payload as? AssociateChannelPayload else {
                self.removeFirstOperation()
                completionHandler(nil)
                return nil
            }
            
            return self.contactAPIClient.associateChannel(identifier: contactInfo.contactID,
                                                          channelID: payload.channelID,
                                                          channelType: payload.channelType) { response, error in
                Contact.logOperationResult(operation: operation, response: response, error: error)
                self.processChannelRegistration(response)
                completionHandler(response)
            }
            
        }
    }
    
    private func shouldSkipOperation(_ operation: ContactOperation, isNext: Bool) -> Bool {
        switch(operation.type) {
        case .update:
            let payload = operation.payload as! UpdatePayload
            if (payload.attrubuteUpdates?.isEmpty ?? true && payload.tagUpdates?.isEmpty ?? true && payload.subscriptionListsUpdates?.isEmpty ?? true) {
                return true
            }
            return false
            
        case .identify:
            let payload = operation.payload as! IdentifyPayload
            return self.isContactIDRefreshed && self.lastContactInfo?.namedUserID == payload.identifier
            
        case .reset:
            return isNext && (self.lastContactInfo?.isAnonymous ?? false) && self.anonContactData == nil
            
        case .resolve:
            return self.isContactIDRefreshed
        
        case .registerEmail:
            return false
            
        case .registerSMS:
            return false
            
        case .registerOpen:
            return false

        case .associateChannel:
            return false
        }
        
    }
    
    private func onConflict(_ namedUserID: String?) {
        guard let data = self.anonContactData else {
            return
        }
        
        let attributes = data.attributes.compactMapValues { $0.value() }
        let anonData = ContactData(tags: data.tags,
                                   attributes: attributes,
                                   channels: data.channels,
                                   subscriptionLists: AudienceUtils.wrap(data.subscriptionLists))
        
        UADispatcher.main.dispatchAsync {
            self.conflictDelegate?.onConflict(anonymousContactData: anonData, namedUserID: namedUserID)
        }
    }
    
    private func updateAnonData(updates: UpdatePayload? = nil, channel: AssociatedChannel? = nil) {
        let data = self.anonContactData
        var tags = data?.tags ?? [:]
        var attributes = data?.attributes ?? [:]
        var channels = data?.channels ?? []
        var subscriptionLists = data?.subscriptionLists ?? [:]
        
        if let updates = updates {
            tags = AudienceUtils.applyTagUpdates(data?.tags, updates: updates.tagUpdates)
            attributes = AudienceUtils.applyAttributeUpdates(data?.attributes, updates: updates.attrubuteUpdates)
            subscriptionLists = AudienceUtils.applySubscriptionListsUpdates(data?.subscriptionLists,
                                                                            updates: updates.subscriptionListsUpdates)
        }
        
        if let channel = channel {
            channels.append(channel)
        }
        
        if (tags.isEmpty && attributes.isEmpty && channels.isEmpty && subscriptionLists.isEmpty) {
            self.anonContactData = nil
        } else {
            self.anonContactData = InternalContactData(tags: tags,
                                                       attributes: attributes,
                                                       channels: channels,
                                                       subscriptionLists: subscriptionLists)
        }
    }
    
    private func processContactResponse(_ response: ContactAPIResponse?, namedUserID: String? = nil) {
        if let response = response {
            if (response.isSuccess) {
                
                let lastInfo = self.lastContactInfo
                
                if (lastInfo == nil || lastInfo?.contactID != response.contactID) {
                    if (lastContactInfo?.isAnonymous == true) {
                        self.onConflict(namedUserID)
                    }
                    
                    self.lastContactInfo = ContactInfo(contactID: response.contactID!, isAnonymous: response.isAnonymous!, namedUserID: namedUserID)
                    self.channel.updateRegistration()
                    self.anonContactData = nil
                    
                    self.notificationCenter.post(name: Contact.contactChangedEvent, object: nil)
                } else {
                    self.lastContactInfo = ContactInfo(contactID: response.contactID!,
                                                       isAnonymous: response.isAnonymous!,
                                                       namedUserID: namedUserID ?? lastInfo?.namedUserID)
                    
                    if (response.isAnonymous == false) {
                        self.anonContactData = nil
                    }
                }
                
                self.isContactIDRefreshed = true
            }
        }
    }
        
    private func processChannelRegistration(_ response: ContactAssociatedChannelResponse?) {
        guard response?.isSuccess == true, let channel = response?.channel, lastContactInfo?.isAnonymous == true else {
            return
        }
        
        updateAnonData(channel: channel)
    }
    
    private class func logOperationResult(operation: ContactOperation, response: HTTPResponse?, error: Error?) {
        if let error = error {
            AirshipLogger.debug("Contact update for operation: \(operation) failed with error: \(error)")
        } else if let response = response {
            if (response.isSuccess) {
                AirshipLogger.debug("Contact update for operation: \(operation) succeeded with response: \(response)")
            } else {
                AirshipLogger.debug("Contact update for operation: \(operation) failed with response: \(response)")
            }
        } else {
            AirshipLogger.debug("Contact update for operation: \(operation) failed")
        }
    }
    
    private func addOperation(_ operation: ContactOperation) {
        self.operationLock.sync {
            var operations = getOperations()
            operations.append(operation)
            self.storeOperations(operations)
        }
    }
    
    private func getOperations() -> [ContactOperation] {
        var result: [ContactOperation]?
        operationLock.sync {
            if let data = self.dataStore.data(forKey: Contact.operationsKey) {
                result = try? self.decoder.decode([ContactOperation].self, from: data)
            }
        }
        return result ?? []
    }
    
    private func storeOperations(_ operations: [ContactOperation]) {
        operationLock.sync {
            if let data = try? self.encoder.encode(operations) {
                self.dataStore.setValue(data, forKey: Contact.operationsKey)
            }
        }
    }
    
    private func removeFirstOperation() {
        operationLock.sync {
            var operations = getOperations()
            if (!operations.isEmpty) {
                operations.removeFirst()
                storeOperations(operations)
            }
        }
    }
    
    private func prepareNextOperation() -> ContactOperation? {
        var next : ContactOperation?
        
        self.operationLock.sync {
            var operations = getOperations()
            
            while (!operations.isEmpty) {
                let first = operations.removeFirst()
                if (!self.shouldSkipOperation(first, isNext: true)) {
                    next = first
                    break
                }
            }
            
            if (next != nil) {
                switch(next?.type) {
                case .update:
                    // Collapse any sequential updates (ignoring anything that can be skipped inbetween)
                    while (!operations.isEmpty) {
                        let first = operations.first!
                        if (self.shouldSkipOperation(first, isNext: false)) {
                            operations.removeFirst()
                            continue
                        }
                        
                        if (first.type == .update) {
                            let firstPayload = first.payload as! UpdatePayload
                            let nextPayload = next!.payload as! UpdatePayload
                            
                            var combinedTags: [TagGroupUpdate] = []
                            combinedTags.append(contentsOf: firstPayload.tagUpdates ?? [])
                            combinedTags.append(contentsOf: nextPayload.tagUpdates ?? [])

                            var combinedAttributes: [AttributeUpdate] = []
                            combinedAttributes.append(contentsOf: firstPayload.attrubuteUpdates ?? [])
                            combinedAttributes.append(contentsOf: nextPayload.attrubuteUpdates ?? [])
                            
                            var combinedSubscriptionLists: [ScopedSubscriptionListUpdate] = []
                            combinedSubscriptionLists.append(contentsOf: firstPayload.subscriptionListsUpdates ?? [])
                            combinedSubscriptionLists.append(contentsOf: nextPayload.subscriptionListsUpdates ?? [])

                            operations.removeFirst()
                            next = ContactOperation.update(tagUpdates: combinedTags,
                                                           attributeUpdates: combinedAttributes,
                                                           subscriptionListUpdates: combinedSubscriptionLists)
                            continue
                        }
                        break
                    }
                    
                    if (next?.payload == nil) {
                        next = nil
                    }
                    
                case .identify:
                    // Only do last identify operation if the current contact info is not anonymous (ignoring anything that can be skipped inbetween)
                    if (self.isContactIDRefreshed && !(self.lastContactInfo?.isAnonymous ?? false)) {
                        while (!operations.isEmpty) {
                            let first = operations.first!
                            if (self.shouldSkipOperation(first, isNext: false)) {
                                operations.removeFirst()
                                continue
                            }
                            
                            if (first.type == .identify) {
                                next = operations.removeFirst()
                                continue
                            }
                            
                            break
                        }
                    }
                    
                   if (next?.payload == nil) {
                       next = nil
                   }
                    
                default:
                    break
                }
            }
            
            if let next = next {
                storeOperations([next] + operations)
            } else {
                storeOperations(operations)
            }
        }
        
        return next
    }
    
    func migrateNamedUser() {
        defer {
            self.dataStore.removeObject(forKey: Contact.legacyNamedUserKey)
            self.dataStore.removeObject(forKey: Contact.legacyPendingTagGroupsKey)
            self.dataStore.removeObject(forKey: Contact.legacyPendingAttributesKey)
        }
        
        guard let legacyNamedUserID = self.dataStore.string(forKey: Contact.legacyNamedUserKey) else {
            return
        }
  
        if self.lastContactInfo == nil {
            self.identify(legacyNamedUserID)
        }
        
        if (self.privacyManager.isEnabled([.contacts, .tagsAndAttributes])) {
            var pendingTagUpdates : [TagGroupUpdate]?
            var pendingAttributeUpdates : [AttributeUpdate]?
            
            if let pendingTagGroupsData = self.dataStore.data(forKey: Contact.legacyPendingTagGroupsKey) {
                if let pendingTagGroups = NSKeyedUnarchiver.unarchiveObject(with: pendingTagGroupsData) as? [TagGroupsMutation] {
                    pendingTagUpdates = pendingTagGroups.map { $0.tagGroupUpdates }.reduce([], +)
                }
            }
            
            if let pendingAttributesData = self.dataStore.data(forKey: Contact.legacyPendingAttributesKey) {
                if let pendingAttributes = NSKeyedUnarchiver.unarchiveObject(with: pendingAttributesData) as? [AttributePendingMutations] {
                    pendingAttributeUpdates = pendingAttributes.map { $0.attributeUpdates }.reduce([], +)
                }
            }
            
            if (!(pendingTagUpdates?.isEmpty ?? true && pendingAttributeUpdates?.isEmpty ?? true)) {
                let operation = ContactOperation.update(tagUpdates: pendingTagUpdates, attributeUpdates: pendingAttributeUpdates)
                addOperation(operation)
            }
        }
    }

    private func notifyChannelSubscriptionListUpdates(_ updates: [ScopedSubscriptionListUpdate]) {
        let channelUpdates = updates
            .filter { $0.scope == .app }
            .map { SubscriptionListUpdate(listId: $0.listId, type: $0.type) }

        guard !channelUpdates.isEmpty else { return }

        self.channel.processContactSubscriptionUpdates(channelUpdates)
    }
}

internal struct ContactInfo : Codable {
    var contactID: String
    var isAnonymous: Bool
    var namedUserID: String?
}

internal struct InternalContactData : Codable {
    var tags: [String : [String]]
    var attributes: [String : JsonValue]
    var channels: [AssociatedChannel]
    var subscriptionLists: [String : [ChannelScope]]
}

