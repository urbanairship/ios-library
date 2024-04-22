/* Copyright Airship and Contributors */

import CoreData

/// - Note: For internal use only. :nodoc:
public protocol CoreDataDelegate: AnyObject {
    func persistentStoreCreated(
        _ store: NSPersistentStore,
        name: String,
        context: NSManagedObjectContext
    )
}


/// - Note: For internal use only. :nodoc:
public final class UACoreData: @unchecked Sendable {

    public enum MergePolicy: Sendable {
        case mergeByPropertyObjectTrump
    }

    private let UAManagedContextStoreDirectory = "com.urbanairship.no-backup"

    private let context: NSManagedObjectContext
    private let storeNames: [String]

    public let inMemory: Bool

    private var shouldCreateStore = false
    private var pendingStores: [String]
    private var isFinished = false

    public weak var delegate: CoreDataDelegate?


    public init(
        modelURL: URL,
        inMemory: Bool = false,
        stores: [String],
        mergePolicy: MergePolicy? = nil
    ) {
        let moc = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        let mom = NSManagedObjectModel(contentsOf: modelURL)
        if let mom = mom {
            let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
            moc.persistentStoreCoordinator = psc
        }

        if let mergePolicy = mergePolicy {
            switch(mergePolicy) {
            case .mergeByPropertyObjectTrump:
                moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            }
        }

        self.context = moc
        self.pendingStores = stores
        self.storeNames = stores
        self.inMemory = inMemory

        #if !os(watchOS)
        Task { @MainActor in
            if (UIApplication.shared.isProtectedDataAvailable) {
                protectedDataAvailable()
            } else {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(protectedDataAvailable),
                    name: UIApplication.protectedDataDidBecomeAvailableNotification,
                    object: nil
                )
            }
        }

