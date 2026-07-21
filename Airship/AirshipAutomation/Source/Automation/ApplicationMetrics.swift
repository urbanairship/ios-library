/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
@_spi(AirshipInternal) import AirshipCore
#endif

protocol ApplicationMetricsProtocol: Sendable {
    var isAppVersionUpdated: Bool { get }
    var currentAppVersion: String? { get }
    var currentBuildVersion: String? { get }
    var lastAppVersion: String? { get }
    var lastBuildVersion: String? { get }
}

/// The ApplicationMetrics class keeps track of application-related metrics.
final class ApplicationMetrics: ApplicationMetricsProtocol {
    private static let lastOpenDataKey = "UAApplicationMetricLastOpenDate"
    private static let lastAppVersionKey = "UAApplicationMetricsLastAppVersion"
    private static let lastBuildVersionKey = "UAApplicationMetricsLastBuildVersion"

    private let dataStore: PreferenceDataStore
    private let privacyManager: any AirshipPrivacyManager

    /**
     * Determines whether the application's short version string has been updated.
     * Only tracked if Feature.inAppAutomation or Feature.analytics are enabled in the privacy manager.
     */
    public var isAppVersionUpdated: Bool {
        guard self.privacyManager.isApplicationMetricsEnabled else { return false }

        // Both nil means fresh install — no prior record at all.
        guard self.lastAppVersion != nil || self.lastBuildVersion != nil else { return false }

        // Use build version (CFBundleVersion) as the sole indicator — it's required to increment.
        guard let current = self.currentBuildVersion, let last = self.lastBuildVersion else { return false }
        return last != current
    }

    /// The application's current short version string (marketing version / CFBundleShortVersionString).
    public let currentAppVersion: String?

    /// The application's current build version (CFBundleVersion).
    public let currentBuildVersion: String?

    /// The application's previous short version string from the last launch.
    public let lastAppVersion: String?

    /// The application's previous build version from the last launch.
    public let lastBuildVersion: String?

    public init(
        dataStore: PreferenceDataStore,
        privacyManager: any AirshipPrivacyManager,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        appVersion: String? = AirshipUtils.bundleShortVersionString(),
        buildVersion: String? = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    ) {
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.currentAppVersion = appVersion
        self.currentBuildVersion = buildVersion

        let metricsEnabled = privacyManager.isApplicationMetricsEnabled
        self.lastAppVersion = metricsEnabled
            ? self.dataStore.string(forKey: ApplicationMetrics.lastAppVersionKey)
            : nil
        self.lastBuildVersion = metricsEnabled
            ? self.dataStore.string(forKey: ApplicationMetrics.lastBuildVersionKey)
            : nil

        // Delete old
        self.dataStore.removeObject(
            forKey: ApplicationMetrics.lastOpenDataKey
        )

        updateData()

        notificationCenter.addObserver(
            self,
            selector: #selector(updateData),
            name: AirshipNotifications.PrivacyManagerUpdated.name,
            object: nil
        )
    }

    @objc
    func updateData() {
        if self.privacyManager.isApplicationMetricsEnabled {
            if let currentVersion = self.currentAppVersion {
                self.dataStore.setObject(currentVersion, forKey: ApplicationMetrics.lastAppVersionKey)
            }
            if let currentBuild = self.currentBuildVersion {
                self.dataStore.setObject(currentBuild, forKey: ApplicationMetrics.lastBuildVersionKey)
            }
        } else {
            self.dataStore.removeObject(forKey: ApplicationMetrics.lastAppVersionKey)
            self.dataStore.removeObject(forKey: ApplicationMetrics.lastBuildVersionKey)
        }
    }
}


fileprivate extension AirshipPrivacyManager {
    var isApplicationMetricsEnabled: Bool {
        self.isEnabled(.inAppAutomation) || self.isEnabled(.analytics)
    }
}
