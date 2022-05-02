/* Copyright Airship and Contributors */

#import "UAInAppMessageHTMLAdapter.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageHTMLViewController+Internal.h"
#import "UAInAppMessageHTMLDisplayContent.h"
#import "UAInAppMessageResizableViewController+Internal.h"
#import "UAInAppMessageSceneManager.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString *const UAHTMLStyleFileName = @"UAInAppMessageHTMLStyle";


@interface UAInAppMessageHTMLAdapter ()
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageHTMLDisplayContent *displayContent;
@property (nonatomic, strong) UAInAppMessageHTMLViewController *htmlViewController;
@property (nonatomic, strong) UAInAppMessageResizableViewController *resizableContainerViewController;
@property (nonatomic, strong) UIWindowScene *scene API_AVAILABLE(ios(13.0));
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
    return ![[UAUtils connectionType] isEqualToString:UAConnectionType.none];
}

- (void)prepareWithAssets:(nonnull UAInAppMessageAssets *)assets completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageHTMLDisplayContent *content = (UAInAppMessageHTMLDisplayContent *)self.message.displayContent;

    if (![[UAirship shared].URLAllowList isAllowed:[NSURL URLWithString:content.url] scope:UAURLAllowListScopeOpenURL]) {
        UA_LERR(@"HTML in-app message URL is not allowed. Unable to display message.");
        return completionHandler(UAInAppMessagePrepareResultCancel);
    }

    UAAutomationNativeBridgeExtension *nativeBridgeExtension = [UAAutomationNativeBridgeExtension extensionWithMessage:self.message];

    self.htmlViewController = [UAInAppMessageHTMLViewController htmlControllerWithDisplayContent:content
                                                                                           style:self.style
                                                                           nativeBridgeExtension:nativeBridgeExtension];
    completionHandler(UAInAppMessagePrepareResultSuccess);
}

- (BOOL)isReadyToDisplay {
    if (self.displayContent.requireConnectivity && ![self isNetworkConnected]) {
        return NO;
    }

    if (@available(iOS 13.0, *)) {
        self.scene = [[UAInAppMessageSceneManager shared] sceneForMessage:self.message];
        if (!self.scene) {
            UA_LDEBUG(@"Unable to display message %@, no scene.", self.message);
            return NO;
        }
    }

    return YES;
}

- (void)createContainerViewController {
    CGSize size = CGSizeMake(self.htmlViewController.displayContent.width,
                             self.htmlViewController.displayContent.height);

    self.resizableContainerViewController = [UAInAppMessageResizableViewController resizableViewControllerWithChild:self.htmlViewController size:size aspectLock:self.htmlViewController.displayContent.aspectLock];

    self.resizableContainerViewController.backgroundColor = self.htmlViewController.displayContent.backgroundColor;
    self.resizableContainerViewController.allowFullScreenDisplay = self.htmlViewController.displayContent.allowFullScreenDisplay;
    self.resizableContainerViewController.extendFullScreenLargeDevice = self.htmlViewController.style.extendFullScreenLargeDevice;
    self.resizableContainerViewController.additionalPadding = self.htmlViewController.style.additionalPadding;
    self.resizableContainerViewController.borderRadius = self.htmlViewController.displayContent.borderRadiusPoints;
    self.resizableContainerViewController.maxWidth = self.htmlViewController.style.maxWidth;
    self.resizableContainerViewController.maxHeight = self.htmlViewController.style.maxHeight;

    self.resizableContainerViewController.allowMaxHeight = YES;

    // Set resizable parent
    self.htmlViewController.resizableParent = self.resizableContainerViewController;
}

- (void)display:(nonnull void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    [self createContainerViewController];

    if (@available(iOS 13.0, *)) {
        UA_WEAKIFY(self)
        [self.resizableContainerViewController showWithScene:self.scene completionHandler:^(UAInAppMessageResolution *result) {
            UA_STRONGIFY(self)
            self.scene = nil;
            completionHandler(result);
        }];
    } else {
        [self.resizableContainerViewController showWithCompletionHandler:completionHandler];
    }
}

@end

