/* Copyright Airship and Contributors */

#import "UAInAppMessageMediaStyle.h"
#import "UAInAppMessageUtils+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString *const UAMediaAddditionalPaddingKey = @"additionalPadding";

@implementation UAInAppMessageMediaStyle

- (instancetype)initWithAdditionalPadding:(nullable UAPadding *)additionalPadding {
    self = [super init];

    if (self) {
        self.additionalPadding = additionalPadding;
    }

    return self;
}

+ (instancetype)styleWithAdditionalPadding:(nullable UAPadding *)additionalPadding {
    return [[self alloc] initWithAdditionalPadding:additionalPadding];
}

+ (instancetype)styleWithDictionary:(nullable NSDictionary *)mediaStyleDict {
    UAPadding *additionalPadding;

    if (mediaStyleDict) {
        if ([mediaStyleDict isKindOfClass:[NSDictionary class]]) {
            NSDictionary *normalizedMediaStyleDict = [UAInAppMessageUtils normalizeStyleDictionary:mediaStyleDict];

            additionalPadding = [UAPadding paddingWithDictionary:(NSDictionary *)normalizedMediaStyleDict[UAMediaAddditionalPaddingKey]];
        }
    }

    return [UAInAppMessageMediaStyle styleWithAdditionalPadding:additionalPadding];
}

@end
