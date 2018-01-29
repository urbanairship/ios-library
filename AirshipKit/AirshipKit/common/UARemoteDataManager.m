/* Copyright 2018 Urban Airship and Contributors */

#import "UARemoteDataManager+Internal.h"
#import "UARemoteDataAPIClient+Internal.h"
#import "UARemoteDataStore+Internal.h"
#import "UARemoteDataStorePayload+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

NSString * const UARemoteDataRefreshIntervalKey = @"remotedata.REFRESH_INTERVAL";
NSString * const UARemoteDataLastRefreshTimeKey = @"remotedata.LAST_REFRESH_TIME";
NSString * const UARemoteDataLastRefreshAppVersionKey = @"remotedata.LAST_REFRESH_APP_VERSION";
NSInteger const UARemoteDataRefreshIntervalDefault = 0;

@interface UARemoteDataSubscription : NSObject

///---------------------------------------------------------------------------------------
/// @name Properties
///---------------------------------------------------------------------------------------

@property (nonatomic, copy) NSSet<NSString *> *payloadTypes;
@property (nonatomic, copy) UARemoteDataPublishBlock publishBlock;
@property (nonatomic, strong) NSDate *lastNotified;

@end

@implementation UARemoteDataSubscription

+ (nonnull instancetype)remoteDataSubscriptionWithTypes:(NSArray<NSString *> *)payloadTypes publishBlock:(UARemoteDataPublishBlock)publishBlock {
    return [[UARemoteDataSubscription alloc] initWithTypes:payloadTypes block:publishBlock];
}

- (nonnull instancetype)initWithTypes:(NSArray<NSString *> *)payloadTypes block:(UARemoteDataPublishBlock)publishBlock {
    self = [super init];
    if (self) {
        self.payloadTypes = [NSSet setWithArray:payloadTypes];
        self.publishBlock = publishBlock;
        self.lastNotified = [NSDate dateWithTimeIntervalSince1970:0];
    }
    return self;
}

@end

@interface UARemoteDataManager()

/**
 * The SDK preferences data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * The remote data API client.
 */
@property (nonatomic, strong) UARemoteDataAPIClient *remoteDataAPIClient;

/**
 * Subscribers to the Remote Data Manager
 */
@property (nonatomic, strong) NSMutableArray<UARemoteDataSubscription *> *subscriptions;

/**
 * The remote data store used for caching remote data.
 */
@property (nonatomic, strong) UARemoteDataStore *remoteDataStore;

@end

@implementation UARemoteDataManager

+ (UARemoteDataManager *)remoteDataManagerWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    UARemoteDataManager *remoteDataManager;
    if (config && dataStore) {
        remoteDataManager = [[UARemoteDataManager alloc] initWithConfig:config dataStore:dataStore];
    }
    return remoteDataManager;
}

- (UARemoteDataManager *)initWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.subscriptions = [NSMutableArray array];
        self.remoteDataStore = [[UARemoteDataStore alloc] initWithConfig:config];
        self.remoteDataAPIClient = [UARemoteDataAPIClient clientWithConfig:config dataStore:dataStore];
        
        // Register for foreground notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(enterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        // if app version has changed, force a refresh
        NSString *appVersionAtTimeOfLastRefresh = ([self.dataStore objectForKey:UARemoteDataLastRefreshAppVersionKey]);
        NSString *currentAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        if (currentAppVersion && ![appVersionAtTimeOfLastRefresh isEqualToString:currentAppVersion]) {
            [self refresh];
        }
    }
    return self;
}

- (NSUInteger)remoteDataRefreshInterval {
    // if key isn't in the data store, default it.
    if (![self.dataStore keyExists:UARemoteDataRefreshIntervalKey]) {
        [self.dataStore setInteger:UARemoteDataRefreshIntervalDefault forKey:UARemoteDataRefreshIntervalKey];
    }
    
    // return the value in the datastore
    return [self.dataStore integerForKey:UARemoteDataRefreshIntervalKey];
}

- (void)setRemoteDataRefreshInterval:(NSUInteger)remoteDataRefreshInterval {
    // save in the data store
   [self.dataStore setInteger:remoteDataRefreshInterval forKey:UARemoteDataRefreshIntervalKey];
}

#pragma mark -
#pragma mark Application State

- (void)enterForeground {
    UA_LTRACE(@"Application will enter foreground.");
    
    // refresh the data from the cloud
    [self foregroundRefresh];
}

- (void)didBecomeActive {
    UA_LTRACE(@"Application did become active.");
    
    // This handles the first active. enterForeground will handle future background->foreground
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    
    // refresh the data from the cloud
    [self foregroundRefresh];
}

// foregroundRefresh refreshes only if the time since the last refresh is greater than the minimum foreground refresh interval
- (void)foregroundRefresh {
    NSDate *lastRefreshTime = ([self.dataStore objectForKey:UARemoteDataLastRefreshTimeKey])?:[NSDate distantPast];
    
    NSTimeInterval timeSinceLastRefresh = - [lastRefreshTime timeIntervalSinceNow];
    if (self.remoteDataRefreshInterval <= timeSinceLastRefresh) {
        [self refresh];
    } else {
        [self notifyRefreshDelegate:YES];
    }
}

