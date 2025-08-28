/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

protocol ApplicationMetricsProtocol: Sendable {
    var isAppVersionUpdated: Bool { get }
    var currentAppVersion: String? { get }

}

/// The ApplicationMetrics class keeps track of application-related metrics.
final class ApplicationMetrics: ApplicationMetricsProtocol {
    private static let lastOpenDataKey = "UAApplicationMetricLastOpenDate"
    private static let lastAppVersionKey = "UAApplicationMetricsLastAppVersion"

    private let dataStore: PreferenceDataStore
    private let privacyManager: any PrivacyManagerProtocol

    /**
     * Determines whether the application's short version string has been updated.
     * Only tracked if Feature.inAppAutomation or Feature.analytics are enabled in the privacy manager.
     */
    public var isAppVersionUpdated: Bool {
        guard
            self.privacyManager.isApplicationMetricsEnabled,
            let currentVersion = self.currentAppVersion,
            let lastVersion = self.lastAppVersion,
            AirshipUtils.compareVersion(lastVersion, toVersion: currentVersion) == .orderedAscending
        else {
            return false
        }

        return true
    }

    /**
     * The application's current short version string also known as the marketing version.
     */
    public let currentAppVersion: String?

    /**
     * The application's last short version string also known as the marketing version.
     */
    public let lastAppVersion: String?

    public init(
        dataStore: PreferenceDataStore,
        privacyManager: any PrivacyManagerProtocol,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        appVersion: String? = AirshipUtils.bundleShortVersionString()
    ) {
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.currentAppVersion = appVersion


        self.lastAppVersion = if privacyManager.isApplicationMetricsEnabled {
            self.dataStore.string(
                forKey: ApplicationMetrics.lastAppVersionKey
            )
        } else {
            nil
        }

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
            guard let currentVersion = self.currentAppVersion else {
                return
            }

            self.dataStore.setObject(
                currentVersion,
                forKey: ApplicationMetrics.lastAppVersionKey
            )
        } else {
            self.dataStore.removeObject(
                forKey: ApplicationMetrics.lastAppVersionKey
            )
        }
    }
}


fileprivate extension PrivacyManagerProtocol {
    var isApplicationMetricsEnabled: Bool {
        self.isEnabled(.inAppAutomation) || self.isEnabled(.analytics)
    }
}
