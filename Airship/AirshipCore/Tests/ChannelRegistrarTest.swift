/* Copyright Airship and Contributors */

import Testing
import Combine

@testable import AirshipCore

@Suite(.timeLimit(.minutes(1)))
struct ChannelRegistrarTest {

    let dataStore: PreferenceDataStore
    let client: TestChannelRegistrationClient
    let date: UATestDate
    let workManager: TestWorkManager
    let appStateTracker: TestAppStateTracker
    let payloadProvider: ChannelRegistrationPayloadProvider
    let workID: String
    let channelRegistrar: ChannelRegistrar

    init() async throws {
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.client = TestChannelRegistrationClient()
        self.date = UATestDate()
        self.workManager = TestWorkManager()
        self.appStateTracker = TestAppStateTracker()
        self.payloadProvider = ChannelRegistrationPayloadProvider()
        self.workID = "UAChannelRegistrar.registration"

        let dataStore = self.dataStore
        let client = self.client
        let date = self.date
        let workManager = self.workManager
        let appStateTracker = self.appStateTracker
        let payloadProvider = self.payloadProvider

        self.channelRegistrar = await MainActor.run {
            let registrar = ChannelRegistrar(
                dataStore: dataStore,
                channelAPIClient: client,
                date: date,
                workManager: workManager,
                appStateTracker: appStateTracker,
                channelCreateMethod: { return .automatic },
                privacyManager: TestPrivacyManager(
                    dataStore: dataStore,
                    config: RuntimeConfig.testConfig(),
                    defaultEnabledFeatures: AirshipFeature.all
                )
            )
            registrar.payloadCreateBlock = { await payloadProvider.getPayload() }
            return registrar
        }
    }

    actor ChannelRegistrationPayloadProvider {
        private var payload: ChannelRegistrationPayload

        init(deviceModel: String? = nil, appVersion: String? = nil) {
            var payload = ChannelRegistrationPayload()
            payload.channel.deviceModel = deviceModel ?? UUID().uuidString
            payload.channel.appVersion = appVersion ?? "test"

            self.payload = payload
        }

        func updatePayload(update: @Sendable @escaping(inout ChannelRegistrationPayload) -> Void ) {
            update(&payload)
        }

        func getPayload() -> ChannelRegistrationPayload {
            payload
        }
    }

    @Test("Register")
    func register() async throws {
        #expect(self.workManager.workRequests.count == 0)

        self.channelRegistrar.register(forcefully: false)

        #expect(self.workManager.workRequests.count == 1)

        let extras = ["forcefully": "false"]

        let request = self.workManager.workRequests[0]
        #expect(request.workID == workID)
        #expect(request.conflictPolicy == .keepIfNotStarted)
        #expect(request.extras == extras)
        #expect(request.initialDelay == 0)
    }

    @Test("Register forcefully")
    func registerForcefully() async throws {
        #expect(self.workManager.workRequests.count == 0)

        self.channelRegistrar.register(forcefully: true)

        #expect(self.workManager.workRequests.count == 1)

        let extras = ["forcefully": "true"]

        let request = self.workManager.workRequests[0]
        #expect(request.workID == workID)
        #expect(request.conflictPolicy == .replace)
        #expect(request.extras == extras)
        #expect(request.initialDelay == 0)
    }

    @Test("Create channel")
    func createChannel() async throws {
        var stream = await self.channelRegistrar.registrationUpdates.makeStream().makeAsyncIterator()

        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        self.client.createCallback =  { channelPayload in
            #expect(channelPayload == payload)
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: "some-channel-id",
                    location: try self.client.makeChannelLocation(
                        channelID: "some-channel-id"
                    )
                ),
                statusCode: 201,
                headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        #expect(result == .success)

        let update = await stream.next()
        #expect(update == .created(channelID: "some-channel-id", isExisting: false))
    }