- (nonnull UADisposable *)subscribeWithTypes:(nonnull NSArray<NSString *> *)payloadTypes block:(nonnull UARemoteDataPublishBlock)publishBlock {
    // store type and block in subscription object
    UARemoteDataSubscription *subscription = [UARemoteDataSubscription remoteDataSubscriptionWithTypes:payloadTypes publishBlock:publishBlock];

    // add object to array of subscriptions
    @synchronized(self.subscriptions) {
        [self.subscriptions addObject:subscription];
    }
    
    UA_WEAKIFY(self);
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        UA_STRONGIFY(self);
        @synchronized(subscription) {
            subscription.publishBlock = nil;
            @synchronized(self.subscriptions) {
                [self.subscriptions removeObject:subscription];
            }
        }
    }];
    

    // give subscriber any remote data we have already received
    [self fetchRemoteDataFromCacheAndNotifySubscriber:subscription];

    // return subscription object
    return disposable;
}

- (void)refresh {
    UA_WEAKIFY(self);
    [self.remoteDataAPIClient fetchRemoteData:^(NSUInteger statusCode, NSArray<UARemoteDataPayload *> *allRemoteDataFromCloud) {
        UA_STRONGIFY(self);
        if (statusCode == 200) {
            [self.dataStore setObject:[NSDate date] forKey:UARemoteDataLastRefreshTimeKey];
            NSString *currentAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
            [self.dataStore setObject:currentAppVersion forKey:UARemoteDataLastRefreshAppVersionKey];
            NSArray<UARemoteDataPayload *> *remoteDataPayloads = [UARemoteDataPayload remoteDataPayloadsFromJSON:allRemoteDataFromCloud];
            [self.remoteDataStore overwriteCachedRemoteDataWithResponse:remoteDataPayloads completionHandler:^(BOOL success) {
                UA_STRONGIFY(self);
                if (!success) {
                    [self.remoteDataAPIClient clearLastModifiedTime];
                    [self notifyRefreshDelegate:NO];
                    return;
                }

                // notify remote data subscribers
                [self notifySubscribersWithRemoteData:remoteDataPayloads completionHandler:^{
                    [self notifyRefreshDelegate:YES];
                }];
            }];
        } else {
            [self notifyRefreshDelegate:YES];
        }
    } onFailure:^{
        [self notifyRefreshDelegate:NO];
    }];
}

- (void)notifyRefreshDelegate:(BOOL)success {
    if ([self.refreshDelegate respondsToSelector:@selector(refreshComplete:)]) {
        [self.refreshDelegate refreshComplete:success];
    }
}

/**
 * Notifies all subscriptions of new remote data
 *
 * @param remoteDataPayloads Remote data from which to notify subscribers. Data must be filtered for each subscriber.
 * @param completionHandler Optional completion handler.
 */
- (void)notifySubscribersWithRemoteData:(NSArray<UARemoteDataPayload *> *)remoteDataPayloads completionHandler:(void (^)(void))completionHandler {
    NSArray *subscriptions = [self.subscriptions copy];

    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    // notify each subscription
    for (UARemoteDataSubscription *subscription in subscriptions) {
        dispatch_group_enter(dispatchGroup);

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"((type IN %@) AND (timestamp > %@))",subscription.payloadTypes,subscription.lastNotified];
        NSArray *remoteDataPayloadsForThisSubscriber = [remoteDataPayloads filteredArrayUsingPredicate:predicate];
        [self notifySubscriber:subscription remoteData:remoteDataPayloadsForThisSubscriber completionHandler:^{
            dispatch_group_leave(dispatchGroup);
        }];
    }
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        // When block executes, all subscriptions have been notified
        if (completionHandler) {
            completionHandler();
        }
    });
}

/**
 * Notifies a single remote data subscriber by prefetching on the private
 * context and then notifying on the main context.
 *
 * @param subscription The subscriber's subscription
 */
- (void)fetchRemoteDataFromCacheAndNotifySubscriber:(UARemoteDataSubscription *)subscription {
    // only send remote data newer than cached last modified timestamps
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"((type IN %@) AND (timestamp > %@))",subscription.payloadTypes,subscription.lastNotified];
    
    UA_WEAKIFY(self);
    [self.remoteDataStore fetchRemoteDataFromCacheWithPredicate:fetchPredicate completionHandler:^(NSArray<UARemoteDataStorePayload *> *payloads) {
        UA_STRONGIFY(self);
        NSMutableArray<UARemoteDataPayload *> *remoteDataPayloads = [NSMutableArray arrayWithCapacity:payloads.count];
        
        for (UARemoteDataStorePayload *payload in payloads) {
            UARemoteDataPayload *remoteData = [[UARemoteDataPayload alloc] initWithType:payload.type timestamp:payload.timestamp data:payload.data];
            [remoteDataPayloads addObject:remoteData];
        }
        
        [self notifySubscriber:subscription remoteData:remoteDataPayloads completionHandler:nil];
    }];
}

/**
 * Notifies a single remote data subscriber.
 *
 * @param subscription The subscriber's subscription
 * @param remoteDataPayloads The remote data payloads to be sent to the subscriber.
 * @param completionHandler Optional completion handler called after the subscriber has been notified.
 */
- (void)notifySubscriber:(UARemoteDataSubscription *)subscription remoteData:(NSArray<UARemoteDataPayload *> *)remoteDataPayloads completionHandler:(void (^)(void))completionHandler {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (remoteDataPayloads.count) {
            @synchronized(subscription) {
                if (subscription.publishBlock) {
                    subscription.publishBlock(remoteDataPayloads);
                }
                subscription.lastNotified = [remoteDataPayloads valueForKeyPath:@"@max.timestamp"];
            }
        }
        if (completionHandler) {
            completionHandler();
        }
    });
}

@end
