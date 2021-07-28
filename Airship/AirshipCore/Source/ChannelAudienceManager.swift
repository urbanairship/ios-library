/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAChannelAudienceManager)
public class ChannelAudienceManager : NSObject {
    static let updateTaskID = "ChannelAudienceManager.update"
    static let updatesKey = "UAChannel.audienceUpdates"
    static let maxCacheTime : TimeInterval = 600 // 10 minutes

    private let dataStore: UAPreferenceDataStore
    private let privacyManager: UAPrivacyManager
    private let taskManager: TaskManagerProtocol
    private let subscriptionListClient: SubscriptionListAPIClientProtocol
    private let date: UADate
    private let dispatcher = UADispatcher.serial()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let updateLock = Lock()
    
    private var cachedSubscriptionListResponse : CachedSubscriptionListResponse?
    
    @objc
    public var channelID: String? {
        didSet {
            self.enqueueTask()
        }
    }
    
    @objc
    public var enabled: Bool = false {
        didSet {
            self.enqueueTask()
        }
    }
    
    init(dataStore: UAPreferenceDataStore,
        taskManager: TaskManagerProtocol,
        subscriptionListClient: SubscriptionListAPIClientProtocol,
        privacyManager: UAPrivacyManager,
        notificationCenter: NotificationCenter,
        date: UADate) {
        
        self.dataStore = dataStore;
        self.taskManager = taskManager;
        self.privacyManager = privacyManager;
        self.subscriptionListClient = subscriptionListClient
        self.date = date
        
        super.init()
        
        self.taskManager.register(taskID: ChannelAudienceManager.updateTaskID, dispatcher: self.dispatcher) { [weak self] task in
            self?.handleUpdateTask(task)
        }
        
        notificationCenter.addObserver(
            self,
            selector: #selector(checkPrivacyManager),
            name: UAPrivacyManager.changeEvent,
            object: nil)
        
        notificationCenter.addObserver(
            self,
            selector: #selector(enqueueTask),
            name: NSNotification.Name.UARemoteConfigURLManagerConfigUpdated,
            object: nil)
        
        self.checkPrivacyManager()
    }
    
    @objc
    public convenience init(dataStore: UAPreferenceDataStore,
                            config: UARuntimeConfig,
                            privacyManager: UAPrivacyManager) {
        
        self.init(dataStore: dataStore,
                  taskManager: UATaskManager.shared,
                  subscriptionListClient: SubscriptionListAPIClient(config: config),
                  privacyManager: privacyManager,
                  notificationCenter: NotificationCenter.default,
                  date: UADate())
    }
    
    @objc
    public func editSubscriptionLists() -> SubscriptionListEditor {
        return SubscriptionListEditor() { updates in
            guard !updates.isEmpty else {
                return
            }
            
            guard self.privacyManager.isEnabled( .tagsAndAttributes) else {
                AirshipLogger.warn("Tags and attributes are disabled. Enable to apply subscription list edits.")
                return
            }
            
            let audienceUpdate = AudienceUpdate(subscriptionListUpdates: updates)
            self.addUpdate(audienceUpdate)
            self.enqueueTask()
        }
    }
    
    @objc
    @discardableResult
    public func fetchSubscriptionLists(completionHandler: @escaping ([String]?, Error?) -> Void) -> UADisposable {
        
        var callback: (([String]?, Error?) -> Void)? = completionHandler
        let disposable = UADisposable() {
            callback = nil
        }
        
        self.dispatcher.dispatchAsync {
            guard let channelID = self.channelID else {
                completionHandler(nil, AirshipErrors.error("Channel not created yet"))
                return
            }
            
            if let cached = self.cachedSubscriptionListResponse {
                if (self.date.now.timeIntervalSince(cached.date) < ChannelAudienceManager.maxCacheTime) {
                    var ids = cached.listIDs
                    
                    if let pending = ChannelAudienceManager.collapse(self.getUpdates()) {
                        pending.subscriptionListUpdates.forEach { update in
                            switch(update.type) {
                            case .subscribe:
                                ids.append(update.listId)
                            case .unsubscribe:
                                ids.removeAll(where: { $0 == update.listId })
                            }
                        }
                    }
                    
                    completionHandler(ids, nil)
                    return
                }
            }
            
            let semaphore = UASemaphore()
            self.subscriptionListClient.get(channelID: channelID) { response, error in
                if let response = response {
                    AirshipLogger.debug("Fetched lists finished with response: \(response)")
                    if (response.isSuccess == true) {
                        AirshipLogger.debug("Fetched lists finished with response: \(response)")
                        let listIDs = response.listIDs ?? []
                        self.cachedSubscriptionListResponse = CachedSubscriptionListResponse(listIDs: listIDs, date: self.date.now)
                        callback?(listIDs, nil)
                    } else {
                        callback?(nil, AirshipErrors.error("Failed to fetch subscriptoin lists with status: \(response.status)"))
                    }
                } else {
                    if let error = error {
                        callback?(nil, AirshipErrors.error("Failed to fetch subscriptoin lists with error: \(error)"))
                    } else {
                        callback?(nil, AirshipErrors.error("Failed to fetch subscriptoin lists"))
                    }
                }
                semaphore.signal()
            }
            
            semaphore.wait()
        }
        
        return disposable
    }
    
