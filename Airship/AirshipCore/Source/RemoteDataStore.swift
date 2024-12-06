/* Copyright Airship and Contributors */

import CoreData

final class RemoteDataStore: Sendable {
    
    static let remoteDataEntity = "UARemoteDataStorePayload"
    
    private let coreData: UACoreData
    private let inMemory: Bool
    
    public init(storeName: String, inMemory: Bool) {
        self.inMemory = inMemory
        let modelURL = AirshipCoreResources.bundle.url(
            forResource: "UARemoteData",
            withExtension: "momd"
        )
        self.coreData = UACoreData(
            name:  "UARemoteData",
            modelURL: modelURL!,
            inMemory: inMemory,
            stores: [storeName]
        )
    }
    
    convenience init(storeName: String) {
        self.init(storeName: storeName, inMemory: false)
    }

    func hasData() async throws -> Bool {
        return try await self.coreData.performWithResult { context in
            let request = NSFetchRequest<any NSFetchRequestResult>(
                entityName: RemoteDataStore.remoteDataEntity
            )
            return try context.count(for: request) > 0
        }
    }

    public func fetchRemoteDataFromCache(
        types: [String]? = nil
    ) async throws -> [RemoteDataPayload] {
        AirshipLogger.trace(
            "Fetching remote data from cache with types: \(String(describing: types))"
        )

        return try await self.coreData.performWithResult { context in
            let request = NSFetchRequest<any NSFetchRequestResult>(
                entityName: RemoteDataStore.remoteDataEntity
            )

            if let types = types {
                let predicate = AirshipCoreDataPredicate(format: "(type IN %@)", args: [types])
                request.predicate = predicate.toNSPredicate()
            }

            let result = try context.fetch(request) as? [RemoteDataStorePayload] ?? []
            return result.compactMap {

                var remoteDataInfo: RemoteDataInfo? = nil
                do {
                    if let data = $0.remoteDataInfo {
                        remoteDataInfo = try RemoteDataInfo.fromJSON(data: data)
                    }
                } catch {
                    AirshipLogger.error("Unable to parse remote-data info from data \(error.localizedDescription)")
                }

                var data: AirshipJSON = AirshipJSON.null

                do {
                    data = try AirshipJSON.from(data: $0.data)
                } catch {
                    AirshipLogger.error("Unable to parse remote-data data \(error.localizedDescription)")
                }


                return RemoteDataPayload(
                    type: $0.type,
                    timestamp: $0.timestamp,
                    data: data,
                    remoteDataInfo: remoteDataInfo
                )
            }
        }
    }


    public func clear() async throws {
        try await self.coreData.perform({ context in
            try self.deleteAll(context: context)
        })
    }

    public func overwriteCachedRemoteData(
        _ payloads: [RemoteDataPayload]
    ) async throws {
        
        try await self.coreData.perform({ context in
            try self.deleteAll(context: context)
            payloads.forEach {
                self.addPayload($0, context: context)
            }
        })
        
    }
    
    private func deleteAll(
        context: NSManagedObjectContext
    ) throws {
        
        let fetchRequest = NSFetchRequest<any NSFetchRequestResult>(
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
        remoteDataStorePayload.data = AirshipJSONUtils.toData(payload.data.unWrap() as? [AnyHashable : Any]) ?? Data()
        do {
            remoteDataStorePayload.remoteDataInfo = try payload.remoteDataInfo?.toEncodedJSONData()
        } catch {
            AirshipLogger.error("Unable to transform remote-data info to data \(error)")
        }
    }
}


