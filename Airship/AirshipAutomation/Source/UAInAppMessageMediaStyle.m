/* Copyright Airship and Contributors */

#import "UAInAppMessageMediaStyle.h"
#import "UAInAppMessageUtils+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
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
