/* Copyright Airship and Contributors */

import Combine
import XCTest

@testable import AirshipCore
@testable import AirshipMessageCenter

final class MessageCenterListTest: XCTestCase {

    private var disposables = Set<AnyCancellable>()
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private lazy var config = RuntimeConfig(
        config: AirshipConfig(),
        dataStore: dataStore
    )
    private lazy var store: MessageCenterStore = {
        let modelURL = MessageCenterResources.bundle?
            .url(
                forResource: "UAInbox",
                withExtension: "momd"
            )
        if let modelURL = modelURL {
            let storeName = String(
                format: "Inbox-%@.sqlite",
                self.config.appKey
            )
            let coreData = UACoreData(
                modelURL: modelURL,
                inMemory: true,
                stores: [storeName]
            )
            return MessageCenterStore(
                config: self.config,
                dataStore: self.dataStore,
                coreData: coreData
            )
        }
        return MessageCenterStore(
            config: self.config,
            dataStore: self.dataStore
        )
    }()

    private let channel = TestChannel()
    private let workManager: TestWorkManager = TestWorkManager()
    private let client: TestMessageCenterAPIClient = TestMessageCenterAPIClient()

    private lazy var inbox = MessageCenterInbox(
        channel: channel,
        client: client,
        config: config,
        store: store,
        workManager: workManager
    )

    func testMessageCenterInboxUser() async throws {

        let expectedUser = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(expectedUser, channelID: "987654433")

        self.inbox.enabled = true
        var user = await self.inbox.user
        XCTAssertNotNil(user)
        XCTAssertEqual(user!.username, expectedUser.username)
        XCTAssertEqual(user!.password, expectedUser.password)

        self.inbox.enabled = false
        user = await self.inbox.user
        XCTAssertNil(user)

        // Reset User
        await store.resetUser()

        let resetedUser = await self.inbox.user
        XCTAssertNil(resetedUser)
    }

    func testMessageCenterIdenityHint() async throws {
        let user = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(user, channelID: "987654433")

        self.inbox.enabled = true

        XCTAssertEqual(1, self.channel.extenders.count)
        let payload = await self.channel.channelPayload
        XCTAssertEqual(user.username, payload.identityHints?.userID)
    }

    func testMessageCenterIdenityHintRestoreMessageCenterDisabled() async throws {
        self.channel.extenders.removeAll()
        let config = AirshipConfig()
        config.restoreMessageCenterOnReinstall = false

        let user = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(user, channelID: "987654433")

        let inbox = MessageCenterInbox(
            channel: channel,
            client: client,
            config: RuntimeConfig(
                config: config,
                dataStore: dataStore
            ),
            store: store,
            workManager: workManager
        )

        inbox.enabled = true

        XCTAssertEqual(1, self.channel.extenders.count)
        let payload = await self.channel.channelPayload
        XCTAssertNil(payload.identityHints?.userID)
    }

    func testRestoreMessageCenterDisabled() async throws {
        self.channel.extenders.removeAll()
        let config = AirshipConfig()
        config.restoreMessageCenterOnReinstall = false

        let user = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(user, channelID: "987654433")

        let inbox = MessageCenterInbox(
            channel: channel,
            client: client,
            config: RuntimeConfig(
                config: config,
                dataStore: dataStore
            ),
            store: store,
            workManager: workManager
        )

        inbox.enabled = true

        let fromInbox = await self.inbox.user
        let fromStore = await self.store.user

        XCTAssertNil(fromInbox)
        XCTAssertNil(fromStore)
    }


    func testMessageRetrieve() async throws {

        self.inbox.enabled = true

        try await self.store.updateMessages(
            messages: MessageCenterMessage.generateMessages(3),
            lastModifiedTime: ""
        )

        let messages = await self.inbox.messages

        XCTAssertNotNil(messages)
        XCTAssertEqual(messages.count, 3)

    }

    func testMessageRetrieveWithId() async throws {

        self.inbox.enabled = true

        let messages = MessageCenterMessage.generateMessages(1)
        try await self.store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )

        let message = try XCTUnwrap(messages.first)

        let fetchedMessage = await self.inbox.message(forID: message.id)

