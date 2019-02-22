/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageButtonStyle.h"
#import "UAInAppMessageUtils+Internal.h"

@implementation UAInAppMessageButtonStyle

NSString *const UAButtonAdditionalPaddingKey = @"additionalPadding";
NSString *const UAButtonTextStyleKey = @"buttonTextStyle";
NSString *const UAButtonHeightKey = @"buttonHeight";
NSString *const UAStackedButtonSpacingKey = @"stackedButtonSpacing";
NSString *const UASeparatedButtonSpacingKey = @"separatedButtonSpacing";
NSString *const UABorderWidthKey = @"borderWidth";

- (instancetype)initWithAdditionalPadding:(nullable UAPadding *)additionalPadding
                          buttonTextStyle:(nullable UAInAppMessageTextStyle *)buttonTextStyle
                             buttonHeight:(nullable NSNumber *)buttonHeight
                     stackedButtonSpacing:(nullable NSNumber *)stackedButtonSpacing
                   separatedButtonSpacing:(nullable NSNumber *)separatedButtonSpacing
                              borderWidth:(nullable NSNumber *)borderWidth {
    self = [super init];

    if (self) {
        self.additionalPadding = additionalPadding;
        self.buttonTextStyle = buttonTextStyle;
        self.buttonHeight = buttonHeight;
        self.stackedButtonSpacing = stackedButtonSpacing;
        self.separatedButtonSpacing = separatedButtonSpacing;
        self.borderWidth = borderWidth;
    }

    return self;
}

+ (instancetype)styleWithAdditionalPadding:(nullable UAPadding *)additionalPadding
                           buttonTextStyle:(nullable UAInAppMessageTextStyle *)buttonTextStyle
                              buttonHeight:(nullable NSNumber *)buttonHeight
                      stackedButtonSpacing:(nullable NSNumber *)stackedButtonSpacing
                    separatedButtonSpacing:(nullable NSNumber *)separatedButtonSpacing
                               borderWidth:(nullable NSNumber *)borderWidth {
    return [[self alloc] initWithAdditionalPadding:additionalPadding
                                   buttonTextStyle:buttonTextStyle
                                      buttonHeight:buttonHeight
                              stackedButtonSpacing:stackedButtonSpacing
                            separatedButtonSpacing:separatedButtonSpacing
                                       borderWidth:borderWidth];
}

+ (instancetype)styleWithDictionary:(nullable NSDictionary *)buttonStyle {
    UAInAppMessageTextStyle *buttonTextStyle;
    NSNumber *buttonHeight;
    NSNumber *stackedButtonSpacing;
    NSNumber *separatedButtonSpacing;
    NSNumber *borderWidth;
    UAPadding *additionalPadding;

    if (buttonStyle) {
        if ([buttonStyle isKindOfClass:[NSDictionary class]]) {
            NSDictionary *normalizedTextStyleDict = [UAInAppMessageUtils normalizeStyleDictionary:buttonStyle];

            // Parse padding
            additionalPadding = [UAPadding paddingWithDictionary:(NSDictionary *)normalizedTextStyleDict[UAButtonAdditionalPaddingKey]];

            // Parse button text style
            buttonTextStyle = [UAInAppMessageTextStyle styleWithDictionary:(NSDictionary *)normalizedTextStyleDict[UAButtonTextStyleKey]];

            // Parse button height
            id buttonHeightObj = normalizedTextStyleDict[UAButtonHeightKey];
            if (buttonHeightObj) {
                if ([buttonHeightObj isKindOfClass:[NSNumber class]]) {
                    buttonHeight = (NSNumber *)buttonHeightObj;
                }
            }

            // Parse stacked button spacing
            id stackedButtonSpacingObj = normalizedTextStyleDict[UAStackedButtonSpacingKey];
            if (stackedButtonSpacingObj) {
                if ([stackedButtonSpacingObj isKindOfClass:[NSNumber class]]) {
                    stackedButtonSpacing = (NSNumber *)stackedButtonSpacingObj;
                }
            }

            // Parse separated button spacing
            id separatedButtonSpacingObj = normalizedTextStyleDict[UASeparatedButtonSpacingKey];
            if (separatedButtonSpacingObj) {
                if ([separatedButtonSpacingObj isKindOfClass:[NSNumber class]]) {
                    separatedButtonSpacing = (NSNumber *)separatedButtonSpacingObj;
                }
            }

            // Parse border width
            id borderWidthObj = normalizedTextStyleDict[UABorderWidthKey];
            if (borderWidthObj) {
                if ([borderWidthObj isKindOfClass:[NSNumber class]]) {
                    borderWidth = (NSNumber *)borderWidthObj;
                }
            }
        }
    }

    return [UAInAppMessageButtonStyle styleWithAdditionalPadding:additionalPadding
                                                 buttonTextStyle:buttonTextStyle
                                                    buttonHeight:buttonHeight
                                            stackedButtonSpacing:stackedButtonSpacing
                                          separatedButtonSpacing:separatedButtonSpacing
                                                     borderWidth:borderWidth];
}


@end

