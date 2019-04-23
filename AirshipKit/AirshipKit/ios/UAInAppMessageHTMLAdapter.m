/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageHTMLAdapter.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageHTMLViewController+Internal.h"
#import "UAInAppMessageHTMLDisplayContent.h"
#import "UAUtils+Internal.h"
#import "UAirship.h"
#import "UAInAppMessageResizableViewController+Internal.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAHTMLStyleFileName = @"UAInAppMessageHTMLStyle";


@interface UAInAppMessageHTMLAdapter ()
@property(nonatomic, strong) UAInAppMessage *message;
@property(nonatomic, strong) UAInAppMessageHTMLDisplayContent *displayContent;
@property(nonatomic, strong) UAInAppMessageHTMLViewController *htmlViewController;
@property(nonatomic, strong) UAInAppMessageResizableViewController *resizableContainerViewController;
@end

@implementation UAInAppMessageHTMLAdapter

+ (nonnull instancetype)adapterForMessage:(nonnull UAInAppMessage *)message {
    return [[self alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
        self.style = [UAInAppMessageHTMLStyle styleWithContentsOfFile:UAHTMLStyleFileName];
        self.displayContent = (UAInAppMessageHTMLDisplayContent *)self.message.displayContent;
    }

    return self;
}

- (BOOL)isNetworkConnected {
    return ![[UAUtils connectionType] isEqualToString:kUAConnectionTypeNone];
}

- (void)prepareWithAssets:(nonnull UAInAppMessageAssets *)assets completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageHTMLDisplayContent *content = (UAInAppMessageHTMLDisplayContent *)self.message.displayContent;

    BOOL whitelisted = [[UAirship shared].whitelist isWhitelisted:[NSURL URLWithString:content.url] scope:UAWhitelistScopeOpenURL];
    if (!whitelisted) {
        UA_LERR(@"HTML in-app message URL is not whitelisted. Unable to display message.");
        return completionHandler(UAInAppMessagePrepareResultCancel);
    }

    if (![self isNetworkConnected]) {
        completionHandler(UAInAppMessagePrepareResultRetry);
        return;
    }

    self.htmlViewController = [UAInAppMessageHTMLViewController htmlControllerWithMessageID:self.message.identifier
                                                                             displayContent:content
                                                                                      style:self.style];
    completionHandler(UAInAppMessagePrepareResultSuccess);
}

- (BOOL)isReadyToDisplay {
    return !self.displayContent.requireConnectivity || [self isNetworkConnected];
}

- (void)display:(nonnull void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {

    CGSize size = CGSizeMake(self.htmlViewController.displayContent.width,
                             self.htmlViewController.displayContent.height);

    self.resizableContainerViewController = [UAInAppMessageResizableViewController resizableViewControllerWithChild:self.htmlViewController size:size aspectLock:self.htmlViewController.displayContent.aspectLock];

    self.resizableContainerViewController.backgroundColor = self.htmlViewController.displayContent.backgroundColor;
    self.resizableContainerViewController.allowFullScreenDisplay = self.htmlViewController.displayContent.allowFullScreenDisplay;
    self.resizableContainerViewController.additionalPadding = self.htmlViewController.style.additionalPadding;
    self.resizableContainerViewController.borderRadius = self.htmlViewController.displayContent.borderRadiusPoints;
    self.resizableContainerViewController.maxWidth = self.htmlViewController.style.maxWidth;
    self.resizableContainerViewController.maxHeight = self.htmlViewController.style.maxHeight;

    // Set resizable parent
    self.htmlViewController.resizableParent = self.resizableContainerViewController;

    // Show resizable view controller with child
    [self.resizableContainerViewController showWithCompletionHandler:completionHandler];
}

@end

NS_ASSUME_NONNULL_END