        #endif
    }

    public func perform(
        skipIfStoreNotCreated: Bool = false,
        _ block: @Sendable @escaping (NSManagedObjectContext) throws -> Void
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform({ [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                guard !self.isFinished else {
                    continuation.resume()
                    return
                }

                if (skipIfStoreNotCreated) {
                    guard self.inMemory || self.storesExistOnDisk() else {
                        continuation.resume()
                        return
                    }
                }

                self.shouldCreateStore = true
                self.createPendingStores()

                if (self.context.persistentStoreCoordinator?
                    .persistentStores
                    .count ?? 0) != 0
                {
                    do {
                        try block(self.context)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }

                } else {
                    continuation.resume(
                        throwing: AirshipErrors.error(
                            "Persistent store unable to be created"
                        )
                    )
                }
            })
        }
    }

    public func performWithNullableResult<T: Sendable>(
        skipIfStoreNotCreated: Bool = false,
        _ block: @Sendable @escaping (NSManagedObjectContext) throws -> T?
    ) async throws -> T? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform { [weak self] in
                guard let self else {
                    return
                }

                guard !self.isFinished else {
                    continuation.resume(throwing: AirshipErrors.error("Finished"))
                    return
                }

                if (skipIfStoreNotCreated) {
                    guard self.inMemory || self.storesExistOnDisk() else {
                        continuation.resume(returning: nil)
                        return
                    }
                }

                self.shouldCreateStore = true
                self.createPendingStores()

                if (self.context.persistentStoreCoordinator?
                    .persistentStores
                    .count ?? 0) != 0
                {
                    do {
                        continuation.resume(returning: try block(self.context))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(
                        throwing: AirshipErrors.error(
                            "Persistent store unable to be created"
                        )
                    )
                }
            }
        }
    }

    public func performWithResult<T: Sendable>(
        _ block: @Sendable @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform { [weak self] in
                guard let self else {
                    return
                }

                guard !self.isFinished else {
                    continuation.resume(throwing: AirshipErrors.error("Finished"))
                    return
                }

                self.shouldCreateStore = true
                self.createPendingStores()

                if (self.context.persistentStoreCoordinator?
                    .persistentStores
                    .count ?? 0) != 0
                {
                    do {
                        continuation.resume(returning: try block(self.context))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(
                        throwing: AirshipErrors.error(
                            "Persistent store unable to be created"
                        )
                    )
                }
            }
        }
    }

    
    @discardableResult
    public func safePerform<T: Sendable>(
        _ block: @escaping @Sendable (Bool, NSManagedObjectContext) -> T
    ) async -> T? {
        
        do {
            return try await performWithResult { context in
                return block(true, context)
            }
        } catch {
            if context.persistentStoreCoordinator?.persistentStores.count == 0 {
                return block(false, context)
            } else {
                AirshipLogger.error("Failed to perform block: \(error)")
                return nil
            }
        }
    }

    public func performBlockIfStoresExist(
        _ block: @escaping @Sendable (Bool, NSManagedObjectContext) -> Void
    ) async {
        
        do {
            try await perform(skipIfStoreNotCreated: true) { context in
                block(true, context)
            }
        } catch {
            if context.persistentStoreCoordinator?.persistentStores.count == 0 {
                block(false, context)
            } else {
                AirshipLogger.error("Failed to perform block: \(error)")
            }
        }
    }

    public func waitForIdle() {
        context.performAndWait({})
    }

    @objc
    func protectedDataAvailable() {
        context.perform({ [weak self] in
            guard let self else {
                return
            }

            if self.shouldCreateStore {
                self.createPendingStores()
            }
        })
    }

    func createPendingStores() {
        guard !self.isFinished else {
            return
        }

        for name in pendingStores {
            var created = false
            if inMemory {
                created = createInMemoryStore(storeName: name)
            } else {
                created = createSqlStore(storeName: name)
            }

            if created {
                pendingStores.removeAll { $0 == name }
            }
        }
    }

    func createInMemoryStore(storeName: String) -> Bool {
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: NSNumber(value: true),
            NSInferMappingModelAutomaticallyOption: NSNumber(value: true),
        ]

        do {
            let result = try context.persistentStoreCoordinator?
                .addPersistentStore(
                    ofType: NSInMemoryStoreType,
                    configurationName: nil,
                    at: nil,
                    options: options
                )

            if let result = result {
                AirshipLogger.debug("Created store: \(storeName)")
                self.delegate?
                    .persistentStoreCreated(
                        result,
                        name: storeName,
                        context: context
                    )
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
        let baseDirectory =
            fileManager.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            )
            .last
        #else
        let baseDirectory =
            fileManager.urls(
                for: .libraryDirectory,
                in: .userDomainMask
            )
            .last
        #endif

        return baseDirectory?
            .appendingPathComponent(UAManagedContextStoreDirectory)
    }

    func storeURL(_ storeName: String?) -> URL? {
        return storeSQLDirectory()?.appendingPathComponent(storeName ?? "")
    }

    func storesExistOnDisk() -> Bool {
        for name in self.storeNames {
            let storeURL = self.storeURL(name)
            if storeURL != nil
                && FileManager.default.fileExists(atPath: storeURL?.path ?? "")
            {
                return true
            }
        }

        return false
    }

    public func deleteStoresOnDisk() throws {
        for name in self.storeNames {
            guard let storeURL = self.storeURL(name) else {
                continue
            }

            if FileManager.default.fileExists(atPath: storeURL.path) {
                try FileManager.default.removeItem(atPath: storeURL.path)
            }
        }
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
                    attributes: nil
                )
            } catch {
                AirshipLogger.debug(
                    "Failed to create airship SQL directory. \(error)"
                )
                return false
            }
        }

        // Make sure it does not already exist
        for store in context.persistentStoreCoordinator?.persistentStores ?? []
        {
            if (store.url == storeURL) && (store.type == NSSQLiteStoreType) {
                return true
            }
        }

        let options = [
            NSMigratePersistentStoresAutomaticallyOption: NSNumber(value: true),
            NSInferMappingModelAutomaticallyOption: NSNumber(value: true),
        ]

        do {
            let result = try context.persistentStoreCoordinator?
                .addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: storeURL,
                    options: options
                )

            if let result = result {
                correctFilePermissions(url: storeURL)
                AirshipLogger.debug(
                    "Created store: \(storeName) url: \(storeURL)"
                )
                self.delegate?
                    .persistentStoreCreated(
                        result,
                        name: storeName,
                        context: context
                    )
                return true
            } else {
                AirshipLogger.error("Failed to create store \(storeName)")
            }
        } catch {
            AirshipLogger.error("Failed to create store \(storeName): \(error)")
        }
        return false
    }
    
    private func correctFilePermissions(url: URL) {
        do {
            let attributes = [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        } catch(let exception) {
            AirshipLogger.error("Failed to set file attribute \(exception)")
        }
    }

    public class func save(_ context: NSManagedObjectContext) throws {
        guard context.persistentStoreCoordinator?.persistentStores.isEmpty == false else {
            throw AirshipErrors.error("Unable to save context. Missing persistent store.")
        }

        try context.save()
    }

    @discardableResult
    public class func safeSave(_ context: NSManagedObjectContext?) -> Bool {
        guard let context = context else {
            AirshipLogger.error("Unable to save, context nil.")
            return false
        }

        do {
            try save(context)
        } catch {
            AirshipLogger.error("Error saving context \(error)")
            return false
        }

        return true
    }
}
