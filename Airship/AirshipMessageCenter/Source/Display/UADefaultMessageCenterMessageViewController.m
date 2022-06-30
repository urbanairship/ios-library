/* Copyright Airship and Contributors */

#import <WebKit/WebKit.h>

#import "UADefaultMessageCenterMessageViewController.h"
#import "UAMessageCenterNativeBridgeExtension.h"
#import "UAMessageCenter.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessage.h"
#import "UAInboxUtils.h"
#import "UAMessageCenterLocalization.h"
#import "UAUser+Internal.h"
#import "UAMessageCenter.h"
#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

static NSString *UAMessageCenterMessageViewControllerAboutBlank = @"about:blank";

NSString * const UAMessageCenterMessageLoadErrorDomain = @"com.urbanairship.message_center.message_load";
NSString * const UAMessageCenterMessageLoadErrorHTTPStatusKey = @"status";

NS_ASSUME_NONNULL_BEGIN

@interface UADefaultMessageCenterMessageViewController () <UANativeBridgeDelegate, UANavigationDelegate>

/**
 * The WebView used to display the message content.
 */
@property (nonatomic, strong) IBOutlet WKWebView *webView;

/**
 * The custom loading indicator container view.
 */
@property (nonatomic, strong) IBOutlet UIView *loadingIndicatorContainerView;

/**
 * The optional custom loading indicator view.
 */
@property (nullable, nonatomic, strong) UIView *loadingIndicatorView;

/**
 * The optional custom animation to execute during loading.
 */
@property (nullable, nonatomic, strong) void (^loadingAnimations)(void);

/**
 * The view displayed when there are no messages.
 */
@property (nonatomic, weak) IBOutlet UIView *coverView;

/**
 * The label displayed in the coverView.
 */
@property (nonatomic, weak) IBOutlet UILabel *coverLabel;

/**
 * Boolean indicating whether or not the view is visible
 */
@property (nonatomic, assign) BOOL isVisible;

/**
 * The UAInboxMessage being displayed.
 */
@property (nonatomic, strong, nullable) UAInboxMessage *message;

/**
 * State of message waiting to load, loading, loaded or currently displayed.
 */
typedef enum MessageState {
    NONE,
    FETCHING,
    TO_LOAD,
    LOADING,
    LOADED
} MessageState;

@property (nonatomic, assign) MessageState messageState;
@property (nonatomic, strong) UANativeBridge *nativeBridge;
@property (nonatomic, strong) UAMessageCenterNativeBridgeExtension *nativeBridgeExtension;

@end

@implementation UADefaultMessageCenterMessageViewController

@synthesize message = _message;

- (id)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.messageState = NONE;
    }
    return self;
}

- (void)dealloc {
    self.message = nil;
    self.webView.navigationDelegate = nil;
    self.webView.UIDelegate = nil;
    [self.webView stopLoading];
}


- (void)setDisableMessageLinkPreviewAndCallouts:(BOOL)disableMessageLinkPreviewAndCallouts {
    _disableMessageLinkPreviewAndCallouts = disableMessageLinkPreviewAndCallouts;
    self.webView.allowsLinkPreview = disableMessageLinkPreviewAndCallouts;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.webView.scrollView setZoomScale:0 animated:YES];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.nativeBridge = [[UANativeBridge alloc] init];
    self.nativeBridgeExtension = [[UAMessageCenterNativeBridgeExtension alloc] init];

    self.nativeBridge.nativeBridgeExtensionDelegate = self.nativeBridgeExtension;
    self.nativeBridge.nativeBridgeDelegate = self;
    self.nativeBridge.forwardNavigationDelegate = self;

    self.webView.navigationDelegate = self.nativeBridge;
    self.webView.allowsLinkPreview = !self.disableMessageLinkPreviewAndCallouts;

    // Allow the webView to detect data types (e.g. phone numbers, addresses) at will
    [self.webView.configuration setDataDetectorTypes:WKDataDetectorTypeAll];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_delete_message")
                                                                               style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(delete:)];
    self.navigationItem.rightBarButtonItem.accessibilityHint = UAMessageCenterLocalizedString(@"ua_delete_message_description");

    // load message or cover view if no message waiting to load
    switch (self.messageState) {
        case NONE:
            [self clearMessage];
            break;
        case FETCHING:
            [self hideMessageWithLoadingIndicator];
            break;
        case TO_LOAD:
            [self loadMessage:self.message];
            break;
        default:
            UA_LWARN(@"MessageState = %u. Should be \"NONE\", \"FETCHING\", or \"TO_LOAD\"",self.messageState);
            break;
    }
    
    self.isVisible = NO;
    
    //Add an observer when the user changes the preferred content size setting.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contentSizeDidChange) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Add the custom loading view if it's been set
    if (self.loadingIndicatorView) {
        // Add custom loading indicator view and constrain it to the center
        [self.loadingIndicatorContainerView addSubview:self.loadingIndicatorView];
        [UAViewUtils applyContainerConstraintsToContainer:self.loadingIndicatorContainerView containedView:self.loadingIndicatorView];
    } else {
        // Generate default loading view
        UABeveledLoadingIndicator *defaultLoadingIndicatorView = [[UABeveledLoadingIndicator alloc] init];

        self.loadingIndicatorView = defaultLoadingIndicatorView;

        // Add default loading indicator view and constrain it to the center
        [self.loadingIndicatorContainerView addSubview:self.loadingIndicatorView];
        [UAViewUtils applyContainerConstraintsToContainer:self.loadingIndicatorContainerView containedView:self.loadingIndicatorView];
    }
    
    if (self.messageState == NONE) {
        [self clearMessage];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    self.isVisible = YES;

    if (self.messageState == LOADED) {
        [self showMessage];
    }

    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.isVisible = NO;
}

