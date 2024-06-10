/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore
class ContactChannelsProviderTest: XCTestCase {
    private var audienceOverridesProvider: DefaultAudienceOverridesProvider!
    private var provider: ContactChannelsProvider!
    var apiClient: TestContactChannelsAPIClient!
    private var privacyManager: AirshipPrivacyManager!
    private var dataStore: PreferenceDataStore!
    private var notificationCenter: AirshipNotificationCenter!
    private var taskSleeper: TestSleeper!
    private var date: UATestDate = UATestDate(dateOverride: Date())

    override func setUp() async throws {
        try await super.setUp()

        self.audienceOverridesProvider = DefaultAudienceOverridesProvider()
        self.apiClient = TestContactChannelsAPIClient()
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.taskSleeper = TestSleeper()
        self.notificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
        self.privacyManager = await AirshipPrivacyManager(
            dataStore: self.dataStore,
            config: RuntimeConfig(config: AirshipConfig(), dataStore: self.dataStore),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.provider = ContactChannelsProvider(
            audienceOverrides: self.audienceOverridesProvider,
            apiClient: self.apiClient,
            date: self.date,
            taskSleeper: self.taskSleeper,
            privacyManager: self.privacyManager
        )
    }

    override func tearDown() async throws {
        try await super.tearDown()

        self.audienceOverridesProvider = nil
        self.apiClient = nil
        self.dataStore = nil
        self.taskSleeper = nil
        self.notificationCenter = nil
        self.privacyManager = nil
        self.provider = nil
    }

    func testPrivacyManagerDisabled() async {
        self.privacyManager.disableFeatures(.contacts)

        let contactIDStream = AsyncStream<String> { continuation in
            continuation.yield("test-contact-id-1")
            continuation.finish()
        }

        var resultStream = provider.contactChannels(stableContactIDUpdates: contactIDStream).makeAsyncIterator()
        let result = await resultStream.next()
        XCTAssertEqual(result, .error(.contactsDisabled))
    }

    func testContactChannelsSuccess() async {
        let contactIDChannel = AirshipAsyncChannel<String>()

        var resultStream = provider.contactChannels(
            stableContactIDUpdates: await contactIDChannel.makeStream()
        ).makeAsyncIterator()


        self.apiClient.fetchResponse = AirshipHTTPResponse(
            result: self.testChannels1,
            statusCode: 200,
            headers: [:]
        )
        await contactIDChannel.send("test-contact-id-1")
        var result = await resultStream.next()
        XCTAssertEqual(result, .success(self.testChannels1))

        self.apiClient.fetchResponse = AirshipHTTPResponse(
            result: self.testChannels2,
            statusCode: 200,
            headers: [:]
        )
        await contactIDChannel.send("test-contact-id-2")
        result = await resultStream.next()
        XCTAssertEqual(result, .success(self.testChannels2))

        self.apiClient.fetchResponse = AirshipHTTPResponse(
            result: self.testChannels3,
            statusCode: 200,
            headers: [:]
        )
        await contactIDChannel.send("test-contact-id-3")
        result = await resultStream.next()
        XCTAssertEqual(result, .success(self.testChannels3))

        XCTAssertEqual(self.apiClient.fetchAssociatedChannelsCallCount, 3)
    }

    func testContactChannelsFailure() async {
        let contactIDStream = AsyncStream<String> { continuation in
            continuation.yield("test-contact-id")
            continuation.finish()
        }


        self.apiClient.fetchResponse = AirshipHTTPResponse(result: [], statusCode: 500, headers: [:])

        var resultStream = provider.contactChannels(stableContactIDUpdates: contactIDStream).makeAsyncIterator()
        let result = await resultStream.next()
        XCTAssertEqual(result, .error(.failedToFetchContacts))
    }

    func testEmptyContactChannelUpdates() async {
        let contactIDStream = AsyncStream<String> { continuation in
            continuation.yield("test-contact-id-1")
            continuation.finish()
        }

        self.apiClient.fetchResponse = AirshipHTTPResponse(result: [], statusCode: 200, headers: [:])

        var resultStream = provider.contactChannels(stableContactIDUpdates: contactIDStream).makeAsyncIterator()
        let result = await resultStream.next()
        XCTAssertEqual(result, .success([]))
    }

    func testBackoffOnFailure() async {
        let contactIDStream = AsyncStream<String> { continuation in
            continuation.yield("test-contact-id-1")
            continuation.finish()
        }

        self.apiClient.fetchResponse = AirshipHTTPResponse(result: [], statusCode: 500, headers: [:])
        var sleepUpdates = await self.taskSleeper.sleepUpdates.makeAsyncIterator()

        var results = provider.contactChannels(stableContactIDUpdates: contactIDStream).makeAsyncIterator()
        _ = await results.next()


        for backoff in [8.0, 16.0, 32.0, 64.0, 64.0] {
            let next = await sleepUpdates.next()
            XCTAssertEqual(next, backoff)
            await self.taskSleeper.advance()
        }

    }

    func testRefreshRateOnSuccess() async {
        let contactIDStream = AsyncStream<String> { continuation in
            continuation.yield("test-contact-id-1")
            continuation.finish()
        }

        var results = provider.contactChannels(stableContactIDUpdates: contactIDStream).makeAsyncIterator()
        self.apiClient.fetchResponse = AirshipHTTPResponse(result: [], statusCode: 200, headers: [:])

        _ = await results.next()
        await self.taskSleeper.advance()

        let sleeps = await self.taskSleeper.sleeps
        XCTAssertEqual(sleeps, [600])
    }
}

// MARK: Utilities

extension ContactChannelsProviderTest {