    @Test("Create channel restores")
    func createChannelRestores() async throws {
        let restoredUUID = UUID().uuidString

        let channelRegistrar = await MainActor.run {
            ChannelRegistrar(
                dataStore: self.dataStore,
                channelAPIClient: self.client,
                date: self.date,
                workManager: self.workManager,
                appStateTracker: self.appStateTracker,
                channelCreateMethod: { return .restore(channelID: restoredUUID) },
                privacyManager: TestPrivacyManager(
                    dataStore: self.dataStore,
                    config: RuntimeConfig.testConfig(),
                    defaultEnabledFeatures: AirshipFeature.all
                )
            )
        }

        var stream = await channelRegistrar.registrationUpdates.makeStream().makeAsyncIterator()

        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        self.client.createCallback =  { channelPayload in
            Issue.record("Should not create")
            throw AirshipErrors.error("")
        }

        self.client.updateCallback = { channelID, channelPayload in
            #expect(restoredUUID == channelID)
            #expect(channelPayload.channel.deviceModel == nil) // minimized

            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: restoredUUID,
                    location: try self.client.makeChannelLocation(
                        channelID: restoredUUID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        var update = await stream.next()
        #expect(update == .created(channelID: restoredUUID, isExisting: true))

        update = await stream.next()
        #expect(update == .updated(channelID: restoredUUID))

        #expect(result == .success)
    }

    @Test("Restore fall back to create on invalid ID")
    func restoreFallBackToCreateOnInvalidID() async throws {
        let channelRegistrar = await MainActor.run {
            ChannelRegistrar(
                dataStore: self.dataStore,
                channelAPIClient: self.client,
                date: self.date,
                workManager: self.workManager,
                appStateTracker: self.appStateTracker,
                channelCreateMethod: { return .restore(channelID: "invalid-uuid") },
                privacyManager: TestPrivacyManager(
                    dataStore: self.dataStore,
                    config: RuntimeConfig.testConfig(),
                    defaultEnabledFeatures: AirshipFeature.all
                )
            )
        }

        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        try await confirmation { confirm in
            self.client.createCallback =  { channelPayload in
                #expect(channelPayload == payload)
                confirm()
                return AirshipHTTPResponse(
                    result: ChannelAPIResponse(
                        channelID: "some-channel-id",
                        location: try self.client.makeChannelLocation(
                            channelID: "some-channel-id"
                        )
                    ),
                    statusCode: 201,
                    headers: [:])
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(workID: workID)
            )

            #expect(result == .success)
        }
    }

    @Test("Create channel existing")
    func createChannelExisting() async throws {
        var stream = await self.channelRegistrar.registrationUpdates.makeStream().makeAsyncIterator()

        let payload = await payloadProvider.getPayload()

        self.client.createCallback =  { channelPayload in
            #expect(channelPayload == payload)
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: "some-channel-id",
                    location: try self.client.makeChannelLocation(
                        channelID: "some-channel-id"
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )
        #expect(result == .success)

        let update = await stream.next()
        #expect(update == .created(channelID: "some-channel-id", isExisting: true))
    }

    @Test("Create channel error")
    func createChannelError() async throws {
        self.client.createCallback =  { channelPayload in
            throw AirshipErrors.error("Some error")
        }

        do {
            _ = try await self.workManager.launchTask(
                request: AirshipWorkRequest(workID: workID)
            )
            Issue.record("Should throw")
        } catch {

        }
    }

    @Test("Create channel server error")
    func createChannelServerError() async throws {
        self.client.createCallback =  { channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 500,
                headers: [:])
        }


        let payload = await payloadProvider.getPayload()
        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        #expect(result == .failure)
    }

    @Test("Create channel client error")
    func createChannelClientError() async throws {
        self.client.createCallback =  { channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        let _ = await payloadProvider.getPayload()

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        #expect(result == .success)
    }

    @Test("Update not configured")
    func updateNotConfigured() async {
        self.client.isURLConfigured = false
        self.channelRegistrar.register(forcefully: true)
        self.channelRegistrar.register(forcefully: false)
        #expect(self.workManager.workRequests.count == 0)

        self.client.isURLConfigured = true

        self.channelRegistrar.register(forcefully: true)
        self.channelRegistrar.register(forcefully: false)
        #expect(self.workManager.workRequests.count == 2)
    }

    @Test("Create channel 429 error")
    func createChannel429Error() async throws {
        self.client.createCallback =  { channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 429,
                headers: [:])
        }

        let payload = await payloadProvider.getPayload()
        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        #expect(result == .failure)
    }

    @Test("Update channel")
    func updateChannel() async throws {
        var stream = await self.channelRegistrar.registrationUpdates.makeStream().makeAsyncIterator()

        let someChannelID = UUID().uuidString

        try await createChannel(channelID: someChannelID)

        await payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
        }

        let payload = await payloadProvider.getPayload()

        self.client.updateCallback = { channelID, channelPayload in
            #expect(someChannelID == channelID)
            #expect(
                channelPayload.channel.deviceModel ==
                payload.channel.deviceModel
            )
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )
        #expect(result == .success)

        var update = await stream.next()
        #expect(update == .created(channelID: someChannelID, isExisting: true))
        update = await stream.next()
        #expect(update == .updated(channelID: someChannelID))
    }

