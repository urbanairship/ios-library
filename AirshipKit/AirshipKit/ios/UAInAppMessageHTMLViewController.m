/* Copyright Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageHTMLViewController+Internal.h"
#import "UABeveledLoadingIndicator.h"
#import "UAWebView+Internal.h"
#import "UAInAppMessageHTMLDisplayContent.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageResolution+Internal.h"
#import "UAViewUtils+Internal.h"
#import "UAInAppMessageNativeBridge+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAMessageCenter.h"
#import "UAInbox.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxMessageList.h"
#import "UAUtils+Internal.h"
#import "UAUser+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageHTMLViewController () <UAWKWebViewDelegate, UAJavaScriptDelegate>

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
@property (nonatomic, strong) UAInAppMessageNativeBridge *nativeBridge;

/**
 * Close button.
 */
@property (strong, nonatomic) UAInAppMessageDismissButton *closeButton;

/**
 * The identifier of the HTML message.
 */
@property (nonatomic, strong) NSString *messageID;

/**
 * The request headers. These are populated and used when displaying an inbox message.
 */
@property (nonatomic, strong) NSDictionary *headers;

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

        if (!self.style.hideDismissIcon) {
            self.closeButton = [self createCloseButton];
        }

        self.nativeBridge = [[UAInAppMessageNativeBridge alloc] init];
        self.nativeBridge.forwardDelegate = self;
        self.nativeBridge.messageJSDelegate = self;
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

    if (self.style.hideDismissIcon) {
        [self.closeButtonContainerView setHidden:YES];
    } else {
        self.closeButton.dismissButtonColor = self.displayContent.dismissButtonColor;
        [self.closeButtonContainerView addSubview:self.closeButton];
    }

    [UAViewUtils applyContainerConstraintsToContainer:self.closeButtonContainerView containedView:self.closeButton];
    [self.webView.configuration setDataDetectorTypes:WKDataDetectorTypeNone];
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

- (void)loadInboxMessage:(UAInboxMessage *)message {
    [self showOverlay];

    NSURL *url = message.messageBodyURL;

    UA_WEAKIFY(self)
    void (^loadRequest)(void) = ^{
        UA_STRONGIFY(self)
        NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:url];

        for (NSString *headerKey in self.headers) {
            NSString *headerValue = [self.headers objectForKey:headerKey];
            [requestObj addValue:headerValue forHTTPHeaderField:headerKey];
        }

        [self loadRequestWithDefaultTimeoutInterval:requestObj];
    };

    if (message) {
        UA_WEAKIFY(self)
        [[UAirship inboxUser] getUserData:^(UAUserData *userData) {
            UA_STRONGIFY(self)
            NSDictionary *auth = @{@"Authorization":[UAUtils userAuthHeaderString:userData]};

            NSMutableDictionary *appended = [NSMutableDictionary dictionaryWithDictionary:self.headers];
            [appended addEntriesFromDictionary:auth];
            self.headers = appended;

            loadRequest();
        } dispatcher:[UADispatcher mainDispatcher]];
    } else {
        loadRequest();
    }
}

- (void)load {
    NSString *inboxMessageID = [self inboxMessageID];
    if (inboxMessageID) {
        [self fetchMessage:inboxMessageID completionHandler:^(UAInboxMessage *message) {
            if (!message) {
                [self dismissWithoutResolution];
                return;
            }

            [self loadInboxMessage:message];
        }];
        return;
    }

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

#pragma mark UAJavaScriptDelegate

- (void)callWithData:(UAWebViewCallData *)data withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {
    /**
     * dismiss calls dismissWithResolution:
     *
     * Expected format:
     * dismiss/<resolution>/
     */
    if ([data.name isEqualToString:UANativeBridgeDismissCommand]) {
        id args = [data.arguments firstObject];

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

        completionHandler(nil);
        return;
    }

    // Arguments not recognized, pass a nil script result
    completionHandler(nil);
}

#pragma mark UAWKWebViewDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    [self hideOverlay];

    NSString *inboxMessageId = [self inboxMessageID];
    // If inbox message ID is available, we should load the inbox message instead of the URL
    if (inboxMessageId) {
        UAInboxMessage  *message = [[UAirship inbox].messageList messageForID:inboxMessageId];
        if (message.unread) {
            [message markMessageReadWithCompletionHandler:nil];
        }
    }
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

/**
 * Fetches the specified message.
 *
 * @param messageID The message ID.
 * @param completionHandler Completion handler to call when the operation is complete.
 */
- (void)fetchMessage:(NSString *)messageID
   completionHandler:(void (^)(UAInboxMessage * __nullable))completionHandler {

    if (messageID == nil) {
        completionHandler(nil);
        return;
    }

    UAInboxMessage *message = [[UAirship inbox].messageList messageForID:messageID];
    if (message) {
        completionHandler(message);
        return;
    }

    // Refresh the list to see if the message is available
    [[UAirship inbox].messageList retrieveMessageListWithSuccessBlock:^{
        completionHandler([[UAirship inbox].messageList messageForID:messageID]);
    } withFailureBlock:^{
        completionHandler(nil);
    }];
}

/**
 * Parses the inbox message ID from the URL.
 * @return The message ID if its an message URL, otherwise nil.
 */
- (NSString *)inboxMessageID {
    NSString *urlString = self.displayContent.url;
    NSURL *url = [NSURL URLWithString:self.displayContent.url];

    // Check the scheme, if it's a message: scheme
    if ([[url scheme] caseInsensitiveCompare:UAMessageDataScheme] == NSOrderedSame) {
        NSString *fullSchemeString = [NSString stringWithFormat:@"%@:", url.scheme];
        return [urlString stringByReplacingOccurrencesOfString:fullSchemeString withString:@""];
    }

    return nil;
}

@end

NS_ASSUME_NONNULL_END
