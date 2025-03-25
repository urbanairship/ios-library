/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif


/// Feature flag errors
public enum FeatureFlagError: Error, Equatable {
    case failedToFetchData
    case staleData
    case outOfDate
    case connectionError(errorMessage: String)
}

enum FeatureFlagEvaluationError: Error, Equatable {
    case outOfDate
    case connectionError(errorMessage: String)
}

/// Airship feature flag manager
public final class FeatureFlagManager: Sendable {

    /// The shared FeatureFlagManager instance. `Airship.takeOff` must be called before accessing this instance.
    @available(*, deprecated, message: "Use Airship.featureFlagManager instead")
    public static var shared: FeatureFlagManager {
        return Airship.featureFlagManager
    }

    private let remoteDataAccess: any FeatureFlagRemoteDataAccessProtocol
    private let audienceChecker: any DeviceAudienceChecker
    private let analytics: any FeatureFlagAnalyticsProtocol
    private let deviceInfoProviderFactory: @Sendable () -> any AudienceDeviceInfoProvider
    private let deferredResolver: any FeatureFlagDeferredResolverProtocol
    private let remoteData: any RemoteDataProtocol
    private let privacyManager: any PrivacyManagerProtocol

    /// Feature flag result cache. This can be used to return a cached result for `flag(name:useResultCache:)`
    /// if the flag fails to resolve or it does not exist.
    public let resultCache: FeatureFlagResultCache

    /// Feature flag status updates. Possible values are upToDate, stale and outOfDate.
    public var featureFlagStatusUpdates: AsyncStream<any Sendable> {
        get async {
            return await self.remoteData.statusUpdates { status in
                return self.toFeatureFlagUpdateStatus(status: status)
           }
        }
    }
    
    /// Current feature flag status. Possible values are upToDate, stale and outOfDate.
    public var featureFlagStatus: FeatureFlagUpdateStatus {
        get async {
            return await self.toFeatureFlagUpdateStatus(status: self.remoteDataAccess.status)
        }
    }
    
    private var enabled: Bool {
        return self.privacyManager.isEnabled(.featureFlags)
    }
    
    init(
        dataStore: PreferenceDataStore,
        remoteDataAccess: any FeatureFlagRemoteDataAccessProtocol,
        remoteData: any RemoteDataProtocol,
        analytics: any FeatureFlagAnalyticsProtocol,
        audienceChecker: any DeviceAudienceChecker,
        deviceInfoProviderFactory: @escaping @Sendable () -> any AudienceDeviceInfoProvider = { CachingAudienceDeviceInfoProvider() },
        deferredResolver: any FeatureFlagDeferredResolverProtocol,
        privacyManager: any PrivacyManagerProtocol,
        resultCache: FeatureFlagResultCache
    ) {
        self.remoteDataAccess = remoteDataAccess
        self.audienceChecker = audienceChecker
        self.analytics = analytics
        self.deviceInfoProviderFactory = deviceInfoProviderFactory
        self.deferredResolver = deferredResolver
        self.privacyManager = privacyManager
        self.resultCache = resultCache
        self.remoteData = remoteData
    }

    /// Tracks a feature flag interaction event.
    /// - Parameter flag: The flag.
    public func trackInteraction(flag: FeatureFlag) {
        guard self.enabled else {
            AirshipLogger.warn("Feature flags disabled.")
            return
        }
        analytics.trackInteraction(flag: flag)
    }


    /// Gets and evaluates  a feature flag
    /// - Parameters
    ///     - name: The flag name
    ///     - useResultCache: `true` to use the `FeatureFlagResultCache` if the flag fails to resolve or if the resolved flag does not exist,`false` to ignore the result cache.
    /// - Returns: The feature flag.
    /// - Throws: Throws `FeatureFlagError` if the flag fails to resolve.
    public func flag(name: String, useResultCache: Bool = true) async throws -> FeatureFlag {
        guard self.enabled else {
            throw AirshipErrors.error("Feature flags disabled.")
        }

        do {
            let flag = try await resolveFlag(name: name)
            if !flag.exists, useResultCache {
                if let fromCache = await resultCache.flag(name: name) {
                    return fromCache
                }
            }
            return flag
        } catch {
            guard
                useResultCache,
                let fromCache = await resultCache.flag(name: name)
            else {
                throw error
            }
            return fromCache
        }
    }

    /// Allows to wait for the refresh of the Feature Flag rules.
    /// /// - Parameters
    ///     - maxTime: Timeout in seconds.
    public func waitRefresh(maxTime: TimeInterval? = nil) async {
        await self.remoteData.waitRefresh(source: RemoteDataSource.app, maxTime: maxTime)
    }

