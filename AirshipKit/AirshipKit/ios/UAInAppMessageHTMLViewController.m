/* Copyright 2018 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageHTMLViewController+Internal.h"
#import "UABeveledLoadingIndicator.h"
#import "UAWebView+Internal.h"
#import "UAInAppMessageHTMLDisplayContent.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageResolution.h"
#import "UAViewUtils+Internal.h"
#import "UAWKWebViewNativeBridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageHTMLViewController () <UAWKWebViewDelegate>

/**
 * The container view.
 */
@property (strong, nonatomic) IBOutlet UIView *containerView;

/**
 * The HTML web view.
 */
@property (strong, nonatomic) IBOutlet UAWebView *webView;

/**
 * The HTML message view loading indicator.
 */
@property (strong, nonatomic) IBOutlet UABeveledLoadingIndicator *loadingIndicator;

/**
 * View to hold close (dismiss) button at top of modal message
 */
@property (weak, nonatomic) IBOutlet UIView *closeButtonContainerView;

/**
 * The native bridge.
 */
@property (nonatomic, strong) UAWKWebViewNativeBridge *nativeBridge;

/**
 * Close button.
 */
@property (strong, nonatomic) UAInAppMessageDismissButton *closeButton;

/**
 * The identifier of the HTML message.
 */
@property (nonatomic, strong) NSString *messageID;

@end

@implementation UAInAppMessageHTMLViewController

+ (instancetype)htmlControllerWithMessageID:(NSString *)messageID
                             displayContent:(UAInAppMessageHTMLDisplayContent *)displayContent
                                      style:(UAInAppMessageHTMLStyle *)style {
    return [[self alloc] initWithHTMLMessageID:messageID displayContent:displayContent style:style];
}

- (instancetype)initWithHTMLMessageID:(NSString *)messageID displayContent:(UAInAppMessageHTMLDisplayContent *)displayContent style:(UAInAppMessageHTMLStyle *)style {
    self = [self initWithNibName:@"UAInAppMessageHTMLViewController" bundle:[UAirship resources]];

    if (self) {
        self.messageID = messageID;
        self.displayContent = displayContent;

        self.style = style;

        self.closeButton = [self createCloseButton];
        self.nativeBridge = [[UAWKWebViewNativeBridge alloc] init];
        self.nativeBridge.forwardDelegate = self;
    }

    return self;
}

- (nullable UAInAppMessageDismissButton *)createCloseButton {
    UAInAppMessageDismissButton *closeButton = [UAInAppMessageDismissButton closeButtonWithIconImageName:self.style.dismissIconResource
                                                                                                   color:self.displayContent.dismissButtonColor];
    [closeButton addTarget:self
                    action:@selector(buttonTapped:)
          forControlEvents:UIControlEventTouchUpInside];

    return closeButton;
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self load];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.webView.navigationDelegate = self.nativeBridge;

    self.closeButton.dismissButtonColor = self.displayContent.dismissButtonColor;
    [self.closeButtonContainerView addSubview:self.closeButton];
    [UAViewUtils applyContainerConstraintsToContainer:self.closeButtonContainerView containedView:self.closeButton];

    if (@available(iOS 10.0, tvOS 10.0, *)) {
        [self.webView.configuration setDataDetectorTypes:WKDataDetectorTypeNone];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.webView.scrollView setZoomScale:0 animated:YES];
    });
}

- (void)showOverlay {
    [self.loadingIndicator show];
}

- (void)hideOverlay {
    [self.loadingIndicator hide];
}

- (void)load {
    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.displayContent.url]];
    [requestObj setTimeoutInterval:30];

    [self.webView stopLoading];
    [self.webView loadRequest:requestObj];
    [self showOverlay];
}

- (void)buttonTapped:(id)sender {
    // Check for close button
    if ([sender isKindOfClass:[UAInAppMessageDismissButton class]]) {
        [self dismissWithResolution:[UAInAppMessageResolution userDismissedResolution]];
        return;
    }
}

- (void)dismissWithResolution:(UAInAppMessageResolution *)resolution  {
    [self.resizableParent dismissWithResolution:resolution];
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

- (void)closeWindowAnimated:(BOOL)animated {
    [self dismissWithResolution:[UAInAppMessageResolution userDismissedResolution]];
}

@end

NS_ASSUME_NONNULL_END
