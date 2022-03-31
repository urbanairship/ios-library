/* Copyright Airship and Contributors */

#import "UAInAppMessageModalAdapter.h"
#import "UAInAppMessageModalDisplayContent+Internal.h"
#import "UAInAppMessageModalViewController+Internal.h"
#import "UAInAppMessageHTMLViewController+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageResizableViewController+Internal.h"
#import "UAInAppMessageSceneManager.h"
#import "UAAirshipAutomationCoreImport.h"

NSString *const UAModalStyleFileName = @"UAInAppMessageModalStyle";

@interface UAInAppMessageModalAdapter ()
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageModalViewController *modalController;
@property (nonatomic, strong) UAInAppMessageResizableViewController *resizableContainerViewController;
@property (nonatomic, strong) UIWindowScene *scene API_AVAILABLE(ios(13.0));
@end

@implementation UAInAppMessageModalAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[UAInAppMessageModalAdapter alloc] initWithMessage:message];
}

-(instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
        self.style = [UAInAppMessageModalStyle styleWithContentsOfFile:UAModalStyleFileName];
    }

    return self;
}

- (void)prepareWithAssets:(nonnull UAInAppMessageAssets *)assets completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageModalDisplayContent *displayContent = (UAInAppMessageModalDisplayContent *)self.message.displayContent;
    [UAInAppMessageUtils prepareMediaView:displayContent.media assets:assets completionHandler:^(UAInAppMessagePrepareResult result, UAInAppMessageMediaView *mediaView) {
        if (result == UAInAppMessagePrepareResultSuccess) {
            mediaView.hideWindowWhenVideoIsFullScreen = YES;
            self.modalController = [UAInAppMessageModalViewController modalControllerWithDisplayContent:displayContent
                                                                                              mediaView:mediaView
                                                                                                  style:self.style];
        }
        completionHandler(result);
    }];
}

- (BOOL)isReadyToDisplay {
    UAInAppMessageModalDisplayContent* modalContent = (UAInAppMessageModalDisplayContent *)self.message.displayContent;
    if (![UAInAppMessageUtils isReadyToDisplayWithMedia:modalContent.media]) {
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
    self.resizableContainerViewController = [UAInAppMessageResizableViewController resizableViewControllerWithChild:self.modalController];

    self.resizableContainerViewController.backgroundColor = self.modalController.displayContent.backgroundColor;
    self.resizableContainerViewController.allowFullScreenDisplay = self.modalController.displayContent.allowFullScreenDisplay;
    self.resizableContainerViewController.extendFullScreenLargeDevice = self.modalController.style.extendFullScreenLargeDevice;
    self.resizableContainerViewController.additionalPadding = self.modalController.style.additionalPadding;
    self.resizableContainerViewController.borderRadius = self.modalController.displayContent.borderRadiusPoints;
    self.resizableContainerViewController.maxWidth = self.modalController.style.maxWidth;
    self.resizableContainerViewController.maxHeight = self.modalController.style.maxHeight;

    // Set weak link to parent
    self.modalController.resizableParent = self.resizableContainerViewController;
}

- (void)display:(void (^)(UAInAppMessageResolution *))completionHandler {
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
