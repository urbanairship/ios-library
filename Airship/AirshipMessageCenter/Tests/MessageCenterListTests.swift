/* Copyright Airship and Contributors */

import Combine
 
@testable
import AirshipCore
@testable
import AirshipMessageCenter

import XCTest

final class MessageCenterListTest: XCTestCase {

    private var disposables = Set<AnyCancellable>()
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private lazy var config = RuntimeConfig(config: Config(), dataStore: dataStore)
    private lazy var store: MessageCenterStore = {
        let modelURL = MessageCenterResources.bundle?.url(forResource: "UAInbox", withExtension: "momd")
        if let modelURL = modelURL {
            let storeName = String(format: "Inbox-%@.sqlite", self.config.appKey)
            let coreData = UACoreData(modelURL: modelURL, inMemory: true, stores: [storeName])
            return MessageCenterStore(config: self.config, dataStore: self.dataStore, coreData: coreData)
        }
        return MessageCenterStore(config: self.config, dataStore: self.dataStore)
    }()
    
    private let channel = TestChannel()
    private let workManager = AirshipWorkManager()
    
    private lazy var inbox = MessageCenterInbox(
        channel: channel,
        client: MessageCenterAPIClient(
            config: config,
            session: AirshipRequestSession(
                appKey: config.appKey)),
        config: config,
        store: store,
        notificationCenter: .default,
        date: AirshipDate(),
        workManager: workManager)
    
    func testMessageCenterInboxUser() async throws {
                
        let expectedUser = MessageCenterUser(username: "AnyName", password: "AnyPassword")
        
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
        
        let expectation = self.expectation(description: "waiting for message publisher")
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
        
        await waitForExpectations(timeout: 3)
        
        let updatedMessage = await self.inbox.message(forID: message.id)
        XCTAssertNotNil(updatedMessage)
    }

}