#pragma mark -
#pragma mark UI

- (void)delete:(nullable id)sender {
    if (self.messageState != LOADED) {
        UA_LWARN(@"MessageState = %u. Should be \"LOADED\"",self.messageState);
    }
    if (self.message) {
        self.messageState = NONE;
        [[UAMessageCenter shared].messageList markMessagesDeleted:@[self.message] completionHandler:nil];
    }
}

- (void)clearMessage {
    [self hideLoadingIndicator];
    [self coverWithText:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
}

- (void)hideMessageWithLoadingIndicator {
    [self coverWithText:nil];
    [self showLoadingIndicator];
}

- (void)showMessage {
    self.coverView.hidden = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [self hideLoadingIndicator];
}

- (void)coverWithText:(nullable NSString *)text {
    self.title = nil;
    self.coverLabel.text = text;
    self.coverView.hidden = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)setLoadingIndicatorView:(UIView *)loadingIndicatorView animations:(void (^)(void))animations {
    self.loadingAnimations = animations;
    self.loadingIndicatorView = loadingIndicatorView;
}

- (void)showLoadingIndicator {
    if (self.loadingAnimations) {
        self.loadingAnimations();
    }

    [self.loadingIndicatorContainerView setHidden:NO];
}

- (void)hideLoadingIndicator {
    [self.loadingIndicatorContainerView setHidden:YES];
}

- (void)loadMessageForID:(nullable NSString *)messageID {
    if (!messageID) {
        [self clearMessage];
        return;
    }
    
    UAInboxMessage *message = [[UAMessageCenter shared].messageList messageForID:messageID];

    if (message) {
        if (message.isExpired) {
           NSString *msg = [NSString stringWithFormat:@"Message is expired: %@", message];
            NSError *error =  [NSError errorWithDomain:UAMessageCenterMessageLoadErrorDomain
                                      code:UAMessageCenterMessageLoadErrorCodeMessageExpired
                                  userInfo:@{NSLocalizedDescriptionKey:msg}];

            [self.delegate messageLoadFailed:messageID error:error];
            return;
        }
        [self loadMessage:message];
        return;
    }

    // start by covering the view and showing the loading indicator
    [self hideMessageWithLoadingIndicator];

    // Refresh the list to see if the message is available in the cloud
    self.messageState = FETCHING;

    UA_WEAKIFY(self);

    [[UAMessageCenter shared].messageList retrieveMessageListWithSuccessBlock:^{
        [UADispatcher.main dispatchAsync:^{
            UA_STRONGIFY(self)

            UAInboxMessage *message = [[UAMessageCenter shared].messageList messageForID:messageID];
            if (message && !message.isExpired) {
                // display the message
                [self loadMessage:message];
            } else {
                // if the message no longer exists, clean up and show an error dialog
                [self hideLoadingIndicator];
                self.messageState = NONE;

                NSString *msg = [NSString stringWithFormat:@"Message is expired: %@", message];
                NSError *error =  [NSError errorWithDomain:UAMessageCenterMessageLoadErrorDomain
                                              code:UAMessageCenterMessageLoadErrorCodeMessageExpired
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];

                [self.delegate messageLoadFailed:messageID error:error];
            }

            return;
        }];
    } withFailureBlock:^{
        [UADispatcher.main dispatchAsync:^{
            UA_STRONGIFY(self);
            
            [self hideLoadingIndicator];

            NSString *msg = [NSString stringWithFormat:@"Remote message list unavailable"];
            NSError *error =  [NSError errorWithDomain:UAMessageCenterMessageLoadErrorDomain
                                          code:UAMessageCenterMessageLoadErrorCodeMessageExpired
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];

            [self.delegate messageLoadFailed:messageID error:error];
        }];
        
        return;
    }];
}

- (void)loadMessage:(nullable UAInboxMessage *)message {
    if (!message) {
        if (self.messageState == LOADING) {
            [self.webView stopLoading];
        }

        self.messageState = NONE;
        self.message = message;

        [self clearMessage];

        return;
    }

    self.message = message;

    if (!self.webView) {
        self.messageState = TO_LOAD;
    } else {
        if (self.messageState == LOADING) {
            [self.webView stopLoading];
        }
        self.messageState = LOADING;

        // start by covering the view and showing the loading indicator
        [self hideMessageWithLoadingIndicator];

        // now load a blank page, so when the view is uncovered, it isn't still showing the previous web page
        // note: when the blank page has finished loading, it will load the message
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:UAMessageCenterMessageViewControllerAboutBlank]]];
    }
}

