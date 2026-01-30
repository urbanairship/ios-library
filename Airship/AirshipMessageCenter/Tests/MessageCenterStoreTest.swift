/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore
@testable import AirshipMessageCenter

final class MessageCenterStoreTest: XCTestCase {
    private var dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let config: RuntimeConfig = .testConfig()
        
    private lazy var store: MessageCenterStore = {
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

    func testMessageCenterStoreSaveAndResetUser() async throws {

        let expectedUser = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(expectedUser, channelID: "987654433")

        let user = await store.user
        XCTAssertNotNil(user)
        XCTAssertEqual(user!.username, expectedUser.username)
        XCTAssertEqual(user!.password, expectedUser.password)

        // Reset User
        await store.resetUser()

        let resetedUser = await store.user
        XCTAssertNil(resetedUser)
    }

    func testUserRequiredUpdate() async throws {
        // Set setUserRequireUpdate true
        await store.setUserRequireUpdate(true)
        var requiredUpdate = await store.userRequiredUpdate
        XCTAssertTrue(requiredUpdate)

        // Set Required update false
        await store.setUserRequireUpdate(false)
        requiredUpdate = await store.userRequiredUpdate
        XCTAssertFalse(requiredUpdate)
    }

    func testFetchMessages() async throws {
        let messages = MessageCenterMessage.generateMessages(3)

        try await store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )
    }

    func testSyncMessages() async throws {
        let generated = MessageCenterMessage.generateMessages(5)
        var messages = Array(generated[0...2])

        try await store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )

        var fetchedMessage = await store.messages
        XCTAssertEqual(messages, fetchedMessage)

        messages.remove(at: 0)
        messages.append(contentsOf: generated[3...4])

        try await store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )

        fetchedMessage = await store.messages
        XCTAssertEqual(messages, fetchedMessage)
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
            messageReporting: [UUID().uuidString: UUID().uuidString],
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
