/* Copyright 2017 Urban Airship and Contributors */

#import "UAGlobal.h"
#import "UAInAppMessageBannerAdapter.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageBannerController+Internal.h"
#import "UAInAppMessageUtils+Internal.h"

@interface UAInAppMessageBannerAdapter ()
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageBannerController *bannerController;
@property (nonatomic, strong) NSCache *imageCache;
@end

NSString *const UAInAppMessageBannerAdapterCacheName = @"UAInAppMessageBannerAdapterCache";

@implementation UAInAppMessageBannerAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[UAInAppMessageBannerAdapter alloc] initWithMessage:message];
}

-(instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
        self.imageCache = [[NSCache alloc] init];
        [self.imageCache setName:UAInAppMessageBannerAdapterCacheName];
        [self.imageCache setCountLimit:1];
    }

    return self;
}

- (void)prepare:(void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageBannerDisplayContent *displayContent = (UAInAppMessageBannerDisplayContent *)self.message.displayContent;

    if (!displayContent.media) {
        self.bannerController = [UAInAppMessageBannerController bannerControllerWithBannerMessageID:self.message.identifier
                                                                                     displayContent:displayContent
                                                                                              image:nil];
        completionHandler(UAInAppMessagePrepareResultSuccess);
        return;
    }

    NSURL *imageURL = [NSURL URLWithString:displayContent.media.url];

    // Prefetch image save as file copy what message center does
    UA_WEAKIFY(self);
    [UAInAppMessageUtils prefetchContentsOfURL:imageURL
                                     WithCache:self.imageCache
                             completionHandler:^(NSString *cacheKey, UAInAppMessagePrepareResult result) {
                                 if (cacheKey) {
                                     UA_STRONGIFY(self);
                                     NSData *data = [self.imageCache objectForKey:cacheKey];
                                     if (data) {
                                         UIImage *prefetchedImage = [UIImage imageWithData:data];
                                         self.bannerController = [UAInAppMessageBannerController bannerControllerWithBannerMessageID:self.message.identifier
                                                                                                                      displayContent:displayContent
                                                                                                                               image:prefetchedImage];
                                     }
                                 }

                                 completionHandler(result);
                             }];
}

- (void)display:(void (^)(void))completionHandler {
    if (!self.bannerController) {
        UA_LDEBUG(@"Attempted to display an in-app message banner with a nil banner controller. This means an app state change likely interrupted the prepare and display cycle before display could occur.");
        completionHandler();
        return;
    }

    [self.bannerController show:^() {
        completionHandler();
    }];
}

- (void)dealloc {
    if (self.imageCache) {
        [self.imageCache removeAllObjects];
    }

    self.imageCache = nil;
}

@end

