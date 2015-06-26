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

#import "UATagUtils.h"
#import "UAGlobal.h"
#import "UAUtils.h"

#define kUAMinTagLength 1
#define kUAMaxTagLength 127

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
        NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
        NSString *countryCode = [locale objectForKey: NSLocaleCountryCode];
        
        //Prefix the tag with "country_" to avoid collisions w/ language
        [tags addObject:[NSString stringWithFormat:@"country_%@", countryCode]];
    }
    
    if (tagFlags & UATagTypeLanguage) {
        // Get user's language code based on currentLocale
        NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
        NSString *languageCode = [locale objectForKey: NSLocaleLanguageCode];
        
        //Prefix the tag with "language_" to avoid collisions w/ country
        [tags addObject:[NSString stringWithFormat:@"language_%@",languageCode]];
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

+ (NSArray *)normalizeTags:(NSArray *)tags {
    NSMutableArray *normalizedTags = [NSMutableArray array];

    for (NSString *tag in tags) {

        NSString *trimmedTag = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if ([trimmedTag length] >= kUAMinTagLength && [trimmedTag length] <= kUAMaxTagLength) {
            [normalizedTags addObject:trimmedTag];
        } else {
            UA_LERR(@"Tags must be > 0 and < 128 characters in length, tag %@ has been removed from the tag set", tag);
        }
    }

    return [NSArray arrayWithArray:normalizedTags];
}

+ (BOOL)isValid:(NSArray *)tags group:(NSString *)tagGroup {
    BOOL retVal = YES;

    if (!tags.count) {
        UA_LERR(@"The tags array cannot be empty.");
        retVal = NO;
    }

    NSString *trimmedTagGroup = [tagGroup stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    if (!trimmedTagGroup.length) {
        UA_LERR(@"The tag group ID string cannot be nil or length must be greater 0.");
        retVal = NO;
    }
    return retVal;
}

+ (NSDictionary *)addPendingTags:(NSArray *)tagsToAdd group:(NSString *)tagGroup pendingTagsDictionary:(NSDictionary *)pendingTags {
    NSMutableDictionary *combinedTags = [NSMutableDictionary dictionaryWithDictionary:pendingTags];
    NSMutableSet *addTagsSet = [NSMutableSet setWithArray:combinedTags[tagGroup]];
    [addTagsSet addObjectsFromArray:tagsToAdd];
    if (addTagsSet.count) {
        combinedTags[tagGroup] = [addTagsSet allObjects];
    } else {
        [combinedTags removeObjectForKey:tagGroup];
    }
    return [NSDictionary dictionaryWithDictionary:combinedTags];
}

+ (NSDictionary *)removePendingTags:(NSArray *)tagsToRemove group:(NSString *)tagGroup pendingTagsDictionary:(NSDictionary *)pendingTags {
    NSMutableDictionary *combinedTags = [NSMutableDictionary dictionaryWithDictionary:pendingTags];
    NSMutableArray *removeTagsArray = [NSMutableArray arrayWithArray:combinedTags[tagGroup]];
    [removeTagsArray removeObjectsInArray:tagsToRemove];
    if (removeTagsArray.count) {
        combinedTags[tagGroup] = removeTagsArray;
    } else {
        [combinedTags removeObjectForKey:tagGroup];
    }
    return [NSDictionary dictionaryWithDictionary:combinedTags];
}

@end
