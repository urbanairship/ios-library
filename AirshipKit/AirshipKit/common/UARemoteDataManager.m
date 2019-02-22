/* Copyright Urban Airship and Contributors */

#import "UARemoteDataManager+Internal.h"
#import "UARemoteDataAPIClient+Internal.h"
#import "UARemoteDataStore+Internal.h"
#import "UARemoteDataStorePayload+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

NSString * const kUACoreDataStoreName = @"RemoteData-%@.sqlite";
NSString * const UARemoteDataRefreshIntervalKey = @"remotedata.REFRESH_INTERVAL";
NSString * const UARemoteDataLastRefreshTimeKey = @"remotedata.LAST_REFRESH_TIME";
NSString * const UARemoteDataLastRefreshAppVersionKey = @"remotedata.LAST_REFRESH_APP_VERSION";
NSString * const UARemoteDataLastRefreshAppLocaleKey = @"remotedata.LAST_REFRESH_APP_LOCALE";

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
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UARemoteDataAPIClient *remoteDataAPIClient;
@property (nonatomic, strong) NSMutableArray<UARemoteDataSubscription *> *subscriptions;
@property (nonatomic, strong) UARemoteDataStore *remoteDataStore;
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UARemoteDataManager

- (UARemoteDataManager *)initWithConfig:(UAConfig *)config
                              dataStore:(UAPreferenceDataStore *)dataStore
                        remoteDataStore:(UARemoteDataStore *)remoteDataStore
                    remoteDataAPIClient:(UARemoteDataAPIClient *)remoteDataAPIClient
                     notificationCenter:(NSNotificationCenter *)notificationCenter
                             dispatcher:(UADispatcher *)dispatcher {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.subscriptions = [NSMutableArray array];
        self.remoteDataStore = remoteDataStore;
        self.dispatcher = dispatcher;
        self.notificationCenter = notificationCenter;
        self.remoteDataAPIClient = remoteDataAPIClient;

        // Register for foreground notifications
        [self.notificationCenter addObserver:self
                                    selector:@selector(enterForeground)
                                        name:UIApplicationWillEnterForegroundNotification
                                      object:nil];
        [self.notificationCenter addObserver:self
                                    selector:@selector(didBecomeActive)
                                        name:UIApplicationDidBecomeActiveNotification
                                      object:nil];

        // Register for locale change notification
        [self.notificationCenter addObserver:self
                                    selector:@selector(localeRefresh)
                                        name:NSCurrentLocaleDidChangeNotification
                                      object:nil];

        // if app version has changed, force a refresh
        NSString *appVersionAtTimeOfLastRefresh = ([self.dataStore objectForKey:UARemoteDataLastRefreshAppVersionKey]);
        NSString *currentAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        if (currentAppVersion && ![appVersionAtTimeOfLastRefresh isEqualToString:currentAppVersion]) {
            [self refresh];
        }

        // if app locale identifier has changed while the app was terminated, force a refresh
        NSString *appLocaleAtTimeOfLastRefresh = ([self.dataStore objectForKey:UARemoteDataLastRefreshAppLocaleKey]);
        NSString *currentAppLocale = [NSLocale currentLocale].localeIdentifier;
        if (currentAppLocale && ![appLocaleAtTimeOfLastRefresh isEqualToString:currentAppLocale]) {
            [self refresh];
        }
    }
    return self;
}

+ (UARemoteDataManager *)remoteDataManagerWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    UARemoteDataStore *remoteDataStore = [UARemoteDataStore storeWithName:[NSString stringWithFormat:kUACoreDataStoreName, config.appKey]];
    return [self remoteDataManagerWithConfig:config
                                   dataStore:dataStore
                             remoteDataStore:remoteDataStore
                         remoteDataAPIClient:[UARemoteDataAPIClient clientWithConfig:config dataStore:dataStore]
                          notificationCenter:[NSNotificationCenter defaultCenter]
                                  dispatcher:[UADispatcher mainDispatcher]];
}


