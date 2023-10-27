/* Copyright Airship and Contributors */

import Foundation


@objc(UAInAppDeferredResult)
public final class _InAppDeferredResult: NSObject, Sendable {
    private let result: AirshipDeferredResult<AirshipJSON>

    init(result: AirshipDeferredResult<AirshipJSON>) {
        self.result = result
    }

    @objc
    public var isSuccess: Bool {
        if case .success(_) = result {
            return true
        }

        return false
    }


    @objc
    public var responseBody: Any? {
        if case let .success(data) = result {
            return data.unWrap()
        }

        return nil
    }

    @objc
    public var timedOut: Bool {
        if case .timedOut = result {
            return true
        }

        return false
    }

    @objc
    public var isOutOfDate: Bool {
        switch(result) {
        case .outOfDate: return true
        case .notFound: return true
        default: return false
        }
    }


    @objc
    public var backOff: TimeInterval {
        if case let .retriableError(retryAfter: backOff) = result {
            return backOff ?? -1
        }

        return -1
    }
}

@objc(UAInAppAudience)
public final class _InAppAudience: NSObject, Sendable {
    let audienceSelector: DeviceAudienceSelector?
    let newUserEvaluationDate: Date
    let deviceInfo: AudienceDeviceInfoProvider
    let experimentProvider: ExperimentDataProvider

    init(
        audienceSelector: DeviceAudienceSelector?,
        newUserEvaluationDate: Date,
        deviceInfo: AudienceDeviceInfoProvider,
        experimentProvider: ExperimentDataProvider
    ) {
        self.audienceSelector = audienceSelector
        self.newUserEvaluationDate = newUserEvaluationDate
        self.deviceInfo = deviceInfo
        self.experimentProvider = experimentProvider
    }

    @objc
    public func evaluateAudience(completionHandler: @escaping @Sendable (Bool, Error?) -> Void) {

        Task {
            guard let audienceSelector = audienceSelector else {
                completionHandler(true, nil)
                return
            }

            do {
                let result = try await audienceSelector.evaluate(
                    newUserEvaluationDate: newUserEvaluationDate,
                    deviceInfoProvider: deviceInfo
                )
                completionHandler(result, nil)
            } catch {
                completionHandler(false, error)
            }
        }

    }

