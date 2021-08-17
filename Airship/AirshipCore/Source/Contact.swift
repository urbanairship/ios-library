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
     *  - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
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
     *  - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editAttributes(_ editorBlock: (AttributesEditor) -> Void)
}


/**
 * Airship contact. A contact is distinct from a channel and  represents a "user"
 * within Airship. Contacts may be named and have channels associated with it.
 */
@objc(UAContact)
public class Contact : UAComponent, ContactProtocol {

    // NOTE: For internal use only. :nodoc:
    static let supplier : () -> (ContactProtocol) = {
        return Contact.shared()
    }
    
    
    static let updateTaskID = "Contact.update"
    static let operationsKey = "Contact.operations"
    static let contactInfoKey = "Contact.contactInfo"
    static let anonContactDataKey = "Contact.anonContactData"
    static let resolveDateKey = "Contact.resolveDate"

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

    private let dataStore: UAPreferenceDataStore
    private let config: UARuntimeConfig
    private let privacyManager: UAPrivacyManager
    private let channel: ChannelProtocol
    private let contactAPIClient: ContactsAPIClientProtocol
    private let taskManager: TaskManagerProtocol
    private let dispatcher = UADispatcher.serial()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let date : UADate
    private let notificationCenter: NotificationCenter

    @objc
    public weak var conflictDelegate: ContactConflictDelegate?

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
    
    private var isContactIDRefreshed = false
    private var operationLock = Lock()
 
    /**
     * Internal only
     * :nodoc:
     */
    init(dataStore: UAPreferenceDataStore,
         config: UARuntimeConfig,
         channel: ChannelProtocol,
         privacyManager: UAPrivacyManager,
         contactAPIClient: ContactsAPIClientProtocol,
         taskManager: TaskManagerProtocol,
         notificationCenter: NotificationCenter = NotificationCenter.default,
         date: UADate = UADate()) {
        
        self.dataStore = dataStore
        self.config = config
        self.channel = channel
        self.privacyManager = privacyManager
        self.contactAPIClient = contactAPIClient
        self.taskManager = taskManager
        self.date = date
        self.notificationCenter = notificationCenter
        
        super.init(dataStore: dataStore)
        
        
        self.taskManager.register(taskID: Contact.updateTaskID, dispatcher: self.dispatcher) { [weak self] task in
            self?.handleUpdateTask(task: task)
        }
        
        self.channel.addRegistrationExtender { [weak self] payload, completionHandler in
            payload.contactID = self?.lastContactInfo?.contactID
            completionHandler(payload)
        }
        
        migrateNamedUser()
        
        self.notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UAAppStateTracker.didBecomeActiveNotification,
            object: nil)

        self.notificationCenter.addObserver(
            self,
            selector: #selector(channelCreated),
            name: Channel.channelCreatedEvent,
            object: nil)
        
        self.notificationCenter.addObserver(
            self,
            selector: #selector(checkPrivacyManager),
            name: UAPrivacyManager.changeEvent,
            object: nil)
        
