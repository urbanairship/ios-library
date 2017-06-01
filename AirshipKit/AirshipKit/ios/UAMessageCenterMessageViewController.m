/* Copyright 2017 Urban Airship and Contributors */

#import "UAMessageCenterMessageViewController.h"
#import "UAWKWebViewNativeBridge.h"
#import "UAInbox.h"
#import "UAirship.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"
#import "UAMessageCenterLocalization.h"

#define kMessageUp 0
#define kMessageDown 1

@interface UAMessageCenterMessageViewController () <UAWKWebViewDelegate, UAMessageCenterMessageViewProtocol>

@property (nonatomic, strong) UAWKWebViewNativeBridge *nativeBridge;

/**
 * The WebView used to display the message content.
 */
@property (nonatomic, strong) WKWebView *webView;

/**
 * The view displayed when there are no messages.
 */
@property (nonatomic, weak) IBOutlet UIView *coverView;

/**
 * The label displayed in the coverView.
 */
@property (nonatomic, weak) IBOutlet UILabel *coverLabel;

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
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.message) {
        if (!self.webView.loading) {
            [self uncover];
        }
    } else {
        [self coverWithMessage:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
    }
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

- (void)uncover {
    self.coverView.hidden = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

- (void)loadMessage:(UAInboxMessage *)message onlyIfChanged:(BOOL)onlyIfChanged {
    if (!message) {
        self.message = message;
        [self coverWithMessage:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
        return;
    }
    
    if (!onlyIfChanged || !self.message || ![message.messageID isEqualToString:self.message.messageID] || ![message.title isEqualToString:self.message.title] || ![message.messageBodyURL isEqual:self.message.messageBodyURL]) {
        [self coverWithMessage:nil];
        [self.webView stopLoading];
        
        self.message = message;
        self.title = self.message.title;
        
        NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:self.message.messageBodyURL];
        requestObj.timeoutInterval = 60;
        
        NSString *auth = [UAUtils userAuthHeaderString];
        [requestObj setValue:auth forHTTPHeaderField:@"Authorization"];
        
        [self.webView loadRequest:requestObj];
    } else {
        [self uncover];
    }
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
        NSString *blank = @"about:blank";
        if (status >= 400 && status <= 599) {
            decisionHandler(WKNavigationResponsePolicyCancel);
            [wv loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:blank]]];
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
    [self uncover];
    
    NSString *blank = @"about:blank";
    if ([wv.URL.absoluteString isEqualToString:blank]) {
        return;
    }
    
    // Mark message as read after it has finished loading
    if (self.message.unread) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }
}

- (void)webView:(WKWebView *)wv didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled)
        return;
    UA_LDEBUG(@"Failed to load message: %@", error);
    [self displayAlert:YES];
}

- (void)closeWindowAnimated:(BOOL)animated {
    if (self.closeBlock) {
        self.closeBlock(animated);
    }
    self.message=nil;
}

@end
