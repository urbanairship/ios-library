/* Copyright Airship and Contributors */

#import "UAInAppMessageAssetManager+Internal.h"
#import "UAInAppMessageAssetCache+Internal.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageDefaultPrepareAssetsDelegate.h"
#import "UAAsyncOperation+Internal.h"
#import "UAGlobal.h"

@interface UAInAppMessageAssetManager()

@property(nonatomic, strong) UAInAppMessageAssetCache *assetCache;
@property(nonatomic, strong) NSOperationQueue *queue;

@end

@implementation UAInAppMessageAssetManager

+ (instancetype)assetManager {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    return [self assetManagerWithAssetCache:[UAInAppMessageAssetCache assetCache] operationQueue:queue];
}

+ (instancetype)assetManagerWithAssetCache:(UAInAppMessageAssetCache *)assetCache operationQueue:(NSOperationQueue *)queue {
    return [[self alloc] initWithAssetCache:assetCache operationQueue:queue];
}

- (instancetype)initWithAssetCache:(UAInAppMessageAssetCache *)assetCache operationQueue:(NSOperationQueue *)queue {
    self = [super init];
    if (self) {
        self.assetCache = assetCache;
        self.queue = queue;
        self.prepareAssetsDelegate = [[UAInAppMessageDefaultPrepareAssetsDelegate alloc] init];
    }
    return self;
}

- (void)onSchedule:(UASchedule *)schedule {
    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        // Get the message for this schedule
        UAInAppMessage *message = ((UAInAppMessageScheduleInfo *)schedule.info).message;
        
        // ask delegate if we should cache the assets onSchedule
        BOOL shouldCacheOnSchedule = NO;
        id<UAInAppMessageCachePolicyDelegate> cachePolicyDelegate = self.cachePolicyDelegate;
        if (cachePolicyDelegate && [cachePolicyDelegate respondsToSelector:@selector(shouldCacheOnSchedule:)]) {
            shouldCacheOnSchedule = [cachePolicyDelegate shouldCacheOnSchedule:message];
        }
        if (!shouldCacheOnSchedule) {
            [operation finish];
            return;
        }
        
        // Do nothing if delegate doesn't implement onSchedule method
        if (!self.prepareAssetsDelegate || ![self.prepareAssetsDelegate respondsToSelector:@selector(onSchedule:assets:completionHandler:)]) {
            UA_LERR(@"Delegate must implement onSchedule");
            [operation finish];
            return;
        }
        
        // Get the assets instance for this schedule
        UAInAppMessageAssets *assets = [self.assetCache assetsForScheduleId:schedule.identifier];
        
        // Prepare the assets for this schedule
        [self.prepareAssetsDelegate onSchedule:message assets:assets completionHandler:^(UAInAppMessagePrepareResult result) {
            // Release the assets instance for this schedule but keep the assets
            [self.assetCache releaseAssets:schedule.identifier wipeFromDisk:NO];
            [operation finish];
        }];
    }];
    [self.queue addOperation:operation];
}

- (void)onPrepare:(UASchedule *)schedule completionHandler:(void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        // Do nothing if delegate doesn't implement onPrepare method
        if (!self.prepareAssetsDelegate || ![self.prepareAssetsDelegate respondsToSelector:@selector(onPrepare:assets:completionHandler:)]) {
            UA_LERR(@"Delegate must implement onPrepare");
            completionHandler(UAInAppMessagePrepareResultSuccess);
            [operation finish];
            return;
        }
        
        // Get the assets instance for this schedule
        // Get the message and assets instance for this schedule
        UAInAppMessageAssets *assets = [self.assetCache assetsForScheduleId:schedule.identifier];
        UAInAppMessage *message = ((UAInAppMessageScheduleInfo *)schedule.info).message;
        
        // Prepare the assets for this schedule
        [self.prepareAssetsDelegate onPrepare:message assets:assets completionHandler:^(UAInAppMessagePrepareResult result) {
            completionHandler(result);
            [operation finish];
        }];
    }];
    [self.queue addOperation:operation];
}

- (void)onDisplayFinished:(UASchedule *)schedule {
    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        UAInAppMessage *message;
        
        // should we cache the assets onSchedule?
        BOOL shouldPersistCacheAfterDisplay = NO;
        id<UAInAppMessageCachePolicyDelegate> cachePolicyDelegate = self.cachePolicyDelegate;
        if (cachePolicyDelegate && [cachePolicyDelegate respondsToSelector:@selector(shouldPersistCacheAfterDisplay:)]) {
            message = ((UAInAppMessageScheduleInfo *)schedule.info).message;
            shouldPersistCacheAfterDisplay = [cachePolicyDelegate shouldPersistCacheAfterDisplay:message];
        }
        
        // Release the assets instance for this schedule
        [self.assetCache releaseAssets:schedule.identifier wipeFromDisk:!shouldPersistCacheAfterDisplay];
        [operation finish];
    }];
    [self.queue addOperation:operation];
}

- (void)onScheduleFinished:(UASchedule *)schedule {
    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        // Release the assets instance for this schedule
        [self.assetCache releaseAssets:schedule.identifier wipeFromDisk:YES];
        [operation finish];
    }];
    [self.queue addOperation:operation];
}

- (void)assetsForSchedule:(UASchedule *)schedule completionHandler:(void (^)(UAInAppMessageAssets *))completionHandler {
    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        // Get and return the assets instance for this schedule
        completionHandler([self.assetCache assetsForScheduleId:schedule.identifier]);
        [operation finish];
    }];
    [self.queue addOperation:operation];
}

@end
