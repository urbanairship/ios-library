/* Copyright Urban Airship and Contributors */
#import "UAirship.h"
#import "UAInAppMessageFullScreenStyle.h"
#import "UAInAppMessageUtils+Internal.h"

NSString *const UAFullScreenDismissIconResourceKey = @"dismissIconResource";
NSString *const UAFullScreenButtonStyleKey = @"buttonStyle";
NSString *const UAFullScreenTextStyleKey = @"textStyle";
NSString *const UAFullScreenHeaderStyleKey = @"headerStyle";
NSString *const UAFullScreenBodyStyleKey = @"bodyStyle";
NSString *const UAFullScreenMediaStyleKey = @"mediaStyle";

@implementation UAInAppMessageFullScreenStyle

+ (instancetype)style {
    return [[self alloc] init];
}

+ (instancetype)styleWithContentsOfFile:(nullable NSString *)file {
    UAInAppMessageFullScreenStyle *style = [UAInAppMessageFullScreenStyle style];
    if (!file) {
        return style;
    }

    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:@"plist"];

    if (!path) {
        return style;
    }

    NSDictionary *normalizedFullScreenStyleDict;

    NSDictionary *fullScreenStyleDict = [[NSDictionary alloc] initWithContentsOfFile:path];

    if (fullScreenStyleDict) {
        normalizedFullScreenStyleDict = [UAInAppMessageUtils normalizeStyleDictionary:fullScreenStyleDict];


        id dismissIconResource = normalizedFullScreenStyleDict[UAFullScreenDismissIconResourceKey];
        if (dismissIconResource) {
            if (![dismissIconResource isKindOfClass:[NSString class]]) {
                UA_LERR(@"Dismiss icon resource name must be a string");
                return nil;
            }
            style.dismissIconResource = dismissIconResource;
        }

        style.headerStyle = [UAInAppMessageTextStyle styleWithDictionary:normalizedFullScreenStyleDict[UAFullScreenHeaderStyleKey]];
        style.bodyStyle = [UAInAppMessageTextStyle styleWithDictionary:normalizedFullScreenStyleDict[UAFullScreenBodyStyleKey]];
        style.buttonStyle = [UAInAppMessageButtonStyle styleWithDictionary:normalizedFullScreenStyleDict[UAFullScreenButtonStyleKey]];;
        style.mediaStyle = [UAInAppMessageMediaStyle styleWithDictionary:normalizedFullScreenStyleDict[UAFullScreenMediaStyleKey]];;

        UA_LTRACE(@"In-app full screen style options: %@", [normalizedFullScreenStyleDict description]);
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
