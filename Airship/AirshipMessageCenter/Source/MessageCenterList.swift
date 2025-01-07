/* Copyright Airship and Contributors */

public import Combine

import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// Airship Message Center inbox protocol.
public protocol MessageCenterInboxProtocol: AnyObject, Sendable {

    /// Refreshes the list of messages in the inbox.
    /// - Returns: `true` if the messages was refreshed, otherwise `false`.
    @discardableResult
    func refreshMessages() async -> Bool

    /// Marks messages read.
    /// - Parameters:
    ///     - messages: The list of messages to be marked read.
    func markRead(messages: [MessageCenterMessage]) async

    /// Marks messages read by message IDs.
    /// - Parameters:
    ///     - messageIDs: The list of message IDs for the messages to be marked read.
    func markRead(messageIDs: [String]) async

    /// Marks messages deleted.
    /// - Parameters:
    ///     - messages: The list of messages to be marked deleted.
    func delete(messages: [MessageCenterMessage]) async

    /// Marks messages deleted by message IDs.
    /// - Parameters:
    ///     - messageIDs: The list of message IDs for the messages to be marked deleted.
    func delete(messageIDs: [String]) async

    /// Returns the message associated with a particular URL.
    /// - Parameters:
    ///     - bodyURL: The URL of the message.
    /// - Returns: The associated `MessageCenterMessage` object or nil if a message was unable to be found.
    func message(forBodyURL bodyURL: URL) async -> MessageCenterMessage?

    /// Returns the message associated with a particular ID.
    /// - Parameters:
    ///     - messageID: The message ID.
    /// - Returns: The associated `MessageCenterMessage` object or nil if a message was unable to be found.
    func message(forID messageID: String) async -> MessageCenterMessage?

    /// Publisher that emits messages.
    @MainActor
    var messagePublisher: AnyPublisher<[MessageCenterMessage], Never> { get }
    
    /// Async Stream on messages' updates
    var messageUpdates: AsyncStream<[MessageCenterMessage]> { get }
    
    /// Publisher that emits unread counts.
    @MainActor
    var unreadCountPublisher: AnyPublisher<Int, Never> { get }
    
    /// Async Stream of unread count updates
    var unreadCountUpdates: AsyncStream<Int> { get }
    
    /// The list of messages in the inbox.
    var messages: [MessageCenterMessage] { get async }

    /// The user associated to the Message Center
    var user: MessageCenterUser? { get async }

    /// The number of messages that are currently unread.
    var unreadCount: Int { get async }

    /// Refreshes the list of messages in the inbox.
    /// - Returns: `true` if the messages was refreshed, otherwise `false`.
    @discardableResult
    func refreshMessages(timeout: TimeInterval) async throws -> Bool
}

/// Airship Message Center inbox.
final class MessageCenterInbox: MessageCenterInboxProtocol, Sendable {
    
    private enum UpdateType: Sendable {
        case local
        case refreshSucess
        case refreshFailed
    }

    private let updateWorkID = "Airship.MessageCenterInbox#update"

    private let store: MessageCenterStore
    private let channel: any InternalAirshipChannelProtocol
    private let client: any MessageCenterAPIClientProtocol
    private let config: RuntimeConfig
    private let notificationCenter: NotificationCenter
    private let date: any AirshipDateProtocol
    private let workManager: any AirshipWorkManagerProtocol
    private let startUpTask: Task<Void, Never>?
    private let _enabled: AirshipAtomicValue<Bool> = AirshipAtomicValue(false)
    private let refreshOnExpireTask: AirshipAtomicValue<Task<Void, any Error>?> = AirshipAtomicValue(nil)
    private let taskSleeper: any AirshipTaskSleeper
    
    var enabled: Bool {
        get {
            _enabled.value
        }
        set {
            if (_enabled.setValue(newValue)) {
                self.dispatchUpdateWorkRequest()
            }
        }
    }

