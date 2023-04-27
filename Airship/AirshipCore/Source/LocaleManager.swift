/* Copyright Airship and Contributors */

@objc(UALocaleManagerProtocol)
public protocol AirshipLocaleManagerProtocol: AnyObject, Sendable {
    /**
     * Resets the current locale.
     */
    @objc
    func clearLocale()

    /**
     * The current locale used by Airship. Defaults to `autoupdatingCurrent`.
     */
    @objc
    var currentLocale: Locale { get }

}

/// Airship locale manager.
@objc(UALocaleManager)
public final class AirshipLocaleManager: NSObject, AirshipLocaleManagerProtocol {

    fileprivate static let storeKey = "com.urbanairship.locale.locale"

    @objc
    public static let localeUpdatedEvent = NSNotification.Name(
        "com.urbanairship.locale.locale_updated"
    )

    @objc
    public static let localeEventKey = "locale"

    private let dataStore: PreferenceDataStore
    private let notificationCenter: AirshipNotificationCenter

    /**
     * The current locale used by Airship. Defaults to `autoupdatingCurrent`.
     */
    @objc
    public var currentLocale: Locale {
        get {
            return dataStore.localeOverride ?? Locale.autoupdatingCurrent
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
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared
    ) {
        self.dataStore = dataStore
        self.notificationCenter = notificationCenter
        super.init()

        self.notificationCenter.addObserver(
            self,
            selector: #selector(autoLocaleChanged),
            name: NSLocale.currentLocaleDidChangeNotification
        )
    }

    /**
     * Resets the current locale.
     */
    @objc
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
            name: AirshipLocaleManager.localeUpdatedEvent,
            object: [AirshipLocaleManager.localeEventKey: self.currentLocale]
        )
    }
}


fileprivate extension PreferenceDataStore {
    var localeOverride: Locale? {
        get {
            guard
                let encodedLocale = object(forKey: AirshipLocaleManager.storeKey) as? Data
            else {
                return nil
            }

            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSLocale.self, from: encodedLocale) as? Locale
        }
        set {
            guard let locale = newValue else {
                removeObject(forKey: AirshipLocaleManager.storeKey)
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
                forKey: AirshipLocaleManager.storeKey
            )
        }
    }
}
