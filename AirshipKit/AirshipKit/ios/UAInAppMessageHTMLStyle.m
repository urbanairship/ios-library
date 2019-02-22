/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageHTMLStyle.h"
#import "UAirship.h"
#import "UAInAppMessageUtils+Internal.h"

NSString *const UAHTMLDismissIconResourceKey = @"dismissIconResource";
NSString *const UAHTMLAdditionalPaddingKey = @"additionalPadding";
NSString *const UAHTMLMaxWidthKey = @"maxWidth";
NSString *const UAHTMLMaxHeightKey = @"maxHeight";

@implementation UAInAppMessageHTMLStyle

+ (instancetype)style {
    return [[self alloc] init];
}

+ (instancetype)styleWithContentsOfFile:(NSString *)file {
    UAInAppMessageHTMLStyle *style = [UAInAppMessageHTMLStyle style];
    if (!file) {
        return style;
    }

    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:@"plist"];

    if (!path) {
        return style;

    }

    NSDictionary *normalizedHTMLStyleDict;
    NSDictionary *HTMLStyleDict = [[NSDictionary alloc] initWithContentsOfFile:path];

    if (HTMLStyleDict) {
        normalizedHTMLStyleDict = [UAInAppMessageUtils normalizeStyleDictionary:HTMLStyleDict];

        id dismissIconResource = normalizedHTMLStyleDict[UAHTMLDismissIconResourceKey];
        if (dismissIconResource) {
            if (![dismissIconResource isKindOfClass:[NSString class]]) {
                UA_LERR(@"Dismiss icon resource name must be a string");
                return nil;
            }
            style.dismissIconResource = dismissIconResource;
        }

        id maxWidthObj = normalizedHTMLStyleDict[UAHTMLMaxWidthKey];
        if (maxWidthObj) {
            if ([maxWidthObj isKindOfClass:[NSNumber class]]) {
                style.maxWidth = (NSNumber *)maxWidthObj;
            }
        }

        id maxHeightObj = normalizedHTMLStyleDict[UAHTMLMaxHeightKey];
        if (maxHeightObj) {
            if ([maxHeightObj isKindOfClass:[NSNumber class]]) {
                style.maxHeight = (NSNumber *)maxHeightObj;
            }
        }

        style.additionalPadding = [UAPadding paddingWithDictionary:normalizedHTMLStyleDict[UAHTMLAdditionalPaddingKey]];

        UA_LTRACE(@"In-app HTML style options: %@", [normalizedHTMLStyleDict description]);
    }

    return style;
}

#pragma mark -
#pragma KVC Overrides
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    // Be leniant and no-op for other undefined keys
    // The `super` implementation throws an exception. We'll just log.
    UA_LDEBUG(@"Ignoring invalid style key: %@", key);
}

@end

