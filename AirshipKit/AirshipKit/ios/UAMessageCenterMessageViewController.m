/* Copyright Urban Airship and Contributors */

#import "UAMessageCenterMessageViewController.h"
#import "UAWKWebViewNativeBridge.h"
#import "UAInbox.h"
#import "UAirship.h"
#import "UAMessageCenter.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessage.h"
#import "UAUtils+Internal.h"
#import "UAViewUtils+Internal.h"
#import "UAMessageCenterLocalization.h"
#import "UABeveledLoadingIndicator.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UADispatcher+Internal.h"
#import "UAUser+Internal.h"

#define kMessageUp 0
#define kMessageDown 1

@interface UAMessageCenterMessageViewController () <UAWKWebViewDelegate, UAMessageCenterMessageViewProtocol>

@property (nonatomic, strong) UAWKWebViewNativeBridge *nativeBridge;

/**
 * The WebView used to display the message content.
 */
@property (nonatomic, strong) WKWebView *webView;

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
@property (nonatomic, strong) UAInboxMessage *message;

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

@end

@implementation UAMessageCenterMessageViewController

@synthesize message = _message;
@synthesize closeBlock = _closeBlock;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
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

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.webView.scrollView setZoomScale:0 animated:YES];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.nativeBridge = [[UAWKWebViewNativeBridge alloc] init];
    self.nativeBridge.forwardDelegate = self;
    self.webView.navigationDelegate = self.nativeBridge;
    self.webView.allowsLinkPreview = ![UAirship messageCenter].disableMessageLinkPreviewAndCallouts;

    // Allow the webView to detect data types (e.g. phone numbers, addresses) at will
    [self.webView.configuration setDataDetectorTypes:WKDataDetectorTypeAll];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_delete")
                                                                               style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(delete:)];

    // load message or cover view if no message waiting to load
    switch (self.messageState) {
        case NONE:
            [self coverWithMessageAndHideLoadingIndicator:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
            break;
        case FETCHING:
            [self coverWithBlankViewAndShowLoadingIndicator];
            break;
        case TO_LOAD:
            [self loadMessage:self.message onlyIfChanged:NO];
            break;
        default:
            UA_LWARN(@"MessageState = %u. Should be \"NONE\", \"FETCHING\", or \"TO_LOAD\"",self.messageState);
            break;
    }
    
    self.isVisible = NO;
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
        [self coverWithMessageAndHideLoadingIndicator:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    self.isVisible = YES;

    if (self.messageState == LOADED) {
        [self uncoverAndHideLoadingIndicator];
    }

    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.isVisible = NO;
}

#pragma mark -
#pragma mark UI

- (void)delete:(id)sender {
    if (self.messageState != LOADED) {
        UA_LWARN(@"MessageState = %u. Should be \"LOADED\"",self.messageState);
    }
    if (self.message) {
        self.messageState = NONE;
        [[UAirship inbox].messageList markMessagesDeleted:@[self.message] completionHandler:nil];
    }
}

- (void)coverWithMessageAndHideLoadingIndicator:(NSString *)message {
    self.title = nil;
    self.coverLabel.text = message;
    self.coverView.hidden = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self hideLoadingIndicator];
}

- (void)coverWithBlankViewAndShowLoadingIndicator {
    self.title = nil;
    self.coverLabel.text = nil;
    self.coverView.hidden = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self showLoadingIndicator];
}

- (void)uncoverAndHideLoadingIndicator {
    self.coverView.hidden = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [self hideLoadingIndicator];
}

- (void)setLoadingIndicatorView:(UIView *)loadingIndicatorView animations:(void (^)(void))animations {
    self.loadingAnimations = animations;
    self.loadingIndicatorView = loadingIndicatorView;
}

- (void)showLoadingIndicator {
    if (self.loadingAnimations) {
        self.loadingAnimations();
    }

    [self.loadingIndicatorView setHidden:NO];
}

- (void)hideLoadingIndicator {
    [self.loadingIndicatorView setHidden:YES];
}

static NSString *urlForBlankPage = @"about:blank";

- (void)loadMessageForID:(NSString *)messageID {
    [self loadMessageForID:messageID onlyIfChanged:NO onError:nil];
}

- (void)loadMessageForID:(NSString *)messageID onlyIfChanged:(BOOL)onlyIfChanged onError:(void (^)(void))errorCompletion {
    if (!messageID) {
        [self coverWithMessageAndHideLoadingIndicator:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
        return;
    }
    
    UAInboxMessage *message = [[UAirship inbox].messageList messageForID:messageID];

    if (message) {
        [self loadMessage:message onlyIfChanged:onlyIfChanged];
        return;
    }

    // start by covering the view and showing the loading indicator
    [self coverWithBlankViewAndShowLoadingIndicator];

    // Refresh the list to see if the message is available in the cloud
    self.messageState = FETCHING;

    UA_WEAKIFY(self);

    [[UAirship inbox].messageList retrieveMessageListWithSuccessBlock:^{
        [[UADispatcher mainDispatcher] dispatchAsync:^{
            UA_STRONGIFY(self)

            UAInboxMessage *message = [[UAirship inbox].messageList messageForID:messageID];
            if (message && !message.isExpired) {
                // display the message
                [self loadMessage:message onlyIfChanged:onlyIfChanged];
            } else {
                // if the message no longer exists, clean up and show an error dialog
                [self hideLoadingIndicator];

                [self displayNoLongerAvailableAlertOnOK:^{
                    UA_STRONGIFY(self);
                    self.messageState = NONE;
                    self.message = nil;
                    if (errorCompletion) {
                        errorCompletion();
                    };
                }];
            }
            return;
        }];
    } withFailureBlock:^{
        [[UADispatcher mainDispatcher] dispatchAsync:^{
            UA_STRONGIFY(self);
            
            [self hideLoadingIndicator];
            
            if (errorCompletion) {
                errorCompletion();
            }
        }];
        return;
    }];
}
- (void)loadMessage:(UAInboxMessage *)message onlyIfChanged:(BOOL)onlyIfChanged {
    if (!message) {
        if (self.messageState == LOADING) {
            [self.webView stopLoading];
        }
        self.messageState = NONE;
        self.message = message;
        [self coverWithMessageAndHideLoadingIndicator:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
        return;
    }
    
    if (!onlyIfChanged || (self.messageState == NONE) || !(self.message && [message.messageID isEqualToString:self.message.messageID])) {
        self.message = message;
        
        if (!self.webView) {
            self.messageState = TO_LOAD;
        } else {
            if (self.messageState == LOADING) {
                [self.webView stopLoading];
            }
            self.messageState = LOADING;
            
            // start by covering the view and showing the loading indicator
            [self coverWithBlankViewAndShowLoadingIndicator];
            
            // now load a blank page, so when the view is uncovered, it isn't still showing the previous web page
            // note: when the blank page has finished loading, it will load the message
            [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlForBlankPage]]];
        }
    } else {
        if (self.isVisible && (self.messageState == LOADED)) {
            [self uncoverAndHideLoadingIndicator];
        }
    }
}