    @objc
    public func evaluateExperiments(
        info: MessageInfo,
        completionHandler: @escaping @Sendable (ExperimentResult?, Error?) -> Void
    ) {
        Task {
            do {
                let result = try await self.experimentProvider.evaluateExperiments(
                    info: info,
                    deviceInfoProvider: self.deviceInfo
                )
                completionHandler(result, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
}

/// NOTE: For internal use only. :nodoc:
@objc(UAInAppCoreSwiftBridge)
public class _InAppCoreSwiftBridge: NSObject {
    private let remoteData: RemoteDataProtocol
    private let meteredUsage: AirshipMeteredUsageProtocol
    private let contact: InternalAirshipContactProtocol
    private let network: NetworkCheckerProtocol
    private let deferredResolver: AirshipDeferredResolverProtocol
    private let deviceInfoProviderFactory: @Sendable (String?) -> AudienceDeviceInfoProvider
    private let experimentProvider: ExperimentDataProvider

    init(
        remoteData: RemoteDataProtocol,
        meteredUsage: AirshipMeteredUsageProtocol,
        contact: InternalAirshipContactProtocol,
        deferredResolver: AirshipDeferredResolverProtocol,
        network: NetworkCheckerProtocol = NetworkChecker(),
        experimentProvider: ExperimentDataProvider,
        deviceInfoProviderFactory: @escaping @Sendable (String?) -> AudienceDeviceInfoProvider = { contactID in
            CachingAudienceDeviceInfoProvider(contactID: contactID)
        }
    ) {
        self.remoteData = remoteData
        self.meteredUsage = meteredUsage
        self.contact = contact
        self.deferredResolver = deferredResolver
        self.network = network
        self.deviceInfoProviderFactory = deviceInfoProviderFactory
        self.experimentProvider = experimentProvider
    }

    @objc
    public func audience(selectorJSON: Any?, isNewUserEvaluationDate: Date?, contactID: String?) throws -> _InAppAudience {
        var audienceSelector: DeviceAudienceSelector? = nil
        if let selectorJSON = selectorJSON {
            let audienceData = try JSONSerialization.data(withJSONObject: selectorJSON)
            audienceSelector = try JSONDecoder().decode(DeviceAudienceSelector.self, from: audienceData)
        }

        
        return _InAppAudience(
            audienceSelector: audienceSelector,
            newUserEvaluationDate: isNewUserEvaluationDate ?? Date.distantPast,
            deviceInfo: deviceInfoProviderFactory(contactID),
            experimentProvider: self.experimentProvider
        )
    }

    @objc
    public func resolveDeferred(
        url: URL,
        channelID: String,
        audience: _InAppAudience,
        triggerType: String?,
        triggerEvent: Any?,
        triggerGoal: Double,
        completionHandler: @escaping @Sendable (_InAppDeferredResult) -> Void
    ) {
        Task {
            var triggerContext: AirshipTriggerContext?
            if let triggerType = triggerType, let triggerEvent = try? AirshipJSON.wrap(triggerEvent) {
                triggerContext = AirshipTriggerContext(type: triggerType, goal: triggerGoal, event: triggerEvent)
            }

            let request = DeferredRequest(
                url: url,
                channelID: channelID,
                contactID: await audience.deviceInfo.stableContactID,
                triggerContext: triggerContext,
                locale: audience.deviceInfo.locale,
                notificationOptIn: await audience.deviceInfo.isUserOptedInPushNotifications
            )

            let result = await self.deferredResolver.resolve(request: request) { data in
                try AirshipJSON.from(data: data)
            }

            completionHandler(_InAppDeferredResult(result: result))
        }

    }


    @objc(addImpressionWithEntityID:product:contactID:reportingContext:)
    public func _addImpression(
        entityID: String,
        product: String,
        contactID: String?,
        reportingContext: Any?
    ) {
        Task {
            await self.addImpression(
                entityID: entityID,
                product: product,
                contactID: contactID,
                reportingContext: reportingContext
            )
        }
    }

    public func addImpression(
        entityID: String,
        product: String,
        contactID: String?,
        reportingContext: Any?
    ) async {
        let date = Date()
        let reportingContextJSON = try? AirshipJSON.wrap(reportingContext)
        let lastContactID = await contact.contactID

        let event = AirshipMeteredUsageEvent(
            eventID: UUID().uuidString,
            entityID: entityID,
            usageType: .inAppExperienceImpression,
            product: product,
            reportingContext: reportingContextJSON,
            timestamp: date,
            contactId: contactID ?? lastContactID
        )

        do {
            try await self.meteredUsage.addEvent(event)
        } catch {
            AirshipLogger.error("Failed to save metered usage event: \(event)")
        }

    }

    @objc
    public func subscribe(types: [String], block: @escaping ([RemoteDataPayload]) -> Void) -> Disposable {
        let cancellable = remoteData.publisher(types: types)
            .receive(on: RunLoop.main)
            .sink { payloads in
                block(payloads)
            }

        return Disposable {
            cancellable.cancel()
        }
    }

    @objc
    public func isCurrent(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        guard let remoteDataInfo = remoteDataInfo else {
            return false
        }
        return await remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
    }

    @objc
    public func requiresUpdate(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        guard await isCurrent(remoteDataInfo: remoteDataInfo) else {
            return true
        }

        let source = remoteDataInfo?.source ?? .app
        switch(await remoteData.status(source: source)) {
        case .outOfDate:
            return true
        case .stale:
            return false
        case .upToDate:
            return false
        }
    }

    @objc
    public func waitFullRefresh(remoteDataInfo: RemoteDataInfo?) async {
        let source = remoteDataInfo?.source ?? .app
        await self.remoteData.waitRefresh(source: source)
    }

    @objc
    public func bestEffortRefresh(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        let source = remoteDataInfo?.source ?? .app
        guard await isCurrent(remoteDataInfo: remoteDataInfo) else {
            return false
        }

        if await self.remoteData.status(source: source) == .upToDate {
            return true
        }

        // if we are connected wait for refresh
        if (await network.isConnected) {
            await remoteData.waitRefreshAttempt(source: source)
        }

        return await isCurrent(remoteDataInfo: remoteDataInfo)
    }

    @objc
    public func notifyOutdated(remoteDataInfo: RemoteDataInfo?) async {
        if let remoteDataInfo = remoteDataInfo {
            await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        }
    }
}


