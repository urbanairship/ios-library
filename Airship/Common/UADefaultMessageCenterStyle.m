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

#import "UADefaultMessageCenterStyle.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAColorUtils+Internal.h"
#import "UADefaultMessageCenterStyle.h"

@implementation UADefaultMessageCenterStyle

- (instancetype)init {
    self = [super init];
    if (self) {
        // Default to disabling icons
        self.iconsEnabled = NO;

        // Default to navigation bar translucency to match UIKit
        self.navigationBarOpaque = NO;
    }

    return self;
}

+ (instancetype)style {
    return [[self alloc] init];
}

+ (instancetype)styleWithContentsOfFile:(NSString *)file {
    UADefaultMessageCenterStyle *style = [UADefaultMessageCenterStyle style];
    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:@"plist"];

    if (path) {
        NSDictionary *styleDict = [[NSDictionary alloc] initWithContentsOfFile:path];
        NSDictionary *normalizedStyleDict = [UADefaultMessageCenterStyle normalizeDictionary:styleDict];

        [style setValuesForKeysWithDictionary:normalizedStyleDict];

        UA_LTRACE(@"Message Center style options: %@", [normalizedStyleDict description]);
    }

    return style;
}

// Validates and normalizes style values
+ (NSDictionary *)normalizeDictionary:(NSDictionary *)keyedValues {
    NSMutableDictionary *normalizedValues = [NSMutableDictionary dictionary];

    for (NSString *key in keyedValues) {

        id value = [keyedValues objectForKey:key];

        // Strip whitespace, if necessary
        if ([value isKindOfClass:[NSString class]]){
            value = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }

        // Validate and normalize colors
        if ([key hasSuffix:@"Color"]) {
            [normalizedValues setValue:[UADefaultMessageCenterStyle createColor:value] forKey:key];
            continue;
        }

        // Validate and normalize fonts
        if ([key hasSuffix:@"Font"]) {
            [normalizedValues setValue:[UADefaultMessageCenterStyle createFont:value] forKey:key];
            continue;
        }

        // Validate and normalize icon images
        if ([key hasSuffix:@"Icon"]) {
            [normalizedValues setValue:[UADefaultMessageCenterStyle createIcon:value] forKey:key];
            continue;
        }

        [normalizedValues setValue:value forKey:key];
    }

    return normalizedValues;
}

+(UIColor *)createColor:(NSString *)colorString {

    if (![colorString isKindOfClass:[NSString class]] || ![UAColorUtils colorWithHexString:colorString]) {
        UA_LDEBUG(@"Color must be a valid string representing a valid color hexidecimal");
        return nil;
    }

    return [UAColorUtils colorWithHexString:colorString];;
}

+(UIFont *)createFont:(NSDictionary *)fontDict {

    if (![fontDict isKindOfClass:[NSDictionary class]]) {
        UA_LDEBUG(@"Font name must be a valid string stored under the key \"fontName\".");
        return nil;
    }

    NSString *fontName = fontDict[@"fontName"];
    NSString *fontSize = fontDict[@"fontSize"];

    if (![fontName isKindOfClass:[NSString class]]) {
        UA_LDEBUG(@"Font name must be a valid string stored under the key \"fontName\".");
        return nil;
    }

    if (![fontSize isKindOfClass:[NSString class]]) {
        UA_LDEBUG(@"Font size must be a valid string stored under the key \"fontSize\".");
        return nil;
    }

    if (!([fontSize doubleValue] > 0)) {
        UA_LDEBUG(@"Font name must be a valid string representing a double greater than 0.");
        return nil;
    }

    // Ensure font exists in bundle
    if (![UIFont fontWithName:fontName size:[fontSize doubleValue]]) {
        UA_LDEBUG(@"Font must exist in app bundle.");
        return nil;
    }

    return [UIFont fontWithName:fontDict[@"fontName"]
                           size:[fontDict[@"fontSize"] doubleValue]];;
}

+(UIImage *)createIcon:(NSString *)iconString {

    if (![iconString isKindOfClass:[NSString class]] || ![UIImage imageNamed:iconString]) {
        UA_LDEBUG(@"Icon key must be a valid image name string representing an image file in the bundle.");
        return nil;
    }

    return [UIImage imageNamed:iconString];
}

#pragma mark -
#pragma KVC Overrides
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    // Be leniant and no-op for other undefined keys
    // The `super` implementation throws an exception. We'll just log.
    UA_LDEBUG(@"Ignoring invalid UAMessageCenterDefaultStyle key: %@", key);
}

@end
