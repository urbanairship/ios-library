
#import "NSString+UALocalization.h"

/**
 * Returns a localized string by key, searching the UAInbox table and falling back on
 * the "en" locale if necessary.
 */
#define UAInboxLocalizedString(key) [NSString localizedStringWithKey:key table:@"UAInboxUI" fallbackLocale:@"en"]
