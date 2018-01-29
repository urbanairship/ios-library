/* Copyright 2018 Urban Airship and Contributors */

#import "UAInAppMessageHTMLController+Internal.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAInAppMessageCloseButton+Internal.h"
#import "UAInAppMessageHTMLView+Internal.h"
#import "UAWebView+Internal.h"
#import "UAWKWebViewNativeBridge.h"
#import "UAGlobal.h"
#import "UAInAppMessageResolution.h"
#import "UABeveledLoadingIndicator.h"

NS_ASSUME_NONNULL_BEGIN

double const UAInAppMessageDefaultHTMLAnimationDuration = 0.2;

@interface UAInAppMessageHTMLController () <UAWKWebViewDelegate>

/**
* The message identifier.
*/
@property (nonatomic, strong) NSString *messageID;

/**
 * Flag indicating the display state of the message.
 */
@property (nonatomic, assign) BOOL isShowing;

/**
 * The message's display content.
 */
@property (nonatomic, strong) UAInAppMessageHTMLDisplayContent *displayContent;

/**
 * The HTML message view. Contains a close button and a webview.
 */
@property (nonatomic, strong) UAInAppMessageHTMLView *htmlView;

/**
 * Vertical constraint is used to vertically position the message.
 */
@property (nonatomic, strong) NSLayoutConstraint *verticalConstraint;

/**
 * The native bridge.
 */
@property (nonatomic, strong) UAWKWebViewNativeBridge *nativeBridge;

/**
 * The completion handler passed in when the message is shown.
 */
@property (nonatomic, copy, nullable) void (^showCompletionHandler)(UAInAppMessageResolution *);

@end

@implementation UAInAppMessageHTMLController

+ (instancetype)htmlControllerWithHTMLMessageID:(NSString *)identifier
                                 displayContent:(UAInAppMessageHTMLDisplayContent *)displayContent {

    return [[self alloc] initWithHTMLMessageID:identifier displayContent:displayContent];
}

- (instancetype)initWithHTMLMessageID:(NSString *)messageID
                       displayContent:(UAInAppMessageHTMLDisplayContent *)displayContent {

    self = [super init];

    if (self) {
        self.messageID = messageID;
        self.displayContent = displayContent;

        self.nativeBridge = [[UAWKWebViewNativeBridge alloc] init];
        self.nativeBridge.forwardDelegate = self;
    }

    return self;
}

- (UAInAppMessageCloseButton * _Nullable)createCloseButton {
    UAInAppMessageCloseButton *closeButton = [[UAInAppMessageCloseButton alloc] init];
    closeButton.dismissButtonColor = self.displayContent.dismissButtonColor;
    [closeButton addTarget:self
                    action:@selector(buttonTapped:)
          forControlEvents:UIControlEventTouchUpInside];

    return closeButton;
}

- (void)addInitialConstraintsToParentView:(UIView *)parentView
                                 htmlView:(UAInAppMessageHTMLView *)htmlView {

    self.verticalConstraint = [NSLayoutConstraint constraintWithItem:htmlView
                                                           attribute:NSLayoutAttributeBottom
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:parentView
                                                           attribute:NSLayoutAttributeBottom
                                                          multiplier:1
                                                            constant:htmlView.bounds.size.height];

    self.verticalConstraint.active = YES;

    // Center on X axis
    [NSLayoutConstraint constraintWithItem:htmlView
                                 attribute:NSLayoutAttributeCenterX
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeCenterX
                                multiplier:1
                                  constant:0].active = YES;

    // Set width
    [NSLayoutConstraint constraintWithItem:htmlView
                                 attribute:NSLayoutAttributeWidth
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeWidth
                                multiplier:1
                                  constant:0].active = YES;

    // Set height
    [NSLayoutConstraint constraintWithItem:htmlView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeHeight
                                multiplier:1
                                  constant:0].active = YES;

    [parentView layoutIfNeeded];
    [htmlView layoutIfNeeded];
}

