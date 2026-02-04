/* Copyright Airship and Contributors */

import Foundation

/// Airship locale manager.
public protocol AirshipLocaleManager: AnyObject, Sendable {
    /**
     * Resets the current locale.
     */
    func clearLocale()

    /**
     * The current locale used by Airship. Defaults to `autoupdatingCurrent` or the user preferred lanaguage, depending on
     * `AirshipConfig.useUserPreferredLocale`.
     */
    var currentLocale: Locale { get set }
}


final class DefaultAirshipLocaleManager: AirshipLocaleManager {

    fileprivate static let storeKey: String = "com.urbanairship.locale.locale"

    private let dataStore: PreferenceDataStore
    private let config: RuntimeConfig
    private let notificationCenter: AirshipNotificationCenter

    /**
     * The current locale used by Airship. Defaults to `autoupdatingCurrent`.
     */
    public var currentLocale: Locale {
        get {
            if self.config.airshipConfig.useUserPreferredLocale {
                let preferredLanguage = Locale.preferredLanguages[0]
                let preferredLocale = Locale(identifier: preferredLanguage)
                return dataStore.localeOverride ?? preferredLocale
            } else {
                return dataStore.localeOverride ?? Locale.autoupdatingCurrent
            }
        }
        set {
            dataStore.localeOverride = newValue
            dispatchUpdate()
        }
    }
    
    /**
     * - Note: For internal use only. :nodoc:
     */
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared
    ) {
        self.dataStore = dataStore
        self.config = config
        self.notificationCenter = notificationCenter

        self.notificationCenter.addObserver(
            self,
            selector: #selector(autoLocaleChanged),
            name: NSLocale.currentLocaleDidChangeNotification
        )
    }

    /**
     * Resets the current locale.
     */
    public func clearLocale() {
        dataStore.localeOverride = nil
        dispatchUpdate()
    }

    @objc
    private func autoLocaleChanged() {
        if (dataStore.localeOverride == nil) {
            dispatchUpdate()
        }
    }

    private func dispatchUpdate() {
        notificationCenter.postOnMain(
            name: AirshipNotifications.LocaleUpdated.name,
            object: [AirshipNotifications.LocaleUpdated.localeKey: self.currentLocale]
        )
    }
}


fileprivate extension PreferenceDataStore {
    var localeOverride: Locale? {
        get {
            guard
                let encodedLocale = object(forKey: DefaultAirshipLocaleManager.storeKey) as? Data
            else {
                return nil
            }

            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSLocale.self, from: encodedLocale) as? Locale
        }
        set {
            guard let locale = newValue else {
                removeObject(forKey: DefaultAirshipLocaleManager.storeKey)
                return
            }

            guard
                let encodedLocale: Data = try? NSKeyedArchiver.archivedData(
                    withRootObject: locale,
                    requiringSecureCoding: true
                )
            else {
                AirshipLogger.error("Failed to encode locale!")
                return
            }

            setValue(
                encodedLocale,
                forKey: DefaultAirshipLocaleManager.storeKey
            )
        }
    }
}


public extension AirshipNotifications {

    /// NSNotification info when the locale is updated.
    final class LocaleUpdated: NSObject {

        /// NSNotification name.
        public static let name: NSNotification.Name = NSNotification.Name(
            "com.urbanairship.locale.locale_updated"
        )
        
        /// NSNotification userInfo key to get the locale.
        public static let localeKey: String = "locale"
    }

}
