/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

- (NSString *)localizedStringWithTable:(NSString *)table defaultValue:(NSString *)defaultValue {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSBundle *resources = [UAirship resources];

    // This "empty" string has a space in it, so as not to be treated as equivalent to nil
    // by the NSBundle method
    NSString *missing = @" ";

    NSString *string = NSLocalizedStringWithDefaultValue(self, table, mainBundle, missing, nil);

    // If the string couldn't be found in the main bundle, search AirshipResources
    if (!string || [string isEqualToString:missing]) {
        string = NSLocalizedStringWithDefaultValue(self, table, resources, defaultValue, nil);
    }

    // If the bundle wasn't loaded corectly, it's possible the result value could be nil.
    // Convert to the key as a last resort in this case.
    return string ?: defaultValue;
}

- (NSString *)localizedStringWithTable:(NSString *)table {
    return [self localizedStringWithTable:table defaultValue:self];
}

@end

