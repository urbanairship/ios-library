/* Copyright Airship and Contributors */


@objc(LocaleManagerProtocol)
public protocol LocaleManagerProtocol {
    /**
     * Resets the current locale.
     */
    @objc
    func clearLocale()
    
    /**
     * The current locale used by Airship. Defaults to `autoupdatingCurrent`.
     */
    @objc
    var currentLocale : Locale { get }

    
}
/**
 * Airship locale manager.
 */
@objc(UALocaleManager)
public class LocaleManager : NSObject, LocaleManagerProtocol {

    private static let storeKey = "com.urbanairship.locale.locale"

    @objc
    public static let localeUpdatedEvent = NSNotification.Name("com.urbanairship.locale.locale_updated")

    @objc
    public static let localeEventKey = "locale"

    private var dataStore: PreferenceDataStore
    private var notificationCenter: NotificationCenter

    /**
     * The current locale used by Airship. Defaults to `autoupdatingCurrent`.
     */
    @objc
    public var currentLocale : Locale {
        get {
            if let encodedLocale = dataStore.object(forKey: LocaleManager.storeKey) as? Data {
                if let locale = NSKeyedUnarchiver.unarchiveObject(with: encodedLocale) as? Locale {
                    return locale
                }
            }
            return Locale.autoupdatingCurrent
        }
        set {
            let encodedLocale: Data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            dataStore.setValue(encodedLocale, forKey: LocaleManager.storeKey)
            notificationCenter.post(name: LocaleManager.localeUpdatedEvent, object:[LocaleManager.localeEventKey: newValue])
        }
    }

    /**
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public convenience init(dataStore: PreferenceDataStore) {
        self.init(dataStore: dataStore, notificationCenter: NotificationCenter.default)
    }

    /**
     * - Note: For internal use only. :nodoc:
     */ 
    @objc
    public init(dataStore: PreferenceDataStore, notificationCenter: NotificationCenter) {
        self.dataStore = dataStore
        self.notificationCenter = notificationCenter
        super.init()
    }

    /**
     * Resets the current locale.
     */
    @objc
    public func clearLocale() {
        dataStore.removeObject(forKey: LocaleManager.storeKey)
        notificationCenter.post(name: LocaleManager.localeUpdatedEvent, object:[LocaleManager.localeEventKey: self.currentLocale])
    }
}
