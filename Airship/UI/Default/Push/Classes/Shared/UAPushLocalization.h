
#import "NSString+UALocalization.h"

/**
 * Returns a localized string by key, searching the UAPushUI table and falling back on 
 * the "en" locale if necessary.
 */
#define UAPushLocalizedString(key) [NSString localizedStringWithKey:key table:@"UAPushUI" fallbackLocale:@"en"]