    @objc
    private func checkPrivacyManager() {
        if (!self.privacyManager.isEnabled(.tagsAndAttributes)) {
            updateLock.sync {
                self.dataStore.removeObject(forKey: ChannelAudienceManager.updatesKey)
            }
        }
    }
    
    @objc
    private func enqueueTask() {
        if (self.enabled && self.channelID != nil) {
            self.taskManager.enqueueRequest(taskID: ChannelAudienceManager.updateTaskID,
                                            options: UATaskRequestOptions.defaultOptions)
        }
    }
    
    private func handleUpdateTask(_ task: UATask)  {
        guard self.enabled && self.privacyManager.isEnabled(.tagsAndAttributes) else {
            task.taskCompleted()
            return
        }
        
        guard let channelID = self.channelID, let update = self.prepareNextUpdate() else {
            task.taskCompleted()
            return
        }
        
        let semaphore = UASemaphore()
        
        let disposable = self.subscriptionListClient.update(channelID: channelID,
                                                            subscriptionLists: update.subscriptionListUpdates) { response, error in
            
            if let response = response {
                AirshipLogger.debug("Update finished with response: \(response)")
                if (response.isSuccess) {
                    self.popFirstUpdate()
                    self.cachedSubscriptionListResponse = nil
                    task.taskCompleted()
                    self.enqueueTask()
                } else if (response.isServerError) {
                    task.taskFailed()
                } else {
                    task.taskCompleted()
                }
            } else {
                if let error = error {
                    AirshipLogger.debug("Update failed with error: \(error)")
                } else {
                    AirshipLogger.debug("Update failed")
                }
                task.taskFailed()
            }
            
            semaphore.signal()
        }
        
        task.expirationHandler = {
            disposable.dispose()
        }
        
        semaphore.wait()
    }
    
    private func addUpdate(_ update: AudienceUpdate) {
        self.updateLock.sync {
            var updates = getUpdates()
            updates.append(update)
            self.storeUpdates(updates)
        }
    }
    
    private func getUpdates() -> [AudienceUpdate] {
        var result: [AudienceUpdate]?
        updateLock.sync {
            if let data = self.dataStore.data(forKey: ChannelAudienceManager.updatesKey) {
                result = try? self.decoder.decode([AudienceUpdate].self, from: data)
            }
        }
        return result ?? []
    }
    
    private func storeUpdates(_ operations: [AudienceUpdate]) {
        updateLock.sync {
            if let data = try? self.encoder.encode(operations) {
                self.dataStore.setValue(data, forKey: ChannelAudienceManager.updatesKey)
            }
        }
    }
    
    private func popFirstUpdate() {
        updateLock.sync {
            var updates = getUpdates()
            if (!updates.isEmpty) {
                updates.removeFirst()
                storeUpdates(updates)
            }
        }
    }
    
    private func prepareNextUpdate() -> AudienceUpdate? {
        var nextUpdate: AudienceUpdate? = nil
        updateLock.sync {
            let updates = self.getUpdates()
            if let collapsed = ChannelAudienceManager.collapse(updates) {
                self.storeUpdates([collapsed])
                nextUpdate = collapsed
            } else {
                self.storeUpdates([])
            }
        }
        return nextUpdate
    }
    
    private class func collapse(_ updates: [AudienceUpdate]) -> AudienceUpdate? {
        var allUpdates : [SubscriptionListUpdate] = []
        
        updates.forEach { allUpdates.append(contentsOf: $0.subscriptionListUpdates) }
        allUpdates = AudienceUtils.collapse(allUpdates)
        
        if (allUpdates.isEmpty) {
            return nil
        } else {
            return AudienceUpdate(subscriptionListUpdates: allUpdates)
        }
    }
}

internal struct AudienceUpdate : Codable {
    let subscriptionListUpdates : [SubscriptionListUpdate]
}

internal struct CachedSubscriptionListResponse {
    let listIDs: [String]
    let date: Date
}
