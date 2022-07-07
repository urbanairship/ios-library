/* Copyright Airship and Contributors */
import CoreData

// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataStore)
public class RemoteDataStore : NSObject {
    
    private static let remoteDataEntity = "UARemoteDataStorePayload"

    private let coreData: UACoreData

    @objc
    public init(storeName: String, inMemory: Bool) {
        let modelURL = AirshipCoreResources.bundle.url(forResource: "UARemoteData", withExtension: "momd")
        self.coreData = UACoreData(modelURL: modelURL!, inMemory: inMemory, stores: [storeName])
    }

    @objc
    public convenience init(storeName: String) {
        self.init(storeName: storeName, inMemory: false)
    }

    @objc
    public func fetchRemoteDataFromCache(predicate: NSPredicate?, completionHandler: @escaping ([RemoteDataPayload]) -> Void) {
        self.coreData.safePerform { isSafe, context in
            guard isSafe else {
                completionHandler([])
                return
            }
        
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: RemoteDataStore.remoteDataEntity)
            request.predicate = predicate

            do {
                let result = try context.fetch(request) as? [RemoteDataStorePayload] ?? []
                let payloads = result.compactMap {
                    return RemoteDataPayload(type: $0.type, timestamp: $0.timestamp, data: $0.data, metadata: $0.metadata)
                }
                
                completionHandler(payloads)
            } catch {
                AirshipLogger.error("Error executing fetch request \(error)")
                completionHandler([])
            }
        }
    }

    @objc
    public func overwriteCachedRemoteData(_ payloads: [RemoteDataPayload], completionHandler: @escaping (Bool) -> Void) {
        self.coreData.safePerform { isSafe, context in
            guard isSafe else {
                completionHandler(false)
                return
            }
        
            do {
                try self.deleteAll(context: context)
                UACoreData.safeSave(context)
                payloads.forEach {
                    self.addPayload($0, context: context)
                }
                completionHandler(UACoreData.safeSave(context))
            } catch {
                AirshipLogger.error("Failed to overwrite payloads \(error).")
                completionHandler(false)
            }
        }
    }
    
    private func deleteAll(context: NSManagedObjectContext) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: RemoteDataStore.remoteDataEntity)

        if (coreData.inMemory) {
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

    private func addPayload(_ payload: RemoteDataPayload, context: NSManagedObjectContext) {
        // create the NSManagedObject
        guard let remoteDataStorePayload = NSEntityDescription.insertNewObject(
            forEntityName: RemoteDataStore.remoteDataEntity,
                into: context) as? RemoteDataStorePayload else {
            return
        }
        
        // set the properties
        remoteDataStorePayload.type = payload.type
        remoteDataStorePayload.timestamp = payload.timestamp
        remoteDataStorePayload.data = payload.data
        remoteDataStorePayload.metadata = payload.metadata
    }

    @objc
    public func shutDown() {
        self.coreData.shutDown()
    }
}
