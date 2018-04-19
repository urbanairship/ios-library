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
    self.messageTop.backgroundColor = displayContent.backgroundColor;
    
    self.displayContent = displayContent;
    self.translatesAutoresizingMaskIntoConstraints = NO;
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
