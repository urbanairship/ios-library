/* Copyright Airship and Contributors */

import Foundation
import CoreData

class UARemoteDataMappingV3toV4: NSEntityMigrationPolicy {

    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {

        // data -> JSON data

        guard source.entity.name == RemoteDataStore.remoteDataEntity else {
            return
        }

        let type = source.value(forKey: "type") as? String
        let timestamp = source.value(forKey: "timestamp") as? Date
        let data = source.value(forKey: "data") as? [AnyHashable: Any]
        let remoteDataInfo = source.value(forKey: "remoteDataInfo") as? Data

        let newRemoteDataEntity = NSEntityDescription.insertNewObject(
            forEntityName: RemoteDataStore.remoteDataEntity,
            into: manager.destinationContext
        )

        newRemoteDataEntity.setValue(type, forKey: "type")
        newRemoteDataEntity.setValue(timestamp, forKey: "timestamp")
        newRemoteDataEntity.setValue(AirshipJSONUtils.toData(data), forKey: "data")
        newRemoteDataEntity.setValue(remoteDataInfo, forKey: "remoteDataInfo")
    }
}


class UARemoteDataMappingV2toV4: NSEntityMigrationPolicy {

    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {

        // data -> JSON data
        // metadata -> drop

        guard source.entity.name == RemoteDataStore.remoteDataEntity else {
            return
        }

        let type = source.value(forKey: "type") as? String
        let timestamp = source.value(forKey: "timestamp") as? Date
        let data = source.value(forKey: "data") as? [AnyHashable: Any]

        let newRemoteDataEntity = NSEntityDescription.insertNewObject(
            forEntityName: RemoteDataStore.remoteDataEntity,
            into: manager.destinationContext
        )

        newRemoteDataEntity.setValue(type, forKey: "type")
        newRemoteDataEntity.setValue(timestamp, forKey: "timestamp")
        newRemoteDataEntity.setValue(AirshipJSONUtils.toData(data), forKey: "data")
    }
}



class UARemoteDataMappingV1toV4: NSEntityMigrationPolicy {

    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {

        // data -> JSON data

        guard source.entity.name == RemoteDataStore.remoteDataEntity else {
            return
        }

        let type = source.value(forKey: "type") as? String
        let timestamp = source.value(forKey: "timestamp") as? Date
        let data = source.value(forKey: "data") as? [AnyHashable: Any]

        let newRemoteDataEntity = NSEntityDescription.insertNewObject(
            forEntityName: RemoteDataStore.remoteDataEntity,
            into: manager.destinationContext
        )

        newRemoteDataEntity.setValue(type, forKey: "type")
        newRemoteDataEntity.setValue(timestamp, forKey: "timestamp")
        newRemoteDataEntity.setValue(AirshipJSONUtils.toData(data), forKey: "data")
    }
}
