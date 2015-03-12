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