        XCTAssertNotNil(fetchedMessage)
        XCTAssertEqual(message.id, fetchedMessage?.id)
        XCTAssertEqual(message.sentDate, fetchedMessage?.sentDate)
        XCTAssertEqual(message.bodyURL, fetchedMessage?.bodyURL)
        XCTAssertEqual(message.expirationDate, fetchedMessage?.expirationDate)
        XCTAssertEqual(message.messageURL, fetchedMessage?.messageURL)

    }

    func testUpdateMessages() async throws {

        self.inbox.enabled = true

        let messages = MessageCenterMessage.generateMessages(1)
        let message = try XCTUnwrap(messages.first)

        // The message does not exists on the store yet
        let fetchedMessage = await self.inbox.message(forID: message.id)
        XCTAssertNil(fetchedMessage)

        let expectation = self.expectation(
            description: "waiting for message publisher"
        )
        self.inbox.messagePublisher
            .receive(on: RunLoop.main)
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &disposables)

        // Add the message to the store
        try await self.store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )

        await fulfillment(of: [expectation], timeout: 3.0)

        let updatedMessage = await self.inbox.message(forID: message.id)
        XCTAssertNotNil(updatedMessage)
    }

    func testRefreshMessages() async throws {
        self.channel.identifier = UUID().uuidString

        let expectations = self.expectation(description: "client called")
        expectations.expectedFulfillmentCount = 2

        let messages = MessageCenterMessage.generateMessages(1)
        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        self.client.onCreateUser = { channelID in
            XCTAssertEqual(channelID, self.channel.identifier)
            expectations.fulfill()
            return AirshipHTTPResponse(
                result: mcUser,
                statusCode: 200,
                headers: [:]
            )
        }

        self.client.onRetrieve = { user, channelID, lastModified in
            XCTAssertEqual(channelID, self.channel.identifier)
            XCTAssertEqual(user, mcUser)
            XCTAssertNil(lastModified)

            expectations.fulfill()
            return AirshipHTTPResponse(
                result: messages,
                statusCode: 200,
                headers: [:]
            )
        }

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        let result = await self.inbox.refreshMessages()
        XCTAssertTrue(result)
        XCTAssertFalse(self.workManager.workRequests.last!.requiresNetwork)
        XCTAssertEqual(self.workManager.workRequests.last!.conflictPolicy, .replace)
        await self.fulfillment(of: [expectations])
    }

    func testRefreshMessagesWithTimeout() async throws {
        self.channel.identifier = UUID().uuidString

        let expectations = self.expectation(description: "client called")
        expectations.expectedFulfillmentCount = 2

        let messages = MessageCenterMessage.generateMessages(1)
        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        self.client.onCreateUser = { channelID in
            XCTAssertEqual(channelID, self.channel.identifier)
            expectations.fulfill()
            return AirshipHTTPResponse(
                result: mcUser,
                statusCode: 200,
                headers: [:]
            )
        }

        self.client.onRetrieve = { user, channelID, lastModified in
            XCTAssertEqual(channelID, self.channel.identifier)
            XCTAssertEqual(user, mcUser)
            XCTAssertNil(lastModified)

            expectations.fulfill()
            return AirshipHTTPResponse(
                result: messages,
                statusCode: 200,
                headers: [:]
            )
        }

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        let result = try await self.inbox.refreshMessages(timeout: 4.0)
        XCTAssertTrue(result)
        XCTAssertFalse(self.workManager.workRequests.last!.requiresNetwork)
        XCTAssertEqual(self.workManager.workRequests.last!.conflictPolicy, .replace)
        await self.fulfillment(of: [expectations])
    }
    
    func testRefreshMessagesNoChannel() async throws {
        self.channel.identifier = nil

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        let result = await self.inbox.refreshMessages()
        XCTAssertFalse(result)
    }

    func testRefreshMessagesUserCreationFailed() async throws {
        self.channel.identifier = UUID().uuidString

        self.client.onCreateUser = { channelID in
            XCTAssertEqual(channelID, self.channel.identifier)
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        let result = await self.inbox.refreshMessages()
        XCTAssertFalse(result)
    }

    func testRefreshMessagesRetrieveFailed() async throws {
        self.channel.identifier = UUID().uuidString

        let mcUser = MessageCenterUser(
            username: UUID().uuidString,
            password: UUID().uuidString
        )

        self.client.onCreateUser = { channelID in
            XCTAssertEqual(channelID, self.channel.identifier)
            return AirshipHTTPResponse(
                result: mcUser,
                statusCode: 200,
                headers: [:]
            )
        }

        self.client.onRetrieve = { user, channelID, lastModified in
            XCTAssertEqual(channelID, self.channel.identifier)
            XCTAssertEqual(user, mcUser)
            XCTAssertNil(lastModified)

            return AirshipHTTPResponse(
                result: [],
                statusCode: 400,
                headers: [:]
            )
        }

        self.inbox.enabled = true
        self.workManager.autoLaunchRequests = true

        let result = await self.inbox.refreshMessages()
        XCTAssertFalse(result)
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
