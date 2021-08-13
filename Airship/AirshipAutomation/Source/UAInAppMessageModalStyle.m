/* Copyright Airship and Contributors */

#import "UAInAppMessageModalStyle.h"
#import "UAInAppMessageUtils+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

NSString *const UAModalDismissIconResourceKey = @"dismissIconResource";
NSString *const UAModalAdditionalPaddingKey = @"additionalPadding";
NSString *const UAModalButtonStyleKey = @"buttonStyle";
NSString *const UAModalTextStyleKey = @"textStyle";
NSString *const UAModalHeaderStyleKey = @"headerStyle";
NSString *const UAModalBodyStyleKey = @"bodyStyle";
NSString *const UAModalMediaStyleKey = @"mediaStyle";
NSString *const UAModalMaxWidthKey = @"maxWidth";
NSString *const UAModalMaxHeightKey = @"maxHeight";

@implementation UAInAppMessageModalStyle

+ (instancetype)style {
    return [[self alloc] init];
}

+ (instancetype)styleWithContentsOfFile:(NSString *)file {
    UAInAppMessageModalStyle *style = [UAInAppMessageModalStyle style];
    if (!file) {
        return style;
    }

    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:@"plist"];

    if (!path) {
        return style;

    }

    NSDictionary *normalizedModalStyleDict;
    NSDictionary *modalStyleDict = [[NSDictionary alloc] initWithContentsOfFile:path];

    if (modalStyleDict) {
        normalizedModalStyleDict = [UAInAppMessageUtils normalizeStyleDictionary:modalStyleDict];

        id dismissIconResource = normalizedModalStyleDict[UAModalDismissIconResourceKey];
        if (dismissIconResource) {
            if (![dismissIconResource isKindOfClass:[NSString class]]) {
                UA_LWARN(@"Dismiss icon resource name must be a string");
                return nil;
            }
            style.dismissIconResource = dismissIconResource;
        }

        id maxWidthObj = normalizedModalStyleDict[UAModalMaxWidthKey];
        if (maxWidthObj) {
            if ([maxWidthObj isKindOfClass:[NSNumber class]]) {
                maxWidthObj = (NSNumber *)maxWidthObj;
            }
            style.maxWidth = maxWidthObj;
        }

        id maxHeightObj = normalizedModalStyleDict[UAModalMaxHeightKey];
        if (maxHeightObj) {
            if ([maxHeightObj isKindOfClass:[NSNumber class]]) {
                maxHeightObj = (NSNumber *)maxHeightObj;
            }
            style.maxHeight = maxHeightObj;
        }

        style.additionalPadding = [UAPadding paddingWithDictionary:normalizedModalStyleDict[UAModalAdditionalPaddingKey]];
        style.headerStyle = [UAInAppMessageTextStyle styleWithDictionary:normalizedModalStyleDict[UAModalHeaderStyleKey]];
        style.bodyStyle = [UAInAppMessageTextStyle styleWithDictionary:normalizedModalStyleDict[UAModalBodyStyleKey]];
        style.buttonStyle = [UAInAppMessageButtonStyle styleWithDictionary:normalizedModalStyleDict[UAModalButtonStyleKey]];;
        style.mediaStyle = [UAInAppMessageMediaStyle styleWithDictionary:normalizedModalStyleDict[UAModalMediaStyleKey]];;

        UA_LTRACE(@"In-app modal style options: %@", [normalizedModalStyleDict description]);
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

