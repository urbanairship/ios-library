/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
protocol ChannelRegistrarProtocol: AnyObject, Sendable {
    var channelID: String? { get }
    var registrationUpdates: AirshipAsyncChannel<ChannelRegistrationUpdate> { get }

    @MainActor
    var payloadCreateBlock: (@Sendable () async -> ChannelRegistrationPayload?)? { get set }

    func register(forcefully: Bool)
}

enum ChannelRegistrationUpdate: Equatable, Sendable {
    case created(channelID: String, isExisting: Bool)
    case updated(channelID: String)
}

/// The ChannelRegistrar class is responsible for device registrations.
/// - Note: For internal use only. :nodoc:
final class ChannelRegistrar: ChannelRegistrarProtocol, Sendable {
    static let workID: String = "UAChannelRegistrar.registration"
    private static let payloadCadence: TimeInterval = 24 * 60 * 60

    fileprivate static let forcefullyKey: String = "forcefully"
    private static let channelIDKey: String = "UAChannelID"
    private static let lastRegistrationInfo: String = "ChannelRegistrar.lastRegistrationInfo"


    private let dataStore: PreferenceDataStore
    private let channelAPIClient: any ChannelAPIClientProtocol
    private let date: any AirshipDateProtocol
    private let workManager: any AirshipWorkManagerProtocol
    private let appStateTracker: any AppStateTrackerProtocol

    @MainActor
    private var checkAppRestoreTask: Task<Void, Never>?
    
    private let channelCreateMethod: (@Sendable () async throws -> ChannelGenerationMethod)?

    @MainActor
    var payloadCreateBlock: (@Sendable () async -> ChannelRegistrationPayload?)?

    private var lastRegistrationInfo: LastRegistrationInfo? {
        get {
            do {
                return try self.dataStore.codable(
                    forKey: ChannelRegistrar.lastRegistrationInfo
                )
            } catch {
                AirshipLogger.error("Unable to load last registration info \(error)")
                return nil
            }
        }
        set {
            do {
                try self.dataStore.setCodable(
                    newValue,
                    forKey: ChannelRegistrar.lastRegistrationInfo
                )
            } catch {
                AirshipLogger.error("Unable to store last registration info \(error)")
            }
        }
    }
    /**
     * The channel ID for this device.
     */
    var channelID: String? {
        get {
            self.dataStore.string(forKey: ChannelRegistrar.channelIDKey)
        }
        set {
            self.dataStore.setObject(
                newValue,
                forKey: ChannelRegistrar.channelIDKey
            )
        }
    }

    let registrationUpdates: AirshipAsyncChannel<ChannelRegistrationUpdate> = .init()

    private let privacyManager: any AirshipPrivacyManager

    @MainActor
    init(
        dataStore: PreferenceDataStore,
        channelAPIClient: any ChannelAPIClientProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared,
        workManager: any AirshipWorkManagerProtocol = AirshipWorkManager.shared,
        appStateTracker: (any AppStateTrackerProtocol)? = nil,
        channelCreateMethod: AirshipChannelCreateOptionClosure? = nil,
        privacyManager: any AirshipPrivacyManager
    ) {
        self.dataStore = dataStore
        self.channelAPIClient = channelAPIClient
        self.date = date
        self.workManager = workManager
        self.appStateTracker = appStateTracker ?? AppStateTracker.shared
        self.channelCreateMethod = channelCreateMethod

        self.privacyManager = privacyManager

        if self.channelID != nil {
            checkAppRestoreTask = Task { [weak self] in
                if await self?.dataStore.isAppRestore == true {
                    self?.clearChannelData()
                }
            }
        }

        self.workManager.registerWorker(
            ChannelRegistrar.workID
        ) { [weak self] request in
           return try await self?.handleRegistrationWorkRequest(request) ?? .success
        }
    }

