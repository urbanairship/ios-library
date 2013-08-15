/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
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

#import "UATagUtils.h"
#import "UAGlobal.h"
#import "UAUtils.h"

@implementation UATagUtils

+ (NSArray *)createTags:(UATagType) tagFlags {
    
    NSMutableArray *tags = [[NSMutableArray alloc] init];
    
    // Full time zone - geopolitical descriptor
    if (tagFlags & UATagTypeTimeZone) {
        [tags addObject:[[NSTimeZone localTimeZone] name]];
    }
    
    // Abbreviated time zone - WARNING: this will contain daylight
    // savings time info
    if (tagFlags & UATagTypeTimeZoneAbbreviation) {
        [tags addObject:[[NSTimeZone localTimeZone] abbreviation]];
    }
    
    if (tagFlags & UATagTypeCountry) {
        // Get user's country code based on currentLocale
        NSLocale *locale = [NSLocale currentLocale];
        NSString *countryCode = [locale objectForKey: NSLocaleCountryCode];
        
        //Prefix the tag with "country_" to avoid collisions w/ language
        //[tags addObject:countryCode];
        [tags addObject:[NSString stringWithFormat:@"country_%@", countryCode]];
        //UALOG(@"%@",[locale displayNameForKey:NSLocaleCountryCode value:countryCode]);
    }
    
    if (tagFlags & UATagTypeLanguage) {
        // Get user's language code based on currentLocale
        NSLocale *locale = [NSLocale currentLocale];
        NSString *languageCode = [locale objectForKey: NSLocaleLanguageCode];
        
        //Prefix the tag with "language_" to avoid collisions w/ country
        //[tags addObject:languageCode];
        [tags addObject:[NSString stringWithFormat:@"language_%@",languageCode]];
        //UALOG(@"%@",[locale displayNameForKey:NSLocaleLanguageCode value:languageCode]);
    }
    
    if (tagFlags & UATagTypeDeviceType) {
        NSString *deviceModel = [UAUtils deviceModelName];
        
        if ([deviceModel hasPrefix:@"iPad"]) {
            [tags addObject:@"iPad"];
        } else if ([deviceModel hasPrefix:@"iPod"]) {
            [tags addObject:@"iPod"];
        } else {
            [tags addObject:@"iPhone"];
        }

    }
    
    UALOG(@"Created Tags: %@", [tags description]);
    
    return tags;
}

@end