    func resolveFlag(name: String) async throws -> FeatureFlag {
        let remoteDataFeatureFlagInfo = try await remoteDataFeatureFlagInfo(name: name)

        do {
            // Attempt to evaluate
            return try await self.evaluate(
                remoteDataFeatureFlagInfo: remoteDataFeatureFlagInfo
            )
        } catch {
            // If it's not an outOfDate evaluation error, throw the error
            guard case FeatureFlagEvaluationError.outOfDate = error else {
                throw mapError(error)
            }

            // Notify out of date
            await self.remoteDataAccess.notifyOutdated(
                remoteDateInfo: remoteDataFeatureFlagInfo.remoteDataInfo
            )

            // Best effort refresh again
            await remoteDataAccess.bestEffortRefresh()

            // Only continue if we actually have updated the status
            guard await remoteDataAccess.status == .upToDate else {
                throw mapError(error)
            }

            // Try one more time
            do {
                return try await self.evaluate(
                    remoteDataFeatureFlagInfo: remoteDataFeatureFlagInfo
                )
            } catch {
                throw mapError(error)
            }
        }
    }

    private func remoteDataFeatureFlagInfo(
        name: String
    ) async throws -> RemoteDataFeatureFlagInfo {

        switch(await remoteDataAccess.status) {
        case .upToDate:
            return await self.remoteDataAccess.remoteDataFlagInfo(name: name)
        case .stale, .outOfDate:
            let info = await self.remoteDataAccess.remoteDataFlagInfo(name: name)
            if info.disallowStale || info.flagInfos.isEmpty {
                await self.remoteDataAccess.bestEffortRefresh()
                let updatedStatus = await self.remoteDataAccess.status
                switch(updatedStatus) {
                case .upToDate:
                    return await self.remoteDataAccess.remoteDataFlagInfo(name: name)
                case .outOfDate:
                    throw FeatureFlagError.outOfDate
                case .stale:
                    throw FeatureFlagError.staleData
                @unknown default:
                    throw AirshipErrors.error("Unexpected state")
                }
            } else {
                return info
            }
        @unknown default:
            throw AirshipErrors.error("Unexpected state")
        }
    }

    private func mapError(_ error: any Error) -> any Error {
        return switch (error) {
        case FeatureFlagEvaluationError.connectionError(let errorMessage):
            FeatureFlagError.connectionError(errorMessage: errorMessage)
        case FeatureFlagEvaluationError.outOfDate:
            FeatureFlagError.outOfDate
        default:
            FeatureFlagError.failedToFetchData
        }
    }

    private func evaluate(
        remoteDataFeatureFlagInfo: RemoteDataFeatureFlagInfo
    ) async throws -> FeatureFlag {
        let name = remoteDataFeatureFlagInfo.name
        let flagInfos = remoteDataFeatureFlagInfo.flagInfos
        let deviceInfoProvider = deviceInfoProviderFactory()

        for (index, flagInfo) in flagInfos.enumerated() {
            let isLast = index == (flagInfos.count - 1)
            let isLocallyEligible = try await self.isLocallyEligible(
                flagInfo: flagInfo,
                deviceInfoProvider: deviceInfoProvider
            )

            // We are not locally eligible and have other flags skip
            if !isLast, !isLocallyEligible {
                continue
            }

            let flag: FeatureFlag = switch (flagInfo.flagPayload) {
            case .deferredPayload(let deferredInfo):
                try await evaluateDeferred(
                    flagInfo: flagInfo,
                    isLocallyEligible: isLocallyEligible,
                    deferredInfo: deferredInfo,
                    deviceInfoProvider: deviceInfoProvider
                )
            case .staticPayload(let staticInfo):
                try await evaluateStatic(
                    flagInfo: flagInfo,
                    isLocallyEligible: isLocallyEligible,
                    staticInfo: staticInfo,
                    deviceInfoProvider: deviceInfoProvider
                )
            }

            /// If the flag is eligible or the last flag return
            if flag.isEligible || isLast {
                return try await self.flag(flag, applyingControlFrom: flagInfo, deviceInfoProvider: deviceInfoProvider)
            }
        }

        return FeatureFlag.makeNotFound(name: name)
    }
    