- (void)loadMessageIntoWebView {
    self.title = self.message.title;
    
    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:self.message.messageBodyURL];
    requestObj.timeoutInterval = 60;

    UA_WEAKIFY(self)
    [[UAirship inboxUser] getUserData:^(UAUserData *userData) {
        UA_STRONGIFY(self)
        NSString *auth = [UAUtils userAuthHeaderString:userData];
        [requestObj setValue:auth forHTTPHeaderField:@"Authorization"];
        [self.webView loadRequest:requestObj];
    } dispatcher:[UADispatcher mainDispatcher]];
}

- (void)displayNoLongerAvailableAlertOnOK:(void (^)(void))okCompletion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_content_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_no_longer_available")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (okCompletion) {
                                                                  okCompletion();
                                                              }
                                                          }];
    
    [alert addAction:defaultAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
}

- (void)displayFailedToLoadAlertOnOK:(void (^)(void))okCompletion onRetry:(void (^)(void))retryCompletion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_connection_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_failed_to_load")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (okCompletion) {
                                                                  okCompletion();
                                                              }
                                                          }];
    
    [alert addAction:defaultAction];
    
    if (retryCompletion) {
        UIAlertAction *retryAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_retry_button")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
                                                                if (retryCompletion) {
                                                                    retryCompletion();
                                                                }
                                                            }];
        
        [alert addAction:retryAction];
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark UAWKWebViewDelegate

- (void)webView:(WKWebView *)wv decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if (self.messageState != LOADING) {
        UA_LWARN(@"MessageState = %u. Should be \"LOADING\"",self.messageState);
    }
    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)navigationResponse.response;
        NSInteger status = httpResponse.statusCode;
        if (status >= 400 && status <= 599) {
            decisionHandler(WKNavigationResponsePolicyCancel);
            [self coverWithBlankViewAndShowLoadingIndicator];
            if (status >= 500) {
                // Display a retry alert
                UA_WEAKIFY(self);
                [self displayFailedToLoadAlertOnOK:nil onRetry:^{
                    UA_STRONGIFY(self);
                    [self loadMessage:self.message onlyIfChanged:NO];
                }];
            } else if (status == 410) {
                // Gone: message has been permanently deleted from the backend.
                // Alert the user that message is no longer available.
                UA_WEAKIFY(self)
                [self displayNoLongerAvailableAlertOnOK:^{
                    UA_STRONGIFY(self)
                    [self uncoverAndHideLoadingIndicator];
                }];
            } else {
                // Display a generic alert
                UA_WEAKIFY(self);
                [self displayFailedToLoadAlertOnOK:^{
                    UA_STRONGIFY(self);
                    [self uncoverAndHideLoadingIndicator];
                } onRetry:nil];
            }
            return;
        }
    }
    
    decisionHandler(WKNavigationResponsePolicyAllow);

}

- (void)webView:(WKWebView *)wv didFinishNavigation:(WKNavigation *)navigation {
    if (self.messageState != LOADING) {
        UA_LWARN(@"MessageState = %u. Should be \"LOADING\"",self.messageState);
    }
    
    if ([UAirship messageCenter].disableMessageLinkPreviewAndCallouts) {
        [self.webView evaluateJavaScript:@"document.body.style.webkitTouchCallout='none';" completionHandler:nil];
    }
    
    if ([wv.URL.absoluteString isEqualToString:urlForBlankPage]) {
        [self loadMessageIntoWebView];
        return;
    }
    
    self.messageState = LOADED;
 
    // Mark message as read after it has finished loading
    if (self.message.unread) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }
    
    [self uncoverAndHideLoadingIndicator];
}

- (void)webView:(WKWebView *)wv didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (self.messageState != LOADING) {
        UA_LWARN(@"MessageState = %u. Should be \"LOADING\"",self.messageState);
    }
    if (error.code == NSURLErrorCancelled) {
        return;
    }

    UA_LDEBUG(@"Failed to load message: %@", error);
    
    self.messageState = NONE;

    [self hideLoadingIndicator];

    // Display a retry alert
    UA_WEAKIFY(self);
    [self displayFailedToLoadAlertOnOK:nil onRetry:^{
        UA_STRONGIFY(self);
        [self loadMessage:self.message onlyIfChanged:NO];
    }];
}

- (void)closeWindowAnimated:(BOOL)animated {
    if (self.closeBlock) {
        self.closeBlock(animated);
    }
    self.message=nil;
}

@end
