/* Copyright Airship and Contributors */

/**
 * The UAApplicationMetrics class keeps track of application-related metrics.
 */
@objc
public class UAApplicationMetrics : NSObject {
    private static let lastOpenDataKey = "UAApplicationMetricLastOpenDate"
    private static let lastAppVersionKey = "UAApplicationMetricsLastAppVersion"

    private let dataStore: UAPreferenceDataStore
    private let date: UADate
    private let privacyManager: UAPrivacyManager

    private var _isAppVersionUpdated = false

    /**
     * Determines whether the application's short version string has been updated.
     * Only tracked if UAFeatureInAppAutomation or UAFeatureAnalytics are enabled in the privacy manager.
     */
    @objc
    public var isAppVersionUpdated : Bool {
        get {
            return _isAppVersionUpdated
        }
    }

    /**
     * The date of the last time the application was active.
     * Only tracked if UAFeatureInAppAutomation or UAFeatureAnalytics are enabled in the privacy manager.
     */
    @objc
    public var lastApplicationOpenDate : Date? {
        get {
            return dataStore.object(forKey: UAApplicationMetrics.lastOpenDataKey) as? Date
        }
    }

    /**
     * The application's current short version string.
     */
    @objc
    public var currentAppVersion : String? {
        get {
            return UAUtils.bundleShortVersionString()
        }
    }

    @objc
    public init(
        dataStore: UAPreferenceDataStore,
        privacyManager: UAPrivacyManager,
        notificationCenter: NotificationCenter,
        date: UADate) {
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.date = date

        super.init()

        updateData()

        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UAAppStateTracker.didBecomeActiveNotification,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(updateData),
            name: UAPrivacyManager.changeEvent,
            object: nil)
    }

    @objc
    public convenience init(dataStore: UAPreferenceDataStore, privacyManager: UAPrivacyManager) {
        self.init(
            dataStore: dataStore,
            privacyManager: privacyManager,
            notificationCenter: NotificationCenter.default,
            date: UADate())
    }

    @objc
    func applicationDidBecomeActive() {
        if (self.privacyManager.isEnabled(.inAppAutomation) || self.privacyManager.isEnabled(.analytics))  {
            self.dataStore.setObject(date.now, forKey: UAApplicationMetrics.lastOpenDataKey)
        }
    }

    @objc
    func updateData() {
        if (self.privacyManager.isEnabled(.inAppAutomation) || self.privacyManager.isEnabled(.analytics))  {

            guard let currentVersion = self.currentAppVersion else {
                return
            }

            let lastVersion = self.dataStore.string(forKey: UAApplicationMetrics.lastAppVersionKey)

            if (lastVersion != nil && UAUtils.compareVersion(lastVersion!, toVersion: currentVersion) == .orderedAscending) {
                self._isAppVersionUpdated = true
            }

            self.dataStore.setObject(currentVersion, forKey: UAApplicationMetrics.lastAppVersionKey)
        } else {
            self.dataStore.removeObject(forKey: UAApplicationMetrics.lastOpenDataKey)
            self.dataStore.removeObject(forKey: UAApplicationMetrics.lastAppVersionKey)
        }
    }
}
