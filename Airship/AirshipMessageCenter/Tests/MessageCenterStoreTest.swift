/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore
@testable import AirshipMessageCenter

struct MessageCenterStoreTest {
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let config: RuntimeConfig = .testConfig()

    private let store: MessageCenterStore

    init() {
        let modelURL = AirshipMessageCenterResources.bundle
            .url(
                forResource: "UAInbox",
                withExtension: "momd"
            )
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
            self.store = MessageCenterStore(
                config: self.config,
                dataStore: self.dataStore,
                coreData: coreData
            )
        } else {
            self.store = MessageCenterStore(
                config: self.config,
                dataStore: self.dataStore
            )
        }
    }

    @Test
    func testMessageCenterStoreSaveAndResetUser() async throws {

        let expectedUser = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(expectedUser, channelID: "987654433")

        let user = await store.user
        #expect(user != nil)
        #expect(user!.username == expectedUser.username)
        #expect(user!.password == expectedUser.password)

        // Reset User
        await store.resetUser()

        let resetedUser = await store.user
        #expect(resetedUser == nil)
    }

    @Test
    func testUserRequiredUpdate() async throws {
        // Set setUserRequireUpdate true
        await store.setUserRequireUpdate(true)
        var requiredUpdate = await store.userRequiredUpdate
        #expect(requiredUpdate)

        // Set Required update false
        await store.setUserRequireUpdate(false)
        requiredUpdate = await store.userRequiredUpdate
        #expect(!requiredUpdate)
    }

    @Test
    func testFetchMessages() async throws {
        let messages = MessageCenterMessage.generateMessages(3)

        try await store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )
    }

    @Test
    func testUpdateAssociatedDataPersistsMutation() async throws {
        let messages = MessageCenterMessage.generateMessages(1)
        try await store.updateMessages(messages: messages, lastModifiedTime: "")

        let viewState = MessageCenterMessage.AssociatedData.ViewState(
            restoreID: "restore-1",
            state: Data("state".utf8)
        )
        try await store.updateAssociatedData(for: messages[0].id) { $0.viewState = viewState }

        let fetched = await store.associatedData(for: messages[0].id)
        #expect(fetched.viewState == viewState)
    }

    @Test
    func testUpdateAssociatedDataDoesNotAffectOtherMessages() async throws {
        let messages = MessageCenterMessage.generateMessages(3)
        try await store.updateMessages(messages: messages, lastModifiedTime: "")

        try await store.updateAssociatedData(for: messages[0].id) {
            $0.viewState = .init(restoreID: "only-first", state: nil)
        }

        let second = await store.associatedData(for: messages[1].id)
        let third = await store.associatedData(for: messages[2].id)
        #expect(second.viewState == nil)
        #expect(third.viewState == nil)
    }

    @Test
    func testUpdateAssociatedDataThrowsForMissingMessage() async throws {
        do {
            try await store.updateAssociatedData(for: "nonexistent-id") { $0.viewState = nil }
            Issue.record("Expected an error to be thrown")
        } catch MessageCenterStoreError.coreDataError {
            // expected
        }
    }

    @Test
    func testSyncMessages() async throws {
        let generated = MessageCenterMessage.generateMessages(5)
        var messages = Array(generated[0...2])

        try await store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )

        var fetchedMessage = await store.messages
        #expect(messages == fetchedMessage)

        messages.remove(at: 0)
        messages.append(contentsOf: generated[3...4])

        try await store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )

        fetchedMessage = await store.messages
        #expect(messages == fetchedMessage)
    }
}

extension MessageCenterMessage {

    static func generateMessage(
        sentDate: Date = Date(),
        expiry: Date? = nil
    ) -> MessageCenterMessage {
        return MessageCenterMessage(
            title: UUID().uuidString,
            id: UUID().uuidString,
            contentType: .html,
            extra: [UUID().uuidString: UUID().uuidString],
            bodyURL: URL(
                string: "https://www.some-url.fr/\(UUID().uuidString)"
            )!,
            expirationDate: expiry,
            messageReporting: [UUID().uuidString: .string(UUID().uuidString)],
            unread: true,
            sentDate: sentDate,
            messageURL: URL(
                string: "https://some-url.fr/\(UUID().uuidString)"
            )!,
            rawMessageObject: [:]
        )
    }

    static func generateMessages(_ count: Int) -> [MessageCenterMessage] {
        // Sets the sent date to make the order predictable
        let date = Date()
        return (0..<count)
            .map { index in
                generateMessage(
                    sentDate: date.advanced(by: Double(-index))
                )
            }
    }

}
