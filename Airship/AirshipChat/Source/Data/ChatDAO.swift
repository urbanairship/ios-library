/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

import Foundation

/**
 * Chat data access object.
 */
@available(iOS 13.0, *)
class ChatDAO: ChatDAOProtocol {
    private static let ChatMessageDataEntityName = "ChatMessageData"
    private static let PendingChatMessageDataEntityName = "PendingChatMessageData"

    private let storeName: String
    private let managedContext: NSManagedObjectContext

    private var persistentStore: NSPersistentStore?

    init(config: ChatConfig) {
        let bundle = ChatResources.bundle()
        let modelURL = bundle?.url(forResource: "ChatMessageData", withExtension: "momd")
        self.managedContext = NSManagedObjectContext(forModelURL: modelURL!, concurrencyType: .privateQueueConcurrencyType)
        self.managedContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.storeName = "Chat-message-data-\(config.appKey).sqlite"

        self.addStores()

        NotificationCenter.default.addObserver(self, selector: #selector(protectedDataAvailable), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
    }

    func upsertMessage(messageID: Int, requestID: String?, text: String?, createdOn: Date, direction: UInt, attachment: URL?) {
        safePerformBlock {
            let data = self.getMessage(messageID) ?? self.insertNewEntity(ChatDAO.ChatMessageDataEntityName) as! ChatMessageData
            data.messageID = messageID
            data.requestID = requestID
            data.text = text
            data.createdOn = createdOn
            data.direction = direction
            data.attachment = attachment
        }
    }

    func insertPending(requestID: String, text: String?, attachment: URL?, createdOn: Date) {
        safePerformBlock {
            let data = self.insertNewEntity(ChatDAO.PendingChatMessageDataEntityName) as! PendingChatMessageData
            data.requestID = requestID
            data.text = text
            data.createdOn = createdOn
            data.attachment = attachment
        }
    }

    func removePending(_ requestID: String) {
        safePerformBlock {
            if let pending = self.getPendingMessage(requestID) {
                self.managedContext.delete(pending)
            }
        }
    }

    func fetchMessages(completionHandler: @escaping (Array<ChatMessageDataProtocol>, Array<PendingChatMessageDataProtocol>)->()) {
        safePerformBlock {
            let messagesData = self.getMessages()
            let pendingMessagesData = self.getPendingMessages()
            completionHandler(messagesData, pendingMessagesData)
        }
    }

    func fetchPending(completionHandler: @escaping (Array<PendingChatMessageDataProtocol>)->()) {
        safePerformBlock {
            let pendingMessagesData = self.getPendingMessages()
            completionHandler(pendingMessagesData)
        }
    }

    func hasPendingMessages(completionHandler: @escaping (Bool)->()) {
        safePerformBlock {
            let pendingMessagesData = self.getPendingMessages()
            completionHandler(!pendingMessagesData.isEmpty)
        }
    }

    func deleteAll() {
        safePerformBlock {
            let pendingRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.PendingChatMessageDataEntityName)
            let pendingDeleteRequest = NSBatchDeleteRequest(fetchRequest: pendingRequest)

            let messageRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.ChatMessageDataEntityName)
            let messageDeleteRequest = NSBatchDeleteRequest(fetchRequest: messageRequest)

            do {
                try self.managedContext.execute(pendingDeleteRequest)
                try self.managedContext.execute(messageDeleteRequest)
            } catch {
                AirshipLogger.error("Unable to delete messages: \(error)")
            }

        }
    }

    @objc private func protectedDataAvailable() {
        if let storeCount = self.managedContext.persistentStoreCoordinator?.persistentStores.count {
            if storeCount == 0 {
                self.addStores()
            }
        }
    }

    private func addStores() {
        self.managedContext.addPersistentSqlStore(self.storeName) { (store: NSPersistentStore?, error: Error?) in
            if (error != nil) {
                AirshipLogger.error("Failed to create chat persistent store: \(error!.localizedDescription)")
                return
            }

            self.persistentStore = store
        }
    }

    private func safePerformBlock(block: @escaping () -> Void) {
        self.managedContext.safePerform { (safe: Bool) in
            if (safe) {
                block()
                self.managedContext.safeSave()
            }
        }
    }

    private func insertNewEntity(_ name: String) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: name, into: self.managedContext)

        if let store = self.persistentStore {
            self.managedContext.assign(object, to: store)
        }

        return object
    }

    private func getMessages() -> [ChatMessageData] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.ChatMessageDataEntityName)
        request.sortDescriptors = [NSSortDescriptor(key: "createdOn", ascending: true)]

        do {
            let result = try self.managedContext.fetch(request)
            return result as! [ChatMessageData]
        } catch {
            AirshipLogger.error("Unable to get message data: \(error)")
            return []
        }
    }

    private func getPendingMessages() -> [PendingChatMessageData] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.PendingChatMessageDataEntityName)
        request.sortDescriptors = [NSSortDescriptor(key: "createdOn", ascending: true)]

        do {
            let result = try self.managedContext.fetch(request)
            return result as! [PendingChatMessageData]
        } catch {
            AirshipLogger.error("Unable to get pending message data: \(error)")
            return []
        }
    }

    private func getPendingMessage(_ requestID: String) -> PendingChatMessageData? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.PendingChatMessageDataEntityName)
        request.predicate = NSPredicate(format: "requestID == %@", requestID)
        do {
            let result = try self.managedContext.fetch(request)
            return result.first as? PendingChatMessageData
        } catch {
            AirshipLogger.error("Unable to get pending message data: \(error)")
            return nil
        }
    }

    private func getMessage(_ messageID: Int) -> ChatMessageData? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.ChatMessageDataEntityName)
        request.predicate = NSPredicate(format: "messageID == %ld", messageID)
        do {
            let result = try self.managedContext.fetch(request)
            return result.first as? ChatMessageData
        } catch {
            AirshipLogger.error("Unable to get message data: \(error)")
            return nil
        }
    }
}
