/* Copyright Airship and Contributors */

import Foundation
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif


/// Feature flag errors
public enum FeatureFlagError: Error {
    /// Failed to fetch the data for the feature flag. The app should retry on this error.
    case failedToFetchData
}

enum FeatureFlagEvaluationError: Error {
    case connectionError
    case outOfDate
    case staleNotAllowed
}

/// Airship feature flag manager
public final class FeatureFlagManager: Sendable {

    /// The shared FeatureFlagManager instance. `Airship.takeOff` must be called before accessing this instance.
    public static var shared: FeatureFlagManager {
        return Airship.requireComponent(ofType: FeatureFlagComponent.self).featureFlagManager
    }

    private let remoteDataAccess: FeatureFlagRemoteDataAccessProtocol
    private let audienceChecker: DeviceAudienceChecker
    private let analytics: FeatureFlagAnalyticsProtocol
    private let deviceInfoProviderFactory: @Sendable () -> AudienceDeviceInfoProvider
    private let deferredResolver: FeatureFlagDeferredResolverProtocol

    init(
        dataStore: PreferenceDataStore,
        remoteDataAccess: FeatureFlagRemoteDataAccessProtocol,
        analytics: FeatureFlagAnalyticsProtocol,
        audienceChecker: DeviceAudienceChecker = DefaultDeviceAudienceChecker(),
        deviceInfoProviderFactory: @escaping @Sendable () -> AudienceDeviceInfoProvider = { CachingAudienceDeviceInfoProvider() },
        deferredResolver: FeatureFlagDeferredResolverProtocol
    ) {
        self.remoteDataAccess = remoteDataAccess
        self.audienceChecker = audienceChecker
        self.analytics = analytics
        self.deviceInfoProviderFactory = deviceInfoProviderFactory
        self.deferredResolver = deferredResolver
    }

    /// Tracks a feature flag interaction event.
    /// - Parameter flag: The flag.
    public func trackInteraction(flag: FeatureFlag) {
        analytics.trackInteraction(flag: flag)
    }

    /// Gets and evaluates  a feature flag
    /// - Parameter name: The flag name
    /// - Returns: The feature flag.
    /// - Throws: Throws `FeatureFlagError`
    public func flag(name: String) async throws -> FeatureFlag {
        return try await flag(name: name, allowRefresh: true)
    }

    private func flag(name: String, allowRefresh: Bool) async throws -> FeatureFlag {
        let remoteDataFeatureFlagInfo = await self.remoteDataAccess.remoteDataFlagInfo(name: name)
        let status = await self.remoteDataAccess.status

        do {
            try self.ensureRemoteDataValid(
                status: status,
                remoteDataFeatureFlagInfo: remoteDataFeatureFlagInfo
            )

            return try await self.evaluate(
                remoteDataFeatureFlagInfo: remoteDataFeatureFlagInfo
            )
        } catch {
            switch (error) {
            case FeatureFlagEvaluationError.connectionError:
                throw FeatureFlagError.failedToFetchData
            case FeatureFlagEvaluationError.outOfDate:
                await self.remoteDataAccess.notifyOutdated(
                    remoteDateInfo: remoteDataFeatureFlagInfo.remoteDataInfo
                )

                if (allowRefresh) {
                    await self.remoteDataAccess.waitForRefresh()
                    return try await self.flag(name: name, allowRefresh: false)
                }
                throw FeatureFlagError.failedToFetchData

            case FeatureFlagEvaluationError.staleNotAllowed:
                if (allowRefresh) {
                    await self.remoteDataAccess.waitForRefresh()
                    return try await self.flag(name: name, allowRefresh: false)
                }
                throw FeatureFlagError.failedToFetchData
            default:
                AirshipLogger.error("Unexpected error \(error)")
                throw FeatureFlagError.failedToFetchData
            }
        }
    }

    private func ensureRemoteDataValid(
        status: RemoteDataSourceStatus,
        remoteDataFeatureFlagInfo: RemoteDataFeatureFlagInfo
    ) throws {
        switch(status) {
        case .upToDate:
            return
        case .stale:
            guard !remoteDataFeatureFlagInfo.flagInfos.isEmpty else {
                throw FeatureFlagEvaluationError.outOfDate
            }

            let disallowStale = remoteDataFeatureFlagInfo.flagInfos.first { flagInfo in
                flagInfo.evaluationOptions?.disallowStaleValue == true
            }

            guard disallowStale == nil else {
                throw FeatureFlagEvaluationError.staleNotAllowed
            }

        case .outOfDate:
            throw FeatureFlagEvaluationError.outOfDate
        #if canImport(AirshipCore)
        default: break
        #endif
        }
    }