- (void)loadMessageIntoWebView {
    self.title = self.message.title;
    
    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:self.message.messageBodyURL];
    requestObj.timeoutInterval = 60;

    UA_WEAKIFY(self)
    [[UAMessageCenter shared].user getUserData:^(UAUserData *userData) {
        UA_STRONGIFY(self)
        NSString *auth = [UAInboxUtils userAuthHeaderString:userData];
        [requestObj setValue:auth forHTTPHeaderField:@"Authorization"];
        [self.webView loadRequest:requestObj];
    } dispatcher:UADispatcher.main];
}

- (void) contentSizeDidChange {
    // Reload the web view when the user changes the preferred content size setting.
    [self.webView reload];
}

#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)wv decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if (self.messageState != LOADING) {
        UA_LWARN(@"MessageState = %u. Should be \"LOADING\"",self.messageState);
    }

    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)navigationResponse.response;
        NSInteger status = httpResponse.statusCode;
        if (status >= 400 && status <= 599) {
            decisionHandler(WKNavigationResponsePolicyCancel);

            NSString *msg = [NSString stringWithFormat:@"Message load resulted in failure status: %lu", status];
            NSError *error =  [NSError errorWithDomain:UAMessageCenterMessageLoadErrorDomain
                                          code:UAMessageCenterMessageLoadErrorCodeFailureStatus
                                              userInfo:@{NSLocalizedDescriptionKey:msg,
                                                         UAMessageCenterMessageLoadErrorHTTPStatusKey:@(status)}];

            [self.delegate messageLoadFailed:self.message.messageID error:error];
            return;
        }
    }
    
    decisionHandler(WKNavigationResponsePolicyAllow);

}

- (void)webView:(WKWebView *)wv didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    if (self.messageState != LOADING) {
        UA_LWARN(@"MessageState = %u. Should be \"LOADING\"",self.messageState);
    }

    if (!self.disableMessageLinkPreviewAndCallouts) {
        [self.webView evaluateJavaScript:@"document.body.style.webkitTouchCallout='none';" completionHandler:nil];
    }
    
    if ([wv.URL.absoluteString isEqualToString:UAMessageCenterMessageViewControllerAboutBlank]) {
        [self loadMessageIntoWebView];
        return;
    }
    
    self.messageState = LOADED;
 
    // Mark message as read after it has finished loading
    if (self.message.unread) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }

    [self.delegate messageLoadSucceeded:self.message.messageID];
    
    [self showMessage];
}

- (void)webView:(WKWebView *)wv didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    if (self.messageState != LOADING) {
        UA_LWARN(@"MessageState = %u. Should be \"LOADING\"",self.messageState);
    }
    if (error.code == NSURLErrorCancelled) {
        return;
    }

    UA_LDEBUG(@"Failed to load message: %@", error);
    
    self.messageState = NONE;

    [self hideLoadingIndicator];

    [self.delegate messageLoadFailed:self.message.messageID error:error];
    self.message = nil;
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    [self webView:webView didFailNavigation:navigation withError:error];
}

#pragma mark UANativeBridgeDelegate

- (void)close {
    [self.delegate messageClosed:self.message.messageID];
}

@end

NS_ASSUME_NONNULL_END
