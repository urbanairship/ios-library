/* Copyright Airship and Contributors */

#import "NSString+UALocalizationAdditions.h"
#import "UAirship.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@implementation NSString (UALocalizationAdditions)

- (nullable NSString *)sanitizedLocalizedStringWithTable:(NSString *)table
                                           primaryBundle:(NSBundle *)primaryBundle
                                         secondaryBundle:(NSBundle *)secondaryBundle
                                          tertiaryBundle:(NSBundle *)tertiaryBundle {

    NSString *string;

    // This "empty" string has a space in it, so as not to be treated as equivalent to nil
    // by the NSBundle method
    NSString *missing = @" ";

    string = NSLocalizedStringWithDefaultValue(self, table, primaryBundle, missing, nil);

    if (!string || [string isEqualToString:missing]) {
        string = NSLocalizedStringWithDefaultValue(self, table, secondaryBundle, missing, nil);
    }

    if (!string || [string isEqualToString:missing]) {
        string = NSLocalizedStringWithDefaultValue(self, table, tertiaryBundle, missing, nil);
    }

    if (!string || [string isEqualToString:missing]) {
        return nil;
    }

    return string;
}

- (NSString *)localizedStringWithTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle defaultValue:(NSString *)defaultValue fallbackLocale:(NSString *)fallbackLocale {

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSBundle *coreBundle = [UAirshipCoreResources bundle];

    NSString *string = [self sanitizedLocalizedStringWithTable:table
                                                 primaryBundle:mainBundle
                                               secondaryBundle:coreBundle
                                                tertiaryBundle:moduleBundle];

    if (!string) {
        if (fallbackLocale) {
            // If a fallback locale was provided, try searching in that locale explicitly
            NSBundle *localizedMainBundle = [NSBundle bundleWithPath:[mainBundle pathForResource:fallbackLocale ofType:@"lproj"]];
            NSBundle *localizedCoreBundle = [NSBundle bundleWithPath:[coreBundle pathForResource:fallbackLocale ofType:@"lproj"]];
            NSBundle *localizedModuleBundle = [NSBundle bundleWithPath:[moduleBundle pathForResource:fallbackLocale ofType:@"lproj"]];

            string = [self sanitizedLocalizedStringWithTable:table
                                               primaryBundle:localizedMainBundle
                                             secondaryBundle:localizedCoreBundle
                                              tertiaryBundle:localizedModuleBundle];
        }
    }

    // If the bundle wasn't loaded correctly, it's possible the result value could be nil.
    // Convert to the key as a last resort in this case.
    return string ?: defaultValue;
}

- (NSString *)localizedStringWithTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle defaultValue:(NSString *)defaultValue {
    return [self localizedStringWithTable:table moduleBundle:moduleBundle defaultValue:defaultValue fallbackLocale:nil];
}

- (NSString *)localizedStringWithTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle {
    return [self localizedStringWithTable:table moduleBundle:moduleBundle defaultValue:self];
}

- (NSString *)localizedStringWithTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle fallbackLocale:(NSString *)fallbackLocale {
    return [self localizedStringWithTable:table moduleBundle:moduleBundle defaultValue:self fallbackLocale:fallbackLocale];
}

- (BOOL)localizedStringExistsInTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle {
    return ([self localizedStringExistsInTable:table moduleBundle:moduleBundle fallbackLocale:nil]);
}

- (BOOL)localizedStringExistsInTable:(NSString *)table moduleBundle:(NSBundle *)moduleBundle fallbackLocale:(NSString *)fallbackLocale {
    return ([self localizedStringWithTable:table moduleBundle:moduleBundle defaultValue:nil fallbackLocale:fallbackLocale] != nil);
}

@end

