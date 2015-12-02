
#import <Foundation/Foundation.h>

@interface UALocalizationUtils : NSObject

/**
 * Returns a localized string for the associated key and table, returning the provided default value if the
 * string cannot be found. This method searches the main bundle before falling back on AirshipResources,
 * allowing for developers to override or supplement any officially bundled localizations.
 *
 * @param key The key.
 * @param table The table.
 * @param defaultValue The default value.
 * @return The localized string corresponding ot the key and table, or the default value if it cannot be found.
 */
+ (NSString *)localizedStringForKey:(NSString *)key table:(NSString *)table defaultValue:(NSString *)defaultValue;

/**
 * Returns a localized string for the associated key and table, returning the key if the
 * string cannot be found. This method searches the main bundle before falling back on AirshipResources,
 * allowing for developers to override or supplement any officially bundled localizations.
 *
 * @param key The key.
 * @param table The table.
 * @return The localized string corresponding ot the key and table, or the key if it cannot be found.
 */
+ (NSString *)localizedStringForKey:(NSString *)key table:(NSString *)table;

@end
