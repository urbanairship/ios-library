/* Copyright Airship and Contributors */

import Foundation

/**
 * Airship contact. A contact is distinct from a channel and  represents a "user"
 * within Airship. Contacts may be named and have channels associated with it.
 */
@objc(UAContact)
public class Contact : UAComponent {

    static let updateTaskID = "Contact.update"
    static let operationsKey = "Contact.operations"
    static let contactInfoKey = "Contact.contactInfo"
    static let anonContactDataKey = "Contact.anonContactData"
    static let resolveDateKey = "Contact.resolveDate"
    
    static let foregroundResolveInterval : TimeInterval = 24 * 60 * 60 // 24 hours

    private let dataStore: UAPreferenceDataStore
    private let privacyManager: UAPrivacyManager
    private let channel: AirshipChannelProtocol
    private let contactAPIClient: ContactsAPIClientProtocol
    private let taskManager: TaskManagerProtocol
    private let dispatcher = UADispatcher.serial()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let date : UADate
    
    @objc
    public weak var conflictDelegate: ContactConflictDelegate?

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
    
    private var isContactIDRefreshed = false
    private var operationLock = Lock()
 
    /**
     * Internal only
     * :nodoc:
     */
    init(dataStore: UAPreferenceDataStore,
                channel: AirshipChannelProtocol,
                privacyManager: UAPrivacyManager,
                contactAPIClient: ContactsAPIClientProtocol,
                taskManager: TaskManagerProtocol,
                notificationCenter: NotificationCenter = NotificationCenter.default,
                date: UADate = UADate()) {
        self.dataStore = dataStore
        self.channel = channel
        self.privacyManager = privacyManager
        self.contactAPIClient = contactAPIClient
        self.taskManager = taskManager
        self.date = date
        
        super.init(dataStore: dataStore)
        
        self.taskManager.register(taskID: Contact.updateTaskID, dispatcher: self.dispatcher) { [weak self] task in
            self?.handleUpdateTask(task: task)
        }
        
        notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UAAppStateTracker.didBecomeActiveNotification,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(channelCreated),
            name: NSNotification.Name.UAChannelCreatedEvent,
            object: nil)
        
        notificationCenter.addObserver(
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
                            channel: UAChannel,
                            privacyManager: UAPrivacyManager) {
        self.init(dataStore: dataStore,
                  channel: channel,
                  privacyManager: privacyManager,
                  contactAPIClient: ContactAPIClient(config: config),
                  taskManager: UATaskManager.shared)
    }

    /**
     * Associates the contact with the given named user identifier.
     * - Parameters:
     *   - namedUserID: The named user ID.
     */
    @objc
    public func identify(_ namedUserID: String) {
        guard self.privacyManager.isEnabled(.contacts) else {
            AirshipLogger.warn("Contacts disabled. Enable to identify user.")
            return
        }
        
        self.addOperation(ContactOperation.identify(identifier: namedUserID))
        self.enqueueTask()
    }

    /**
     * Disassociate the channel from its current contact, and create a new
     * un-named contact.
     */
    @objc
    public func reset() {
        guard self.privacyManager.isEnabled(.contacts) else {
            return
        }

        self.addOperation(ContactOperation.reset())
        self.enqueueTask()
    }

    /**
     * Edits tags.
     * - Returns: A tag groups editor.
     */
    @objc
    public func editTags() -> TagGroupsEditor {
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

    /**
     * Edits attributes.
     * - Returns: An attributes editor.
     */
    @objc
    public func editAttibutes() -> AttributesEditor {
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
    private func channelCreated() {
        resolveContact()
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
                if (response?.isSuccess == true && contactInfo.isAnonymous) {
                    self.updateAnonData(updatePayload)
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
                if let lastContactInfo = self.lastContactInfo {
                    if (lastContactInfo.contactID != response.contactID) {
                        if (lastContactInfo.isAnonymous) {
                            self.onConflict(namedUserID)
                        }
                        self.anonContactData = nil
                    }
                }
                
                if (response.isAnonymous == false) {
                    self.anonContactData = nil
                }

                self.isContactIDRefreshed = true
                self.lastContactInfo = ContactInfo(contactID: response.contactID!, isAnonymous: response.isAnonymous!, namedUserID: namedUserID)
                self.channel.updateRegistration()
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
