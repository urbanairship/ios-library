/* Copyright Airship and Contributors */

import Combine
import Testing
import Foundation
@_spi(AirshipInternal) import AirshipBasement

@_spi(AirshipInternal) @testable import AirshipCore
@_spi(AirshipInternal) @testable import AirshipMessageCenter

@MainActor
struct MessageCenterListTest {

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let config: RuntimeConfig = .testConfig()

    private let store: MessageCenterStore

    private let channel = TestChannel()
    private let workManager: TestWorkManager = TestWorkManager()
    private let client: TestMessageCenterAPIClient = TestMessageCenterAPIClient()
    private let sleeper = TestTaskSleeper()
    private let notificationCenter = NotificationCenter()
    private let date = UATestDate(offset: 0, dateOverride: Date())

    private let inbox: DefaultMessageCenterInbox

    init() {
        let modelURL = AirshipMessageCenterResources.bundle
            .url(
                forResource: "UAInbox",
                withExtension: "momd"
            )
        let store: MessageCenterStore
        if let modelURL = modelURL {
            let storeName = String(
                format: "Inbox-%@.sqlite",
                self.config.appCredentials.appKey
            )
            let coreData = UACoreData(
                name: "UAInbox",
                modelURL: modelURL,
                inMemory: true,
                stores: [storeName]
            )
            store = MessageCenterStore(
                config: self.config,
                dataStore: self.dataStore,
                coreData: coreData,
                date: self.date
            )
        } else {
            store = MessageCenterStore(
                config: self.config,
                dataStore: self.dataStore,
                date: self.date
            )
        }
        self.store = store

        self.inbox = DefaultMessageCenterInbox(
            channel: channel,
            client: client,
            config: config,
            store: store,
            notificationCenter: notificationCenter,
            date: date,
            workManager: workManager,
            taskSleeper: sleeper
        )
    }

    @Test
    func testMessageCenterInboxUser() async throws {

        let expectedUser = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(expectedUser, channelID: "987654433")

        self.inbox.enabled = true
        var user = await self.inbox.user
        #expect(user != nil)
        #expect(user!.username == expectedUser.username)
        #expect(user!.password == expectedUser.password)

        self.inbox.enabled = false
        user = await self.inbox.user
        #expect(user == nil)

        // Reset User
        await store.resetUser()

        let resetedUser = await self.inbox.user
        #expect(resetedUser == nil)
    }

    @Test
    func testMessageCenterIdenityHint() async throws {
        let user = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(user, channelID: "987654433")

        self.inbox.enabled = true

        #expect(1 == self.channel.extenders.count)
        let payload = await self.channel.channelPayload
        #expect(user.username == payload.identityHints?.userID)
    }

    @Test
    func testMessageCenterIdenityHintRestoreMessageCenterDisabled() async throws {
        self.channel.extenders.removeAll()
        var airshipConfig = AirshipConfig()
        airshipConfig.restoreMessageCenterOnReinstall = false

        let user = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(user, channelID: "987654433")

        let inbox = DefaultMessageCenterInbox(
            channel: channel,
            client: client,
            config: .testConfig(airshipConfig: airshipConfig),
            store: store,
            workManager: workManager
        )

        inbox.enabled = true

        #expect(1 == self.channel.extenders.count)
        let payload = await self.channel.channelPayload
        #expect(payload.identityHints?.userID == nil)
    }

    @Test
    func testRestoreMessageCenterDisabled() async throws {
        self.channel.extenders.removeAll()
        var airshipConfig = AirshipConfig()
        airshipConfig.restoreMessageCenterOnReinstall = false

        let user = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(user, channelID: "987654433")

        let inbox = DefaultMessageCenterInbox(
            channel: channel,
            client: client,
            config: .testConfig(airshipConfig: airshipConfig),
            store: store,
            workManager: workManager
        )

        inbox.enabled = true

        let fromInbox = await self.inbox.user
        let fromStore = await self.store.user

        #expect(fromInbox == nil)
        #expect(fromStore == nil)
    }

