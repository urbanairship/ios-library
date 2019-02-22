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
    }

    return self;
}

- (BOOL)isNetworkConnected {
    return ![[UAUtils connectionType] isEqualToString:kUAConnectionTypeNone];
}

- (void)prepare:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
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
    return [self isNetworkConnected];
}

- (void)display:(nonnull void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    self.resizableContainerViewController = [UAInAppMessageResizableViewController resizableViewControllerWithChild:self.htmlViewController];

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
