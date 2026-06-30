/* Copyright Airship and Contributors */

import Testing
import Foundation
@_spi(AirshipInternal) import AirshipBasement

@testable import AirshipCore

@Suite(.timeLimit(.minutes(1)))
struct ContactChannelsProviderTest {
    private let audienceOverridesProvider: DefaultAudienceOverridesProvider
    private let provider: ContactChannelsProvider
    private let apiClient: TestContactChannelsAPIClient
    private let privacyManager: TestPrivacyManager
    private let dataStore: PreferenceDataStore
    private let notificationCenter: AirshipNotificationCenter
    private let taskSleeper: TestSleeper
    private let date: UATestDate = UATestDate(dateOverride: Date())

    private let testChannels1: [ContactChannel] = [
        .email(
            .registered(
                ContactChannel.Email.Registered(
                    channelID: UUID().uuidString,
                    maskedAddress: "****@email.com"
                )
            )
        ),
        .sms(
            .registered(
                ContactChannel.Sms.Registered(
                    channelID: UUID().uuidString,
                    maskedAddress: "****@email.com",
                    isOptIn: true,
                    senderID: "123"
                )
            )
        )
    ]


    private let testChannels2: [ContactChannel] = [
        .email(
            .registered(
                ContactChannel.Email.Registered(
                    channelID: UUID().uuidString,
                    maskedAddress: "****@email.com"
                )
            )
        ),
        .email(
            .registered(
                ContactChannel.Email.Registered(
                    channelID: UUID().uuidString,
                    maskedAddress: "****@email.com"
                )
            )
        )
    ]

    private let testChannels3: [ContactChannel] = [
        .sms(
            .registered(
                ContactChannel.Sms.Registered(
                    channelID: UUID().uuidString,
                    maskedAddress: "****@email.com",
                    isOptIn: false,
                    senderID: "123"
                )
            )
        )
    ]

    init() {
        self.audienceOverridesProvider = DefaultAudienceOverridesProvider()
        self.apiClient = TestContactChannelsAPIClient()
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.taskSleeper = TestSleeper()
        self.notificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: .testConfig(),
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

    @Test
    func testPrivacyManagerDisabled() async {
        self.privacyManager.disableFeatures(.contacts)

        let contactIDStream = AsyncStream<String> { continuation in
            continuation.yield("test-contact-id-1")
            continuation.finish()
        }

        self.apiClient.fetchResponse = AirshipHTTPResponse(
            result: self.testChannels2,
            statusCode: 200,
            headers: [:]
        )

        var resultStream = provider.contactChannels(stableContactIDUpdates: contactIDStream).makeAsyncIterator()
        let result = await resultStream.next()
        #expect(result == .error(.contactsDisabled))
    }

    @Test
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
        #expect(result == .success(self.testChannels1))

        self.apiClient.fetchResponse = AirshipHTTPResponse(
            result: self.testChannels2,
            statusCode: 200,
            headers: [:]
        )
        await contactIDChannel.send("test-contact-id-2")
        result = await resultStream.next()
        #expect(result == .success(self.testChannels2))

        self.apiClient.fetchResponse = AirshipHTTPResponse(
            result: self.testChannels3,
            statusCode: 200,
            headers: [:]
        )
        await contactIDChannel.send("test-contact-id-3")
        result = await resultStream.next()
        #expect(result == .success(self.testChannels3))

        #expect(self.apiClient.fetchAssociatedChannelsCallCount == 3)
    }
    
    @Test
    func testContactChannelsRefresh() async {
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
        #expect(result == .success(self.testChannels1))
        #expect(1 == self.apiClient.fetchAssociatedChannelsCallCount)

        //from cache
        await contactIDChannel.send("test-contact-id-1")
        result = await resultStream.next()
        #expect(result == .success(self.testChannels1))
        #expect(1 == self.apiClient.fetchAssociatedChannelsCallCount)
        
        await provider.refresh()
        
        await contactIDChannel.send("test-contact-id-1")
        result = await resultStream.next()
        #expect(result == .success(self.testChannels1))
        #expect(2 == self.apiClient.fetchAssociatedChannelsCallCount)
    }

    @Test
    func testContactChannelsFailure() async {
        let contactIDStream = AsyncStream<String> { continuation in
            continuation.yield("test-contact-id")
            continuation.finish()
        }


        self.apiClient.fetchResponse = AirshipHTTPResponse(result: [], statusCode: 500, headers: [:])

        var resultStream = provider.contactChannels(stableContactIDUpdates: contactIDStream).makeAsyncIterator()
        let result = await resultStream.next()
        #expect(result == .error(.failedToFetchContacts))
    }

    @Test
    func testEmptyContactChannelUpdates() async {
        let contactIDStream = AsyncStream<String> { continuation in
            continuation.yield("test-contact-id-1")
            continuation.finish()
        }

        self.apiClient.fetchResponse = AirshipHTTPResponse(result: [], statusCode: 200, headers: [:])

        var resultStream = provider.contactChannels(stableContactIDUpdates: contactIDStream).makeAsyncIterator()
        let result = await resultStream.next()
        #expect(result == .success([]))
    }

    @Test
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
            #expect(next == backoff)
            await self.taskSleeper.advance()
        }

    }

    @Test
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
        #expect(sleeps == [600])
    }
}


fileprivate final class TestContactChannelsAPIClient: ContactChannelsAPIClientProtocol, @unchecked Sendable {
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
        if let continuation = continuations.first {
            continuations.removeFirst()
            continuation.resume()
        } else {
            // The sleeper sends its update before parking, so a consumer can
            // call advance() before the continuation is registered. Bank the
            // advance so the next sleep doesn't lose the wakeup and hang.
            pendingAdvances += 1
        }
    }


    var sleeps: [TimeInterval] = []
    var continuations: [CheckedContinuation<Void, Never>] = []
    private var pendingAdvances: Int = 0

    func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
        await channel.send(timeInterval)

        if pendingAdvances > 0 {
            pendingAdvances -= 1
            return
        }

        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }
}