    @MainActor
    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        privacyManager: any AirshipPrivacyManager
    ) {
        self.init(
            dataStore: dataStore,
            channelAPIClient: ChannelAPIClient(config: config),
            channelCreateMethod: config.airshipConfig.restoreChannelID,
            privacyManager: privacyManager
        )
    }

    /**
     * Register the device with Airship.
     *
     * - Note: This method will execute asynchronously on the main thread.
     *
     * - Parameter forcefully: YES to force the registration.
     */
    func register(forcefully: Bool) {
        guard self.channelAPIClient.isURLConfigured else {
            return
        }
                
        self.workManager.dispatchWorkRequest(
            AirshipWorkRequest(
                workID: ChannelRegistrar.workID,
                extras: [
                    ChannelRegistrar.forcefullyKey: String(forcefully)
                ],
                requiresNetwork: true,
                conflictPolicy: forcefully ? .replace : .keepIfNotStarted
            )
        )
    }

    private func handleRegistrationWorkRequest(
        _ workRequest: AirshipWorkRequest
    ) async throws -> AirshipWorkResult {

        _ = await self.checkAppRestoreTask?.value

        let payload = try await self.makePayload()

        guard let channelID = self.channelID else {
            return try await self.createChannel(
                payload: payload
            )
        }

        let forcefully = workRequest.extras?[
            ChannelRegistrar.forcefullyKey
        ]?.lowercased() == "true"

        let updatePayload = try await makeNextUpdatePayload(
            channelID: channelID,
            forcefully: forcefully,
            payload: payload,
            lastRegistrationInfo: self.lastRegistrationInfo
        )

        guard let updatePayload = updatePayload else {
            AirshipLogger.debug(
                "Ignoring registration request, registration is up to date."
            )
            return .success
        }

        return try await self.updateChannel(
            channelID,
            payload: payload,
            minimizedPayload: updatePayload
        )
    }

    private func updateChannel(
        _ channelID: String,
        payload: ChannelRegistrationPayload,
        minimizedPayload: ChannelRegistrationPayload
    ) async throws -> AirshipWorkResult {
        let response = try await self.channelAPIClient.updateChannel(
            channelID,
            payload: minimizedPayload
        )

        AirshipLogger.debug("Channel update request finished with response: \(response)")
        let fullPayloadUploadDate = payload == minimizedPayload ? self.date.now : self.lastRegistrationInfo?.lastFullPayloadSent 

        if response.isSuccess, let result = response.result {
            await self.registrationSuccess(
                channelID: channelID,
                registrationInfo: LastRegistrationInfo(
                    date: self.date.now,
                    lastFullPayloadSent: fullPayloadUploadDate,
                    payload: payload,
                    location: result.location
                )
            )

            await registrationUpdates.send(.updated(channelID: channelID))

            return .success
        } else if response.statusCode == 409 {
            AirshipLogger.trace("Channel conflict, recreating")
            self.clearChannelData()
            self.register(forcefully: true)
            return .success
        } else {
            if response.isServerError || response.statusCode == 429 {
                return .failure
            } else {
                return .success
            }
        }
    }

    private func createChannel(
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipWorkResult {
        
        let method = try await channelCreateMethod?() ?? .automatic
        
        guard 
            case .restore(let channelID) = method,
            method.isValid,
            let result = try await tryRestoreChannel(channelID, payload: payload)
        else {
            return try await regularCreateChannel(payload: payload)
        }
        
        return result
    }
    
    private func tryRestoreChannel(
        _ channelId: String,
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipWorkResult? {
        
        let response: AirshipHTTPResponse<ChannelAPIResponse> = .init(
            result: .init(
                channelID: channelId,
                location: try channelAPIClient.makeChannelLocation(channelID: channelId)),
            statusCode: 200,
            headers: [:]
        )
        
        guard 
            await onNewChannelID(payload: payload, response: response) == .success,
            let nextPayload = try await self.makeNextUpdatePayload(
                channelID: channelId,
                forcefully: true,
                payload: payload,
                lastRegistrationInfo: lastRegistrationInfo)
        else {
            return nil
        }
        
        return try await updateChannel(channelId, payload: payload, minimizedPayload: nextPayload)
    }
    
    private func regularCreateChannel(
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipWorkResult {
        
        let response = try await self.channelAPIClient.createChannel(
            payload: payload
        )

        AirshipLogger.debug("Channel create request finished with response: \(response)")

        return await onNewChannelID(payload: payload, response: response)
    }
    
    private func onNewChannelID(
        payload: ChannelRegistrationPayload,
        response: AirshipHTTPResponse<ChannelAPIResponse>
    ) async -> AirshipWorkResult {
        
        guard response.isSuccess, let result = response.result else {
            if response.isServerError || response.statusCode == 429 {
                return .failure
            } else {
                return .success
            }
        }
        
        self.channelID = result.channelID

        await registrationUpdates.send(
            .created(
                channelID: result.channelID,
                isExisting: response.statusCode == 200
            )
        )

        await self.registrationSuccess(
            channelID: result.channelID,
            registrationInfo: LastRegistrationInfo(
                date: self.date.now,
                lastFullPayloadSent: self.date.now,
                payload: payload,
                location: result.location
            )
        )
        
        return .success
    }

    private func clearChannelData() {
        self.channelID = nil
        self.lastRegistrationInfo = nil
    }

    private func registrationSuccess(
        channelID: String,
        registrationInfo: LastRegistrationInfo
    ) async {
        self.lastRegistrationInfo = registrationInfo
        let nextUploadPayload = try? await self.makeNextUpdatePayload(
            channelID: channelID,
            forcefully: false,
            payload: await makePayload(),
            lastRegistrationInfo: registrationInfo
        )

        if (nextUploadPayload != nil) {
            self.register(forcefully: false)
        }
    }

    @MainActor
    private func makePayload() async throws -> ChannelRegistrationPayload {
        guard let payloadCreateBlock, let payload = await payloadCreateBlock() else {
            throw AirshipErrors.error("Failed to make a payload")
        }
        return payload
    }

    private func makeNextUpdatePayload(
        channelID: String,
        forcefully: Bool,
        payload: ChannelRegistrationPayload,
        lastRegistrationInfo: LastRegistrationInfo?
    ) async throws -> ChannelRegistrationPayload? {
        let currentLocation = try self.channelAPIClient.makeChannelLocation(
            channelID: channelID
        )

        // If no channel registrations are enabled - skip the cadence check
        guard privacyManager.isAnyFeatureEnabled() else {
            return if lastRegistrationInfo?.location != currentLocation || lastRegistrationInfo?.payload != payload {
                payload.minimizePayload(previous: lastRegistrationInfo?.payload)
            } else {
                nil
            }
        }

        guard let lastRegistrationInfo = lastRegistrationInfo,
              currentLocation == lastRegistrationInfo.location,
              let lastFullPayloadSent = lastRegistrationInfo.lastFullPayloadSent,
              self.date.now.timeIntervalSince(lastFullPayloadSent) <= Self.payloadCadence
        else {
            return payload
        }

        let timeSinceLastUpdate = self.date.now.timeIntervalSince(
            lastRegistrationInfo.date
        )

        let isActive = await self.appStateTracker.state == .active
        let shouldUpdateForActive = isActive && timeSinceLastUpdate >= Self.payloadCadence

        guard forcefully || shouldUpdateForActive || payload != lastRegistrationInfo.payload else {
            return nil
        }

        return payload.minimizePayload(previous: lastRegistrationInfo.payload)
    }

    fileprivate struct LastRegistrationInfo: Codable {
        let date: Date
        let lastFullPayloadSent: Date?
        let payload: ChannelRegistrationPayload
        let location: URL
    }
}

fileprivate extension ChannelGenerationMethod {
    var isValid: Bool {
        switch self {
        case .automatic: return true
        case .restore(let id): return UUID(uuidString: id) != nil
        }
    }
}
