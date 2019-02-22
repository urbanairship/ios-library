/* Copyright Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAViewUtils+Internal.h"


NS_ASSUME_NONNULL_BEGIN

@implementation UAInAppMessageTextView

+ (nullable instancetype)textViewWithTextInfo:(nullable UAInAppMessageTextInfo *)textInfo style:(nullable UAInAppMessageTextStyle *)style {
    return [[self alloc] initWithTextInfo:textInfo style:style];
}

- (nullable instancetype)initWithTextInfo:(nullable UAInAppMessageTextInfo *)textInfo style:(nullable UAInAppMessageTextStyle *)style {
    self = [super init];

    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        if (textInfo) {
            self.textInfo = textInfo;
            self.textLabel = [[UILabel alloc] init];
            self.style = style;

            [self addSubview:self.textLabel];
            [UAViewUtils applyContainerConstraintsToContainer:self
                                                        containedView:self.textLabel];

            self.textLabel.translatesAutoresizingMaskIntoConstraints = NO;
            [self.textLabel setContentHuggingPriority:UILayoutPriorityRequired
                                              forAxis:UILayoutConstraintAxisVertical];
            // High but still breakable by parent max height
            [self.textLabel setContentCompressionResistancePriority:999
                                                            forAxis:UILayoutConstraintAxisVertical];

            // Apply text info and style
            [UAInAppMessageUtils applyTextInfo:textInfo style:style label:self.textLabel];

            // Add the text label style padding
            [UAInAppMessageUtils applyPaddingToView:self.textLabel padding:style.additionalPadding replace:NO];
        }
    }

    if (!self.textLabel) {
        return nil;
    }

    return self;
}

@end

NS_ASSUME_NONNULL_END
