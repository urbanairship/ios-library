/* Copyright 2018 Urban Airship and Contributors */

#import "UAInAppMessageHTMLView+Internal.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageHTMLDisplayContent.h"
#import "UAirship.h"
#import "UAWebView+Internal.h"
#import "UABeveledLoadingIndicator.h"
#import "UAUtils+Internal.h"

NSString *const UAInAppMessageHTMLViewNibName = @"UAInAppMessageHTMLView";

/**
 * Default view padding
 */
CGFloat const HTMLDefaultPadding = 24.0;

/**
 * Hand tuned value that removes excess vertical safe area to make the
 * top padding look more consistent with the iPhone X nub
 */
CGFloat const HTMLExcessiveSafeAreaPadding = -8;

@interface UAInAppMessageHTMLView ()

@property (strong, nonatomic) IBOutlet UAInAppMessageDismissButton *closeButtonContainer;
@property (strong, nonatomic) IBOutlet UIView *wrapperView;
@property (strong, nonatomic) IBOutlet UAWebView *webView;
@property (strong, nonatomic) IBOutlet UABeveledLoadingIndicator *loadingIndicator;
@property (strong, nonatomic) UAInAppMessageHTMLDisplayContent *displayContent;

@end

@implementation UAInAppMessageHTMLView

+ (instancetype)htmlViewWithDisplayContent:(UAInAppMessageHTMLDisplayContent *)displayContent closeButton:(UIButton *)closeButton {
    NSString *nibName = UAInAppMessageHTMLViewNibName;
    NSBundle *bundle = [UAirship resources];
    
    UAInAppMessageHTMLView *view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];
    [view configureWithDisplayContent:displayContent closeButton:closeButton];
    
    return view;
}

- (void)configureWithDisplayContent:(UAInAppMessageHTMLDisplayContent *)displayContent closeButton:(UIButton *)closeButton {
    // Always add the close button
    [self.closeButtonContainer addSubview:closeButton];
    
    [UAInAppMessageUtils applyContainerConstraintsToContainer:self.closeButtonContainer containedView:closeButton];
    
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.opaque = NO;
    
    if (@available(iOS 10.0, tvOS 10.0, *)) {
        [self.webView.configuration setDataDetectorTypes:WKDataDetectorTypeNone];
    }
    
    self.backgroundColor = displayContent.backgroundColor;
    self.webView.backgroundColor = displayContent.backgroundColor;

    self.displayContent = displayContent;
    self.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [self refreshViewForCurrentOrientation];
}

- (void)refreshViewForCurrentOrientation {
    BOOL statusBarShowing = !([UIApplication sharedApplication].isStatusBarHidden);

    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow;

        // Black out the inset and compensate for excess vertical safe area when iPhone X is horizontal
        if (window.safeAreaInsets.top == 0 && window.safeAreaInsets.left > 0) {
            self.backgroundColor = [UIColor blackColor];
        } else if (window.safeAreaInsets.top > 0 && window.safeAreaInsets.left == 0) {
            self.backgroundColor = self.displayContent.backgroundColor;
        }

        // If the orientation has a bar without inset
        if (window.safeAreaInsets.top == 0 && statusBarShowing) {
            [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                   onView:self.wrapperView
                                                  padding:HTMLDefaultPadding
                                                  replace:YES];
            [self.wrapperView layoutIfNeeded];
            return;
        }

        // If the orientation has a bar with inset
        if (window.safeAreaInsets.top > 0 && statusBarShowing) {
            [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                   onView:self.wrapperView
                                                  padding:HTMLExcessiveSafeAreaPadding
                                                  replace:YES];
            [self.wrapperView layoutIfNeeded];
            return;
        }
    } else {
        if (statusBarShowing) {
            [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                   onView:self.wrapperView
                                                  padding:HTMLDefaultPadding
                                                  replace:YES];
            [self.wrapperView layoutIfNeeded];
            return;
        }
    }

    // Otherwise remove top padding
    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                           onView:self.wrapperView
                                          padding:0
                                          replace:YES];

    [self.wrapperView layoutIfNeeded];
}


@end
