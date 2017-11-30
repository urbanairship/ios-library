/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageBannerAdapter.h"
#import "UAInAppMessageBannerDisplayContent.h"

@interface UAInAppMessageBannerAdapter ()

@property (nonatomic, strong) UAInAppMessage *message;

@end

@implementation UAInAppMessageBannerAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[UAInAppMessageBannerAdapter alloc] initWithMessage:message];
}

-(instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
    }

    return self;
}

- (void)prepare:(void (^)(void))completionHandler {
//    BannerDisplayContent displayContent = message.getDisplayContent();
//    if (displayContent.getImage() == null) {
//        return OK;
//    }
//
//    try {
//        if (cache == null) {
//            cache = InAppMessageCache.newCache(context, message);
//        }
//
//        File file = cache.file(IMAGE_FILE_NAME);
//        if (!FileUtils.downloadFile(new URL(displayContent.getImage().getUrl()), file)) {
//            return RETRY;
//        }
//        cache.getBundle().putString(BannerFragment.IMAGE_CACHE_KEY, Uri.fromFile(file).toString());
//    } catch (IOException e) {
//        return RETRY;
//    }
//
//    return OK;

    UAInAppMessageBannerDisplayContent *bannerContent = (UAInAppMessageBannerDisplayContent *)self.message.displayContent;

    // If there's no media call the completion handler

}

/**
 * Displays the in-app message.
 *
 * @param completionHandler the completion handler to be called when adapter has finished
 * displaying the in-app message.
 */
- (void)display:(void (^)(void))completionHandler {

}

@end
