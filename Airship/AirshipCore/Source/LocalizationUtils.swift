/* Copyright Airship and Contributors */

import Foundation

/// - NOTE: Internal use only :nodoc:
@objc(UALocalizationUtils)
public class LocalizationUtils : NSObject {
    
    @objc
    private static func sanitizedLocalizedString(_ localizedString: String,
                                                 withTable table: String?,
                                                 primaryBundle: Bundle,
                                                 secondaryBundle: Bundle,
                                                 tertiaryBundle: Bundle?
    ) -> String? {
        
        var string: String?
        
        /// This "empty" string has a space in it, so as not to be treated as equivalent to nil by the NSBundle method
        let missing = " "
        
        string = NSLocalizedString(localizedString, tableName: table, bundle: primaryBundle, value: missing, comment: "")
        
        if string == nil || (string == missing) {
            string = NSLocalizedString(localizedString, tableName: table, bundle: secondaryBundle, value: missing, comment: "")
        }
        
        if string == nil || (string == missing) {
            string = NSLocalizedString(localizedString, tableName: table, bundle: tertiaryBundle!, value: missing, comment: "")
        }
        
        if string == nil || (string == missing) {
            return nil
        }
        
        return string
    }
    
    @objc
    private static func localizedString(_ string:String, withTable table: String, moduleBundle: Bundle?, defaultValue: String?, fallbackLocale: String?) -> String? {
        
        let mainBundle = Bundle.main
        let coreBundle = AirshipCoreResources.bundle
        
        var string = sanitizedLocalizedString(string,
                                              withTable: table,
                                              primaryBundle: mainBundle,
                                              secondaryBundle: coreBundle,
                                              tertiaryBundle: moduleBundle)
        
        if string == "" {
            if let fallbackLocale = fallbackLocale {
                // If a fallback locale was provided, try searching in that locale explicitly
                let localizedMainBundle = Bundle(path: mainBundle.path(forResource: fallbackLocale, ofType: "lproj") ?? "")
                let localizedCoreBundle = Bundle(path: coreBundle.path(forResource: fallbackLocale, ofType: "lproj") ?? "")
                let localizedModuleBundle = Bundle(path: moduleBundle!.path(forResource: fallbackLocale, ofType: "lproj") ?? "")
                
                string = sanitizedLocalizedString(string!,
                                                  withTable: table,
                                                  primaryBundle: localizedMainBundle!,
                                                  secondaryBundle: localizedCoreBundle!,
                                                  tertiaryBundle: localizedModuleBundle!)
            }
        }
        
        /// If the bundle wasn't loaded correctly, it's possible the result value could be nil.
        /// Convert to the key as a last resort in this case.
        return string ?? defaultValue
    }
    
    /**
     * Returns a localized string associated to the receiver by the given table, returning the receiver if the
     * string cannot be found. This method searches the main bundle before falling back on AirshipCore, and
     * finally the provided module bundle, allowing for developers to override or supplement any officially bundled localizations.
     *
     * - Parameters:
     *   - string The string.
     *   - table The table.
     *   - moduleBundle The module bundle.
     *   - defaultValue The default value.
     * - Returns: The localized string corresponding to the key and table, or the default value if it cannot be found.
     */

    @objc
    public static func localizedString(_ string:String, withTable table: String, moduleBundle: Bundle?, defaultValue: String) -> String? {
        return localizedString(string, withTable: table, moduleBundle: moduleBundle, defaultValue: defaultValue, fallbackLocale: nil)
    }
    
    /**
     * Returns a localized string associated to the receiver by the given table, returning the receiver if the
     * string cannot be found. This method searches the main bundle before falling back on AirshipCore, and
     * finally the provided module bundle, allowing for developers to override or supplement any officially bundled localizations.
     *
     * - Parameters:
     *   - string The string.
     *   - table The table.
     *   - moduleBundle The module bundle.
     * - Returns: The localized string corresponding to the key and table, or the key if it cannot be found.
     */

    @objc
    public static func localizedString(_ string: String, withTable table: String, moduleBundle: Bundle?) -> String? {
        return localizedString(string, withTable: table, moduleBundle: moduleBundle, defaultValue: string)
    }
    
    /**
     * Returns a localized string associated to the receiver by the given table, falling back on the provided
     * locale and finally the receiver if the string cannot be found. This method searches the main bundle before
     * falling back on AirshipCore, and finally the the provided module bundle, allowing for developers to override
     * or supplement any officially bundled localizations.
     *
     * - Parameters:
     *   - string The string.
     *   - table The table.
     *   - moduleBundle The module bundle.
     *   - fallbackLocale The locale to use in case a localized string for the current locale cannot be found.
     * - Returns: The localized string corresponding to the key and table, or the key if it cannot be found.
     */
    @objc
    public static func localizedString(_ string:String, withTable table: String, moduleBundle: Bundle?, fallbackLocale: String?) -> String? {
        return localizedString(string, withTable: table, moduleBundle: moduleBundle, defaultValue: string, fallbackLocale: fallbackLocale)
    }
    
    /**
     * Checks if a localized string associated to the receiver exists in the given table. This method searches
     * the main bundle before falling back on AirshipCore, and finally the provided module bundle, allowing for developers
     * to override or supplement any officially bundled localizations.
     *
     * - Parameters:
     *   - string The string.
     *   - table The table.
     *   - moduleBundle The module bundle.
     * - Returns: YES if a localized string corresponding to the key and table was found, or NO if it cannot be found.
     */
    @objc
    public static func localizedStringExists(_ string:String, inTable table: String, moduleBundle: Bundle?) -> Bool {
        return localizedStringExists(string, inTable: table, moduleBundle: moduleBundle, fallbackLocale: nil)
    }
    
    /**
     * Checks if a localized string associated to the receiver exists in the given table, falling back on the provided
     * locale. This method searches the main bundle before falling back on AirshipCore, and finally the provided module bundle,
     * allowing for developers to override or supplement any officially bundled localizations.
     *
     * - Parameters:
     *   - string The string.
     *   - table The table.
     *   - moduleBundle The module bundle.
     *   - fallbackLocale The locale to use in case a localized string for the current locale cannot be found.
     * - Returns: YES if a localized string corresponding to the key and table was found, or NO if it cannot be found.
     */
    @objc
    public static func localizedStringExists(_ string:String, inTable table: String, moduleBundle: Bundle?, fallbackLocale: String?) -> Bool {
        return localizedString(string, withTable: table, moduleBundle: moduleBundle, defaultValue: nil, fallbackLocale: fallbackLocale) != nil
    }
    
}