- (void)htmlView:(UAInAppMessageHTMLView *)htmlView animateInWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    self.verticalConstraint.constant = 0;

    // Set Height
    [NSLayoutConstraint constraintWithItem:htmlView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeHeight
                                multiplier:1
                                  constant:0].active = YES;

    [UIView animateWithDuration:UAInAppMessageDefaultHTMLAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        [parentView layoutIfNeeded];
        [htmlView layoutIfNeeded];
    } completion:^(BOOL finished) {
        completionHandler();
    }];
}

- (void)htmlView:(UAInAppMessageHTMLView *)htmlView animateOutWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    self.verticalConstraint.constant = htmlView.bounds.size.height;

    [UIView animateWithDuration:UAInAppMessageDefaultHTMLAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        [parentView layoutIfNeeded];
        [htmlView layoutIfNeeded];
    } completion:^(BOOL finished){
        completionHandler();
    }];
}

- (void)createViews:(UIView *)parentView {
    UAInAppMessageCloseButton *closeButton = [self createCloseButton];

    self.htmlView = [UAInAppMessageHTMLView htmlViewWithDisplayContent:self.displayContent
                                                           closeButton:closeButton];

    self.htmlView.webView.navigationDelegate = self.nativeBridge;

    if (@available(iOS 10.0, tvOS 10.0, *)) {
        [self.htmlView.webView.configuration setDataDetectorTypes:WKDataDetectorTypeNone];
    }

    [parentView addSubview:self.htmlView];
    [self addInitialConstraintsToParentView:parentView htmlView:self.htmlView];
}

- (void)showWithParentView:(UIView *)parentView completionHandler:(void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    self.showCompletionHandler = completionHandler;

    [self createViews:parentView];

    [self load];

    [self htmlView:self.htmlView animateInWithParentView:parentView completionHandler:^{
        self.isShowing = YES;
    }];
}

- (void)dismissWithResolution:(UAInAppMessageResolution *)resolution  {
    if (self.showCompletionHandler) {
        self.showCompletionHandler(resolution);
        self.showCompletionHandler = nil;
    }

    [self beginTeardown];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self htmlView:self.htmlView animateOutWithParentView:self.htmlView.superview completionHandler:^{
            [self finishTeardown];
            self.isShowing = NO;
        }];
    });
}

- (void)buttonTapped:(id)sender {
    // Check for close button
    if ([sender isKindOfClass:[UAInAppMessageCloseButton class]]) {
        [self dismissWithResolution:[UAInAppMessageResolution userDismissedResolution]];
    }
}

- (void)showOverlay {
    [self.htmlView.loadingIndicator show];
}

- (void)hideOverlay {
    [self.htmlView.loadingIndicator hide];
}

- (void)load {
    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.displayContent.url]];
    [requestObj setTimeoutInterval:30];

    [self.htmlView.webView stopLoading];
    [self.htmlView.webView loadRequest:requestObj];
    [self showOverlay];
}

#pragma mark UAWKWebViewDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    [self hideOverlay];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(nonnull NSError *)error {

    UA_WEAKIFY(self);

    // Wait twenty seconds, try again if necessary
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        UA_STRONGIFY(self)
        if (self) {
            UA_LINFO(@"Retrying url: %@", self.displayContent.url);
            [self load];
        }
    });
}

#pragma mark -
#pragma mark Teardown

/**
 * Releases all resources. This method can be safely called
 * in dealloc as a protection against unexpected early release.
 */
- (void)teardown {
    [self beginTeardown];
    [self finishTeardown];
}

/**
 * Prepares the message view for dismissal by disabling interaction
 * and releasing resources that can be disposed of prior to starting the dismissal animation.
 */
- (void)beginTeardown {
    self.htmlView.userInteractionEnabled = NO;
}

/**
 * Finalizes dismissal by removing the message view from its
 * parent, and releasing the reference to self
 */
- (void)finishTeardown {
    [self.htmlView removeFromSuperview];
    self.htmlView.webView.navigationDelegate = nil;
}

- (void)dealloc {
    [self teardown];
}

@end

NS_ASSUME_NONNULL_END
