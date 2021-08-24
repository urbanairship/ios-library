/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif


import Foundation

/**
 * Chat data access object.
 */
@available(iOS 13.0, *)
class ChatDAO: ChatDAOProtocol {
    private static let chatMessageDataEntityName = "ChatMessageData"
    private static let pendingChatMessageDataEntityName = "PendingChatMessageData"
    private static let fetchLimit = 50

    private let coreData: UACoreData

    init(config: ChatConfig) {
        let bundle = ChatResources.bundle()
        let modelURL = bundle?.url(forResource: "ChatMessageDataModel", withExtension: "momd")
        self.coreData = UACoreData(modelURL: modelURL!,
                                   inMemory: false,
                                   stores: ["Chat-message-data-\(config.appKey).sqlite"],
                                   mergePolicy: NSMergeByPropertyStoreTrumpMergePolicy)
    }

    func upsertMessage(messageID: Int, requestID: String?, text: String?, createdOn: Date, direction: UInt, attachment: URL?) {
        safePerformBlock { context in
            let data = self.getMessage(messageID, context: context) ?? self.insertNewEntity(ChatDAO.chatMessageDataEntityName, context: context) as! ChatMessageData
            data.messageID = messageID
            data.requestID = requestID
            data.text = text
            data.createdOn = createdOn
            data.direction = direction
            data.attachment = attachment
        }
    }

    func upsertPending(requestID: String, text: String?, attachment: URL?, createdOn: Date, direction: UInt) {
        safePerformBlock { context in
            let data = self.getPendingMessage(requestID, context: context) ?? self.insertNewEntity(ChatDAO.pendingChatMessageDataEntityName, context: context) as! PendingChatMessageData
            data.requestID = requestID
            data.text = text
            data.createdOn = createdOn
            data.attachment = attachment
            data.direction = direction
        }
    }

    func removePending(_ requestID: String) {
        safePerformBlock { context in
            if let pending = self.getPendingMessage(requestID, context: context) {
                context.delete(pending)
            }
        }
    }

    func fetchMessages(completionHandler: @escaping (Array<ChatMessageDataProtocol>, Array<PendingChatMessageDataProtocol>)->()) {
        safePerformBlock { context in
            let messagesData = self.getMessages(context)
            let pendingMessagesData = self.getPendingMessages(context)
            completionHandler(messagesData, pendingMessagesData)
        }
    }

    func fetchPending(completionHandler: @escaping (Array<PendingChatMessageDataProtocol>)->()) {
        safePerformBlock { context in
            let pendingMessagesData = self.getPendingMessages(context)
            completionHandler(pendingMessagesData)
        }
    }

    func hasPendingMessages(completionHandler: @escaping (Bool)->()) {
        safePerformBlock { context in
            let pendingMessagesData = self.getPendingMessages(context)
            completionHandler(!pendingMessagesData.isEmpty)
        }
    }

    func deleteAll() {
        self.coreData.performBlockIfStoresExist { safe, context in
            if (safe) {
                let pendingRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.pendingChatMessageDataEntityName)
                let pendingDeleteRequest = NSBatchDeleteRequest(fetchRequest: pendingRequest)

                let messageRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.chatMessageDataEntityName)
                let messageDeleteRequest = NSBatchDeleteRequest(fetchRequest: messageRequest)

                do {
                    try context.execute(pendingDeleteRequest)
                    try context.execute(messageDeleteRequest)
                } catch {
                    AirshipLogger.error("Unable to delete messages: \(error)")
                }
            }
        }
    }

    private func safePerformBlock(block: @escaping (NSManagedObjectContext) -> Void) {
        self.coreData.safePerform { safe, context in
            if (safe) {
                block(context)
                UACoreData.safeSave(context)
            }
        }
    }

    private func insertNewEntity(_ name: String, context: NSManagedObjectContext) -> NSManagedObject {
        return NSEntityDescription.insertNewObject(forEntityName: name, into: context)
    }

    private func getMessages(_ context: NSManagedObjectContext) -> [ChatMessageData] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.chatMessageDataEntityName)
        request.sortDescriptors = [NSSortDescriptor(key: "createdOn", ascending: true)]
        request.fetchLimit = ChatDAO.fetchLimit

        do {
            let result = try context.fetch(request)
            return result as! [ChatMessageData]
        } catch {
            AirshipLogger.error("Unable to get message data: \(error)")
            return []
        }
    }

    private func getPendingMessages(_ context: NSManagedObjectContext) -> [PendingChatMessageData] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.pendingChatMessageDataEntityName)
        request.sortDescriptors = [NSSortDescriptor(key: "createdOn", ascending: true)]

        do {
            let result = try context.fetch(request)
            return result as! [PendingChatMessageData]
        } catch {
            AirshipLogger.error("Unable to get pending message data: \(error)")
            return []
        }
    }

    private func getPendingMessage(_ requestID: String, context: NSManagedObjectContext) -> PendingChatMessageData? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.pendingChatMessageDataEntityName)
        request.predicate = NSPredicate(format: "requestID == %@", requestID)
        do {
            let result = try context.fetch(request)
            return result.first as? PendingChatMessageData
        } catch {
            AirshipLogger.error("Unable to get pending message data: \(error)")
            return nil
        }
    }

    private func getMessage(_ messageID: Int, context: NSManagedObjectContext) -> ChatMessageData? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChatDAO.chatMessageDataEntityName)
        request.predicate = NSPredicate(format: "messageID == %ld", messageID)
        do {
            let result = try context.fetch(request)
            return result.first as? ChatMessageData
        } catch {
            AirshipLogger.error("Unable to get message data: \(error)")
            return nil
        }
    }
}
