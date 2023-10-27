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

    /// NOTE: For internal use only. :nodoc:
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
    private let eventTracker: EventTracker
    private let deviceInfoProviderFactory: @Sendable () -> AudienceDeviceInfoProvider
    private let notificationCenter: AirshipNotificationCenter

    init(
        dataStore: PreferenceDataStore,
        remoteDataAccess: FeatureFlagRemoteDataAccessProtocol,
        eventTracker: EventTracker,
        audienceChecker: DeviceAudienceChecker = DefaultDeviceAudienceChecker(),
        date: AirshipDateProtocol = AirshipDate.shared,
        deviceInfoProviderFactory: @escaping @Sendable () -> AudienceDeviceInfoProvider = { CachingAudienceDeviceInfoProvider() },
        notificationCenter: AirshipNotificationCenter = .shared
    ) {
        self.remoteDataAccess = remoteDataAccess
        self.audienceChecker = audienceChecker
        self.date = date
        self.eventTracker = eventTracker
        self.deviceInfoProviderFactory = deviceInfoProviderFactory
        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "FeatureFlags"
        )
        self.notificationCenter = notificationCenter
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

    /// Tracks a feature flag interaction event.
    /// - Parameter flag: The flag.
    public func trackInteraction(flag: FeatureFlag) {
        guard flag.exists else { return }

        do {
            let event = try FeatureFlagInteractedEvent(flag: flag)
            eventTracker.addEvent(event)
            self.notificationCenter.post(
                name: AirshipAnalytics.featureFlagInterracted,
                object: self,
                userInfo: [AirshipAnalytics.eventKey: event]
            )
        } catch {
            AirshipLogger.error("Failed to generate FeatureFlagInteractedEvent \(error)")
        }
    }

    private func flag(name: String, allowRefresh: Bool) async throws -> FeatureFlag {
        switch(await self.remoteDataAccess.status) {
        case .upToDate:
            let flagInfos = await flagInfos(name: name)
            return await evaluate(name: name, flagInfos: flagInfos)
        case .stale:
            let flagInfos = await flagInfos(name: name)
            if (flagInfos.isEmpty || !isStaleAllowed(flagInfos: flagInfos)) {
                if (allowRefresh) {
                    await self.remoteDataAccess.waitForRefresh()
                    return try await flag(name: name, allowRefresh: false)
                }
                throw FeatureFlagError.failedToFetchData
            }
            return await evaluate(name: name, flagInfos: flagInfos)
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

    private func evaluate(name: String, flagInfos: [FeatureFlagInfo]) async -> FeatureFlag {
        let deviceInfoProvider = deviceInfoProviderFactory()

        guard !flagInfos.isEmpty else {
            return FeatureFlag(
                name: name,
                isEligible: false,
                exists: false,
                variables: nil,
                reportingInfo: nil
            )
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
            case .deferredPayload(_): continue
            case .staticPayload(let staticInfo):
                let variables = await evaluateVariables(staticInfo.variables, flagInfo: flagInfo, deviceInfoProvider: deviceInfoProvider)
                return FeatureFlag(
                    name: name,
                    isEligible: true,
                    exists: true,
                    variables: variables?.data,
                    reportingInfo: FeatureFlag.ReportingInfo(
                        reportingMetadata: variables?.reportingMetadata ?? flagInfo.reportingMetadata,
                        contactID: await deviceInfoProvider.stableContactID,
                        channelID: deviceInfoProvider.channelID
                    )
                )
            }
        }

        return FeatureFlag(
            name: name,
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: flagInfos.last?.reportingMetadata ?? .null,
                contactID: await deviceInfoProvider.stableContactID,
                channelID: deviceInfoProvider.channelID
            )
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

    struct VariableResult {
        let data: AirshipJSON?
        let reportingMetadata: AirshipJSON?
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

protocol EventTracker: Sendable {
    func addEvent(_ event: AirshipEvent)
}

