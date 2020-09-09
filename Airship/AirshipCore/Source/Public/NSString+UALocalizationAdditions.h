/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@interface NSString (UALocalizationAdditions)

///---------------------------------------------------------------------------------------
/// @name NSString Localization Additions Core Methods
///---------------------------------------------------------------------------------------

/**
 * Returns a localized string associated to the receiver by the given table, returning the receiver if the
 * string cannot be found. This method searches the main bundle before falling back on AirshipCore, and
 * finally the provided module bundle, allowing for developers to override or supplement any officially bundled localizations.
 *
 * @param table The table.
 * @param moduleBundle The module bundle.
 * @param defaultValue The default value.
 * @return The localized string corresponding to the key and table, or the default value if it cannot be found.
 */
- (NSString *)localizedStringWithTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle defaultValue:(NSString *)defaultValue;

/**
 * Returns a localized string associated to the receiver by the given table, returning the receiver if the
 * string cannot be found. This method searches the main bundle before falling back on AirshipCore, and
 * finally the provided module bundle, allowing for developers to override or supplement any officially bundled localizations.
 *
 * @param table The table.
 * @param moduleBundle The module bundle.
 * @return The localized string corresponding to the key and table, or the key if it cannot be found.
 */
- (NSString *)localizedStringWithTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle;

/**
 * Returns a localized string associated to the receiver by the given table, falling back on the provided
 * locale and finally the receiver if the string cannot be found. This method searches the main bundle before
 * falling back on AirshipCore, and finally the the provided module bundle, allowing for developers to override
 * or supplement any officially bundled localizations.
 *
 * @param table The table.
 * @param moduleBundle The module bundle.
 * @param fallbackLocale The locale to use in case a localized string for the current locale cannot be found.
 * @return The localized string corresponding to the key and table, or the key if it cannot be found.
 */
- (NSString *)localizedStringWithTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle fallbackLocale:(NSString *)fallbackLocale;

/**
 * Checks if a localized string associated to the receiver exists in the given table. This method searches
 * the main bundle before falling back on AirshipCore, and finally the provided module bundle, allowing for developers
 * to override or supplement any officially bundled localizations.
 *
 * @param table The table.
 * @param moduleBundle The module bundle.
 * @return YES if a localized string corresponding to the key and table was found, or NO if it cannot be found.
 */
- (BOOL)localizedStringExistsInTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle;

/**
 * Checks if a localized string associated to the receiver exists in the given table, falling back on the provided
 * locale. This method searches the main bundle before falling back on AirshipCore, and finally the provided module bundle,
 * allowing for developers to override or supplement any officially bundled localizations.
 *
 * @param table The table.
 * @param moduleBundle The module bundle.
 * @param fallbackLocale The locale to use in case a localized string for the current locale cannot be found.
 * @return YES if a localized string corresponding to the key and table was found, or NO if it cannot be found.
 */
- (BOOL)localizedStringExistsInTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle fallbackLocale:(NSString *)fallbackLocale;

@end
