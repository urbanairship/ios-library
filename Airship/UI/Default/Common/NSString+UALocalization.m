
#import "NSString+UALocalization.h"

@implementation NSString (UALocalization)

+ (NSString *)localizedStringWithKey:(NSString *)key
                               table:(NSString *)table
                      fallbackLocale:(NSString *)fallbackLocale {

    // This empty string has a space in it, so as not to be treated as equivalent to nil
    // by the NSBundle method
    NSString *missing = @" ";

    NSString *string = [[NSBundle mainBundle] localizedStringForKey:key value:missing table:table];

    // If a localized string can't be found for the desired language, fall back to "en"
    if ([string isEqualToString:missing]) {
        NSString *fallbackPath = [[NSBundle mainBundle] pathForResource:fallbackLocale ofType:@"lproj"];
        string = [[NSBundle bundleWithPath:fallbackPath] localizedStringForKey:key value:key table:table];
    }

    // If there is not result for "en", return the key as a last resort, instead of nil
    return string ?: key;
}

@end