    private func flag(
        _ flag: FeatureFlag,
        applyingControlFrom info: FeatureFlagInfo,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> FeatureFlag {
        guard
            flag.isEligible,
            let control = info.controlOptins
        else {
            return flag
        }
        
        let isAudienceMatch = try await self.audienceChecker.evaluate(
            audienceSelector: control.compoundAudience?.selector,
            newUserEvaluationDate: info.created,
            deviceInfoProvider: deviceInfoProvider
        )
        
        if !isAudienceMatch.isMatch {
            return flag
        }
        
        var result = flag
        
        switch control.controlType {
        case .flag:
            result.isEligible = false
        case .variables(let override):
            result.variables = override
        }
        
        guard var reportingInfo = flag.reportingInfo else {
            return result
        }
        
        reportingInfo.addSuperseded(metadata: reportingInfo.reportingMetadata)
        reportingInfo.reportingMetadata = control.reportingMetadata
        
        result.reportingInfo = reportingInfo
        
        return result
    }

    private func isLocallyEligible(
        flagInfo: FeatureFlagInfo,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> Bool {
        let result = try await self.audienceChecker.evaluate(
            audienceSelector: .combine(
                compoundSelector: flagInfo.compoundAudience?.selector,
                deviceSelector: flagInfo.audienceSelector
            ),
            newUserEvaluationDate: flagInfo.created,
            deviceInfoProvider: deviceInfoProvider
        )
        
        return result.isMatch
    }

    private func evaluateDeferred(
        flagInfo: FeatureFlagInfo,
        isLocallyEligible: Bool,
        deferredInfo: FeatureFlagPayload.DeferredInfo,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> FeatureFlag {

        guard isLocallyEligible else {
            return try await FeatureFlag.makeFound(
                name: flagInfo.name,
                isEligible: false,
                deviceInfoProvider: deviceInfoProvider,
                reportingMetadata: flagInfo.reportingMetadata,
                variables: nil
            )
        }

        let request = DeferredRequest(
            url: deferredInfo.deferred.url,
            channelID: try await deviceInfoProvider.channelID,
            contactID: await deviceInfoProvider.stableContactInfo.contactID,
            locale: deviceInfoProvider.locale,
            notificationOptIn: await deviceInfoProvider.isUserOptedInPushNotifications
        )

        let deferredFlagResult = try await deferredResolver.resolve(
            request: request,
            flagInfo: flagInfo
        )

        switch(deferredFlagResult) {
        case .notFound:
            return FeatureFlag.makeNotFound(name: flagInfo.name)

        case .found(let deferredFlag):
            let variables = await evaluateVariables(
                deferredFlag.variables,
                flagInfo: flagInfo,
                isEligible: deferredFlag.isEligible,
                deviceInfoProvider: deviceInfoProvider
            )

            return try await FeatureFlag.makeFound(
                name: flagInfo.name,
                isEligible: deferredFlag.isEligible,
                deviceInfoProvider: deviceInfoProvider,
                reportingMetadata: deferredFlag.reportingMetadata,
                variables: variables
            )
        }
    }

    private func evaluateStatic(
        flagInfo: FeatureFlagInfo,
        isLocallyEligible: Bool,
        staticInfo: FeatureFlagPayload.StaticInfo,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> FeatureFlag {
        let variables = await evaluateVariables(
            staticInfo.variables,
            flagInfo: flagInfo,
            isEligible: isLocallyEligible,
            deviceInfoProvider: deviceInfoProvider
        )

        return try await FeatureFlag.makeFound(
            name: flagInfo.name,
            isEligible: isLocallyEligible,
            deviceInfoProvider: deviceInfoProvider,
            reportingMetadata: flagInfo.reportingMetadata,
            variables: variables
        )
    }

    private func evaluateVariables(
        _ variables: FeatureFlagVariables?,
        flagInfo: FeatureFlagInfo,
        isEligible: Bool,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async -> VariableResult? {
        guard let variables = variables, isEligible else {
            return nil
        }

        switch (variables) {
        case .fixed(let data):
            return VariableResult(data: data, reportingMetadata: nil)
        case .variant(let variants):
            for variant in variants {

                let result = try? await self.audienceChecker.evaluate(
                    audienceSelector: .combine(
                        compoundSelector: variant.compoundAudience?.selector,
                        deviceSelector: variant.audienceSelector
                    ),
                    newUserEvaluationDate: flagInfo.created,
                    deviceInfoProvider: deviceInfoProvider
                )
                
                if (result?.isMatch != true) {
                    continue
                }

                return VariableResult(
                    data: variant.data,
                    reportingMetadata: variant.reportingMetadata
                )
            }

            return nil
        }
    }
    
    private func toFeatureFlagUpdateStatus(status: RemoteDataSourceStatus) -> FeatureFlagUpdateStatus {
        
        switch(status) {
            
        case .upToDate:
            return FeatureFlagUpdateStatus.upToDate
            
        case .stale:
            return FeatureFlagUpdateStatus.stale
            
        case .outOfDate:
            return FeatureFlagUpdateStatus.outOfDate
            
        @unknown default:
            return FeatureFlagUpdateStatus.upToDate
        }
        
    }
}


fileprivate struct VariableResult {
    let data: AirshipJSON?
    let reportingMetadata: AirshipJSON?
}

fileprivate extension FeatureFlag {
    static func makeNotFound(name: String) -> FeatureFlag {
        return FeatureFlag(
            name: name,
            isEligible: false,
            exists: false,
            variables: nil,
            reportingInfo: nil
        )
    }

    static func makeFound(
        name: String,
        isEligible: Bool,
        deviceInfoProvider: any AudienceDeviceInfoProvider,
        reportingMetadata: AirshipJSON,
        variables: VariableResult?
    ) async throws -> FeatureFlag {
        return FeatureFlag(
            name: name,
            isEligible: isEligible,
            exists: true,
            variables: variables?.data,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: variables?.reportingMetadata ?? reportingMetadata,
                contactID: await deviceInfoProvider.stableContactInfo.contactID,
                channelID: try await deviceInfoProvider.channelID
            )
        )
    }
}

public extension Airship {
    /// The shared MessageCenter instance. `Airship.takeOff` must be called before accessing this instance.
    static var featureFlagManager: FeatureFlagManager {
        return Airship.requireComponent(ofType: FeatureFlagComponent.self).featureFlagManager
    }
}