    @Test
    func testMessageRetrieve() async throws {
        self.inbox.enabled = true

        try await self.store.updateMessages(
            messages: MessageCenterMessage.generateMessages(3),
            lastModifiedTime: ""
        )

        let messages = await self.inbox.messages

        #expect(messages.count == 3)

    }

    @Test
    func testMessageRetrieveWithId() async throws {
        self.inbox.enabled = true

        let messages = MessageCenterMessage.generateMessages(1)
        try await self.store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )

        let message = try #require(messages.first)

        let fetchedMessage = await self.inbox.message(forID: message.id)

        #expect(fetchedMessage != nil)
        #expect(message.id == fetchedMessage?.id)
        #expect(message.sentDate == fetchedMessage?.sentDate)
        #expect(message.bodyURL == fetchedMessage?.bodyURL)
        #expect(message.expirationDate == fetchedMessage?.expirationDate)
        #expect(message.messageURL == fetchedMessage?.messageURL)

    }

    @Test
    @MainActor
    func testUpdateMessages() async throws {
        self.inbox.enabled = true

        let messages = MessageCenterMessage.generateMessages(1)
        let message = try #require(messages.first)

        // The message does not exists on the store yet
        let fetchedMessage = await self.inbox.message(forID: message.id)
        #expect(fetchedMessage == nil)

        try await confirmation("waiting for message publisher", expectedCount: 1...) { confirmation in
            var disposables = Set<AnyCancellable>()
            self.inbox.messagePublisher
                .receive(on: RunLoop.main)
                .sink { _ in
                    confirmation()
                }
                .store(in: &disposables)

            // Add the message to the store
            try await self.store.updateMessages(
                messages: messages,
                lastModifiedTime: ""
            )

            // Give the main run loop time to deliver the publisher value
            try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
            _ = disposables
        }

        let updatedMessage = await self.inbox.message(forID: message.id)
        #expect(updatedMessage != nil)
    }

    @Test
    func testRefreshMessages() async throws {
        self.channel.identifier = UUID().uuidString

        var messageUpdates = self.inbox.messageUpdates.makeAsyncIterator()
        var messageUpdate = await messageUpdates.next()
        #expect(messageUpdate == [])

        var unreadCountUpdates = self.inbox.unreadCountUpdates.makeAsyncIterator()
        var unreadCountUpdate = await unreadCountUpdates.next()
        #expect(unreadCountUpdate == 0)


        let messages = MessageCenterMessage.generateMessages(1)
        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        await confirmation(expectedCount: 2) { confirmation in
            self.client.onCreateUser = { channelID in
                #expect(channelID == self.channel.identifier)
                confirmation()
                return AirshipHTTPResponse(
                    result: mcUser,
                    statusCode: 200,
                    headers: [:]
                )
            }

            self.client.onRetrieve = { user, channelID, lastModified in
                #expect(channelID == self.channel.identifier)
                #expect(user == mcUser)
                #expect(lastModified == nil)

                confirmation()
                return AirshipHTTPResponse(
                    result: messages,
                    statusCode: 200,
                    headers: [:]
                )
            }

            self.inbox.enabled = true
            self.workManager.autoLaunchRequests = true

            let result = await self.inbox.refreshMessages()
            #expect(result)
            #expect(!self.workManager.workRequests.last!.requiresNetwork)
            #expect(self.workManager.workRequests.last!.conflictPolicy == .replace)
        }

        messageUpdate = await messageUpdates.next()
        #expect(messageUpdate == messages)

        unreadCountUpdate = await unreadCountUpdates.next()
        #expect(unreadCountUpdate == 1)
    }

    @Test
    func testRefreshMessagesThrowingSuccess() async throws {
        self.channel.identifier = UUID().uuidString

        let messages = MessageCenterMessage.generateMessages(1)
        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        try await confirmation(expectedCount: 2) { confirmation in
            self.client.onCreateUser = { channelID in
                #expect(channelID == self.channel.identifier)
                confirmation()
                return AirshipHTTPResponse(
                    result: mcUser,
                    statusCode: 200,
                    headers: [:]
                )
            }

            self.client.onRetrieve = { user, channelID, lastModified in
                #expect(channelID == self.channel.identifier)
                #expect(user == mcUser)
                #expect(lastModified == nil)

                confirmation()
                return AirshipHTTPResponse(
                    result: messages,
                    statusCode: 200,
                    headers: [:]
                )
            }

            self.inbox.enabled = true
            self.workManager.autoLaunchRequests = true

            try await self.inbox.refreshMessagesThrowing()
        }

        let inboxMessages = await self.inbox.messages
        #expect(inboxMessages == messages)
    }

    @Test
    func testRefreshMessagesThrowingThrowsDisabled() async throws {
        self.inbox.enabled = false
        self.workManager.autoLaunchRequests = true

        do {
            try await self.inbox.refreshMessagesThrowing()
            Issue.record("Expected MessageCenterInboxError.disabled")
        } catch let error as MessageCenterInboxError {
            #expect(error == .disabled)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func testRefreshMessagesThrowingThrowsFailedToFetchWhenNoChannel() async throws {
        self.channel.identifier = nil
        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        do {
            try await self.inbox.refreshMessagesThrowing()
            Issue.record("Expected MessageCenterInboxError.failedToFetchMessage")
        } catch let error as MessageCenterInboxError {
            #expect(error == .failedToFetchMessage)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func testRefreshMessagesThrowingThrowsFailedToFetchWhenRetrieveFails() async throws {
        self.channel.identifier = UUID().uuidString

        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        self.client.onCreateUser = { channelID in
            #expect(channelID == self.channel.identifier)
            return AirshipHTTPResponse(
                result: mcUser,
                statusCode: 200,
                headers: [:]
            )
        }

        self.client.onRetrieve = { user, channelID, lastModified in
            #expect(channelID == self.channel.identifier)
            #expect(user == mcUser)
            #expect(lastModified == nil)

            return AirshipHTTPResponse(
                result: [],
                statusCode: 400,
                headers: [:]
            )
        }

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        do {
            try await self.inbox.refreshMessagesThrowing()
            Issue.record("Expected MessageCenterInboxError.failedToFetchMessage")
        } catch let error as MessageCenterInboxError {
            #expect(error == .failedToFetchMessage)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func testRefreshMessagesWithTimeout() async throws {
        self.channel.identifier = UUID().uuidString

        let messages = MessageCenterMessage.generateMessages(1)
        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        try await confirmation(expectedCount: 2) { confirmation in
            self.client.onCreateUser = { channelID in
                #expect(channelID == self.channel.identifier)
                confirmation()
                return AirshipHTTPResponse(
                    result: mcUser,
                    statusCode: 200,
                    headers: [:]
                )
            }

            self.client.onRetrieve = { user, channelID, lastModified in
                #expect(channelID == self.channel.identifier)
                #expect(user == mcUser)
                #expect(lastModified == nil)

                confirmation()
                return AirshipHTTPResponse(
                    result: messages,
                    statusCode: 200,
                    headers: [:]
                )
            }

            self.inbox.enabled = true
            self.workManager.autoLaunchRequests = true

            let result = try await self.inbox.refreshMessages(timeout: 4.0)
            #expect(result)
            #expect(!self.workManager.workRequests.last!.requiresNetwork)
            #expect(self.workManager.workRequests.last!.conflictPolicy == .replace)
        }
    }

    @Test
    func testRefreshMessagesNoChannel() async throws {
        self.channel.identifier = nil

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        let result = await self.inbox.refreshMessages()
        #expect(!result)
    }

    @Test
    func testRefreshMessagesUserCreationFailed() async throws {
        self.channel.identifier = UUID().uuidString

        self.client.onCreateUser = { channelID in
            #expect(channelID == self.channel.identifier)
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        let result = await self.inbox.refreshMessages()
        #expect(!result)
    }

    @Test
    func testRefreshMessagesRetrieveFailed() async throws {
        self.channel.identifier = UUID().uuidString

        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        self.client.onCreateUser = { channelID in
            #expect(channelID == self.channel.identifier)
            return AirshipHTTPResponse(
                result: mcUser,
                statusCode: 200,
                headers: [:]
            )
        }

        self.client.onRetrieve = { user, channelID, lastModified in
            #expect(channelID == self.channel.identifier)
            #expect(user == mcUser)
            #expect(lastModified == nil)

            return AirshipHTTPResponse(
                result: [],
                statusCode: 400,
                headers: [:]
            )
        }

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        let result = await self.inbox.refreshMessages()
        #expect(!result)
    }

    @Test
    func testRefreshOnMessageExpiresOnAfterUpdate() async throws {
        var sleeps = await self.sleeper.sleepUpdates.makeStream().makeAsyncIterator()

        // Pause the sleeper so the expiry-triggered second refresh can't run until we let it,
        // otherwise it can race ahead and overwrite the store before we check `fetched` below.
        await self.sleeper.pause()

        self.channel.identifier = UUID().uuidString

        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        let message = MessageCenterMessage.generateMessage(
            sentDate: self.date.now.advanced(by: -1),
            expiry: self.date.now.advanced(by: 1)
        )

        self.client.onCreateUser = { _ in
            return AirshipHTTPResponse(
                result: mcUser,
                statusCode: 200,
                headers: [:]
            )
        }

        var refreshes = AsyncStream<Bool> { continuation in
            let responses = AirshipAtomicValue([[message], []])
            self.client.onRetrieve = { _, _, _ in
                defer {
                    continuation.yield(true)
                }

                let response = responses.value.first
                responses.update { responses in
                    var updated = responses
                    if !updated.isEmpty {
                        updated.removeFirst()
                    }
                    return updated
                }

                return AirshipHTTPResponse(
                    result: response ?? [],
                    statusCode: 200,
                    headers: [:]
                )
            }
        }.makeAsyncIterator()

        #expect(self.workManager.workRequests.isEmpty)

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true
        await self.inbox.refreshMessages()
        _ = await refreshes.next()

        var fetched = await self.inbox.message(forID: message.id)
        #expect(fetched != nil)

        let sleep = await sleeps.next()
        #expect(1 == sleep)

        await self.sleeper.resume()
        _ = await refreshes.next()

        fetched = await self.inbox.message(forID: message.id)
        #expect(fetched == nil)
    }

    @Test
    func testRefreshOnMessageExpiresTakesEarliestDate() async throws {
        self.channel.identifier = UUID().uuidString

        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        let messages = [
            MessageCenterMessage.generateMessage(
                sentDate: self.date.now.advanced(by: -1),
                expiry: self.date.now.advanced(by: 2)
            ),
            MessageCenterMessage.generateMessage(
                sentDate: self.date.now.advanced(by: -1),
                expiry: self.date.now.advanced(by: 3)
            )
        ]

        // Signals the current work request count each time one is dispatched, so we can wait
        // for the third (expiry-triggered) one instead of guessing with a fixed sleep.
        let workRequestCounts = AirshipAsyncChannel<Int>()
        let workManager = self.workManager
        self.workManager.onNewWorkRequestAdded = { _ in
            Task { await workRequestCounts.send(workManager.workRequests.count) }
        }
        var workRequestCountUpdates = await workRequestCounts.makeStream().makeAsyncIterator()

        // Pause the sleeper so the expiry-triggered second refresh can't run until we let it,
        // otherwise it can race ahead and overwrite the store before we check `saved` below.
        await self.sleeper.pause()

        self.client.onCreateUser = { _ in
            return AirshipHTTPResponse(
                result: mcUser,
                statusCode: 200,
                headers: [:]
            )
        }

        var isRefreshed = false
        self.client.onRetrieve = { _, _, _ in
            defer { isRefreshed = true }

            return AirshipHTTPResponse(
                result: isRefreshed ? [] : messages,
                statusCode: 200,
                headers: [:]
            )
        }


        #expect(self.workManager.workRequests.isEmpty)

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        await self.inbox.refreshMessages()

        let saved = await self.inbox.message(forID: messages.first!.id)
        #expect(saved != nil)

        await self.sleeper.resume()
        while await workRequestCountUpdates.next() != 3 {}

        #expect(3 == self.workManager.workRequests.count)
    }

    @Test
    func testNoRefreshWithNoExpirationDate() async throws {
        self.channel.identifier = UUID().uuidString

        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        let messages = [
            MessageCenterMessage.generateMessage(
                sentDate: self.date.now.advanced(by: -1)
            ),
            MessageCenterMessage.generateMessage(
                sentDate: self.date.now.advanced(by: -2)
            )
        ]

        self.client.onCreateUser = { _ in
            return AirshipHTTPResponse(
                result: mcUser,
                statusCode: 200,
                headers: [:]
            )
        }

        var isRefreshed = false
        self.client.onRetrieve = { _, _, _ in
            defer { isRefreshed = true }

            return AirshipHTTPResponse(
                result: isRefreshed ? [] : messages,
                statusCode: 200,
                headers: [:]
            )
        }

        #expect(self.workManager.workRequests.isEmpty)

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        await self.inbox.refreshMessages()

        let saved = await self.inbox.message(forID: messages.first!.id)
        #expect(saved != nil)

        self.date.advance(by: 1)

        #expect(2 == self.workManager.workRequests.count)
    }
}


fileprivate final class TestMessageCenterAPIClient : MessageCenterAPIClientProtocol, @unchecked Sendable {
    var onRetrieve: ((MessageCenterUser, String, String?) async throws -> AirshipHTTPResponse<[MessageCenterMessage]>)?
    var onDelete: (([MessageCenterMessage], MessageCenterUser, String) async throws -> AirshipHTTPResponse<Void>)?
    var onRead: (([MessageCenterMessage], MessageCenterUser, String) async throws -> AirshipHTTPResponse<Void>)?
    var onCreateUser: ((String) async throws -> AirshipHTTPResponse<MessageCenterUser>)?
    var onUpdateUser: ((MessageCenterUser, String) async throws -> AirshipHTTPResponse<Void>)?

    func retrieveMessageList(user: MessageCenterUser, channelID: String, lastModified: String?) async throws -> AirshipHTTPResponse<[MessageCenterMessage]> {
        return try await self.onRetrieve!(user, channelID, lastModified)
    }
    
    func performBatchDelete(forMessages messages: [MessageCenterMessage], user: MessageCenterUser, channelID: String) async throws -> AirshipHTTPResponse<Void> {
        return try await self.onDelete!(messages, user, channelID)
    }
    
    func performBatchMarkAsRead(forMessages messages: [MessageCenterMessage], user: MessageCenterUser, channelID: String) async throws -> AirshipHTTPResponse<Void> {
        return try await self.onRead!(messages, user, channelID)
    }
    
    func createUser(withChannelID channelID: String) async throws -> AirshipHTTPResponse<MessageCenterUser> {
        return try await self.onCreateUser!(channelID)
    }
    
    func updateUser(_ user: MessageCenterUser, channelID: String) async throws -> AirshipHTTPResponse<Void> {
        return try await self.onUpdateUser!(user, channelID)
    }
    
}

actor TestTaskSleeper : AirshipTaskSleeper {
    var sleepUpdates: AirshipAsyncChannel<TimeInterval> = AirshipAsyncChannel()
    var sleeps : [TimeInterval] = []
    private var isPaused = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    /// Once paused, subsequent sleep() calls park until resume() is called.
    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }

    func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
        await sleepUpdates.send(timeInterval)
        await Task.yield()

        if isPaused {
            await withCheckedContinuation { continuations.append($0) }
        }
    }
}
