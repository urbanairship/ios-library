/* Copyright Airship and Contributors */

#import "UAInAppMessageHTMLViewController+Internal.h"
#import "UAInAppMessageHTMLDisplayContent.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageResolution+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppNativeBridgeDismissCommand = @"dismiss";

@interface UAInAppMessageHTMLViewController () <WKNavigationDelegate, UANativeBridgeDelegate, UAJavaScriptCommandDelegate>

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
@property (nonatomic, strong) UANativeBridge *nativeBridge;

/*
 * Close button.
 */
@property (strong, nonatomic) UAInAppMessageDismissButton *closeButton;

/**
 * The identifier of the HTML message.
 */
@property (nonatomic, copy) NSString *messageID;

/**
 * The request headers. These are populated and used when displaying an inbox message.
 */
@property (nonatomic, copy) NSDictionary *headers;

@end


@implementation UAInAppMessageHTMLViewController

+ (instancetype)htmlControllerWithMessageID:(NSString *)messageID
                             displayContent:(UAInAppMessageHTMLDisplayContent *)displayContent
                                      style:(UAInAppMessageHTMLStyle *)style {
    return [[self alloc] initWithHTMLMessageID:messageID displayContent:displayContent style:style];
}

- (instancetype)initWithHTMLMessageID:(NSString *)messageID displayContent:(UAInAppMessageHTMLDisplayContent *)displayContent style:(UAInAppMessageHTMLStyle *)style {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    self = [self initWithNibName:@"UAInAppMessageHTMLViewController" bundle:bundle];

    if (self) {
        self.messageID = messageID;
        self.displayContent = displayContent;

        self.style = style;

        if (!self.style.hideDismissIcon) {
            self.closeButton = [self createCloseButton];
        }
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

    self.nativeBridge = [UANativeBridge nativeBridge];
    self.nativeBridge.forwardNavigationDelegate = self;
    self.nativeBridge.javaScriptCommandDelegate = self;
    self.nativeBridge.nativeBridgeDelegate = self;
    self.webView.navigationDelegate = self.nativeBridge;

    if (self.style.hideDismissIcon) {
        [self.closeButtonContainerView setHidden:YES];
    } else {
        self.closeButton.dismissButtonColor = self.displayContent.dismissButtonColor;
        [self.closeButtonContainerView addSubview:self.closeButton];
    }

    [UAViewUtils applyContainerConstraintsToContainer:self.closeButtonContainerView containedView:self.closeButton];
    [self.webView.configuration setDataDetectorTypes:WKDataDetectorTypeNone];
    
    ////Add an observer when the user changes the preferred content size setting.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contentSizeDidChange) name:UIContentSizeCategoryDidChangeNotification object:nil];
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
    [self loadRequestWithDefaultTimeoutInterval:requestObj];
}

- (void)loadRequestWithDefaultTimeoutInterval:(NSMutableURLRequest *)request {
    [request setTimeoutInterval:30];

    [self.webView stopLoading];
    [self.webView loadRequest:request];
    [self showOverlay];
}

- (void)buttonTapped:(id)sender {
    // Check for close button
    if ([sender isKindOfClass:[UAInAppMessageDismissButton class]]) {
        [self dismissWithResolution:[UAInAppMessageResolution userDismissedResolution]];
        return;
    }
}

- (void)dismissWithoutResolution  {
    [self.resizableParent dismissWithoutResolution];
}

- (void)dismissWithResolution:(UAInAppMessageResolution *)resolution  {
    [self.resizableParent dismissWithResolution:resolution];
}

- (void) contentSizeDidChange {
    // Reload the web view when the user changes the preferred content size setting.
    [self.webView reload];
}

#pragma mark UAJavaScriptCommandDelegate

- (BOOL)performCommand:(UAJavaScriptCommand *)command webView:(WKWebView *)webView {
    if (![command.name isEqualToString:UAInAppNativeBridgeDismissCommand]) {
        return NO;
    }

    id args = [command.arguments firstObject];

    // allow the reading of fragments so we can parse lower level JSON values
    id jsonDecodedArgs = [NSJSONSerialization objectWithString:args
                                                       options:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments];
    if (!jsonDecodedArgs) {
        UA_LERR(@"Unable to json decode resolution: %@", args);
    } else {
        UA_LDEBUG(@"Decoded resolution value: %@", jsonDecodedArgs);
        NSError *error;
        UAInAppMessageResolution *resolution = [UAInAppMessageResolution resolutionWithJSON:jsonDecodedArgs error:&error];
        if (resolution) {
            [self dismissWithResolution:resolution];
        } else {
            UA_LERR(@"Unable to decode resolution: %@, error: %@", jsonDecodedArgs, error);
        }
    }

    return YES;
}

#pragma mark WKNavigationDelegate

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

#pragma mark UANativeBridgeDelegate

- (void)close {
    [self dismissWithResolution:[UAInAppMessageResolution userDismissedResolution]];
}

@end

NS_ASSUME_NONNULL_END
