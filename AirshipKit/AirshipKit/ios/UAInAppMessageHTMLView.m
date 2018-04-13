/* Copyright 2018 Urban Airship and Contributors */

#import "UAInAppMessageHTMLView+Internal.h"
#import "UAInAppMessageCloseButton+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageHTMLDisplayContent.h"
#import "UAirship.h"
#import "UAWebView+Internal.h"
#import "UABeveledLoadingIndicator.h"
#import "UAUtils+Internal.h"

NSString *const UAInAppMessageHTMLViewNibName = @"UAInAppMessageHTMLView";

@interface UAInAppMessageHTMLView ()

@property (strong, nonatomic) IBOutlet UAInAppMessageCloseButton *closeButtonContainer;
@property (strong, nonatomic) IBOutlet UIView *messageTop;
@property (strong, nonatomic) IBOutlet UAWebView *webView;
@property (strong, nonatomic) IBOutlet UABeveledLoadingIndicator *loadingIndicator;
@property (strong, nonatomic) UAInAppMessageHTMLDisplayContent *displayContent;

@end

@implementation UAInAppMessageHTMLView

+ (instancetype)htmlViewWithDisplayContent:(UAInAppMessageHTMLDisplayContent *)displayContent closeButton:(UIButton *)closeButton {
    NSString *nibName = UAInAppMessageHTMLViewNibName;
    NSBundle *bundle = [UAirship resources];

    UAInAppMessageHTMLView *view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];

    if (view) {
        // Always add the close button
        [view.closeButtonContainer addSubview:closeButton];

        [UAInAppMessageUtils applyContainerConstraintsToContainer:view.closeButtonContainer containedView:closeButton];

        view.webView.backgroundColor = [UIColor clearColor];
        view.webView.opaque = NO;

        if (@available(iOS 10.0, tvOS 10.0, *)) {
            [view.webView.configuration setDataDetectorTypes:WKDataDetectorTypeNone];
        }

        view.backgroundColor = displayContent.backgroundColor;
        view.webView.backgroundColor = displayContent.backgroundColor;
        view.messageTop.backgroundColor = displayContent.backgroundColor;

        view.displayContent = displayContent;
        view.translatesAutoresizingMaskIntoConstraints = NO;
    }

    return view;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UAUtils mainWindow];

        // Black out the inset when iPhone X is horizontal
        if (window.safeAreaInsets.top == 0 && window.safeAreaInsets.left > 0) {
            self.backgroundColor = [UIColor blackColor];
        } else {
            self.backgroundColor = self.displayContent.backgroundColor;
        }
    }
}

@end
