/* Copyright Airship and Contributors */

#import "UAInAppMessageHTMLStyle.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString *const UAHTMLDismissIconResourceKey = @"dismissIconResource";
NSString *const UAHTMLAdditionalPaddingKey = @"additionalPadding";
NSString *const UAHTMLMaxWidthKey = @"maxWidth";
NSString *const UAHTMLMaxHeightKey = @"maxHeight";
NSString *const UAHTMLHideDismissIconKey = @"hideDismissIcon";
NSString *const UAHTMLExtendFullScreenLargeDeviceKey = @"extendFullscreenLargeDevices";


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

        id hideDismissIconObj = normalizedHTMLStyleDict[UAHTMLHideDismissIconKey];
        if (hideDismissIconObj) {
            if ([hideDismissIconObj isKindOfClass:[NSNumber class]]) {
                style.hideDismissIcon = [hideDismissIconObj boolValue];
            }
        }

        style.additionalPadding = [UAPadding paddingWithDictionary:normalizedHTMLStyleDict[UAHTMLAdditionalPaddingKey]];

        id extendFullScreenLargeDeviceObj = normalizedHTMLStyleDict[UAHTMLExtendFullScreenLargeDeviceKey];
        if (extendFullScreenLargeDeviceObj) {
            if ([extendFullScreenLargeDeviceObj isKindOfClass:[NSNumber class]]) {
                style.extendFullScreenLargeDevice = [extendFullScreenLargeDeviceObj boolValue];
            }
        }
        
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

