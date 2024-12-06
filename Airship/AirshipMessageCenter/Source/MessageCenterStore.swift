/* Copyright Airship and Contributors */

import CoreData
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

enum MessageCenterStoreError: Error {
    case coreDataUnavailble
    case coreDataError
}

enum MessageCenterStoreLevel: Int {
    case local
    case global
}


actor MessageCenterStore {

    /// User defualts key to clear the keychain of Airship values for one app run. Used for testing. :nodoc:
    private static let resetKeychainKey = "com.urbanairship.reset_keychain"

    private static let coreDataStoreName = "Inbox-%@.sqlite"
    private static let lastMessageListModifiedTime =
        "UALastMessageListModifiedTime"
    private static let userRegisteredChannelID = "UAUserRegisteredChannelID"
    private static let userRequireUpdate = "UAUserRequireUpdate"

    private let coreData: UACoreData?
    private let config: RuntimeConfig
    private let dataStore: PreferenceDataStore
    private let keychainAccess: any AirshipKeychainAccessProtocol
    private let date: any AirshipDateProtocol

    private nonisolated let inMemory: Bool
    
    var registeredChannelID: String? {
        return self.dataStore.string(
            forKey: MessageCenterStore.userRegisteredChannelID
        )
    }

    private var _user: MessageCenterUser? = nil
    var user: MessageCenterUser? {
        get async {
            // Clearing the keychain
            if UserDefaults.standard.bool(forKey: MessageCenterStore.resetKeychainKey) == true {
                AirshipLogger.debug("Deleting the keychain credentials")
                await resetUser()
                UserDefaults.standard.removeObject(
                    forKey: MessageCenterStore.resetKeychainKey
                )
            }

            if let user = _user {
                return user
            }

            let credentials = await self.keychainAccess.readCredentails(
                identifier: self.config.appCredentials.appKey,
                appKey: self.config.appCredentials.appKey
            )

            if let credentials = credentials {
                _user = MessageCenterUser(
                    username: credentials.username,
                    password: credentials.password
                )
            }
            return _user
        }
    }

    var userRequiredUpdate: Bool {
        return self.dataStore.bool(forKey: MessageCenterStore.userRequireUpdate)
    }

    var lastMessageListModifiedTime: String? {
        return self.dataStore.string(
            forKey: MessageCenterStore.lastMessageListModifiedTime
        )
    }

    
    var messages: [MessageCenterMessage] {
        get async {
            let predicate = AirshipCoreDataPredicate(
                format:
                    "(messageExpiration == nil || messageExpiration >= %@) && (deletedClient == NO || deletedClient == nil)",
                args: [self.date.now]
            )
            
            let messages = try? await fetchMessages(withPredicate: predicate)
            return messages ?? []
        }
    }

    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.config = config
        self.dataStore = dataStore
        self.keychainAccess = AirshipKeychainAccess.shared
        self.date = date
        
        let modelURL = MessageCenterResources.bundle?
            .url(
                forResource: "UAInbox",
                withExtension: "momd"
            )
        if let modelURL = modelURL {
            let storeName = String(
                format: MessageCenterStore.coreDataStoreName,
                config.appCredentials.appKey
            )
            self.coreData = UACoreData(
                name: "UAInbox",
                modelURL: modelURL,
                inMemory: false,
                stores: [storeName]
            )
        } else {
            self.coreData = nil
        }
        self.inMemory = false
    }

    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        coreData: UACoreData,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.inMemory = coreData.inMemory
        self.config = config
        self.dataStore = dataStore
        self.coreData = coreData
        self.keychainAccess = AirshipKeychainAccess.shared
        self.date = date
    }

    var unreadCount: Int {
        get async {
            guard let coreData = self.coreData else {
                return 0
            }

            let result: Int? = try? await coreData.performWithResult { context in
                let request: NSFetchRequest<InboxMessageData> =
                    InboxMessageData.fetchRequest()
                request.predicate = NSPredicate(format: "unread == YES")
                request.includesPropertyValues = false
                let fetchedMessages = try context.fetch(request)
                return fetchedMessages.count
            }

            return result ?? 0
        }
    }

    func message(forID messageID: String) async throws -> MessageCenterMessage?
    {
        let predicate = AirshipCoreDataPredicate(
            format:
                "messageID == %@ && (messageExpiration == nil || messageExpiration >= %@) && (deletedClient == NO || deletedClient == nil)",
            args: [
                messageID,
                self.date.now
            ]
        )

        let messages = try await fetchMessages(withPredicate: predicate)
        return messages.first
    }

    func message(forBodyURL bodyURL: URL) async throws -> MessageCenterMessage?
    {
        let predicate = AirshipCoreDataPredicate(
            format:
                "messageBodyURL == %@ && (messageExpiration == nil || messageExpiration >= %@) && (deletedClient == NO || deletedClient == nil)",
            args: [
                bodyURL,
                self.date.now
            ]
        )

        let messages = try await fetchMessages(withPredicate: predicate)
        return messages.first
    }

    func markRead(
        messageIDs: [String],
        level: MessageCenterStoreLevel
    ) async throws {
        guard let coreData = self.coreData else {
            throw MessageCenterStoreError.coreDataUnavailble
        }

        AirshipLogger.trace("Mark messsages with IDs: \(messageIDs) read")

        try await coreData.perform { context in
            let request = InboxMessageData.batchUpdateRequest()
            request.predicate = NSPredicate(
                format: "messageID IN %@",
                messageIDs
            )
            if level == .local {
                request.propertiesToUpdate = ["unreadClient": false]
            } else if level == .global {
                request.propertiesToUpdate = ["unread": false]
            }

            request.resultType = .updatedObjectsCountResultType
            try context.execute(request)
        }
    }

    func delete(messageIDs: [String]) async throws {
        guard let coreData = self.coreData else {
            throw MessageCenterStoreError.coreDataUnavailble
        }

        AirshipLogger.trace("Deleting messages with IDs: \(messageIDs)")

        try await coreData.perform { context in
            try self.delete(
                predicate: NSPredicate(
                    format: "messageID IN %@",
                    messageIDs
                ),
                useBatch: !self.inMemory,
                context: context
            )
        }
    }

    func markDeleted(messageIDs: [String]) async throws {
        guard let coreData = self.coreData else {
            throw MessageCenterStoreError.coreDataUnavailble
        }

        AirshipLogger.trace("Mark messsages with IDs: \(messageIDs) deleted")

        try await coreData.perform { context in
            let request = InboxMessageData.batchUpdateRequest()
            request.predicate = NSPredicate(
                format: "messageID IN %@",
                messageIDs
            )
            request.propertiesToUpdate = ["deletedClient": true]
            request.resultType = .updatedObjectsCountResultType
            try context.execute(request)
        }
    }

    func fetchLocallyDeletedMessages() async throws -> [MessageCenterMessage] {
        let predicate = AirshipCoreDataPredicate(
            format: "deletedClient == YES"
        )

        return try await fetchMessages(withPredicate: predicate)
    }

    func fetchLocallyReadOnlyMessages() async throws -> [MessageCenterMessage] {
        let predicate = AirshipCoreDataPredicate(
            format: "unreadClient == NO && unread == YES"
        )

        return try await fetchMessages(withPredicate: predicate)
    }

    func saveUser(_ user: MessageCenterUser, channelID: String) async {
        let result = await self.keychainAccess.writeCredentials(
            AirshipKeychainCredentials(
                username: user.username,
                password: user.password
            ),
            identifier: self.config.appCredentials.appKey,
            appKey: self.config.appCredentials.appKey
        )

        if !result {
            AirshipLogger.error("Failed to write user credentials")
        }

        setUserRegisteredChannelID(channelID)
        _user = user
    }

    func resetUser() async {
        _user = nil
        await self.keychainAccess.deleteCredentials(
            identifier: self.config.appCredentials.appKey,
            appKey: self.config.appCredentials.appKey
        )
    }

    func setUserRequireUpdate(_ value: Bool) {
        self.dataStore.setBool(
            value,
            forKey: MessageCenterStore.userRequireUpdate
        )
    }

    func setUserRegisteredChannelID(_ value: String) {
        self.dataStore.setValue(
            value,
            forKey: MessageCenterStore.userRegisteredChannelID
        )
    }

    func setLastMessageListModifiedTime(_ value: String?) {
        self.dataStore.setValue(
            value,
            forKey: MessageCenterStore.lastMessageListModifiedTime
        )
    }

    func clearLastModified(username: String) {
        self.dataStore.removeObject(
            forKey: MessageCenterStore.lastMessageListModifiedTime
        )
    }

    private func fetchMessages(
        withPredicate predicate: AirshipCoreDataPredicate? = nil
    ) async throws -> [MessageCenterMessage] {
        guard let coreData = self.coreData else {
            throw MessageCenterStoreError.coreDataUnavailble
        }

        AirshipLogger.trace(
            "Fetching messsage center with predicate: \(String(describing: predicate))"
        )

        return try await coreData.performWithResult { context in
            let request: NSFetchRequest<InboxMessageData> =
                InboxMessageData.fetchRequest()

            request.sortDescriptors = [
                NSSortDescriptor(
                    key: "messageSent",
                    ascending: false
                )
            ]

            if let predicate = predicate {
                request.predicate = predicate.toNSPredicate()
            }

            let fetchedMessages = try context.fetch(request)
            return fetchedMessages.compactMap { data in data.message() }
        }
    }

    nonisolated private func delete(
        predicate: NSPredicate,
        useBatch: Bool,
        context: NSManagedObjectContext
    ) throws {
        if useBatch {
            let request = InboxMessageData.fetchRequest()
            request.predicate = predicate
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        } else {
            let request: NSFetchRequest<InboxMessageData> =
                InboxMessageData.fetchRequest()
            request.predicate = predicate
            request.includesPropertyValues = false
            let fetchedMessages = try context.fetch(request)
            fetchedMessages.forEach { message in
                context.delete(message)
            }
        }

    }

    nonisolated private func getOrCreateMessageEntity(
        messageID: String,
        context: NSManagedObjectContext
    ) throws -> InboxMessageData {
        let request: NSFetchRequest<InboxMessageData> =
            InboxMessageData.fetchRequest()
        request.predicate = NSPredicate(format: "messageID == %@", messageID)
        request.fetchLimit = 1

        let response = try context.fetch(request)
        if let existing = response.first {
            return existing
        }

        guard
            let data = NSEntityDescription.insertNewObject(
                forEntityName: InboxMessageData.messageDataEntity,
                into: context
            ) as? InboxMessageData
        else {
            throw MessageCenterStoreError.coreDataError
        }

        return data
    }

    func updateMessages(
        messages: [MessageCenterMessage],
        lastModifiedTime: String?
    ) async throws {
        guard let coreData = self.coreData else {
            throw MessageCenterStoreError.coreDataUnavailble
        }

        try await coreData.perform { context in
            // Track the response messageIDs so we can remove any messages that are
            // no longer in the response.
            try messages.forEach { message in
                let data = try self.getOrCreateMessageEntity(
                    messageID: message.id,
                    context: context
                )

                data.messageID = message.id
                data.title = message.title
                data.extra = AirshipJSONUtils.toData(message.extra)
                data.messageBodyURL = message.bodyURL
                data.messageURL = message.messageURL
                data.unread = message.unread
                data.messageSent = message.sentDate
                data.rawMessageObject = AirshipJSONUtils.toData(message.rawMessageObject.unWrap() as? [String: Any])
                data.messageReporting = AirshipJSONUtils.toData (message.messageReporting?.unWrap()as? [String: Any])
                data.messageExpiration = message.expirationDate
            }

            // Delete any messages no longer in the listing
            let messageIDs = messages.map { message in message.id }
            try self.delete(
                predicate: NSPredicate(
                    format: "NOT(messageID IN %@)",
                    messageIDs
                ),
                useBatch: !self.inMemory,
                context: context
            )
        }
        
        self.setLastMessageListModifiedTime(lastModifiedTime)
    }
}

extension InboxMessageData {
    fileprivate func message() -> MessageCenterMessage? {
        guard let title = self.title,
            let messageID = self.messageID,
            let messageBodyURL = self.messageBodyURL,
            let messageReporting = self.messageReporting,
            let messageURL = self.messageURL,
            let messageSent = self.messageSent,
            let rawMessageObject = self.rawMessageObject
        else {
            AirshipLogger.error("Invalid message data")
            return nil
        }

        return MessageCenterMessage(
            title: title,
            id: messageID,
            extra: AirshipJSONUtils.json(self.extra) as? [String : String] ?? [:],
            bodyURL: messageBodyURL,
            expirationDate: self.messageExpiration,
            messageReporting: AirshipJSONUtils.json(messageReporting) as? [String : Any] ?? [:],
            unread: (self.unread && self.unreadClient),
            sentDate: messageSent,
            messageURL: messageURL,
            rawMessageObject: AirshipJSONUtils.json(rawMessageObject) as? [String : Any] ?? [:]
        )
    }
}
