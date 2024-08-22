/* Copyright Airship and Contributors */

import CoreData


/// - Note: For internal use only. :nodoc:
public actor UACoreData {
    private static let managedContextStoreDirectory = "com.urbanairship.no-backup"

    private let name: String
    private let modelURL: URL
    private let storeNames: [String]
    public nonisolated let inMemory: Bool


    private var shouldPrepareCoreData = false
    private var coreDataPrepared: Bool = false
    private var prepareCoreDataTask: Task<Void, Error>?

    private var _container: NSPersistentContainer?
    private var container: NSPersistentContainer {
        get async throws {
            try await prepareCoreData()
            guard let container = _container  else {
                throw AirshipErrors.error("Failed to get container")
            }
            return container
        }
    }

    private var _context: NSManagedObjectContext?
    private var context: NSManagedObjectContext {
        get async throws {
            if let context = _context {
                return context
            }

            let context = try await container.newBackgroundContext()
            _context = context
            return context
        }
    }

    public init(
        name: String,
        modelURL: URL,
        inMemory: Bool = false,
        stores: [String]
    ) {
        self.name = name
        self.modelURL = modelURL
        self.inMemory = inMemory
        self.storeNames = stores

        #if !os(watchOS)
        Task { @MainActor [weak self] in
            if (UIApplication.shared.isProtectedDataAvailable) {
                await self?.protectedDataAvailable()
            } else {
                guard let self else { return }
                NotificationCenter.default.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: nil, using: { _ in
                    Task { [weak self] in
                        await self?.protectedDataAvailable()
                    }
                })
            }
        }
        #endif
    }


    public func perform(
        skipIfStoreNotCreated: Bool = false,
        _ block: @Sendable @escaping (NSManagedObjectContext) throws -> Void
    ) async throws {
        if (skipIfStoreNotCreated) {
            guard self.inMemory || self.storesExistOnDisk() else {
                return
            }
        }

        let context = try await self.context
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    try block(context)
                    try context.saveIfChanged()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func performWithNullableResult<T: Sendable>(
        skipIfStoreNotCreated: Bool = false,
        _ block: @Sendable @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T? {
        if (skipIfStoreNotCreated) {
            guard self.inMemory || self.storesExistOnDisk() else {
                return nil
            }
        }

        return try await performWithResult(block)
    }

    public func performWithResult<T: Sendable>(
        _ block: @Sendable @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = try await self.context

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try block(context)
                    try context.saveIfChanged()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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

    private func protectedDataAvailable() {
        Task {
            if self.shouldPrepareCoreData {
                _ = try? await self.prepareCoreData()
            }
        }
    }

    private func prepareCoreData() async throws {
        if (coreDataPrepared) {
            return
        }

        try? await prepareCoreDataTask?.value

        let task = Task {
            let container = try (_container ?? makeContainer())
            if (_container == nil) {
                _container = container
            } 

            if !coreDataPrepared {
                try await prepareStore()
                try await loadStores(container: container)
                coreDataPrepared = true
            }
        }

        prepareCoreDataTask = task
        try await task.value
    }

    private func prepareStore() async throws {
        if !inMemory {
            guard let storeDirectory = self.storeSQLDirectory() else {
                throw AirshipErrors.error("Unable to get store directory.")
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
                    throw AirshipErrors.error(
                        "Failed to create airship SQL directory. \(error)"
                    )
                }
            }

            for name in self.storeNames {
                if let storeURL = self.storeURL(name) {
                    correctFilePermissions(url: storeURL)
                }
            }
        }
    }

    private func loadStores(container: NSPersistentContainer) async throws {
        let remaining = AirshipAtomicValue(container.persistentStoreDescriptions.count)
        let errorMessage = AirshipAtomicValue<String?>(nil)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            container.loadPersistentStores { description, error in
                if let error {
                    AirshipLogger.error(
                        "Failed to create store \(description): \(error)"
                    )

                    errorMessage.update { msg in
                        if let msg {
                            return "\(msg), \(error.localizedDescription)"
                        } else {
                            return error.localizedDescription
                        }
                    }
                }

                remaining.update { current in
                    current - 1
                }

                if (remaining.value == 0) {
                    if let msg = errorMessage.value {
                        continuation.resume(throwing: AirshipErrors.error(msg))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func storeSQLDirectory() -> URL? {
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

        return baseDirectory?.appendingPathComponent(
            Self.managedContextStoreDirectory
        )
    }

    private func storeURL(_ storeName: String?) -> URL? {
        return storeSQLDirectory()?.appendingPathComponent(storeName ?? "")
    }

    private func storesExistOnDisk() -> Bool {
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

    private func makeContainer() throws -> NSPersistentContainer {
        guard let mom = NSManagedObjectModel(contentsOf: self.modelURL) else {
            throw AirshipErrors.error("Failed to create managed object model \(self.modelURL)")
        }

        let container = NSPersistentContainer(name: self.name, managedObjectModel: mom)

        if inMemory {
            let description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            container.persistentStoreDescriptions =  self.storeNames.compactMap { store in
                guard let storeURL = self.storeURL(store) else {
                    return nil
                }

                let description = NSPersistentStoreDescription(url: storeURL)
                description.type = NSSQLiteStoreType
                description.shouldAddStoreAsynchronously = true
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
                return description
            }
        }
        return container
    }

    private func correctFilePermissions(url: URL) {
        do {
            guard (FileManager.default.fileExists(atPath: url.path)) else {
                return
            }
            let attributes = [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        } catch(let exception) {
            AirshipLogger.error("Failed to set file attribute \(exception)")
        }
    }
}


fileprivate extension NSManagedObjectContext {
    func saveIfChanged() throws {
        if hasChanges {
            try save()
        }
    }
}
