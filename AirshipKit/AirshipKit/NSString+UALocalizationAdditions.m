/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSString+UALocalizationAdditions.h"
#import "UAirship.h"

@implementation NSString (UALocalizationAdditions)

- (NSString *)sanitizedLocalizedStringWithTable:(NSString *)table primaryBundle:(NSBundle *)primaryBundle fallbackBundle:(NSBundle *)fallbackBundle {

    NSString *string;

    // This "empty" string has a space in it, so as not to be treated as equivalent to nil
    // by the NSBundle method
    NSString *missing = @" ";

    if (primaryBundle) {
        string = NSLocalizedStringWithDefaultValue(self, table, primaryBundle, missing, nil);
    }

    if (!string || [string isEqualToString:missing]) {
        if (fallbackBundle) {
            string = NSLocalizedStringWithDefaultValue(self, table, fallbackBundle, missing, nil);
        }
    }

    if (!string || [string isEqualToString:missing]) {
        return nil;
    }

    return string;
}

- (NSString *)localizedStringWithTable:(NSString *)table defaultValue:(NSString *)defaultValue fallbackLocale:(NSString *)fallbackLocale {

    NSBundle *primaryBundle = [NSBundle mainBundle];

    // If the string couldn't be found in the main bundle, search AirshipResources
    NSBundle *fallbackBundle = [UAirship resources];

    NSString *string = [self sanitizedLocalizedStringWithTable:table primaryBundle:primaryBundle fallbackBundle:fallbackBundle];
    if (!string) {
        if (fallbackLocale) {
            // If a fallback locale was provided, try searching in that locale explicitly
            primaryBundle = [NSBundle bundleWithPath:[primaryBundle pathForResource:fallbackLocale ofType:@"lproj"]];
            fallbackBundle = [NSBundle bundleWithPath:[fallbackBundle pathForResource:fallbackLocale ofType:@"lproj"]];

            string = [self sanitizedLocalizedStringWithTable:table primaryBundle:primaryBundle fallbackBundle:fallbackBundle];
        }
    }

    // If the bundle wasn't loaded correctly, it's possible the result value could be nil.
    // Convert to the key as a last resort in this case.
    return string ?: defaultValue;
}

- (NSString *)localizedStringWithTable:(NSString *)table defaultValue:(NSString *)defaultValue {
    return [self localizedStringWithTable:table defaultValue:defaultValue fallbackLocale:nil];
}

- (NSString *)localizedStringWithTable:(NSString *)table {
    return [self localizedStringWithTable:table defaultValue:self];
}

- (NSString *)localizedStringWithTable:(NSString *)table fallbackLocale:(NSString *)fallbackLocale {
    return [self localizedStringWithTable:table defaultValue:self fallbackLocale:fallbackLocale];
}


@end

