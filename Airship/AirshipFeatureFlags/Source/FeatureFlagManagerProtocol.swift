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

/// Airship feature flag manager
public protocol FeatureFlagManager: AnyObject, Sendable {

    /// Feature flag result cache. This can be used to return a cached result for `flag(name:useResultCache:)`
    /// if the flag fails to resolve or it does not exist.
    var resultCache: any FeatureFlagResultCache { get }

    /// Feature flag status updates. Possible values are upToDate, stale and outOfDate.
    var featureFlagStatusUpdates: AsyncStream<any Sendable> { get async }

    /// Current feature flag status. Possible values are upToDate, stale and outOfDate.
    var featureFlagStatus: FeatureFlagUpdateStatus { get async }

    /// Tracks a feature flag interaction event.
    /// - Parameter flag: The flag.
    func trackInteraction(flag: FeatureFlag)

    /// Gets and evaluates a feature flag.
    /// - Parameters
    ///     - name: The flag name
    ///     - useResultCache: `true` to use the `FeatureFlagResultCache` if the flag fails to resolve or if the resolved flag does not exist,`false` to ignore the result cache.
    /// - Returns: The feature flag.
    /// - Throws: Throws `FeatureFlagError` if the flag fails to resolve.
    func flag(name: String, useResultCache: Bool ) async throws -> FeatureFlag

    /// Gets and evaluates a feature flag using a result cache.
    /// - Parameters
    ///     - name: The flag name
    ///     - useResultCache: `true` to use the `FeatureFlagResultCache` if the flag fails to resolve or if the resolved flag does not exist,`false` to ignore the result cache.
    /// - Returns: The feature flag.
    /// - Throws: Throws `FeatureFlagError` if the flag fails to resolve.
    func flag(name: String) async throws -> FeatureFlag

    /// Waits for the refresh of the Feature Flag rules.
    func waitRefresh() async

    /// Waits for the refresh of the Feature Flag rules.
    /// - Parameters maxTime: Timeout in seconds.
    func waitRefresh(maxTime: TimeInterval) async
}

public extension Airship {
    /// The shared `FeatureFlagManager` instance. `Airship.takeOff` must be called before accessing this instance.
    static var featureFlagManager: any FeatureFlagManager {
        return Airship.requireComponent(ofType: FeatureFlagComponent.self).featureFlagManager
    }
}
