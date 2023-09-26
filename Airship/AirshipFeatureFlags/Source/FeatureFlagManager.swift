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

/// Airship feature flag manager
public final class FeatureFlagManager: NSObject, AirshipComponent, Sendable {

    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }


    /// The shared FeatureFlagManager instance. `Airship.takeOff` must be called before accessing this instance.
    public static var shared: FeatureFlagManager {
        return Airship.requireComponent(ofType: FeatureFlagManager.self)
    }

    private let remoteDataAccess: FeatureFlagRemoteDataAccessProtocol
    private let audienceChecker: DeviceAudienceChecker
    private let date: AirshipDateProtocol
    private let disableHelper: ComponentDisableHelper

    init(
        dataStore: PreferenceDataStore,
        remoteDataAccess: FeatureFlagRemoteDataAccessProtocol,
        audienceChecker: DeviceAudienceChecker = DefaultDeviceAudienceChecker(),
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.remoteDataAccess = remoteDataAccess
        self.audienceChecker = audienceChecker
        self.date = date

        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "FeatureFlags"
        )
    }

    /// Gets and evaluates  a feature flag
    /// - Parameter name: The flag name
    /// - Returns: The feature flag.
    /// - Throws: Throws `FeatureFlagError`
    public func flag(name: String) async throws -> FeatureFlag {
        guard self.isComponentEnabled else {
            throw FeatureFlagError.failedToFetchData
        }

        return try await flag(name: name, allowRefresh: true)
    }

    private func flag(name: String, allowRefresh: Bool) async throws -> FeatureFlag {
        switch(await self.remoteDataAccess.status) {
        case .upToDate:
            let flagInfos = await flagInfos(name: name)
            return await evaluate(flagInfos: flagInfos)
        case .stale:
            let flagInfos = await flagInfos(name: name)
            if (flagInfos.isEmpty || !isStaleAllowed(flagInfos: flagInfos)) {
                if (allowRefresh) {
                    await self.remoteDataAccess.waitForRefresh()
                    return try await flag(name: name, allowRefresh: false)
                }
                throw FeatureFlagError.failedToFetchData
            }
            return await evaluate(flagInfos: flagInfos)
        case .outOfDate:
            if (allowRefresh) {
                await self.remoteDataAccess.waitForRefresh()
                return try await flag(name: name, allowRefresh: false)
            }
            throw FeatureFlagError.failedToFetchData

#if canImport(AirshipCore)
        default: throw FeatureFlagError.failedToFetchData
#endif
        }
    }

    private func isStaleAllowed(flagInfos: [FeatureFlagInfo]) -> Bool {
        let disallowStale = flagInfos.first { flagInfo in
            flagInfo.evaluationOptions?.disallowStaleValue == true
        }
        return disallowStale == nil
    }

    private func evaluate(flagInfos: [FeatureFlagInfo]) async -> FeatureFlag {
        let deviceInfoProvider = CachingAudienceDeviceInfoProvider()

        guard !flagInfos.isEmpty else {
            return FeatureFlag(isEligible: false, exists: false, variables: nil)
        }

        for flagInfo in flagInfos {
            if let audienceSelector = flagInfo.audienceSelector {
                let result = try? await self.audienceChecker.evaluate(
                    audience: audienceSelector,
                    newUserEvaluationDate: flagInfo.created,
                    contactID: nil,
                    deviceInfoProvider: deviceInfoProvider
                )

                if (result != true) {
                    continue
                }
            }

            switch (flagInfo.flagPayload) {
            case .deferredPayload(_): continue
            case .staticPayload(let staticInfo):
                let variables = await evaluateVariables(staticInfo.variables, flagInfo: flagInfo, deviceInfoProvider: deviceInfoProvider)
                return FeatureFlag(isEligible: true, exists: true, variables: variables)
            }
        }

        return FeatureFlag(isEligible: false, exists: true, variables: nil)
    }

    private func evaluateVariables(
        _ variables: FeatureFlagVariables?,
        flagInfo: FeatureFlagInfo,
        deviceInfoProvider: AudienceDeviceInfoProvider
    ) async -> AirshipJSON? {
        guard let variables = variables else {
            return nil
        }

        switch (variables) {
        case .fixed(let variables):
            return variables
        case .variant(let variants):
            for variant in variants {
                if let audienceSelector = variant.audienceSelector {
                    let result = try? await self.audienceChecker.evaluate(
                        audience: audienceSelector,
                        newUserEvaluationDate: flagInfo.created,
                        contactID: nil,
                        deviceInfoProvider: deviceInfoProvider
                    )

                    if (result != true) {
                        continue
                    }
                }

                return variant.data
            }

            return nil
        }
    }

    private func flagInfos(
        name: String
    ) async -> [FeatureFlagInfo] {
        return await self.remoteDataAccess.flagInfos
            .filter { $0.name == name }
            .filter { $0.timeCriteria?.isActive(date: self.date.now) ?? true }
            .filter { !$0.isDeferred } // ignore deferred for now
    }
}
