/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageTextStyle.h"
#import "UAirship.h"
#import "UAInAppMessageUtils+Internal.h"

@implementation UAInAppMessageTextStyle

NSString *const UATextAdditonalPaddingKey = @"additionalPadding";
NSString *const UALetterSpacingKey = @"letterSpacing";
NSString *const UALineSpacingKey = @"lineSpacing";

- (instancetype)initWithAdditionalPadding:(nullable UAPadding *)additionalPadding
                            letterSpacing:(nullable NSNumber *)letterSpacing
                              lineSpacing:(nullable NSNumber *)lineSpacing {
    self = [super init];

    if (self) {
        self.additionalPadding = additionalPadding;
        self.letterSpacing = letterSpacing;
        self.lineSpacing = lineSpacing;
    }

    return self;
}

+ (instancetype)styleWithAdditionalPadding:(nullable UAPadding *)additionalPadding
                             letterSpacing:(nullable NSNumber *)letterSpacing
                               lineSpacing:(nullable NSNumber *)lineSpacing {

    return [[self alloc] initWithAdditionalPadding:additionalPadding letterSpacing:letterSpacing lineSpacing:lineSpacing];
}

+ (instancetype)styleWithDictionary:(nullable NSDictionary *)textStyle {
    NSNumber *letterSpacing;
    NSNumber *lineSpacing;
    UAPadding *additionalPadding;

    if (textStyle) {
        if ([textStyle isKindOfClass:[NSDictionary class]]) {
            NSDictionary *normalizedTextStyleDict = [UAInAppMessageUtils normalizeStyleDictionary:textStyle];

            // Parse padding
            additionalPadding = [UAPadding paddingWithDictionary:(NSDictionary *)normalizedTextStyleDict[UATextAdditonalPaddingKey]];

            // Parse letter spacing
            id letterSpacingObj = normalizedTextStyleDict[UALetterSpacingKey];
            if (letterSpacingObj) {
                if ([letterSpacingObj isKindOfClass:[NSNumber class]]) {
                    letterSpacing = (NSNumber *)letterSpacingObj;
                }
            }

            // Parse line spacing
            id lineSpacingObj = normalizedTextStyleDict[UALineSpacingKey];
            if (lineSpacingObj) {
                if ([lineSpacingObj isKindOfClass:[NSNumber class]]) {
                    lineSpacing = (NSNumber *)lineSpacingObj;
                }
            }
        }
    }

    // Default style is an empty UAInAppMessageTextStyle
    return [UAInAppMessageTextStyle styleWithAdditionalPadding:additionalPadding
                                                 letterSpacing:letterSpacing
                                                   lineSpacing:lineSpacing];
}

@end

