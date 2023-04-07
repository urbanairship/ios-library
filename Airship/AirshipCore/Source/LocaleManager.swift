/* Copyright Airship and Contributors */

@objc(UALocaleManagerProtocol)
public protocol AirshipLocaleManagerProtocol {
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
public class AirshipLocaleManager: NSObject, AirshipLocaleManagerProtocol {

    private static let storeKey = "com.urbanairship.locale.locale"

    @objc
    public static let localeUpdatedEvent = NSNotification.Name(
        "com.urbanairship.locale.locale_updated"
    )

    @objc
    public static let localeEventKey = "locale"

    private var dataStore: PreferenceDataStore
    private var notificationCenter: NotificationCenter

    /**
     * The current locale used by Airship. Defaults to `autoupdatingCurrent`.
     */
    @objc
    public var currentLocale: Locale {
        get {
            if let encodedLocale = dataStore.object(
                forKey: AirshipLocaleManager.storeKey
            )
                as? Data
            {
                if let locale = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClass: NSLocale.self,
                    from: encodedLocale
                ) as? Locale {
                    return locale
                }
            }
            return Locale.autoupdatingCurrent
        }
        set {
            if let encodedLocale: Data = try? NSKeyedArchiver.archivedData(
                withRootObject: newValue,
                requiringSecureCoding: true
            ) {
                dataStore.setValue(
                    encodedLocale,
                    forKey: AirshipLocaleManager.storeKey
                )
                notificationCenter.post(
                    name: AirshipLocaleManager.localeUpdatedEvent,
                    object: [AirshipLocaleManager.localeEventKey: newValue]
                )
            } else {
                AirshipLogger.error("Failed to encode locale!")
            }
        }
    }

    /**
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public convenience init(dataStore: PreferenceDataStore) {
        self.init(
            dataStore: dataStore,
            notificationCenter: NotificationCenter.default
        )
    }

    /**
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public init(
        dataStore: PreferenceDataStore,
        notificationCenter: NotificationCenter
    ) {
        self.dataStore = dataStore
        self.notificationCenter = notificationCenter
        super.init()
    }

    /**
     * Resets the current locale.
     */
    @objc
    public func clearLocale() {
        dataStore.removeObject(forKey: AirshipLocaleManager.storeKey)
        notificationCenter.post(
            name: AirshipLocaleManager.localeUpdatedEvent,
            object: [AirshipLocaleManager.localeEventKey: self.currentLocale]
        )
    }
}
