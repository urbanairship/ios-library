/* Copyright 2018 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageTextViewNibName = @"UAInAppMessageTextView";

/*
 * Default padding between parent and top of the text view when the
 * text view is on top of the IAM view stack
 */
CGFloat const TopPadding = 24.0;

/*
* Instead of padding the body on the right to avoid the close button
* it is given extra top padding
*/
CGFloat const AdditionalBodyPadding = 16.0;

/*
 * Width of the close button is used to properly pad heading text when
 * it is at the top of a IAM view stack
 */
CGFloat const CloseButtonViewWidth = 46.0;

@interface UAInAppMessageTextView ()

@property (strong, nonatomic) UILabel *headingLabel;
@property (strong, nonatomic) UILabel *bodyLabel;

@property (strong, nonatomic) IBOutlet UIStackView *textContainer;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *textContainerToTop;

// Top padding from the topmost text to the parent top
@property (assign, nonatomic) CGFloat topPadding;


@end

@implementation UAInAppMessageTextView

+ (nullable instancetype)textViewWithHeading:(UAInAppMessageTextInfo * _Nullable)heading
                               body:(UAInAppMessageTextInfo * _Nullable)body {
    return [UAInAppMessageTextView textViewWithHeading:heading body:body onTop:NO];
}

+ (nullable instancetype)textViewWithHeading:(UAInAppMessageTextInfo * _Nullable)heading body:(UAInAppMessageTextInfo * _Nullable)body onTop:(BOOL)onTop {
    if (!heading && !body) {
        return nil;
    }
    
    NSString *nibName = UAInAppMessageTextViewNibName;
    NSBundle *bundle = [UAirship resources];
    
    UAInAppMessageTextView *view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];
    
    [view configureWithHeading:heading body:body onTop:onTop];
    
    return view;
}

- (void)configureWithHeading:(UAInAppMessageTextInfo * _Nullable)heading body:(UAInAppMessageTextInfo * _Nullable)body onTop:(BOOL)onTop {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    if (heading) {
        UIView *closeButtonPaddedHeading;
        UILabel *headingLabel = [[UILabel alloc] init];
        headingLabel.translatesAutoresizingMaskIntoConstraints = NO;
        
        self.headingLabel = headingLabel;
        [self.headingLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        
        [UAInAppMessageUtils applyTextInfo:heading label:headingLabel];
        
        if (onTop) {
            // Add horizontal padding to the header
            closeButtonPaddedHeading = [self viewWithCloseButtonPadding:headingLabel];
            // Add padding to top
            self.textContainerToTop.constant = TopPadding;
            [self layoutIfNeeded];
        }
        
        [self.textContainer addArrangedSubview:closeButtonPaddedHeading ?: headingLabel];
    }
    
    if (body) {
        UILabel *bodyLabel = [[UILabel alloc] init];
        bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.bodyLabel = bodyLabel;
        [self.bodyLabel setContentHuggingPriority:UILayoutPriorityRequired
                                          forAxis:UILayoutConstraintAxisVertical];
        
        [UAInAppMessageUtils applyTextInfo:body label:bodyLabel];
        
        if (onTop && !heading) {
            // Add padding with additional body padding to top
            self.textContainerToTop.constant = TopPadding + AdditionalBodyPadding;
            [self layoutIfNeeded];
        }
        
        [self.textContainer addArrangedSubview:bodyLabel];
    }
    
    [UIView performWithoutAnimation:^{
        [self.textContainer layoutIfNeeded];
    }];
}

// Takes a text view, returns a compound view with top bar and close button padding
- (UIView *)viewWithCloseButtonPadding:(UIView *)view {
    // Horizontal stack for close button padding
    UIStackView *horizontalStack = [[UIStackView alloc] init];
    horizontalStack.axis = UILayoutConstraintAxisHorizontal;

    UIView *closeButtonPaddingView = [[UIView alloc] init];
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:closeButtonPaddingView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:CloseButtonViewWidth];
    widthConstraint.active = YES;

    [horizontalStack addArrangedSubview:view];
    [horizontalStack addArrangedSubview:closeButtonPaddingView];

    return horizontalStack;
}

@end

NS_ASSUME_NONNULL_END
