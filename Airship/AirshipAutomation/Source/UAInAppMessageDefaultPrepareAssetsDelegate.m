/* Copyright Airship and Contributors */

#import "UAInAppMessageDefaultPrepareAssetsDelegate.h"
#import "UAInAppMessageMediaInfo.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageModalDisplayContent.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageAirshipLayoutDisplayContent+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@implementation UAInAppMessageDefaultPrepareAssetsDelegate

- (void)onSchedule:(nonnull UAInAppMessage *)message assets:(nonnull UAInAppMessageAssets *)assets completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    [self onPrepare:message assets:assets completionHandler:completionHandler];
}

- (void)onPrepare:(nonnull UAInAppMessage *)message
           assets:(nonnull UAInAppMessageAssets *)assets
completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    
    NSSet *cachableURLs = [self cacheableURLFromMessage:message];
    if (!cachableURLs.count) {
        completionHandler(UAInAppMessagePrepareResultSuccess);
        return;
    }
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    __block UAInAppMessagePrepareResult result = UAInAppMessagePrepareResultSuccess;

    for (NSString *url in cachableURLs) {
        dispatch_group_enter(dispatchGroup);
        
        NSURL *imageURL = [NSURL URLWithString:url];
        NSURL *assetsURL = [assets getCacheURL:imageURL];

        if (!imageURL || !assetsURL || [assets isCached:imageURL]) {
            dispatch_group_leave(dispatchGroup);
            continue;
        }
        
        [self cacheImage:imageURL
                cacheURL:assetsURL
       completionHandler:^(UAInAppMessagePrepareResult assetResult) {
            @synchronized (cachableURLs) {
                switch(assetResult) {
                    case UAInAppMessagePrepareResultSuccess:
                        break;
                    case UAInAppMessagePrepareResultInvalidate:
                        break;
                    case UAInAppMessagePrepareResultRetry:
                        if (result != UAInAppMessagePrepareResultCancel) {
                            result = UAInAppMessagePrepareResultRetry;
                        }
                        break;
                    case UAInAppMessagePrepareResultCancel:
                        result = UAInAppMessagePrepareResultCancel;
                        break;
                    
                }
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        completionHandler(result);
    });
}

- (NSSet<NSString *> *)cacheableURLFromMessage:(UAInAppMessage *)message {
    switch (message.displayType) {
        case UAInAppMessageDisplayTypeBanner: {
            UAInAppMessageBannerDisplayContent *bannerDisplayContent = (UAInAppMessageBannerDisplayContent *)message.displayContent;
            return [self cacheableURLFromMediaInfo:bannerDisplayContent.media];
        }
        case UAInAppMessageDisplayTypeFullScreen: {
            UAInAppMessageFullScreenDisplayContent *fullScreenDisplayContent = (UAInAppMessageFullScreenDisplayContent *)message.displayContent;
            return [self cacheableURLFromMediaInfo:fullScreenDisplayContent.media];
        }
        case UAInAppMessageDisplayTypeModal: {
            UAInAppMessageModalDisplayContent *modalDisplayContent = (UAInAppMessageModalDisplayContent *)message.displayContent;
            return [self cacheableURLFromMediaInfo:modalDisplayContent.media];
        }
        case UAInAppMessageDisplayTypeAirshipLayout: {
            if (@available(iOS 13.0.0, *)) {
                UAInAppMessageAirshipLayoutDisplayContent *displayContent = (UAInAppMessageAirshipLayoutDisplayContent *)message.displayContent;
                
                if (displayContent != nil) {
                    NSMutableSet *images = [NSMutableSet set];
                    for (UAURLInfo *info in [UAThomas urlsWithJson:displayContent.layout error:nil]) {
                        if (info.urlType == UrlTypesImage) {
                            [images addObject:info.url];
                        }
                    }
                    return images;
                    
                }
            }
        }
        case UAInAppMessageDisplayTypeHTML:
        case UAInAppMessageDisplayTypeCustom:
            break;
    }
    return nil;
}

- (NSSet<NSString *> *)cacheableURLFromMediaInfo:(nullable UAInAppMessageMediaInfo *)mediaInfo {
    if (mediaInfo && UAInAppMessageMediaInfoTypeImage == mediaInfo.type) {
        return [NSSet setWithObject:mediaInfo.url];
    }
    
    return nil;
}


- (void)cacheImage:(NSURL *)assetURL
          cacheURL:(NSURL *)cacheURL
 completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    [[[NSURLSession sharedSession] downloadTaskWithURL:assetURL completionHandler:^(NSURL * _Nullable temporaryFileLocation, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            UA_LERR(@"Error prefetching media at URL: %@, %@", assetURL, error.localizedDescription);
            completionHandler(UAInAppMessagePrepareResultCancel);
            return;
        }
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
            NSInteger status = httpResponse.statusCode;
            if (status >= 500 && status <= 599) {
                completionHandler(UAInAppMessagePrepareResultRetry);
                return;
            } else if (status != 200) {
                completionHandler(UAInAppMessagePrepareResultCancel);
                return;
            }
        }
        
        NSString *cachedPath = [cacheURL path];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        
        // Remove anything currently existing at the cache path
        if ([fm fileExistsAtPath:cachedPath]) {
            [fm removeItemAtPath:cachedPath error:&error];
            if (error) {
                UA_LERR(@"Error removing file %@: %@", cachedPath, error.localizedDescription);
                completionHandler(UAInAppMessagePrepareResultCancel);
                return;
            }
        }
        
        // Move temp file to cache location
        [fm moveItemAtPath:temporaryFileLocation.path toPath:cachedPath error:&error];
        if (error) {
            UA_LERR(@"Error moving temp file %@ to %@: %@", temporaryFileLocation.path, cachedPath, error.localizedDescription);
            completionHandler(UAInAppMessagePrepareResultCancel);
            return;
        }
        
        completionHandler(UAInAppMessagePrepareResultSuccess);
    }] resume];
}

@end
