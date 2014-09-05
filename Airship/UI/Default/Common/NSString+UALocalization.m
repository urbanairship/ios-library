
#import "NSString+UALocalization.h"

@implementation NSString (UALocalization)

+ (NSString *)localizedStringWithKey:(NSString *)key
                               table:(NSString *)table
                      fallbackLocale:(NSString *)fallbackLocale {

    NSString *string = [[NSBundle mainBundle] localizedStringForKey:key value:nil table:table];

    if ([string isEqualToString:key]) {
        NSString *fallbackPath = [[NSBundle mainBundle] pathForResource:fallbackLocale ofType:@"lproj"];
        string = [[NSBundle bundleWithPath:fallbackPath] localizedStringForKey:key value:key table:table];
    }

    return string ?: key;
}

@end
