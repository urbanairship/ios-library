/* Copyright Airship and Contributors */

#import "UAInAppMessageFullScreenAdapter.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageFullScreenViewController+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageSceneManager.h"
#import "UAAirshipAutomationCoreImport.h"

NSString *const UAFullScreenStyleFileName = @"UAInAppMessageFullScreenStyle";

@interface UAInAppMessageFullScreenAdapter ()
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageFullScreenViewController *fullScreenController;
@property (nonatomic, strong) UIWindowScene *scene API_AVAILABLE(ios(13.0));
@end

@implementation UAInAppMessageFullScreenAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[UAInAppMessageFullScreenAdapter alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
        self.style = [UAInAppMessageFullScreenStyle styleWithContentsOfFile:UAFullScreenStyleFileName];
    }

    return self;
}

- (void)prepareWithAssets:(nonnull UAInAppMessageAssets *)assets completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageFullScreenDisplayContent *displayContent = (UAInAppMessageFullScreenDisplayContent *)self.message.displayContent;
    [UAInAppMessageUtils prepareMediaView:displayContent.media assets:assets completionHandler:^(UAInAppMessagePrepareResult result, UAInAppMessageMediaView *mediaView) {
        if (result == UAInAppMessagePrepareResultSuccess) {
            self.fullScreenController = [UAInAppMessageFullScreenViewController fullScreenControllerWithDisplayContent:displayContent
                                                                                                             mediaView:mediaView
                                                                                                                 style:self.style];
        }
        completionHandler(result);
    }];
}

- (BOOL)isReadyToDisplay {
    UAInAppMessageFullScreenDisplayContent *fullScreenContent = (UAInAppMessageFullScreenDisplayContent *)self.message.displayContent;
    if (![UAInAppMessageUtils isReadyToDisplayWithMedia:fullScreenContent.media]) {
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

- (void)display:(void (^)(UAInAppMessageResolution *))completionHandler {
    if (@available(iOS 13.0, *)) {
        UA_WEAKIFY(self)
        [self.fullScreenController showWithScene:self.scene completionHandler:^(UAInAppMessageResolution *result) {
            UA_STRONGIFY(self)
            self.scene = nil;
            completionHandler(result);
        }];
    } else {
        [self.fullScreenController showWithCompletionHandler:completionHandler];
    }
}


@end

