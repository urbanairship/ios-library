/* Copyright Urban Airship and Contributors */

#import "UAGlobal.h"
#import "UAInAppMessageBannerAdapter.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageBannerController+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAUtils+Internal.h"

NSString *const UABannerStyleFileName = @"UAInAppMessageBannerStyle";

@interface UAInAppMessageBannerAdapter ()
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageBannerController *bannerController;
@property (nonatomic, strong) NSCache *imageCache;
@end

@implementation UAInAppMessageBannerAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[UAInAppMessageBannerAdapter alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
        self.imageCache = [UAInAppMessageUtils createImageCache];
        self.style = [UAInAppMessageBannerStyle styleWithContentsOfFile:UABannerStyleFileName];
    }

    return self;
}

- (void)prepare:(void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageBannerDisplayContent *displayContent = (UAInAppMessageBannerDisplayContent *)self.message.displayContent;
    [UAInAppMessageUtils prepareMediaView:displayContent.media imageCache:self.imageCache completionHandler:^(UAInAppMessagePrepareResult result, UAInAppMessageMediaView *mediaView) {
        if (result == UAInAppMessagePrepareResultSuccess) {
            self.bannerController = [UAInAppMessageBannerController bannerControllerWithBannerMessageID:self.message.identifier
                                                                                         displayContent:displayContent
                                                                                              mediaView:mediaView
                                                                                                  style:self.style];
        }
        completionHandler(result);
    }];
}


- (BOOL)isReadyToDisplay {
    UAInAppMessageBannerDisplayContent* displayContent = (UAInAppMessageBannerDisplayContent *)self.message.displayContent;
    return [UAInAppMessageUtils isReadyToDisplayWithMedia:displayContent.media];
}

- (void)display:(void (^)(UAInAppMessageResolution *))completionHandler {
    [self.bannerController showWithParentView:[UAUtils mainWindow]
                            completionHandler:completionHandler];
}

- (void)dealloc {
    if (self.imageCache) {
        [self.imageCache removeAllObjects];
    }

    self.imageCache = nil;
}

@end

