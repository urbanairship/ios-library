/* Copyright Airship and Contributors */

import Foundation
import CoreData

class UARemoteDataMapping: NSEntityMigrationPolicy {
    
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        
        if sInstance.entity.name == RemoteDataStore.remoteDataEntity {
            
            let type = sInstance.value(forKey: "type") as? String
            let timestamp = sInstance.value(forKey: "timestamp") as? Date
            let data = sInstance.value(forKey: "data") as? [AnyHashable: Any]
            let remoteDataInfo = sInstance.value(forKey: "remoteDataInfo") as? Data
            
            let newRemoteDataEntity = NSEntityDescription.insertNewObject(
                forEntityName: RemoteDataStore.remoteDataEntity,
                into: manager.destinationContext
            )
            
            newRemoteDataEntity.setValue(type, forKey: "type")
            newRemoteDataEntity.setValue(timestamp, forKey: "timestamp")
            newRemoteDataEntity.setValue(JSONUtils.toData(data), forKey: "data")
            newRemoteDataEntity.setValue(remoteDataInfo, forKey: "remoteDataInfo")
        }
    }
}
