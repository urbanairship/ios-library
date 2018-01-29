/* Copyright 2018 Urban Airship and Contributors */

#import "UAGlobal.h"
#import "UAInAppMessageFullScreenAdapter.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageFullScreenController+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAUtils.h"

@interface UAInAppMessageFullScreenAdapter ()
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageFullScreenController *fullScreenController;
@property (nonatomic, strong) NSCache *imageCache;
@end

@implementation UAInAppMessageFullScreenAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[UAInAppMessageFullScreenAdapter alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
        self.imageCache = [UAInAppMessageUtils createImageCache];
    }

    return self;
}

- (void)prepare:(void (^)(UAInAppMessagePrepareResult))completionHandler {    
    UAInAppMessageFullScreenDisplayContent *displayContent = (UAInAppMessageFullScreenDisplayContent *)self.message.displayContent;
    [UAInAppMessageUtils prepareMediaView:displayContent.media imageCache:self.imageCache completionHandler:^(UAInAppMessagePrepareResult result, UAInAppMessageMediaView *mediaView) {
        if (result == UAInAppMessagePrepareResultSuccess) {
            self.fullScreenController = [UAInAppMessageFullScreenController fullScreenControllerWithFullScreenMessageID:self.message.identifier
                                                                                                         displayContent:displayContent
                                                                                                              mediaView:mediaView];
        }
        completionHandler(result);
    }];
}

- (BOOL)isReadyToDisplay {
    UAInAppMessageFullScreenDisplayContent* fullScreenContent = (UAInAppMessageFullScreenDisplayContent *)self.message.displayContent;
    return [UAInAppMessageUtils isReadyToDisplayWithMedia:fullScreenContent.media];
}

- (void)display:(void (^)(UAInAppMessageResolution *))completionHandler {
    [self.fullScreenController showWithParentView:[UAUtils mainWindow]
                                completionHandler:completionHandler];
}

- (void)dealloc {
    if (self.imageCache) {
        [self.imageCache removeAllObjects];
    }

    self.imageCache = nil;
}

@end

