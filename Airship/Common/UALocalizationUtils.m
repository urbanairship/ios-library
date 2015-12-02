
#import "UALocalizationUtils.h"
#import "UAirship.h"

@implementation UALocalizationUtils

+ (NSString *)localizedStringForKey:(NSString *)key table:(NSString *)table defaultValue:(NSString *)defaultValue {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSBundle *resources = [UAirship resources];

    // This "empty" string has a space in it, so as not to be treated as equivalent to nil
    // by the NSBundle method
    NSString *missing = @" ";

    NSString *string = NSLocalizedStringWithDefaultValue(key, table, mainBundle, missing, nil);

    // If the string couldn't be found in the main bundle, search AirshipResources
    if (!string || [string isEqualToString:missing]) {
        string = NSLocalizedStringWithDefaultValue(key, table, resources, defaultValue, nil);
    }

    // If the bundle wasn't loaded corectly, it's possible the result value could be nil.
    // Convert to the key as a last resort in this case.
    return string ?: defaultValue;
}

+ (NSString *)localizedStringForKey:(NSString *)key table:(NSString *)table {
    return [self localizedStringForKey:key table:table defaultValue:key];
}

@end
