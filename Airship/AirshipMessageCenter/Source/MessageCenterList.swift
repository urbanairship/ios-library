/* Copyright Airship and Contributors */

import Foundation
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc(UAMessageCenterInboxBaseProtocol)
public protocol MessageCenterInboxBaseProtocol {

    @objc(getMessagesWithCompletionHandler:)
    func _getMessages() async -> [MessageCenterMessage]

    @objc(getUserWithCompletionHandler:)
    func _getUser() async -> MessageCenterUser?

    @objc(getUnreadCountWithCompletionHandler:)
    func _getUnreadCount() async -> Int

    @objc
    @discardableResult
    func refreshMessages() async -> Bool

    @objc
    func markRead(messages: [MessageCenterMessage]) async

    @objc
    func markRead(messageIDs: [String]) async

    @objc
    func delete(messages: [MessageCenterMessage]) async

    @objc
    func delete(messageIDs: [String]) async

    @objc
    func message(forBodyURL bodyURL: URL) async -> MessageCenterMessage?

    @objc
    func message(forID messageID: String) async -> MessageCenterMessage?
}

public protocol MessageCenterInboxProtocol: MessageCenterInboxBaseProtocol {
    var messagePublisher: AnyPublisher<[MessageCenterMessage], Never> { get }
    var unreadCountPublisher: AnyPublisher<Int, Never> { get }
    var messages: [MessageCenterMessage] { get async }
    var user: MessageCenterUser? { get async }
    var unreadCount: Int { get async }
}

@objc(UAMessageCenterInbox)
public class MessageCenterInbox: NSObject, MessageCenterInboxProtocol {
    private enum UpdateType {
        case local
        case refreshSucess
        case refreshFailed
    }

    private let updateSubject = PassthroughSubject<UpdateType, Never>()

    private let updateWorkID = "Airship.MessageCenterInbox#update"

    public static let messageListUpdatedEvent = NSNotification.Name(
        "com.urbanairship.notification.message_list_updated"
    )

    private let store: MessageCenterStore
    private let channel: ChannelProtocol
    private let client: MessageCenterAPIClient
    private let config: RuntimeConfig
    private let notificationCenter: NotificationCenter
    private let date: AirshipDate
    private let workManager: AirshipWorkManagerProtocol
    var enabled: Bool = false {
        didSet {
            self.dispatchUpdateWorkRequest()
        }
    }

    private var messagesFuture: Future<[MessageCenterMessage], Never> {
        return Future { promise in
            Task {
                let messages = await self.messages
                promise(.success(messages))
            }
        }
    }

    private var unreadCountFuture: Future<Int, Never> {
        return Future { promise in
            Task {
                let count = await self.unreadCount
                promise(.success(count))
            }
        }
    }

    public var messagePublisher: AnyPublisher<[MessageCenterMessage], Never> {
        return self.updateSubject
            .filter { update in
                update != .refreshFailed
            }
            .flatMap { _ in
                self.messagesFuture
            }
            .prepend(self.messagesFuture.eraseToAnyPublisher())
            .eraseToAnyPublisher()
    }

