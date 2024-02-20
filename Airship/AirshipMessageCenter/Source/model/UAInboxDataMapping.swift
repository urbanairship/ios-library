/* Copyright Airship and Contributors */

import Foundation
import CoreData

#if canImport(AirshipCore)
import AirshipCore
#endif  

class UAInboxDataMapping: NSEntityMigrationPolicy {
    
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        
        if sInstance.entity.name == InboxMessageData.messageDataEntity {
            
            let messageID = sInstance.value(forKey: "messageID") as? String
            let messageBodyURL = sInstance.value(forKey: "messageBodyURL") as? URL
            let messageURL = sInstance.value(forKey: "messageURL") as? URL
            let messageReporting = sInstance.value(forKey: "messageReporting") as? [String: Any]
            let unread = sInstance.value(forKey: "unread") as? Bool
            let unreadClient = sInstance.value(forKey: "unreadClient") as? Bool
            let deletedClient = sInstance.value(forKey: "deletedClient") as? Bool
            let messageSent = sInstance.value(forKey: "messageSent") as? Date
            let messageExpiration = sInstance.value(forKey: "messageExpiration") as? Date
            let title = sInstance.value(forKey: "title") as? String
            let extra = sInstance.value(forKey: "extra") as? [String: String]
            let rawMessageObject = sInstance.value(forKey: "rawMessageObject") as? [String: Any]
            
            
            let newRemoteDataEntity = NSEntityDescription.insertNewObject(
                forEntityName: InboxMessageData.messageDataEntity,
                into: manager.destinationContext
            )
            
            newRemoteDataEntity.setValue(messageID, forKey: "messageID")
            newRemoteDataEntity.setValue(messageBodyURL, forKey: "messageBodyURL")
            newRemoteDataEntity.setValue(messageURL, forKey: "messageURL")
            newRemoteDataEntity.setValue(JSONUtils.toData(messageReporting), forKey: "messageReporting")
            newRemoteDataEntity.setValue(unread, forKey: "unread")
            newRemoteDataEntity.setValue(unreadClient, forKey: "unreadClient")
            newRemoteDataEntity.setValue(deletedClient, forKey: "deletedClient")
            newRemoteDataEntity.setValue(messageSent, forKey: "messageSent")
            newRemoteDataEntity.setValue(messageExpiration, forKey: "messageExpiration")
            newRemoteDataEntity.setValue(title, forKey: "title")
            newRemoteDataEntity.setValue(JSONUtils.toData(extra), forKey: "extra")
            newRemoteDataEntity.setValue(JSONUtils.toData(rawMessageObject), forKey: "rawMessageObject")
        }
    }
}