    static let registeredJSON = [
    """
    {
        "registered": {
            "_0": {
                "channelID": "01234",
                "deIdentifiedAddress": "u*****r@example.com",
                "registrationInfo": {
                    "email": {
                        "_0": {
                            "transactionalOptedIn": "2024-04-30T12:00:00Z",
                            "transactionalOptedOut": "2024-04-30T12:00:00Z",
                            "commercialOptedIn": "2024-04-30T12:00:00Z",
                            "commercialOptedOut": "2024-04-30T12:00:00Z"
                        }
                    }
                }
            }
        }
    }
    """.data(using: .utf8)!,
    """
    {
        "registered": {
            "_0": {
                "channelID": "56789",
                "deIdentifiedAddress": "u*****r@example.com",
                "registrationInfo": {
                    "email": {
                        "_0": {
                            "transactionalOptedIn": "2024-04-30T12:00:00Z",
                            "transactionalOptedOut": "2024-04-30T12:00:00Z",
                            "commercialOptedIn": "2024-04-30T12:00:00Z",
                            "commercialOptedOut": "2024-04-30T12:00:00Z"
                        }
                    }
                }
            }
        }
    }
    """.data(using: .utf8)!
    ]

    static let pendingJSON = [
    """
    {
        "pending": {
            "_0": {
                "address": "5038675309",
                "pendingRegistrationInfo": {
                    "sms": {
                        "_0": {
                            "senderID": "12345"
                        }
                    }
                },
                "deIdentifiedAddress": "XXX-XXX-7890"
            }
        }
    }
    """.data(using: .utf8)!,
    """
    {
        "pending": {
            "_0": {
                "address": "coolbeats@music.net",
                "pendingRegistrationInfo": {
                    "email": {
                        "_0": {}
                    }
                },
                "deIdentifiedAddress": "u*****r@example.com"
            }
        }
    }
    """.data(using: .utf8)!
    ]

    private var decodedRegistered: [ContactChannel] {
        (try? decodeContactChannels(from: Self.registeredJSON)) ?? []
    }

    private var decodedPending: [ContactChannel] {
        (try? decodeContactChannels(from: Self.pendingJSON)) ?? []
    }

    var testChannels1: [ContactChannel] {
        [decodedPending[0], decodedPending[1], decodedRegistered[0]]
    }

    var testChannels2: [ContactChannel] {
        [decodedRegistered[0], decodedRegistered[1]]
    }

    var testChannels3: [ContactChannel] {
        [decodedRegistered[0], decodedRegistered[1]]
    }


    private func decodeContactChannels(from data: [Data]) throws -> [ContactChannel] {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601


        return data.compactMap { datum in
            return try! jsonDecoder.decode(ContactChannel.self, from: datum)
        }
    }
}

class TestContactChannelsAPIClient: ContactChannelsAPIClientProtocol, @unchecked Sendable {
    internal init(
        fetchAssociatedChannelsCallCount: Int = 0,
        fetchedContactIDs: [String] = [],
        fetchResponse: AirshipHTTPResponse<[ContactChannel]>? = nil
    ) {
        self.fetchAssociatedChannelsCallCount = fetchAssociatedChannelsCallCount
        self.fetchedContactIDs = fetchedContactIDs
        self.fetchResponse = fetchResponse
    }

    var fetchAssociatedChannelsCallCount = 0
    var fetchedContactIDs: [String] = []
    var fetchResponse: AirshipHTTPResponse<[ContactChannel]>?

    func fetchAssociatedChannelsList(contactID: String) async throws -> AirshipHTTPResponse<[ContactChannel]> {
        fetchAssociatedChannelsCallCount += 1
        fetchedContactIDs.append(contactID)

        return fetchResponse!
    }
}

private actor TestSleeper: AirshipTaskSleeper, @unchecked Sendable {

    private let channel = AirshipAsyncChannel<TimeInterval>()
    var sleepUpdates: AsyncStream<TimeInterval> {
        get async {
            await channel.makeStream()
        }
    }


    func advance() {
        continuations.forEach {
            $0.resume()
        }
        continuations.removeAll()
    }


    var sleeps: [TimeInterval] = []
    var continuations: [CheckedContinuation<Void, Never>] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
        await channel.send(timeInterval)
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }
}
