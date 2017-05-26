/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.
 
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

#import "UATagUtils+Internal.h"
#import "UAGlobal.h"

#define kUAMinTagLength 1
#define kUAMaxTagLength 127

@implementation UATagUtils

+ (NSArray *)normalizeTags:(NSArray *)tags {
    NSMutableSet *normalizedTags = [NSMutableSet set];

    for (NSString *tag in tags) {

        NSString *trimmedTag = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if ([trimmedTag length] >= kUAMinTagLength && [trimmedTag length] <= kUAMaxTagLength) {
            [normalizedTags addObject:trimmedTag];
        } else {
            UA_LERR(@"Tags must be > 0 and < 128 characters in length, tag %@ has been removed from the tag set", tag);
        }
    }

    return [normalizedTags allObjects];
}

+ (NSString *)normalizeTagGroupID:(NSString *)tagGroup {
    NSString *normalizedID = [tagGroup stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    if (!normalizedID.length) {
        UA_LERR(@"The tag group ID string cannot be nil or length must be greater 0.");
        return nil;
    }

    return normalizedID;
}
@end