    private func evaluate(
        remoteDataFeatureFlagInfo: RemoteDataFeatureFlagInfo
    ) async throws -> FeatureFlag {
        let name = remoteDataFeatureFlagInfo.name
        let flagInfos = remoteDataFeatureFlagInfo.flagInfos
        let deviceInfoProvider = deviceInfoProviderFactory()

        guard !flagInfos.isEmpty else {
            return FeatureFlag.makeNotFound(name: name)
        }

        for flagInfo in flagInfos {
            if let audienceSelector = flagInfo.audienceSelector {
                let result = try? await self.audienceChecker.evaluate(
                    audience: audienceSelector,
                    newUserEvaluationDate: flagInfo.created,
                    deviceInfoProvider: deviceInfoProvider
                )

                if (result != true) {
                    continue
                }
            }

            switch (flagInfo.flagPayload) {
            case .deferredPayload(let deferredInfo):
                return try await evaluateDeferred(
                    flagInfo: flagInfo,
                    deferredInfo: deferredInfo,
                    deviceInfoProvider: deviceInfoProvider
                )


            case .staticPayload(let staticInfo):
                return try await evaluateStatic(
                    flagInfo: flagInfo,
                    isElegible: true,
                    staticInfo: staticInfo,
                    deviceInfoProvider: deviceInfoProvider
                )
            }
        }

        let lastFlagInfo = flagInfos.last
        return if let lastFlagInfo, case let .staticPayload(staticInfo) = lastFlagInfo.flagPayload {
            try await evaluateStatic(
                flagInfo: lastFlagInfo,
                isElegible: false,
                staticInfo: staticInfo,
                deviceInfoProvider: deviceInfoProvider
            )
        } else {
            FeatureFlag(
                name: name,
                isEligible: false,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: lastFlagInfo?.reportingMetadata ?? .null,
                    contactID: await deviceInfoProvider.stableContactInfo.contactID,
                    channelID: try await deviceInfoProvider.channelID
                )
            )
        }
    }
    
    private func evaluateDeferred(
        flagInfo: FeatureFlagInfo,
        deferredInfo: FeatureFlagPayload.DeferredInfo,
        deviceInfoProvider: AudienceDeviceInfoProvider
    ) async throws -> FeatureFlag {
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
                deviceInfoProvider: deviceInfoProvider
            )

            return try await FeatureFlag.makeFound(
                name: flagInfo.name,
                isElegible: deferredFlag.isEligible,
                deviceInfoProvider: deviceInfoProvider,
                reportingMetadata: deferredFlag.reportingMetadata,
                variables: variables
            )
        }
    }

    private func evaluateStatic(
        flagInfo: FeatureFlagInfo,
        isElegible: Bool,
        staticInfo: FeatureFlagPayload.StaticInfo,
        deviceInfoProvider: AudienceDeviceInfoProvider
    ) async throws -> FeatureFlag {
        let variables = await evaluateVariables(
            staticInfo.variables,
            flagInfo: flagInfo,
            deviceInfoProvider: deviceInfoProvider
        )

        return try await FeatureFlag.makeFound(
            name: flagInfo.name,
            isElegible: isElegible,
            deviceInfoProvider: deviceInfoProvider,
            reportingMetadata: flagInfo.reportingMetadata,
            variables: variables
        )
    }

    private func evaluateVariables(
        _ variables: FeatureFlagVariables?,
        flagInfo: FeatureFlagInfo,
        deviceInfoProvider: AudienceDeviceInfoProvider
    ) async -> VariableResult? {
        guard let variables = variables else {
            return nil
        }

        switch (variables) {
        case .fixed(let data):
            return VariableResult(data: data, reportingMetadata: nil)
        case .variant(let variants):
            for variant in variants {
                if let audienceSelector = variant.audienceSelector {
                    let result = try? await self.audienceChecker.evaluate(
                        audience: audienceSelector,
                        newUserEvaluationDate: flagInfo.created,
                        deviceInfoProvider: deviceInfoProvider
                    )

                    if (result != true) {
                        continue
                    }
                }

                return VariableResult(
                    data: variant.data,
                    reportingMetadata: variant.reportingMetadata
                )
            }

            return nil
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
        isElegible: Bool,
        deviceInfoProvider: AudienceDeviceInfoProvider,
        reportingMetadata: AirshipJSON,
        variables: VariableResult?
    ) async throws -> FeatureFlag {
        return FeatureFlag(
            name: name,
            isEligible: isElegible,
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
