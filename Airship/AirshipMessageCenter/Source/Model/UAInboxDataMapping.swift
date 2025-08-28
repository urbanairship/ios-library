/* Copyright Airship and Contributors */


import CoreData

#if canImport(AirshipCore)
import AirshipCore
#endif  

@objc(UAInboxDataMappingV2toV3)
class UAInboxDataMappingV2toV3: NSEntityMigrationPolicy {

    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {

        /// extras -> JSON Data
        /// rawMessageObject -> JSON Data
        /// messageReporting -> JSON Data

        guard source.entity.name == InboxMessageData.messageDataEntity else {
            return
        }

        let messageID = source.value(forKey: "messageID") as? String
        let messageBodyURL = source.value(forKey: "messageBodyURL") as? URL
        let messageURL = source.value(forKey: "messageURL") as? URL
        let messageReporting = source.value(forKey: "messageReporting") as? [String: Any]
        let unread = source.value(forKey: "unread") as? Bool
        let unreadClient = source.value(forKey: "unreadClient") as? Bool
        let deletedClient = source.value(forKey: "deletedClient") as? Bool
        let messageSent = source.value(forKey: "messageSent") as? Date
        let messageExpiration = source.value(forKey: "messageExpiration") as? Date
        let title = source.value(forKey: "title") as? String
        let extra = source.value(forKey: "extra") as? [String: String]
        let rawMessageObject = source.value(forKey: "rawMessageObject") as? [String: Any]


        let newEntity = NSEntityDescription.insertNewObject(
            forEntityName: InboxMessageData.messageDataEntity,
            into: manager.destinationContext
        )

        newEntity.setValue(messageID, forKey: "messageID")
        newEntity.setValue(messageBodyURL, forKey: "messageBodyURL")
        newEntity.setValue(messageURL, forKey: "messageURL")
        newEntity.setValue(AirshipJSONUtils.toData(messageReporting), forKey: "messageReporting")
        newEntity.setValue(unread, forKey: "unread")
        newEntity.setValue(unreadClient, forKey: "unreadClient")
        newEntity.setValue(deletedClient, forKey: "deletedClient")
        newEntity.setValue(messageSent, forKey: "messageSent")
        newEntity.setValue(messageExpiration, forKey: "messageExpiration")
        newEntity.setValue(title, forKey: "title")
        newEntity.setValue(AirshipJSONUtils.toData(extra), forKey: "extra")
        newEntity.setValue(AirshipJSONUtils.toData(rawMessageObject), forKey: "rawMessageObject")
    }
}

@objc(UAInboxDataMappingV1toV3)
class UAInboxDataMappingV1toV3: NSEntityMigrationPolicy {

    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {

        /// extras -> Json Data
        /// rawMessageObject -> Json Data

        guard source.entity.name == InboxMessageData.messageDataEntity else {
            return
        }

        let messageID = source.value(forKey: "messageID") as? String
        let messageBodyURL = source.value(forKey: "messageBodyURL") as? URL
        let messageURL = source.value(forKey: "messageURL") as? URL
        let unread = source.value(forKey: "unread") as? Bool
        let unreadClient = source.value(forKey: "unreadClient") as? Bool
        let deletedClient = source.value(forKey: "deletedClient") as? Bool
        let messageSent = source.value(forKey: "messageSent") as? Date
        let messageExpiration = source.value(forKey: "messageExpiration") as? Date
        let title = source.value(forKey: "title") as? String
        let extra = source.value(forKey: "extra") as? [String: String]
        let rawMessageObject = source.value(forKey: "rawMessageObject") as? [String: Any]

        let newEntity = NSEntityDescription.insertNewObject(
            forEntityName: InboxMessageData.messageDataEntity,
            into: manager.destinationContext
        )

        newEntity.setValue(messageID, forKey: "messageID")
        newEntity.setValue(messageBodyURL, forKey: "messageBodyURL")
        newEntity.setValue(messageURL, forKey: "messageURL")
        newEntity.setValue(unread, forKey: "unread")
        newEntity.setValue(unreadClient, forKey: "unreadClient")
        newEntity.setValue(deletedClient, forKey: "deletedClient")
        newEntity.setValue(messageSent, forKey: "messageSent")
        newEntity.setValue(messageExpiration, forKey: "messageExpiration")
        newEntity.setValue(title, forKey: "title")
        newEntity.setValue(AirshipJSONUtils.toData(extra), forKey: "extra")
        newEntity.setValue(AirshipJSONUtils.toData(rawMessageObject), forKey: "rawMessageObject")
    }
}
