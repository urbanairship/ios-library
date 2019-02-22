/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageBannerStyle.h"
#import "UAirship.h"
#import "UAInAppMessageUtils+Internal.h"

NSString *const UABannerAdditionalPaddingKey = @"additionalPadding";
NSString *const UABannerTextStyleKey = @"textStyle";
NSString *const UABannerHeaderStyleKey = @"headerStyle";
NSString *const UABannerBodyStyleKey = @"bodyStyle";
NSString *const UABannerMediaStyleKey = @"mediaStyle";
NSString *const UABannerButtonStyleKey = @"buttonStyle";
NSString *const UABannerMaxWidthKey = @"maxWidth";

@implementation UAInAppMessageBannerStyle

+ (instancetype)style {
    return [[self alloc] init];
}

+ (instancetype)styleWithContentsOfFile:(NSString *)file {
    UAInAppMessageBannerStyle *style = [UAInAppMessageBannerStyle style];

    if (!file) {
        return style;
    }

    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:@"plist"];

    if (!path) {
        return style;

    }

    NSDictionary *normalizedBannerStyleDict;

    NSDictionary *bannerStyleDict = [[NSDictionary alloc] initWithContentsOfFile:path];

    if (bannerStyleDict) {
        normalizedBannerStyleDict = [UAInAppMessageUtils normalizeStyleDictionary:bannerStyleDict];

        id maxWidthObj = normalizedBannerStyleDict[UABannerMaxWidthKey];
        if (maxWidthObj) {
            if ([maxWidthObj isKindOfClass:[NSNumber class]]) {
                maxWidthObj = (NSNumber *)maxWidthObj;
            }
            style.maxWidth = maxWidthObj;
        }

        style.additionalPadding = [UAPadding paddingWithDictionary:normalizedBannerStyleDict[UABannerAdditionalPaddingKey]];
        style.headerStyle = [UAInAppMessageTextStyle styleWithDictionary:normalizedBannerStyleDict[UABannerHeaderStyleKey]];
        style.bodyStyle = [UAInAppMessageTextStyle styleWithDictionary:normalizedBannerStyleDict[UABannerBodyStyleKey]];
        style.buttonStyle = [UAInAppMessageButtonStyle styleWithDictionary:normalizedBannerStyleDict[UABannerButtonStyleKey]];
        style.mediaStyle = [UAInAppMessageMediaStyle styleWithDictionary:normalizedBannerStyleDict[UABannerMediaStyleKey]];;

        UA_LTRACE(@"In-app banner style options: %@", [normalizedBannerStyleDict description]);
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

