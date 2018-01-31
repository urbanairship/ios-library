/* Copyright 2018 Urban Airship and Contributors */

#import "UAGlobal.h"
#import "UAInAppMessageModalAdapter.h"
#import "UAInAppMessageModalDisplayContent+Internal.h"
#import "UAInAppMessageModalViewController+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAUtils.h"

@interface UAInAppMessageModalAdapter ()
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageModalViewController *modalController;
@property (nonatomic, strong) NSCache *imageCache;

@end

@implementation UAInAppMessageModalAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[UAInAppMessageModalAdapter alloc] initWithMessage:message];
}

-(instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];
    
    if (self) {
        self.message = message;
        self.imageCache = [UAInAppMessageUtils createImageCache];
    }
    
    return self;
}

- (void)prepare:(void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageModalDisplayContent *displayContent = (UAInAppMessageModalDisplayContent *)self.message.displayContent;
    [UAInAppMessageUtils prepareMediaView:displayContent.media imageCache:self.imageCache completionHandler:^(UAInAppMessagePrepareResult result, UAInAppMessageMediaView *mediaView) {
        if (result == UAInAppMessagePrepareResultSuccess) {
            mediaView.hideWindowWhenVideoIsFullScreen = YES;
            self.modalController = [UAInAppMessageModalViewController modalControllerWithModalMessageID:self.message.identifier
                                                                                                         displayContent:displayContent
                                                                                                              mediaView:mediaView];
        }
        completionHandler(result);
    }];
}

- (BOOL)isReadyToDisplay {
    UAInAppMessageModalDisplayContent* modalContent = (UAInAppMessageModalDisplayContent *)self.message.displayContent;
    return [UAInAppMessageUtils isReadyToDisplayWithMedia:modalContent.media];
}

- (void)display:(void (^)(UAInAppMessageResolution *))completionHandler {
    [self.modalController showWithCompletionHandler:completionHandler];
}

- (void)dealloc {
    if (self.imageCache) {
        [self.imageCache removeAllObjects];
    }
    
    self.imageCache = nil;
}

@end


