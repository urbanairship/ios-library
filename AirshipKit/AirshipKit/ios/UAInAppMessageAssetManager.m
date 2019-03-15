/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageAssetManager+Internal.h"
#import "UAInAppMessageAssetCache+Internal.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageDefaultPrepareAssetsDelegate.h"
#import "UAGlobal.h"

@interface UAInAppMessageAssetManager()

@property(nonatomic, strong) UAInAppMessageAssetCache *assetCache;

@end

@implementation UAInAppMessageAssetManager

+ (instancetype)assetManager {
    return [self assetManagerWithAssetCache:[UAInAppMessageAssetCache assetCache]];
}

+ (instancetype)assetManagerWithAssetCache:(UAInAppMessageAssetCache *)assetCache {
    return [[self alloc] initWithAssetCache:assetCache];
}

- (instancetype)initWithAssetCache:(UAInAppMessageAssetCache *)assetCache {
    self = [super init];
    if (self) {
        self.assetCache = assetCache;
        self.prepareAssetsDelegate = [[UAInAppMessageDefaultPrepareAssetsDelegate alloc] init];
    }
    return self;
}

- (void)onSchedule:(UASchedule *)schedule completionHandler:(void (^)(UAInAppMessagePrepareResult))completionHandler {
    // Get the message for this schedule
    UAInAppMessage *message = ((UAInAppMessageScheduleInfo *)schedule.info).message;

    // ask delegate if we should cache the assets onSchedule
    BOOL shouldCacheOnSchedule = NO;
    if (self.cachePolicyDelegate && [self.cachePolicyDelegate respondsToSelector:@selector(shouldCacheOnSchedule:)]) {
        shouldCacheOnSchedule = [self.cachePolicyDelegate shouldCacheOnSchedule:message];
    }
    if (!shouldCacheOnSchedule) {
        completionHandler(UAInAppMessagePrepareResultSuccess);
        return;
    }
    
    // Do nothing if delegate doesn't implement onSchedule method
    if (!self.prepareAssetsDelegate || ![self.prepareAssetsDelegate respondsToSelector:@selector(onSchedule:assets:completionHandler:)]) {
        UA_LERR(@"Delegate must implement onSchedule");
        completionHandler(UAInAppMessagePrepareResultSuccess);
        return;
    }

    // Get the assets instance for this schedule
    UAInAppMessageAssets *assets = [self.assetCache assetsForScheduleId:schedule.identifier];
    
    // Prepare the assets for this schedule
    [self.prepareAssetsDelegate onSchedule:message assets:assets completionHandler:^(UAInAppMessagePrepareResult result) {
        // Release the assets instance for this schedule but keep the assets
        [self.assetCache releaseAssets:schedule.identifier wipeFromDisk:NO];
        
        completionHandler(result);
    }];
}

- (void)onPrepare:(UASchedule *)schedule completionHandler:(void (^)(UAInAppMessagePrepareResult))completionHandler {
    // Do nothing if delegate doesn't implement onPrepare method
    if (!self.prepareAssetsDelegate || ![self.prepareAssetsDelegate respondsToSelector:@selector(onPrepare:assets:completionHandler:)]) {
        UA_LERR(@"Delegate must implement onPrepare");
        completionHandler(UAInAppMessagePrepareResultSuccess);
        return;
    }
    
    // Get the assets instance for this schedule
    // Get the message and assets instance for this schedule
    UAInAppMessageAssets *assets = [self.assetCache assetsForScheduleId:schedule.identifier];
    UAInAppMessage *message = ((UAInAppMessageScheduleInfo *)schedule.info).message;

    // Prepare the assets for this schedule
    [self.prepareAssetsDelegate onPrepare:message assets:assets completionHandler:^(UAInAppMessagePrepareResult result) {
        completionHandler(result);
    }];
}

- (void)onDisplayFinished:(UASchedule *)schedule {
    UAInAppMessage *message;
    
    // should we cache the assets onSchedule?
    BOOL shouldPersistCacheAfterDisplay = NO;
    if (self.cachePolicyDelegate && [self.cachePolicyDelegate respondsToSelector:@selector(shouldPersistCacheAfterDisplay:)]) {
        message = ((UAInAppMessageScheduleInfo *)schedule.info).message;
        shouldPersistCacheAfterDisplay = [self.cachePolicyDelegate shouldPersistCacheAfterDisplay:message];
    }
    
    // Release the assets instance for this schedule
    [self.assetCache releaseAssets:schedule.identifier wipeFromDisk:!shouldPersistCacheAfterDisplay];
}

- (void)onScheduleFinished:(UASchedule *)schedule {
    // Release the assets instance for this schedule
    [self.assetCache releaseAssets:schedule.identifier wipeFromDisk:YES];
}

- (UAInAppMessageAssets *)assetsForSchedule:(UASchedule *)schedule {
    // Get and return the assets instance for this schedule
    return [self.assetCache assetsForScheduleId:schedule.identifier];
}

@end