    @MainActor
    public var messagePublisher: AnyPublisher<[MessageCenterMessage], Never> {
        return self.messageUpdates
            .airshipPublisher
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    var messageUpdates: AsyncStream<[MessageCenterMessage]> {
        return self.updateChannel.makeNonIsolatedDedupingStream { [weak self] in
            await self?.messages
        } transform: { [weak self] _ in
            await self?.messages
        }
    }

    @MainActor
    public var unreadCountPublisher: AnyPublisher<Int, Never> {
        return self.unreadCountUpdates
            .airshipPublisher
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    var unreadCountUpdates: AsyncStream<Int> {
        return self.updateChannel.makeNonIsolatedDedupingStream { [weak self] in
            await self?.unreadCount
        } transform: { [weak self] _ in
            await self?.unreadCount
        }
    }

    public var messages: [MessageCenterMessage] {
        get async {
            guard self.enabled else {
                AirshipLogger.error("Message center is disabled")
                return []
            }
            return await self.store.messages
        }
    }

    public var user: MessageCenterUser? {
        get async {
            guard self.enabled else {
                AirshipLogger.error("Message center is disabled")
                return nil
            }

            await self.startUpTask?.value
            return await self.store.user
        }
    }

    public var unreadCount: Int {
        get async {
            guard self.enabled else {
                AirshipLogger.error("Message center is disabled")
                return 0
            }

            return await self.store.unreadCount
        }
    }
    
    init(
        channel: any InternalAirshipChannelProtocol,
        client: any MessageCenterAPIClientProtocol,
        config: RuntimeConfig,
        store: MessageCenterStore,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        date: any AirshipDateProtocol = AirshipDate.shared,
        workManager: any AirshipWorkManagerProtocol,
        taskSleeper: (any AirshipTaskSleeper)? = nil
    ) {
        self.channel = channel
        self.client = client
        self.config = config
        self.store = store
        self.notificationCenter = notificationCenter
        self.date = date
        self.workManager = workManager
        self.taskSleeper = taskSleeper ?? DefaultAirshipTaskSleeper.shared

        self.startUpTask = if channel.identifier == nil, !config.airshipConfig.restoreMessageCenterOnReinstall {
            Task { [weak store] in
                await store?.resetUser()
            }
        } else {
            nil
        }
        
        workManager.registerWorker(
            updateWorkID
        ) { [weak self] request in
            self?.refreshOnExpireTask.value?.cancel()
            return try await self?.updateInbox() ?? .success
        }

        notificationCenter.addObserver(
            forName: RuntimeConfig.configUpdatedEvent,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.remoteURLConfigUpdated()
        }

        notificationCenter.addObserver(
            forName: AppStateTracker.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.dispatchUpdateWorkRequest()
        }
        
        notificationCenter.addObserver(
            forName: AppStateTracker.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshOnExpireTask.value?.cancel()
        }

        notificationCenter.addObserver(
            forName: AirshipNotifications.ChannelCreated.name,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.dispatchUpdateWorkRequest(
                conflictPolicy: .replace
            )
        }

        Task { @MainActor [weak self] in
            guard let stream = await self?.updateChannel.makeStream() else { return }
            for await update in stream {
                guard update != .refreshFailed else { continue }
                notificationCenter.post(
                    name: AirshipNotifications.MessageCenterListUpdated.name,
                    object: nil
                )
                
                await self?.setupRefreshOnMessageExpires()
            }
        }

        self.channel.addRegistrationExtender { [weak self] payload in
            await self?.startUpTask?.value
            guard self?.enabled == true,
                  let user = await self?.store.user
            else {
                return payload
            }

            var payload = payload
            if payload.identityHints == nil {
                payload.identityHints = ChannelRegistrationPayload.IdentityHints(
                    userID: user.username
                )
            } else {
                payload.identityHints?.userID = user.username
            }


            return payload
        }
    }

    convenience init(
        with config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: any InternalAirshipChannelProtocol,
        workManager: any AirshipWorkManagerProtocol
    ) {
        self.init(
            channel: channel,
            client: MessageCenterAPIClient(
                config: config,
                session: config.requestSession
            ),
            config: config,
            store: MessageCenterStore(
                config: config,
                dataStore: dataStore
            ),
            workManager: workManager
        )
    }

    private func sendUpdate(_ update: UpdateType) async {
        await self.updateChannel.send(update)
    }
    
    private func setupRefreshOnMessageExpires() async {
        self.refreshOnExpireTask.value?.cancel()
        
        guard
            let refresh = await self.messages
                .compactMap({ $0.expirationDate })
                .sorted()
                .first
        else {
            return
        }
        
        let delay = refresh.timeIntervalSince(self.date.now)
        
        self.refreshOnExpireTask.value = Task { [weak self] in
            try await self?.taskSleeper.sleep(timeInterval: delay)
            self?.dispatchUpdateWorkRequest()
        }
    }

    private let updateChannel: AirshipAsyncChannel<UpdateType> = AirshipAsyncChannel()

    @discardableResult
    public func refreshMessages() async -> Bool {
        if !self.enabled {
            AirshipLogger.error("Message center is disabled")
            return false
        }

        let stream = await updateChannel.makeStream()

        dispatchUpdateWorkRequest(
            conflictPolicy: .replace,
            requireNetwork: false
        )

        for await update in stream {
            guard !Task.isCancelled else { break }
            guard update == .refreshSucess || update == .refreshFailed else {
                continue
            }
            return update == .refreshSucess
        }
        return false
    }

    func refreshMessages(timeout: TimeInterval) async throws -> Bool {
        return try await withThrowingTaskGroup(of: Bool.self) { [weak self] group in

            group.addTask { [weak self] in
                return await self?.refreshMessages() ?? false
            }

            group.addTask {
                try await _Concurrency.Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AirshipErrors.error("Timed out")
            }

            guard let success = try await group.next() else {
                group.cancelAll()
                throw CancellationError()
            }
            group.cancelAll()
            return success
        }
    }

    public func markRead(messages: [MessageCenterMessage]) async {
        await self.markRead(
            messageIDs: messages.map { message in message.id }
        )
    }

    public func markRead(messageIDs: [String]) async {
        do {
            try await self.store.markRead(messageIDs: messageIDs, level: .local)
            self.dispatchUpdateWorkRequest()
            await self.sendUpdate(.local)
        } catch {
            AirshipLogger.error("Failed to mark messages read: \(error)")
        }
    }

    public func delete(messages: [MessageCenterMessage]) async {
        await self.delete(
            messageIDs: messages.map { message in message.id }
        )
    }

    public func delete(messageIDs: [String]) async {
        do {
            try await self.store.markDeleted(messageIDs: messageIDs)
            self.dispatchUpdateWorkRequest()
            await self.sendUpdate(.local)
        } catch {
            AirshipLogger.error("Failed to delete messages: \(error)")
        }
    }

    public func message(forBodyURL bodyURL: URL) async -> MessageCenterMessage?
    {
        do {
            return try await self.store.message(forBodyURL: bodyURL)
        } catch {
            AirshipLogger.error("Failed to fetch message: \(error)")
            return nil
        }

    }

    public func message(forID messageID: String) async -> MessageCenterMessage?
    {
        do {
            return try await self.store.message(forID: messageID)
        } catch {
            AirshipLogger.error("Failed to fetch message: \(error)")
            return nil
        }
    }

    private func getOrCreateUser(forChannelID channelID: String) async
        -> MessageCenterUser?
    {
        guard let user = await self.store.user else {
            do {
                AirshipLogger.debug("Creating Message Center user")

                let response = try await self.client.createUser(
                    withChannelID: channelID
                )
                AirshipLogger.debug(
                    "Message Center user create request finished with response: \(response)"
                )

                guard let user = response.result else {
                    return nil
                }
                await self.store.setUserRequireUpdate(false)
                await self.store.saveUser(user, channelID: channelID)
                return user
            } catch {
                AirshipLogger.info(
                    "Failed to create Message Center user: \(error)"
                )
                return nil
            }
        }

        let requireUpdate = await self.store.userRequiredUpdate
        let channelMismatch = await self.store.registeredChannelID != channelID

        guard requireUpdate || channelMismatch else {
            return user
        }

        do {
            AirshipLogger.debug("Updating Message Center user")
            let response = try await self.client.updateUser(
                user,
                channelID: channelID
            )

            AirshipLogger.debug(
                "Message Center update request finished with response: \(response)"
            )

            guard response.isSuccess else {
                return nil
            }

            await self.store.setUserRegisteredChannelID(channelID)
            await self.store.setUserRequireUpdate(false)
            return user
        } catch {
            AirshipLogger.info("Failed to update Message Center user: \(error)")
            return nil
        }
    }

    private func updateInbox() async throws -> AirshipWorkResult {
        await self.startUpTask?.value

        guard let channelID = channel.identifier else {
            await self.sendUpdate(.refreshFailed)
            return .success
        }

        guard
            let user = await getOrCreateUser(
                forChannelID: channelID
            )
        else {
            await self.sendUpdate(.refreshFailed)
            return .failure
        }

        let syncedRead = await syncReadMessageState(
            user: user,
            channelID: channelID
        )

        let synedDeleted = await syncDeletedMessageState(
            user: user,
            channelID: channelID
        )

        let syncedList = await syncMessageList(
            user: user,
            channelID: channelID
        )

        if syncedList {
            await self.sendUpdate(.refreshSucess)
        } else {
            await self.sendUpdate(.refreshFailed)
        }

        guard syncedRead && synedDeleted && syncedList else {
            return .failure
        }
        return .success
    }

    // MARK: Enqueue tasks

    private func dispatchUpdateWorkRequest(
        conflictPolicy: AirshipWorkRequestConflictPolicy = .keepIfNotStarted,
        requireNetwork: Bool = true
    ) {
        self.workManager.dispatchWorkRequest(
            AirshipWorkRequest(
                workID: self.updateWorkID,
                requiresNetwork: requireNetwork,
                conflictPolicy: conflictPolicy
            )
        )
    }

    private func syncMessageList(
        user: MessageCenterUser,
        channelID: String
    ) async -> Bool {
        do {
            let lastModified = await self.store.lastMessageListModifiedTime
            let response = try await self.client.retrieveMessageList(
                user: user,
                channelID: channelID,
                lastModified: lastModified
            )

            guard
                response.isSuccess || response.statusCode == 304
            else {
                AirshipLogger.error("Retrieve list message failed")
                return false
            }

            if response.isSuccess, let messages = response.result {
                try await self.store.updateMessages(
                    messages: messages,
                    lastModifiedTime: response.headers["Last-Modified"]
                )
            }
            
            return true
        } catch {
            AirshipLogger.error("Retrieve message list failed with error \(error.localizedDescription)")
        }

        return false
    }

    private func syncReadMessageState(
        user: MessageCenterUser,
        channelID: String
    ) async -> Bool {
        do {
            let messages = try await self.store.fetchLocallyReadOnlyMessages()
            guard !messages.isEmpty else {
                return true
            }

            AirshipLogger.trace(
                "Synchronizing locally read messages on server. \(messages)"
            )
            let response = try await self.client.performBatchMarkAsRead(
                forMessages: messages,
                user: user,
                channelID: channelID
            )

            if response.isSuccess {
                AirshipLogger.trace(
                    "Successfully synchronized locally read messages on server."
                )

                try await self.store.markRead(
                    messageIDs: messages.compactMap { $0.id },
                    level: .local
                )
                return true
            }
        } catch {
            AirshipLogger.trace(
                "Failed to synchronize locally read messages on server."
            )
        }
        return false
    }

    private func syncDeletedMessageState(
        user: MessageCenterUser,
        channelID: String
    ) async -> Bool {
        do {

            let messages = try await self.store.fetchLocallyDeletedMessages()
            guard !messages.isEmpty else {
                return true
            }

            AirshipLogger.trace(
                "Synchronizing locally deleted messages on server."
            )
            let response = try await self.client.performBatchDelete(
                forMessages: messages,
                user: user,
                channelID: channelID
            )

            if response.isSuccess {
                AirshipLogger.trace(
                    "Successfully synchronized locally deleted messages on server."
                )

                try await self.store.delete(
                    messageIDs: messages.compactMap { $0.id }
                )

                return true
            }

        } catch {
            AirshipLogger.trace(
                "Failed to synchronize locally deleted messages on server."
            )
        }
        return false
    }

    private func remoteURLConfigUpdated() {
        Task {
            await self.store.setUserRequireUpdate(true)
            dispatchUpdateWorkRequest(
                conflictPolicy: .replace
            )
        }
    }
}


public extension AirshipNotifications {
    
    /// NSNotification info when the inbox is updated is updated.
    final class MessageCenterListUpdated: NSObject {

        /// NSNotification name.
        public static let name = NSNotification.Name(
            "com.urbanairship.notification.message_list_updated"
        )
    }
}
