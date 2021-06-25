/* Copyright Airship and Contributors */

/**
 * Airship locale manager.
 */
@objc
public class UALocaleManager : NSObject {

    private static let storeKey = "com.urbanairship.locale.locale"

    @objc
    public static let localeUpdatedEvent = NSNotification.Name("com.urbanairship.locale.locale_updated")

    @objc
    public static let localeEventKey = "locale"

    private var dataStore: UAPreferenceDataStore
    private var notificationCenter: NotificationCenter

    /**
     * The current locale used by Airship. Defaults to `autoupdatingCurrent`.
     */
    @objc
    public var currentLocale : Locale {
        get {
            if let encodedLocale = dataStore.object(forKey: UALocaleManager.storeKey) as? Data {
                if let locale = NSKeyedUnarchiver.unarchiveObject(with: encodedLocale) as? Locale {
                    return locale
                }
            }
            return Locale.autoupdatingCurrent
        }
        set {
            let encodedLocale: Data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            dataStore.setValue(encodedLocale, forKey: UALocaleManager.storeKey)
            notificationCenter.post(name: UALocaleManager.localeUpdatedEvent, object:[UALocaleManager.localeEventKey: newValue])
        }
    }

    /**
     * @note For internal use only. :nodoc:
     */
    @objc
    public convenience init(dataStore: UAPreferenceDataStore) {
        self.init(dataStore: dataStore, notificationCenter: NotificationCenter.default)
    }

    /**
     * @note For internal use only. :nodoc:
     */ 
    @objc
    public init(dataStore: UAPreferenceDataStore, notificationCenter: NotificationCenter) {
        self.dataStore = dataStore
        self.notificationCenter = notificationCenter
        super.init()
    }

    /**
     * Resets the current locale.
     */
    @objc
    public func clearLocale() {
        dataStore.removeObject(forKey: UALocaleManager.storeKey)
        notificationCenter.post(name: UALocaleManager.localeUpdatedEvent, object:[UALocaleManager.localeEventKey: self.currentLocale])
    }
}
