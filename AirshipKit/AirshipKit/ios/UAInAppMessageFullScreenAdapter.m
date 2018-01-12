/* Copyright 2017 Urban Airship and Contributors */

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

NSString *const UAInAppMessageFullScreenAdapterCacheName = @"UAInAppMessageFullScreenAdapterCache";

@implementation UAInAppMessageFullScreenAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[UAInAppMessageFullScreenAdapter alloc] initWithMessage:message];
}

-(instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
        self.imageCache = [[NSCache alloc] init];
        [self.imageCache setName:UAInAppMessageFullScreenAdapterCacheName];
        [self.imageCache setCountLimit:1];
    }

    return self;
}

- (void)prepare:(void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageFullScreenDisplayContent *displayContent = (UAInAppMessageFullScreenDisplayContent *)self.message.displayContent;

    if (!displayContent.media) {
        self.fullScreenController = [UAInAppMessageFullScreenController fullScreenControllerWithFullScreenMessageID:self.message.identifier
                                                                                                     displayContent:displayContent
                                                                                                          mediaView:nil];

        completionHandler(UAInAppMessagePrepareResultSuccess);
        return;
    }

    if (displayContent.media.type != UAInAppMessageMediaInfoTypeImage) {
        UAInAppMessageMediaView *mediaView = [UAInAppMessageMediaView mediaViewWithMediaInfo:displayContent.media];
        self.fullScreenController = [UAInAppMessageFullScreenController fullScreenControllerWithFullScreenMessageID:self.message.identifier
                                                                                                     displayContent:displayContent
                                                                                                          mediaView:mediaView];
        completionHandler(UAInAppMessagePrepareResultSuccess);
        return;
    }

    NSURL *mediaURL = [NSURL URLWithString:displayContent.media.url];

    // Prefetch image save as file copy what message center does
    UA_WEAKIFY(self);
    [UAInAppMessageUtils prefetchContentsOfURL:mediaURL
                                     WithCache:self.imageCache
                             completionHandler:^(NSString *cacheKey, UAInAppMessagePrepareResult result) {
                                 if (cacheKey){
                                     UA_STRONGIFY(self);
                                     NSData *data = [self.imageCache objectForKey:cacheKey];
                                     if (data) {
                                         UIImage *prefetchedImage = [UIImage imageWithData:data];

                                         UAInAppMessageMediaView *mediaView = [UAInAppMessageMediaView mediaViewWithImage:prefetchedImage];
                                         self.fullScreenController = [UAInAppMessageFullScreenController fullScreenControllerWithFullScreenMessageID:self.message.identifier
                                                                                                                                      displayContent:displayContent
                                                                                                                                           mediaView:mediaView];
                                     }
                                 }

                                 completionHandler(result);
                             }];
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

