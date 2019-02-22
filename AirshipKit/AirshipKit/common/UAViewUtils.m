/* Copyright Urban Airship and Contributors */

#import "UAGlobal.h"
#import "UAViewUtils+Internal.h"


@implementation UAViewUtils

+ (void)applyContainerConstraintsToContainer:(UIView *)container containedView:(UIView *)contained {
    if (!container || !contained) {
        UA_LDEBUG(@"Attempted to constrain a nil view");
        return;
    }

    // This is a side effect, but these should be set to NO by default when using autolayout
    container.translatesAutoresizingMaskIntoConstraints = NO;
    contained.translatesAutoresizingMaskIntoConstraints = NO;

    NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:contained
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:container
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0f
                                                                      constant:0.0f];

    // The container and contained are reversed here to allow positive constant increases to result in expected padding
    NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:container
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:contained
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0f
                                                                         constant:0.0f];

    // The container and contained are reversed here to allow positive constant increases to result in expected padding
    NSLayoutConstraint *trailingConstraint = [NSLayoutConstraint constraintWithItem:container
                                                                          attribute:NSLayoutAttributeTrailing
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:contained
                                                                          attribute:NSLayoutAttributeTrailing
                                                                         multiplier:1.0f
                                                                           constant:0.0f];

    NSLayoutConstraint *leadingConstraint = [NSLayoutConstraint constraintWithItem:contained
                                                                         attribute:NSLayoutAttributeLeading
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:container
                                                                         attribute:NSLayoutAttributeLeading
                                                                        multiplier:1.0f
                                                                          constant:0.0f];

    topConstraint.active = true;
    bottomConstraint.active = true;
    trailingConstraint.active = true;
    leadingConstraint.active = true;
}

@end

