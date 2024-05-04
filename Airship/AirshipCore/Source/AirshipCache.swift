import CoreData

public protocol AirshipCache: AnyActor {
    func getCachedValue<T: Codable & Sendable>(key: String) async -> T?
    func getCachedValue<T: Codable & Sendable>(key: String, decoder: JSONDecoder) async -> T?
    func setCachedValue<T: Codable & Sendable>(_ value: T?, key: String, ttl: TimeInterval) async
    func setCachedValue<T: Codable & Sendable>(_ value: T?, key: String, ttl: TimeInterval, encoder: JSONEncoder) async
}

actor CoreDataAirshipCache: AirshipCache {
    private let coreData: UACoreData?
    private let appVersion: String
    private let sdkVersion: String
    private let date: AirshipDateProtocol
    private let cleanUpTask: Task<Void, Never>

    static func makeCoreData(appKey: String) -> UACoreData? {
        let modelURL = AirshipCoreResources.bundle.url(
            forResource: "UAirshipCache",
            withExtension: "momd"
        )

        if let modelURL = modelURL {
            return UACoreData(
                modelURL: modelURL,
                inMemory: false,
                stores: ["AirshipCache-\(appKey).sqlite"]
            )
        }

        AirshipLogger.error("Failed to create AirshipCache")
        return nil
    }

    init(appKey: String) {
        self.init(
            coreData: CoreDataAirshipCache.makeCoreData(appKey: appKey)
        )
    }

    init(
        coreData: UACoreData?,
        appVersion: String = AirshipUtils.bundleShortVersionString() ?? "0.0.0",
        sdkVersion: String = AirshipVersion.version,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.coreData = coreData
        self.appVersion = appVersion
        self.sdkVersion = sdkVersion
        self.date = date

        self.cleanUpTask = Task { [appVersion, sdkVersion, date] in
            guard let coreData = coreData else { return }

            do {
                let predicate = AirshipCoreDataPredicate(
                    format: "appVersion != %@ || sdkVersion != %@ || expiry <= %@",
                    args: [
                        appVersion,
                        sdkVersion,
                        date.now
                    ]
                )
                try await coreData.perform(skipIfStoreNotCreated: true) { context in
                    try context.delete(
                        predicate: predicate,
                        useBatch: !coreData.inMemory
                    )
                }
            } catch {
                AirshipLogger.error("Failed to cleanup cache \(error)")
            }
        }
    }

    func getCachedValue<T>(key: String) async -> T? where T : Decodable, T : Encodable, T : Sendable {
        return await getCachedValue(key: key, decoder: AirshipJSON.defaultDecoder)
    }

    func getCachedValue<T>(
        key: String,
        decoder: JSONDecoder
    ) async -> T? where T : Decodable, T : Encodable, T : Sendable {
        await self.cleanUpTask.value
        do {
            let result: T? = try await requireCoreData().performWithNullableResult { context in
                let entity = try context.getAirshipCacheEntity(key: key)

                guard let data = entity?.data,
                      let expiry = entity?.expiry,
                      entity?.appVersion == self.appVersion,
                      entity?.sdkVersion == self.sdkVersion
                else {
                    AirshipLogger.trace("Invalid cache data, deleting")
                    try? context.deleteCacheEntity(key: key)
                    return nil
                }

                guard expiry > self.date.now else {
                    AirshipLogger.trace("Value expired, deleting")
                    try? context.deleteCacheEntity(key: key)
                    return nil
                }

                return try decoder.decode(T.self, from: data)
            }
            return result
        } catch {
            AirshipLogger.error("Failed to fetch cached value \(key) \(error)")
            return nil
        }
    }

    func setCachedValue<T>(_ value: T?, key: String, ttl: TimeInterval) async where T : Decodable, T : Encodable, T : Sendable {
        return await setCachedValue(value, key: key, ttl: ttl, encoder: AirshipJSON.defaultEncoder)
    }

    func setCachedValue<T>(
        _ value: T?, key:
        String, ttl: TimeInterval,
        encoder: JSONEncoder
    ) async where T : Decodable, T : Encodable, T : Sendable {
        await self.cleanUpTask.value

        do {
            try await requireCoreData().perform { context in
                let entity = try context.getOrCreateAirshipCacheEntity(key: key)
                entity.key = key
                entity.sdkVersion = self.sdkVersion
                entity.appVersion = self.appVersion
                entity.expiry = self.date.now + ttl
                entity.data = try AirshipJSON.defaultEncoder.encode(value)
                UACoreData.safeSave(context)
            }
        } catch {
            AirshipLogger.error("Failed to cache value for key \(key) \(error)")
        }
    }

    private func requireCoreData() throws -> UACoreData {
        guard let coreData = self.coreData else {
            throw AirshipErrors.error("Coredata does not exist")
        }
        return coreData
    }
}

fileprivate extension NSManagedObjectContext {
    func getOrCreateAirshipCacheEntity(
        key: String
    ) throws -> AirshipCacheData {
        return try getAirshipCacheEntity(key: key) ?? createAirshipCacheEntity()
    }

    func deleteCacheEntity(
        key: String
    ) throws {
        let predicate = AirshipCoreDataPredicate(
            format: "key == %@",
            args: [key]
        )
        try? delete(predicate: predicate, useBatch: false)
    }

    func getAirshipCacheEntity(
        key: String
    ) throws -> AirshipCacheData? {
        let request = NSFetchRequest<AirshipCacheData>(
            entityName: AirshipCacheData.entityName
        )

        let predicate = AirshipCoreDataPredicate(
            format: "key == %@",
            args: [key]
        )

        request.fetchLimit = 1
        request.predicate = predicate.toNSPredicate()

        let fetchResult = try fetch(request)
        return fetchResult.first
    }

    func createAirshipCacheEntity() throws -> AirshipCacheData {
        let entity = NSEntityDescription.insertNewObject(
           forEntityName: AirshipCacheData.entityName,
           into: self
       ) as? AirshipCacheData

        guard let entity = entity else {
            throw AirshipErrors.error("Failed to create AirshipCacheData")
        }

        return entity
    }

    func delete(
        predicate: AirshipCoreDataPredicate,
        useBatch: Bool
    ) throws {
        if useBatch {
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: AirshipCacheData.entityName
            )
            request.predicate = predicate.toNSPredicate()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try execute(deleteRequest)
        } else {
            let request = NSFetchRequest<AirshipCacheData>(
                entityName: AirshipCacheData.entityName
            )
            request.predicate = predicate.toNSPredicate()
            request.includesPropertyValues = false
            let fetched = try fetch(request)
            fetched.forEach { entity in
                delete(entity)
            }
        }
    }
}

// Internal core data entity
@objc(UAirshipCacheData)
fileprivate class AirshipCacheData: NSManagedObject {
    static let entityName = "UAirshipCacheData"

    @NSManaged public dynamic var data: Data?

    @objc
    @NSManaged public dynamic var key: String?

    @objc
    @NSManaged public dynamic var appVersion: String?

    @objc
    @NSManaged public dynamic var sdkVersion: String?

    @objc
    @NSManaged public dynamic var expiry: Date?
}