    public var unreadCountPublisher: AnyPublisher<Int, Never> {
        return self.updateSubject
            .filter { update in
                update != .refreshFailed
            }
            .flatMap { _ in
                self.unreadCountFuture
            }
            .prepend(self.unreadCountFuture.eraseToAnyPublisher())
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var messages: [MessageCenterMessage] {
        get async {
            return await _getMessages()
        }
    }

    public var user: MessageCenterUser? {
        get async {
            return await _getUser()
        }
    }

    public var unreadCount: Int {
        get async {
            return await _getUnreadCount()
        }
    }

    private var subscriptions: Set<AnyCancellable> = Set()

    init(
        channel: ChannelProtocol,
        client: MessageCenterAPIClient,
        config: RuntimeConfig,
        store: MessageCenterStore,
        notificationCenter: NotificationCenter,
        date: AirshipDate,
        workManager: AirshipWorkManagerProtocol
    ) {
        self.channel = channel
        self.client = client
        self.config = config
        self.store = store
        self.notificationCenter = notificationCenter
        self.date = date
        self.workManager = workManager

        super.init()

        workManager.registerWorker(
            updateWorkID,
            type: .serial
        ) { [weak self] request in
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
            forName: Channel.channelCreatedEvent,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.dispatchUpdateWorkRequest(
                conflictPolicy: .replace
            )
        }

        self.updateSubject
            .filter { update in update != .refreshFailed }
            .receive(on: RunLoop.main)
            .sink { _ in
                notificationCenter.post(
                    name: MessageCenterInbox.messageListUpdatedEvent,
                    object: nil
                )
            }.store(in: &self.subscriptions)

        self.channel.addRegistrationExtender { [weak self] payload, completionHandler in
            Task { [weak self] in
                guard self?.enabled == true,
                      let user = await self?.store.user
                else {
                    completionHandler(payload)
                    return
                }

                if (payload.identityHints == nil) {
                    let identityHints = ChannelRegistrationPayload.IdentityHints()
                    payload.identityHints = identityHints
                }

                payload.identityHints?.userID = user.username
                completionHandler(payload)
            }
        }
    }

    convenience init (
        with config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: ChannelProtocol,
        workManager: AirshipWorkManagerProtocol
    ) {
        self.init(
            channel: channel,
            client: MessageCenterAPIClient(
                config: config,
                session: AirshipRequestSession(
                    appKey: config.appKey
                )
            ),
            config: config,
            store: MessageCenterStore(
                config: config,
                dataStore: dataStore
            ),
            notificationCenter: .default,
            date: AirshipDate(),
            workManager: workManager
        )
    }

    public func _getMessages() async -> [MessageCenterMessage] {
        guard self.enabled else {
            AirshipLogger.error("Message center is disabled")
            return []
        }
        return await self.store.messages
    }

    public func _getUser() async -> MessageCenterUser? {
        guard self.enabled else {
            AirshipLogger.error("Message center is disabled")
            return nil
        }

        return await self.store.user
    }

    public func _getUnreadCount() async -> Int {
        guard self.enabled else {
            AirshipLogger.error("Message center is disabled")
            return 0
        }

        return await self.store.unreadCount
    }

    @objc
    @discardableResult
    public func refreshMessages() async -> Bool {
        if !self.enabled {
            AirshipLogger.error("Message center is disabled")
            return false
        }

        var cancellable: AnyCancellable?
        let onCancel = {
            cancellable?.cancel()
        }

        return await withTaskCancellationHandler(
            operation: {
                return await withCheckedContinuation { continuation in
                    cancellable = self.updateSubject
                        .filter { update in
                            update == .refreshFailed || update == .refreshSucess
                        }
                        .first()
                        .sink { result in
                            let success = result == .refreshSucess
                            continuation.resume(returning: success)
                        }

                    self.dispatchUpdateWorkRequest(
                        conflictPolicy: .replace
                    )
                }
            },
            onCancel: {
                onCancel()
            }
        )
    }

    @objc
    public func markRead(messages: [MessageCenterMessage]) async {
        await self.markRead(
            messageIDs: messages.map { message in message.id }
        )
    }

    @objc
    public func markRead(messageIDs: [String]) async {
        do {
            try await self.store.markRead(messageIDs: messageIDs, level: .local)
            self.dispatchUpdateWorkRequest()
            self.updateSubject.send(.local)
        } catch {
            AirshipLogger.error("Failed to mark messages read: \(error)")
        }
    }

    @objc
    public func delete(messages: [MessageCenterMessage]) async {
        await self.delete(
            messageIDs: messages.map { message in message.id }
        )
    }

    @objc
    public func delete(messageIDs: [String]) async {
        do {
            try await self.store.markDeleted(messageIDs: messageIDs)
            self.dispatchUpdateWorkRequest()
            self.updateSubject.send(.local)
        } catch {
            AirshipLogger.error("Failed to delete messages: \(error)")
        }
    }

    @objc
    public func message(forBodyURL bodyURL: URL) async -> MessageCenterMessage? {
        do {
            return try await self.store.message(forBodyURL: bodyURL)
        } catch {
            AirshipLogger.error("Failed to fetch message: \(error)")
            return nil
        }

    }

    public func message(forID messageID: String) async -> MessageCenterMessage? {
        do {
            return try await self.store.message(forID: messageID)
        } catch {
            AirshipLogger.error("Failed to fetch message: \(error)")
            return nil
        }
    }


    private func getOrCreateUser(forChannelID channelID: String) async -> MessageCenterUser? {
        guard let user = await self.store.user else {
            do {
                AirshipLogger.debug("Creating Message Center user")

                let response = try await self.client.createUser(withChannelID: channelID)
                AirshipLogger.debug("Message Center user create request finished with response: \(response)")

                if let user = response.result {
                    await self.store.saveUser(user, channelID: channelID)
                    return user
                } else {
                    return nil
                }
            } catch {
                AirshipLogger.info("Failed to create Message Center user: \(error)")
                return nil
            }
        }

        let requireUpdate = await self.store.userRequiredUpdate
        let channelMismatch = await self.store.registeredChannelID != channelID

        if (requireUpdate || channelMismatch) {
            do {
                AirshipLogger.debug("Updating Message Center user")
                let response = try await self.client.updateUser(
                    user,
                    channelID: channelID
                )

                AirshipLogger.debug("Message Center update request finished with response: \(response)")

                if (response.isSuccess) {
                    await self.store.setUserRequireUpdate(true)
                    return user
                } else {
                    return nil
                }
            } catch {
                AirshipLogger.info("Failed to update Message Center user: \(error)")
                return nil
            }
        } else {
            return user
        }
    }

    private func updateInbox() async throws -> AirshipWorkResult {
        guard let channelID = channel.identifier else { return .success }

        guard let user = await getOrCreateUser(
            forChannelID: channelID
        )
        else {
            self.updateSubject.send(.refreshFailed)
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

        if (syncedList) {
            self.updateSubject.send(.refreshSucess)
        } else {
            self.updateSubject.send(.refreshFailed)
        }

        if syncedRead && synedDeleted && syncedList {
            return .success
        } else {
            return .failure
        }
    }


    // MARK: Enqueue tasks

    private func dispatchUpdateWorkRequest(
        conflictPolicy: AirshipWorkRequest.ConflictPolicy = .keep
    ) {
        self.workManager.dispatchWorkRequest(
            AirshipWorkRequest(
                workID: self.updateWorkID,
                requiresNetwork: true,
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
            let response =  try await self.client.retrieveMessageList(
                user: user,
                channelID: channelID,
                lastModified: lastModified
            )

            guard response.isSuccess,
                  let messages = response.result
            else {
                AirshipLogger.error("Retrieve list message failed")
                return false
            }

            try await self.store.updateMessages(
                messages: messages,
                lastModifiedTime: response.headers["Last-Modified"] as? String
            )
            return true
        } catch {
            AirshipLogger.error("Retrieve message list failed")
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

            AirshipLogger.trace("Synchronizing locally read messages on server. \(messages)")
            let response = try await self.client.performBatchMarkAsRead(
                forMessages: messages,
                user: user,
                channelID: channelID
            )

            if response.isSuccess {
                AirshipLogger.trace("Successfully synchronized locally read messages on server.")

                try await self.store.markRead(
                    messageIDs: messages.compactMap{ $0.id },
                    level: .local
                )
                return true
            }
        } catch {
            AirshipLogger.trace("Failed to synchronize locally read messages on server.")
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

            AirshipLogger.trace("Synchronizing locally deleted messages on server.");
            let response = try await self.client.performBatchDelete(
                forMessages: messages,
                user: user,
                channelID: channelID
            )

            if response.isSuccess {
                AirshipLogger.trace("Successfully synchronized locally deleted messages on server.")

                try await self.store.delete(
                    messageIDs: messages.compactMap{ $0.id }
                )

                return true
            }

        } catch {
            AirshipLogger.trace("Failed to synchronize locally deleted messages on server.")
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