    @Test("Update channel error")
    func updateChannelError() async throws {
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        await payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
        }

        self.client.updateCallback = { channelID, channelPayload in
            throw AirshipErrors.error("Error!")
        }

        do {
            _ = try await self.workManager.launchTask(
                request: AirshipWorkRequest(workID: workID)
            )
            Issue.record("Should throw")
        } catch {}
    }

    @Test("Update channel server error")
    func updateChannelServerError() async throws {
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        await payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
        }

        self.client.updateCallback = { channelID, channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 500,
                headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        #expect(result == .failure)
    }

    @Test("Update channel client error")
    func updateChannelClientError() async throws {
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        self.client.updateCallback = { channelID, channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        #expect(result == .success)
    }


    @Test("Update channel 429 error")
    @MainActor
    func updateChannel429Error() async throws {
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        await payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
        }

        self.client.updateCallback = { channelID, channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 429,
                headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        #expect(result == .failure)
    }

    @Test("Skip update channel up to date")
    func skipUpdateChannelUpToDate() async throws {
        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        let someChannelID = UUID().uuidString

        // Create the channel
        try await createChannel(channelID: someChannelID)

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        #expect(result == .success)
    }

    @Test("Update forcefully")
    func updateForcefully() async throws {
        var stream = await self.channelRegistrar.registrationUpdates.makeStream().makeAsyncIterator()

        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        self.client.updateCallback = { channelID, channelPayload in
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID,
                extras: ["forcefully": "true"]
            )
        )

        #expect(result == .success)

        var update = await stream.next()
        #expect(update == .created(channelID: someChannelID, isExisting: true))
        update = await stream.next()
        #expect(update == .updated(channelID: someChannelID))
    }

    @Test("Update location changed")
    func updateLocationChanged() async throws {
        var stream = await self.channelRegistrar.registrationUpdates.makeStream().makeAsyncIterator()

        let someChannelID = UUID().uuidString

        let payload = await payloadProvider.getPayload()

        try await createChannel(channelID: someChannelID)

        self.client.channelLocation = { _ in
            return URL(string: "some:otherlocation")!
        }

        self.client.updateCallback = { channelID, channelPayload in
            #expect(payload == channelPayload)
            #expect(payload.minimizePayload(previous: payload) != channelPayload)
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )
        #expect(result == .success)

        var update = await stream.next()
        #expect(update == .created(channelID: someChannelID, isExisting: true))
        update = await stream.next()
        #expect(update == .updated(channelID: someChannelID))
    }

    @Test("Update min payload")
    func updateMinPayload() async throws {
        var stream = await self.channelRegistrar.registrationUpdates.makeStream().makeAsyncIterator()

        let someChannelID = UUID().uuidString

        let firstPayload = await self.payloadProvider.getPayload()

        try await createChannel(channelID: someChannelID)

        await self.payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
        }

        let secondPayload = await payloadProvider.getPayload()

        self.client.updateCallback = { channelID, channelPayload in
            #expect(
                secondPayload.minimizePayload(
                    previous: firstPayload
                ) ==
                channelPayload
            )
            #expect(secondPayload != channelPayload)
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        #expect(result == .success)

        var update = await stream.next()
        #expect(update == .created(channelID: someChannelID, isExisting: true))
        update = await stream.next()
        #expect(update == .updated(channelID: someChannelID))
    }

    @Test("Update after 24 hours")
    @MainActor
    func updateAfter24Hours() async throws {
        self.appStateTracker.currentState = .active
        self.date.dateOverride = Date()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        var updateCount = 0
        self.client.updateCallback = { channelID, channelPayload in
            updateCount += 1
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )
        #expect(updateCount == 0)

        // Forward to almost 1 second before 24 hours
        self.date.offset = 24 * 60 * 60 - 1

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )
        #expect(updateCount == 0)


        // 24 hours
        self.date.offset += 1

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        #expect(updateCount == 1)
    }

    @Test("Full payload upload after 24 hours")
    @MainActor
    func fullPayloadUploadAfter24Hours() async throws {
        self.appStateTracker.currentState = .active
        self.date.dateOverride = Date()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        let payload = await payloadProvider.getPayload()

        var updatePayload: ChannelRegistrationPayload? = nil
        self.client.updateCallback = { channelID, channelPayload in
            updatePayload = channelPayload
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        #expect(updatePayload == nil)

        self.date.offset = 24 * 60 * 60 - 1

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        #expect(updatePayload == nil)

        // 24 hours
        self.date.offset += 2

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        #expect(payload == updatePayload)
    }

    @Test("Empty last full registration")
    @MainActor
    func emptyLastFullRegistration() async throws {
        self.appStateTracker.currentState = .active
        self.date.dateOverride = Date()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        var registrationInfo: LastRegistrationInfo = self.dataStore.safeCodable(forKey: "ChannelRegistrar.lastRegistrationInfo")!
        registrationInfo.lastFullPayloadSent = nil
        self.dataStore.setSafeCodable(registrationInfo, forKey: "ChannelRegistrar.lastRegistrationInfo")

        let payload = await payloadProvider.getPayload()

        var updatePayload: ChannelRegistrationPayload? = nil
        self.client.updateCallback = { channelID, channelPayload in
            updatePayload = channelPayload
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        #expect(payload == updatePayload)

       updatePayload = nil
        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        // No update
        #expect(updatePayload == nil)
    }

    private func createChannel(channelID: String) async throws {
        // Set a payload since the create flow now requires one
        let _ = await payloadProvider.getPayload()

        self.client.createCallback = { _ in
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: channelID,
                    location: try self.client.makeChannelLocation(
                        channelID: channelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        #expect(result == .success)
    }
}

fileprivate struct LastRegistrationInfo: Codable {
    var date: Date
    var payload: ChannelRegistrationPayload
    var lastFullPayloadSent: Date?
    var location: URL
}

internal class TestChannelRegistrationClient: ChannelAPIClientProtocol, @unchecked Sendable {
    var isURLConfigured: Bool = true

    var createCallback:((ChannelRegistrationPayload) async throws -> AirshipHTTPResponse<ChannelAPIResponse>)?
    var updateCallback:
    ((String, ChannelRegistrationPayload) async throws -> AirshipHTTPResponse<ChannelAPIResponse>)?

    var channelLocation: ((String) throws -> URL)?

    func makeChannelLocation(channelID: String) throws -> URL {
        guard let channelLocation = channelLocation else {
            return URL(string: "channel:\(channelID)")!
        }

        return try channelLocation(channelID)
    }

    func createChannel(
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse> {
        return try await createCallback!(payload)
    }

    func updateChannel(
        _ channelID: String,
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse> {
        return try await updateCallback!(channelID, payload)
    }
}