+ (instancetype)remoteDataManagerWithConfig:(UAConfig *)config
                                  dataStore:(UAPreferenceDataStore *)dataStore
                            remoteDataStore:(UARemoteDataStore *)remoteDataStore
                        remoteDataAPIClient:(UARemoteDataAPIClient *)remoteDataAPIClient
                         notificationCenter:(NSNotificationCenter *)notificationCenter
                                 dispatcher:(UADispatcher *)dispatcher {

    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                        remoteDataStore:remoteDataStore
                    remoteDataAPIClient:remoteDataAPIClient
                     notificationCenter:notificationCenter
                             dispatcher:dispatcher];
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
    [self.notificationCenter removeObserver:self
                                       name:UIApplicationDidBecomeActiveNotification
                                     object:nil];

    // refresh the data from the cloud
    [self foregroundRefresh];
}

// foregroundRefresh refreshes only if the time since the last refresh is greater than the minimum foreground refresh interval
- (void)foregroundRefresh {
    [self foregroundRefreshWithCompletionHandler:nil];
}

- (void)localeRefresh {
    // if app locale has changed, force a refresh
    [self refresh];
}

- (void)foregroundRefreshWithCompletionHandler:(nullable void(^)(BOOL success))completionHandler {
    NSDate *lastRefreshTime = ([self.dataStore objectForKey:UARemoteDataLastRefreshTimeKey])?:[NSDate distantPast];

    NSTimeInterval timeSinceLastRefresh = - [lastRefreshTime timeIntervalSinceNow];
    if (self.remoteDataRefreshInterval <= timeSinceLastRefresh) {
        [self refreshWithCompletionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(YES);
        }
    }
}

- (void)refresh {
    [self refreshWithCompletionHandler:nil];
}

- (void)refreshWithCompletionHandler:(void(^)(BOOL success))completionHandler {
    UA_WEAKIFY(self);
    [self.remoteDataAPIClient fetchRemoteData:^(NSUInteger statusCode, NSArray<UARemoteDataPayload *> *allRemoteDataFromCloud) {
        UA_STRONGIFY(self);
        if (statusCode == 200) {
            [self.dataStore setObject:[NSDate date] forKey:UARemoteDataLastRefreshTimeKey];

            NSString *currentAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
            [self.dataStore setObject:currentAppVersion forKey:UARemoteDataLastRefreshAppVersionKey];

            NSString *currentAppLocale = [NSLocale currentLocale].localeIdentifier;
            [self.dataStore setObject:currentAppLocale forKey:UARemoteDataLastRefreshAppLocaleKey];

            NSArray<UARemoteDataPayload *> *remoteDataPayloads = [UARemoteDataPayload remoteDataPayloadsFromJSON:allRemoteDataFromCloud];
            [self.remoteDataStore overwriteCachedRemoteDataWithResponse:remoteDataPayloads completionHandler:^(BOOL success) {
                UA_STRONGIFY(self);
                if (!success) {
                    [self.remoteDataAPIClient clearLastModifiedTime];
                    if (completionHandler) {
                        completionHandler(NO);
                    }
                    return;
                }

                // notify remote data subscribers
                [self notifySubscribersWithRemoteData:remoteDataPayloads completionHandler:^{
                    if (completionHandler) {
                        completionHandler(YES);
                    }
                }];
            }];
        } else {
            // statusCode == 304
            if (completionHandler) {
                completionHandler(YES);
            }
        }
    } onFailure:^{
        if (completionHandler) {
            completionHandler(NO);
        }
    }];
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
- (void)notifySubscriber:(UARemoteDataSubscription *)subscription
              remoteData:(NSArray<UARemoteDataPayload *> *)remoteDataPayloads
       completionHandler:(void (^)(void))completionHandler {

    [self.dispatcher dispatchAsync:^{
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
    }];
}

@end

