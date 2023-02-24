/* Copyright Airship and Contributors */

import CoreData

actor RemoteDataStore {
    
    private static let remoteDataEntity = "UARemoteDataStorePayload"
    
    private let coreData: UACoreData
    private nonisolated let inMemory: Bool
    
    public init(
        storeName: String,
        inMemory: Bool
    ) {
        self.inMemory = inMemory
        let modelURL = AirshipCoreResources.bundle.url(
            forResource: "UARemoteData",
            withExtension: "momd"
        )
        self.coreData = UACoreData(
            modelURL: modelURL!,
            inMemory: inMemory,
            stores: [storeName]
        )
    }
    
    init(
        storeName: String
    ) {
        self.init(storeName: storeName, inMemory: false)
    }
    
    public func fetchRemoteDataFromCache(
        predicate: AirshipCoreDataPredicate?
    ) async throws -> [RemoteDataPayload] {
        
        AirshipLogger.trace(
            "Fetching remote data from cache with predicate: \(String(describing: predicate))"
        )
        
        
        return try await self.coreData.performWithResult { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: RemoteDataStore.remoteDataEntity
            )
            request.predicate = predicate?.toNSPredicate()
            let result = try context.fetch(request) as? [RemoteDataStorePayload] ?? []
            return result.compactMap {
                return RemoteDataPayload(
                    type: $0.type,
                    timestamp: $0.timestamp,
                    data: $0.data,
                    metadata: $0.metadata
                )
            }
        }
    }
    
    public func overwriteCachedRemoteData(
        _ payloads: [RemoteDataPayload]
    ) async throws {
        
        try await self.coreData.perform({ context in
            try self.deleteAll(context: context)
            UACoreData.safeSave(context)
            payloads.forEach {
                self.addPayload($0, context: context)
            }
        })
        
    }
    
    nonisolated private func deleteAll(
        context: NSManagedObjectContext
    ) throws {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(
            entityName: RemoteDataStore.remoteDataEntity
        )
        
        if self.inMemory {
            fetchRequest.includesPropertyValues = false
            let payloads = try context.fetch(fetchRequest) as? [NSManagedObject]
            payloads?.forEach {
                context.delete($0)
            }
        } else {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
        }
    }
    
    nonisolated private func addPayload(
        _ payload: RemoteDataPayload,
        context: NSManagedObjectContext
    ) {
        // create the NSManagedObject
        guard
            let remoteDataStorePayload = NSEntityDescription.insertNewObject(
                forEntityName: RemoteDataStore.remoteDataEntity,
                into: context
            ) as? RemoteDataStorePayload
        else {
            return
        }
        
        // set the properties
        remoteDataStorePayload.type = payload.type
        remoteDataStorePayload.timestamp = payload.timestamp
        remoteDataStorePayload.data = payload.data
        remoteDataStorePayload.metadata = payload.metadata
    }
}
