/* Copyright Airship and Contributors */

#import "UAInAppMessageDefaultPrepareAssetsDelegate.h"
#import "UAInAppMessageMediaInfo.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageModalDisplayContent.h"
#import "UAAirshipAutomationCoreImport.h"

@implementation UAInAppMessageDefaultPrepareAssetsDelegate

- (void)onSchedule:(nonnull UAInAppMessage *)message assets:(nonnull UAInAppMessageAssets *)assets completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    [self onPrepare:message assets:assets completionHandler:completionHandler];
}

- (void)onPrepare:(nonnull UAInAppMessage *)message assets:(nonnull UAInAppMessageAssets *)assets completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageMediaInfo *mediaInfo = [self getMediaInfo:message];
    
    if (!mediaInfo || (UAInAppMessageMediaInfoTypeImage != mediaInfo.type)) {
        completionHandler(UAInAppMessagePrepareResultSuccess);
        return;
    }
    
    if ([assets isCached:[NSURL URLWithString:mediaInfo.url]]) {
        completionHandler(UAInAppMessagePrepareResultSuccess);
        return;
    }

    NSURL *mediaURL = [NSURL URLWithString:mediaInfo.url];
    NSURL *cacheURL = [assets getCacheURL:mediaURL];
    if (!cacheURL) {
        completionHandler(UAInAppMessagePrepareResultCancel);
        return;
    }
    [self cacheImage:mediaURL cacheURL:cacheURL completionHandler:completionHandler];
}

- (UAInAppMessageMediaInfo *)getMediaInfo:(nonnull UAInAppMessage *)message {
    switch (message.displayType) {
        case UAInAppMessageDisplayTypeBanner: {
            UAInAppMessageBannerDisplayContent *bannerDisplayContent = (UAInAppMessageBannerDisplayContent *)message.displayContent;
            return (bannerDisplayContent) ? bannerDisplayContent.media : nil;
        }
        case UAInAppMessageDisplayTypeFullScreen: {
            UAInAppMessageFullScreenDisplayContent *fullScreenDisplayContent = (UAInAppMessageFullScreenDisplayContent *)message.displayContent;
            return (fullScreenDisplayContent) ? fullScreenDisplayContent.media : nil;
        }
        case UAInAppMessageDisplayTypeModal: {
            UAInAppMessageModalDisplayContent *modalDisplayContent = (UAInAppMessageModalDisplayContent *)message.displayContent;
            return (modalDisplayContent) ? modalDisplayContent.media : nil;
        }
        case UAInAppMessageDisplayTypeHTML: {
            break;
        }
        case UAInAppMessageDisplayTypeCustom:
            break;
    }
    return nil;
}

- (void)cacheImage:(NSURL *)assetURL cacheURL:(NSURL *)cacheURL completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
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
