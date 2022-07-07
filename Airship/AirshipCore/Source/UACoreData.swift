/* Copyright Airship and Contributors */

import CoreData

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UACoreDataDelegate)
public protocol CoreDataDelegate: AnyObject {
    @objc
    func persistentStoreCreated(_ store: NSPersistentStore, name: String, context: NSManagedObjectContext)
}

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UACoreData)
public class UACoreData : NSObject {
    private let UAManagedContextStoreDirectory = "com.urbanairship.no-backup"

    private let context: NSManagedObjectContext
    private let storeNames: [String]

    @objc
    public let inMemory: Bool

    private var shouldCreateStore = false
    private var pendingStores: [String]
    private var isFinished = false

    @objc
    public weak var delegate: CoreDataDelegate?;

    init(context: NSManagedObjectContext, inMemory: Bool, stores: [String]) {
        self.context = context
        self.pendingStores = stores
        self.storeNames = stores
        self.inMemory = inMemory

        super.init()

        #if !os(watchOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(protectedDataAvailable),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil)
        #endif
    }

    @objc
    public convenience init(modelURL: URL, inMemory: Bool, stores: [String]) {
        self.init(modelURL: modelURL, inMemory: inMemory, stores: stores, mergePolicy: NSErrorMergePolicy)
    }

    @objc
    public convenience init(modelURL: URL, inMemory: Bool, stores: [String], mergePolicy: Any?) {
        let moc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        let mom = NSManagedObjectModel(contentsOf: modelURL)
        if let mom = mom {
            let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
            moc.persistentStoreCoordinator = psc
        }

        if let mergePolicy = mergePolicy {
            moc.mergePolicy = mergePolicy
        }

        self.init(context: moc, inMemory: inMemory, stores: stores)
    }

    @objc(safePerformBlock:)
    public func safePerform(_ block: @escaping (Bool, NSManagedObjectContext) -> Void) {
        context.perform({ [weak self] in
            guard let strongSelf = self else {
                return
            }

            guard (!strongSelf.isFinished) else {
                return
            }

            strongSelf.shouldCreateStore = true
            strongSelf.createPendingStores()

            if (strongSelf.context.persistentStoreCoordinator?.persistentStores.count ?? 0) != 0 {
                block(true, strongSelf.context)
            } else {
                block(false, strongSelf.context)
            }
        })
    }

    @objc(safePerformBlockAndWait:)
    public func safePerformAndWait(_ block: @escaping (Bool, NSManagedObjectContext) -> Void) {
        context.performAndWait({ [weak self] in
            guard let strongSelf = self else {
                return
            }

            guard (!strongSelf.isFinished) else {
                return
            }

            strongSelf.shouldCreateStore = true
            strongSelf.createPendingStores()

            if (strongSelf.context.persistentStoreCoordinator?.persistentStores.count ?? 0) != 0 {
                block(true, strongSelf.context)
            } else {
                block(false, strongSelf.context)
            }
        })
    }

    @objc
    public func performBlockIfStoresExist(_ block: @escaping (Bool, NSManagedObjectContext) -> Void) {
        context.perform({ [weak self] in
            guard let strongSelf = self else {
                return
            }

            guard !strongSelf.isFinished else {
                return
            }

            guard strongSelf.inMemory || strongSelf.storesExistOnDisk() else {
                return
            }

            strongSelf.shouldCreateStore = true
            strongSelf.createPendingStores()

            if (strongSelf.context.persistentStoreCoordinator?.persistentStores.count ?? 0) != 0 {
                block(true, strongSelf.context)
            } else {
                block(false, strongSelf.context)
            }
        })
    }

    @objc
    public func shutDown() {
        isFinished = true
    }

    @objc
    public func waitForIdle() {
        context.performAndWait({})
    }

    @objc
    func protectedDataAvailable() {
        context.perform({ [weak self] in
            guard let strongSelf = self else {
                return
            }

            if (strongSelf.shouldCreateStore) {
                strongSelf.createPendingStores()
            }
        })
    }

    func createPendingStores() {
        guard !self.isFinished else {
            return
        }

        for name in pendingStores {
            var created = false
            if (inMemory) {
                created = createInMemoryStore(storeName: name)
            } else {
                created = createSqlStore(storeName: name)
            }

            if (created) {
                pendingStores.removeAll { $0 == name }
            }
        }
    }

    func createInMemoryStore(storeName: String) -> Bool {
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: NSNumber(value: true),
            NSInferMappingModelAutomaticallyOption: NSNumber(value: true)
        ]

        do {
            let result = try context.persistentStoreCoordinator?.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: options)

            if let result = result {
                AirshipLogger.debug("Created store: \(storeName)")
                self.delegate?.persistentStoreCreated(result, name: storeName, context: context)
                return true
            } else {
                AirshipLogger.error("Failed to create store \(storeName)")
            }
        } catch {
            AirshipLogger.error("Failed to create store \(storeName): \(error)")
        }

        return false
    }

    func storeSQLDirectory() -> URL? {
        let fileManager = FileManager.default

        #if os(tvOS)
        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).last
        #else
        let baseDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).last
        #endif

        return baseDirectory?.appendingPathComponent(UAManagedContextStoreDirectory)
    }

    func storeURL(_ storeName: String?) -> URL? {
        return storeSQLDirectory()?.appendingPathComponent(storeName ?? "")
    }

    func storesExistOnDisk() -> Bool {
        for name in self.storeNames {
            let storeURL = self.storeURL(name)
            if storeURL != nil && FileManager.default.fileExists(atPath: storeURL?.path ?? "") {
                return true
            }
        }

        return false
    }

    func createSqlStore(storeName: String) -> Bool {
        guard let storeURL = self.storeURL(storeName) else {
            return false
        }

        guard let storeDirectory = storeSQLDirectory() else {
            return false
        }

        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: storeDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: storeDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil)
            } catch {
                AirshipLogger.debug("Failed to create aiship SQL directory. \(error)")
                return false
            }
        }

        // Make sure it does not already exist
        for store in context.persistentStoreCoordinator?.persistentStores ?? [] {
            if (store.url == storeURL) && (store.type == NSSQLiteStoreType) {
                return true
            }
        }

        let options = [
            NSMigratePersistentStoresAutomaticallyOption: NSNumber(value: true),
            NSInferMappingModelAutomaticallyOption: NSNumber(value: true)
        ]

        do {
            let result = try context.persistentStoreCoordinator?.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options)

            if let result = result {
                AirshipLogger.debug("Created store: \(storeName) url: \(storeURL)")
                self.delegate?.persistentStoreCreated(result, name: storeName, context: context)
                return true
            } else {
                AirshipLogger.error("Failed to create store \(storeName)")
            }
        } catch {
            AirshipLogger.error("Failed to create store \(storeName): \(error)")
        }
        return false
    }

    @objc
    @discardableResult
    public class func safeSave(_ context: NSManagedObjectContext?) -> Bool {
        if (context?.persistentStoreCoordinator?.persistentStores.count ?? 0) == 0 {
            AirshipLogger.error("Unable to save context. Missing persistent store.")
            return false
        }

        do {
            try context?.save()
        } catch {
            AirshipLogger.error("Error saving context \(error)")
            return false
        }

        return true
    }
}