        self.checkPrivacyManager()
        self.enqueueTask()
    }
    
    /**
     * Internal only
     * :nodoc:
     */
    @objc
    public convenience init(dataStore: UAPreferenceDataStore,
                            config: UARuntimeConfig,
                            channel: Channel,
                            privacyManager: UAPrivacyManager) {
        self.init(dataStore: dataStore,
                  config: config,
                  channel: channel,
                  privacyManager: privacyManager,
                  contactAPIClient: ContactAPIClient(config: config),
                  taskManager: UATaskManager.shared)
    }

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
    
    @objc
    public func reset() {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        self.addOperation(ContactOperation.reset())
        self.enqueueTask()
    }

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
    
    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }

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

    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    /**
     * :nodoc:
     */
    public override func onComponentEnableChange() {
        if (self.componentEnabled()) {
            self.enqueueTask()
        }
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
        self.taskManager.enqueueRequest(taskID: Contact.updateTaskID, options: UATaskRequestOptions.defaultOptions)
    }
    
    private func handleUpdateTask(task: UATask) {
        guard let channelID = self.channel.identifier else {
            task.taskCompleted()
            return
        }
        
        guard let operation = prepareNextOperation() else {
            task.taskCompleted()
            return
        }
        
        let semaphore = UASemaphore()
        
        let disposable = self.performOperation(operation: operation, channelID: channelID) { response in
            if let response = response {
                if (response.isSuccess) {
                    self.removeFirstOperation()
                    task.taskCompleted()
                    self.enqueueTask()
                } else if (response.isServerError) {
                    task.taskFailed()
                } else {
                    task.taskCompleted()
                }
            } else {
                task.taskFailed()
            }
            
            semaphore.signal()
        }
        
        task.expirationHandler = {
            disposable?.dispose()
        }
        
        semaphore.wait()
    }
    
    private func performOperation(operation: ContactOperation, channelID: String, completionHandler: @escaping (UAHTTPResponse?) -> Void) -> UADisposable? {
        switch(operation.type) {
        case .update:
            guard let contactInfo = self.lastContactInfo else {
                self.removeFirstOperation()
                completionHandler(nil)
                return nil
            }
            
            let updatePayload = operation.payload as! UpdatePayload
            return self.contactAPIClient.update(identifier: contactInfo.contactID, tagGroupUpdates: updatePayload.tagUpdates, attributeUpdates: updatePayload.attrubuteUpdates) { response, error in
                Contact.logOperationResult(operation: operation, response: response, error: error)
                if (response?.isSuccess == true) {
                    if (contactInfo.isAnonymous) {
                        self.updateAnonData(updatePayload)
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
            let identifyPayload = operation.payload as! IdentifyPayload
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
        }
    }
    
    private func shouldSkipOperation(_ operation: ContactOperation) -> Bool {
        switch(operation.type) {
        case .update:
            return false
            
        case .identify:
            let payload = operation.payload as! IdentifyPayload
            return self.isContactIDRefreshed && self.lastContactInfo?.namedUserID == payload.identifier
            
        case .reset:
            return (self.lastContactInfo?.isAnonymous ?? false) && self.anonContactData != nil
            
        case .resolve:
            return self.isContactIDRefreshed
        }
    }
    
    private func onConflict(_ namedUserID: String?) {
        guard let data = self.anonContactData else {
            return
        }
        
        let attributes = data.attributes.compactMapValues { $0.value() }
        let anonData = ContactData(tags: data.tags, attributes: attributes)
        
        UADispatcher.main.dispatchAsync {
            self.conflictDelegate?.onConflict(anonymousContactData: anonData, namedUserID: namedUserID)
        }
    }
    
    private func updateAnonData(_ updates: UpdatePayload) {
        let data = self.anonContactData
        let tags = AudienceUtils.applyTagUpdates(tagGroups: data?.tags, tagGroupUpdates: updates.tagUpdates)
        let attributes = AudienceUtils.applyAttributeUpdates(attributes: data?.attributes, attributeUpdates: updates.attrubuteUpdates)
        
        if (tags.isEmpty && attributes.isEmpty) {
            self.anonContactData = nil
        } else {
            self.anonContactData = InternalContactData(tags: tags, attributes: attributes)
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
    
    private class func logOperationResult(operation: ContactOperation, response: UAHTTPResponse?, error: Error?) {
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
                if (!self.shouldSkipOperation(first)) {
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
                        if (self.shouldSkipOperation(first)) {
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

                            operations.removeFirst()
                            next = ContactOperation.update(tagUpdates: combinedTags, attributeUpdates: combinedAttributes)
                            continue
                        }
                        
                        break
                    }
                    
                case .identify:
                    // Only do last identify operation if the current contact info is not anonymous (ignoring anything that can be skipped inbetween)
                    if (self.isContactIDRefreshed && !(self.lastContactInfo?.isAnonymous ?? false)) {
                        while (!operations.isEmpty) {
                            let first = operations.first!
                            if (self.shouldSkipOperation(first)) {
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
  
        guard self.lastContactInfo == nil else {
            return
        }
        
        self.identify(legacyNamedUserID)
        
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
            
            if (pendingTagUpdates != nil || pendingAttributeUpdates != nil) {
                let operation = ContactOperation.update(tagUpdates: pendingTagUpdates, attributeUpdates: pendingAttributeUpdates)
                addOperation(operation)
            }
        }
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
}
