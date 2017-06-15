/* Copyright 2017 Urban Airship and Contributors */

#import "UAMessageCenterMessageViewController.h"
#import "UAWKWebViewNativeBridge.h"
#import "UAInbox.h"
#import "UAirship.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"
#import "UAMessageCenterLocalization.h"
#import "UABeveledLoadingIndicator.h"

#define kMessageUp 0
#define kMessageDown 1

@interface UAMessageCenterMessageViewController () <UAWKWebViewDelegate, UAMessageCenterMessageViewProtocol>

@property (nonatomic, strong) UAWKWebViewNativeBridge *nativeBridge;

/**
 * The WebView used to display the message content.
 */
@property (nonatomic, strong) WKWebView *webView;

@property (weak, nonatomic) IBOutlet UABeveledLoadingIndicator *loadingIndicatorView;

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

@end

@implementation UAMessageCenterMessageViewController

@synthesize message = _message;
@synthesize closeBlock = _closeBlock;

- (void)dealloc {
    self.webView.navigationDelegate = nil;
    self.message = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.nativeBridge = [[UAWKWebViewNativeBridge alloc] init];
    self.nativeBridge.forwardDelegate = self;
    self.webView.navigationDelegate = self.nativeBridge;

    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}]) {
        // Allow the webView to detect data types (e.g. phone numbers, addresses) at will
        [self.webView.configuration setDataDetectorTypes:WKDataDetectorTypeAll];
    }

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_delete")
                                                                               style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(delete:)];

    if (self.message) {
        [self loadMessage:self.message onlyIfChanged:NO];
    } else {
        [self coverWithMessage:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
    }
    
    self.isVisible = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    self.isVisible = YES;

    [super viewDidAppear:animated];
    
    if (self.message) {
        // if webview has already finished loading, we need to hide the loading indicator and uncover the view.
        if (!self.webView.loading) {
            [self uncoverAndHideLoadingIndicator];
        }
    } else {
        [self coverWithMessage:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.isVisible = NO;
}

#pragma mark -
#pragma mark UI

- (void)delete:(id)sender {
    if (self.message) {
        [[UAirship inbox].messageList markMessagesDeleted:@[self.message] completionHandler:nil];
    }
}

- (void)coverWithMessage:(NSString *)message {
    self.title = nil;
    self.coverLabel.text = message;
    self.coverView.hidden = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)coverWithBlankViewAndShowLoadingIndicator {
    self.coverLabel.text = nil;
    self.coverView.hidden = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self.loadingIndicatorView show];
}

- (void)uncoverAndHideLoadingIndicator {
    self.coverView.hidden = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [self.loadingIndicatorView hide];
}

static NSString *urlForBlankPage = @"about:blank";

- (void)loadMessage:(UAInboxMessage *)message onlyIfChanged:(BOOL)onlyIfChanged {
    if (!message) {
        self.message = message;
        [self.webView stopLoading];
        [self coverWithMessage:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
        return;
    }
    
    if (!onlyIfChanged || !self.message || ![message.messageID isEqualToString:self.message.messageID] || ![message.title isEqualToString:self.message.title] || ![message.messageBodyURL isEqual:self.message.messageBodyURL]) {
        [self.webView stopLoading];
        
        // start by covering the view and showing the loading indicator
        [self coverWithBlankViewAndShowLoadingIndicator];
        
        // now load a blank page, so when the view is uncovered, it isn't still showing the previous web page
        // note: when the blank page has finished loading, it will load the message
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlForBlankPage]]];
        self.message = message;
    } else {
        if (!self.webView.loading) {
            [self uncoverAndHideLoadingIndicator];
        }
    }
}

- (void)loadMessageIntoWebView {
    self.title = self.message.title;
    
    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:self.message.messageBodyURL];
    requestObj.timeoutInterval = 60;
    
    NSString *auth = [UAUtils userAuthHeaderString];
    [requestObj setValue:auth forHTTPHeaderField:@"Authorization"];
    
    [self.webView loadRequest:requestObj];
}

- (void)displayAlert:(BOOL)retry {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_connection_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_failed_to_load")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];

    if (retry) {
        UIAlertAction *retryAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_retry_button")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
                                                                [self loadMessage:self.message onlyIfChanged:NO];
        }];

        [alert addAction:retryAction];
    }

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark UAWKWebViewDelegate

- (void)webView:(WKWebView *)wv decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)navigationResponse.response;
        NSInteger status = httpResponse.statusCode;
        if (status >= 400 && status <= 599) {
            decisionHandler(WKNavigationResponsePolicyCancel);
            [self coverWithBlankViewAndShowLoadingIndicator];
            if (status >= 500) {
                // Display a retry alert
                [self displayAlert:YES];
            } else {
                // Display a generic alert
                [self displayAlert:NO];
            }
            return;
        }
    }
    
    decisionHandler(WKNavigationResponsePolicyAllow);

}

- (void)webView:(WKWebView *)wv didFinishNavigation:(WKNavigation *)navigation {
    if ([wv.URL.absoluteString isEqualToString:urlForBlankPage]) {
        [self loadMessageIntoWebView];
        return;
    }
    
    // Mark message as read after it has finished loading
    if (self.message.unread) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }
    
    // if view has already appeared, we need to hide the loading indicator and uncover the view.
    if (self.isVisible) {
        [self uncoverAndHideLoadingIndicator];
    }
}

- (void)webView:(WKWebView *)wv didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) {
        return;
    }
    UA_LDEBUG(@"Failed to load message: %@", error);
    [self uncoverAndHideLoadingIndicator];
    [self displayAlert:YES];
}

- (void)closeWindowAnimated:(BOOL)animated {
    if (self.closeBlock) {
        self.closeBlock(animated);
    }
    self.message=nil;
}

@end
