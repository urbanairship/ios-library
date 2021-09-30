/* Copyright Airship and Contributors */

#import "UAInAppMessageBannerAdapter.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageBannerController+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageSceneManager.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString *const UABannerStyleFileName = @"UAInAppMessageBannerStyle";

@interface UAInAppMessageBannerAdapter ()
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageBannerController *bannerController;
@property (nonatomic, strong) UIWindowScene *scene API_AVAILABLE(ios(13.0));
@end

@implementation UAInAppMessageBannerAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[UAInAppMessageBannerAdapter alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
        self.style = [UAInAppMessageBannerStyle styleWithContentsOfFile:UABannerStyleFileName];
    }

    return self;
}

- (void)prepareWithAssets:(nonnull UAInAppMessageAssets *)assets completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageBannerDisplayContent *displayContent = (UAInAppMessageBannerDisplayContent *)self.message.displayContent;
    [UAInAppMessageUtils prepareMediaView:displayContent.media assets:assets completionHandler:^(UAInAppMessagePrepareResult result, UAInAppMessageMediaView *mediaView) {
        if (result == UAInAppMessagePrepareResultSuccess) {
            self.bannerController = [UAInAppMessageBannerController bannerControllerWithDisplayContent:displayContent
                                                                                             mediaView:mediaView
                                                                                                 style:self.style];
        }
        completionHandler(result);
    }];
}


- (BOOL)isReadyToDisplay {
    UAInAppMessageBannerDisplayContent* displayContent = (UAInAppMessageBannerDisplayContent *)self.message.displayContent;
    if (![UAInAppMessageUtils isReadyToDisplayWithMedia:displayContent.media]) {
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
        [self.bannerController showWithParentView:[UAUtils mainWindow:self.scene] completionHandler:^(UAInAppMessageResolution *result) {
            UA_STRONGIFY(self)
            self.scene = nil;
            completionHandler(result);
        }];
    } else {
        [self.bannerController showWithParentView:[UAUtils mainWindow]
                                completionHandler:completionHandler];
    }
}

@end

