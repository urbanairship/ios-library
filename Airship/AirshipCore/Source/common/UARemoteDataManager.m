/* Copyright Airship and Contributors */

#import "UARemoteDataManager+Internal.h"
#import "UARemoteDataAPIClient+Internal.h"
#import "UARemoteDataStore+Internal.h"
#import "UARemoteDataStorePayload+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAirshipVersion.h"
#import "UAUtils+Internal.h"
#import "UAAppStateTracker.h"

NSString * const kUACoreDataStoreName = @"RemoteData-%@.sqlite";
NSString * const UARemoteDataRefreshIntervalKey = @"remotedata.REFRESH_INTERVAL";
NSString * const UARemoteDataLastRefreshTimeKey = @"remotedata.LAST_REFRESH_TIME";
NSString * const UARemoteDataLastRefreshMetadataKey = @"remotedata.LAST_REFRESH_METADATA";
NSString * const UARemoteDataLastRefreshAppVersionKey = @"remotedata.LAST_REFRESH_APP_VERSION";
NSString * const UARemoteDataRefreshPayloadKey = @"com.urbanairship.remote-data.update";

NSInteger const UARemoteDataRefreshIntervalDefault = 0;

@interface UARemoteDataSubscription : NSObject

///---------------------------------------------------------------------------------------
/// @name Properties
///---------------------------------------------------------------------------------------

@property (nonatomic, copy) NSArray<NSString *> *payloadTypes;
@property (nonatomic, copy) UARemoteDataPublishBlock publishBlock;
@property (nonatomic, copy) NSArray<UARemoteDataPayload *> *previousPayloads;

@end

@implementation UARemoteDataSubscription

+ (nonnull instancetype)remoteDataSubscriptionWithTypes:(NSArray<NSString *> *)payloadTypes publishBlock:(UARemoteDataPublishBlock)publishBlock {
    return [[UARemoteDataSubscription alloc] initWithTypes:payloadTypes block:publishBlock];
}

- (nonnull instancetype)initWithTypes:(NSArray<NSString *> *)payloadTypes block:(UARemoteDataPublishBlock)publishBlock {
    self = [super init];
    if (self) {
        self.payloadTypes = payloadTypes;
        self.publishBlock = publishBlock;
    }
    return self;
}

/**
 * Notifies a single remote data subscriber.
 *
 * @param remoteDataPayloads The remote data payloads to be sent to the subscriber.
 * @param completionHandler Optional completion handler called after the subscriber has been notified.
 */
- (void)notifyRemoteData:(NSArray<UARemoteDataPayload *> *)remoteDataPayloads
              dispatcher:(UADispatcher *)dispatcher
       completionHandler:(void (^)(void))completionHandler {

    [dispatcher dispatchAsync:^{
        if (remoteDataPayloads.count && ![self.previousPayloads isEqualToArray:remoteDataPayloads]) {
            @synchronized(self) {
                if (self.publishBlock) {
                    self.publishBlock(remoteDataPayloads);
                }
                self.previousPayloads = remoteDataPayloads;
            }
        }
        if (completionHandler) {
            completionHandler();
        }
    }];
}

@end

@interface UARemoteDataManager()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UARemoteDataAPIClient *remoteDataAPIClient;
@property (nonatomic, strong) NSMutableArray<UARemoteDataSubscription *> *subscriptions;
@property (nonatomic, strong) UARemoteDataStore *remoteDataStore;
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) UADate *date;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UAAppStateTracker *appStateTracker;

@end

@implementation UARemoteDataManager

- (UARemoteDataManager *)initWithConfig:(UARuntimeConfig *)config
                              dataStore:(UAPreferenceDataStore *)dataStore
                        remoteDataStore:(UARemoteDataStore *)remoteDataStore
                    remoteDataAPIClient:(UARemoteDataAPIClient *)remoteDataAPIClient
                     notificationCenter:(NSNotificationCenter *)notificationCenter
                        appStateTracker:(UAAppStateTracker *)appStateTracker
                             dispatcher:(UADispatcher *)dispatcher
                                   date:(UADate *)date {
    self = [super initWithDataStore:dataStore];
    if (self) {
        self.dataStore = dataStore;
        self.subscriptions = [NSMutableArray array];
        self.remoteDataStore = remoteDataStore;
        self.dispatcher = dispatcher;
        self.date = date;
        self.notificationCenter = notificationCenter;
        self.remoteDataAPIClient = remoteDataAPIClient;
        self.appStateTracker = appStateTracker;

        // Register for locale change notification
        [self.notificationCenter addObserver:self
                                    selector:@selector(localeRefresh)
                                        name:NSCurrentLocaleDidChangeNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationWillEnterForeground)
                                        name:UAApplicationDidTransitionToForeground
                                      object:nil];

        if ([self shouldRefresh]) {
            [self refresh];
        }
    }

    return self;
}

+ (UARemoteDataManager *)remoteDataManagerWithConfig:(UARuntimeConfig *)config
                                           dataStore:(UAPreferenceDataStore *)dataStore {
    UARemoteDataStore *remoteDataStore = [UARemoteDataStore storeWithName:[NSString stringWithFormat:kUACoreDataStoreName, config.appKey]];
    return [self remoteDataManagerWithConfig:config
                                   dataStore:dataStore
                             remoteDataStore:remoteDataStore
                         remoteDataAPIClient:[UARemoteDataAPIClient clientWithConfig:config dataStore:dataStore]
                          notificationCenter:[NSNotificationCenter defaultCenter]
                             appStateTracker:[UAAppStateTracker shared]
                                  dispatcher:[UADispatcher mainDispatcher]
                                        date:[[UADate alloc] init]];
}

+ (instancetype)remoteDataManagerWithConfig:(UARuntimeConfig *)config
                                  dataStore:(UAPreferenceDataStore *)dataStore
                            remoteDataStore:(UARemoteDataStore *)remoteDataStore
                        remoteDataAPIClient:(UARemoteDataAPIClient *)remoteDataAPIClient
                         notificationCenter:(NSNotificationCenter *)notificationCenter
                            appStateTracker:(UAAppStateTracker *)appStateTracker
                                 dispatcher:(UADispatcher *)dispatcher
                                       date:(UADate *)date {

    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                        remoteDataStore:remoteDataStore
                    remoteDataAPIClient:remoteDataAPIClient
                     notificationCenter:notificationCenter
                        appStateTracker:appStateTracker
                             dispatcher:dispatcher
                                   date:date];
}

- (NSUInteger)remoteDataRefreshInterval {
    // if key isn't in the data store, default it.
    if (![self.dataStore keyExists:UARemoteDataRefreshIntervalKey]) {
        [self.dataStore setInteger:UARemoteDataRefreshIntervalDefault forKey:UARemoteDataRefreshIntervalKey];
    }

    // return the value in the datastore
    return [self.dataStore integerForKey:UARemoteDataRefreshIntervalKey];
}

- (NSDate *)lastModified {
    return [self.dataStore objectForKey:UARemoteDataLastRefreshTimeKey];
}

- (NSDictionary *)lastMetadata {
    return [self.dataStore objectForKey:UARemoteDataLastRefreshMetadataKey];
}

- (void)setLastMetadata:(NSDictionary *)metadata {
    [self.dataStore setObject:metadata forKey:UARemoteDataLastRefreshMetadataKey];
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

- (void)applicationWillEnterForeground {
    UA_LTRACE(@"Application will enter foreground.");

    // refresh the data from the cloud
    [self foregroundRefresh];
}

// foregroundRefresh refreshes only if the time since the last refresh is greater than the minimum foreground refresh interval
- (void)foregroundRefresh {
    [self foregroundRefreshWithCompletionHandler:nil];
}

- (void)localeRefresh {
    if ([self shouldRefresh]) {
        // if app locale has changed, force a refresh
        [self refresh];
    }
}

- (void)foregroundRefreshWithCompletionHandler:(nullable void(^)(BOOL success))completionHandler {
    if ([self shouldRefresh]) {
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

-(BOOL)shouldRefresh {
    NSDate *lastRefreshTime = [self.dataStore objectForKey:UARemoteDataLastRefreshTimeKey] ?: [NSDate distantPast];
    NSTimeInterval timeSinceLastRefresh = -([lastRefreshTime timeIntervalSinceDate:self.date.now]);

    if (self.appStateTracker.state != UAApplicationStateActive) {
        return false;
    }

    if (self.remoteDataRefreshInterval <= timeSinceLastRefresh) {
        return true;
    }
 
    if (![self isLastAppVersionCurrent]) {
        return true;
    }

    if (![self isLastMetadataCurrent]) {
        return true;
    }

    return false;
}

- (void)onNewData:(NSArray<UARemoteDataPayload *> *)remoteData
         metadata:(NSDictionary *)metadata
     lastModified:(NSDate *)lastModified
completionHandler:(void(^)(BOOL success))completionHandler {
    // The result from this can be empty if any expected fields are missing from JSON
    NSArray<UARemoteDataPayload *> *payloads = [UARemoteDataPayload remoteDataPayloadsFromJSON:remoteData metadata:metadata];

    UA_WEAKIFY(self);
    [self.remoteDataStore overwriteCachedRemoteDataWithResponse:payloads completionHandler:^(BOOL success) {
        UA_STRONGIFY(self);
        if (!success) {
            [self.remoteDataAPIClient clearLastModifiedTime];
            if (completionHandler) {
                completionHandler(NO);
            }
            return;
        }

        [self.dataStore setObject:lastModified forKey:UARemoteDataLastRefreshTimeKey];
        self.lastMetadata = metadata;

        // notify remote data subscribers
        [self notifySubscribersWithRemoteData:payloads completionHandler:^{
            if (completionHandler) {
                completionHandler(YES);
            }
        }];
    }];
}

- (void)refreshWithCompletionHandler:(void(^)(BOOL success))completionHandler {
    UA_WEAKIFY(self);

    if (![self isLastMetadataCurrent]) {
        [self.remoteDataAPIClient clearLastModifiedTime];
    }

    [self.remoteDataAPIClient fetchRemoteData:^(NSUInteger statusCode, NSArray<UARemoteDataPayload *> *allRemoteDataFromCloud) {
        UA_STRONGIFY(self);
        if (statusCode == 200) {
            NSString *currentAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
            [self.dataStore setObject:currentAppVersion forKey:UARemoteDataLastRefreshAppVersionKey];

            NSDictionary *metadata = [self createMetadata:[NSLocale autoupdatingCurrentLocale]];

            [self onNewData:allRemoteDataFromCloud metadata:metadata lastModified:[NSDate date] completionHandler:completionHandler];
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

-(BOOL)isLastAppVersionCurrent {
    NSString *appVersionAtTimeOfLastRefresh = ([self.dataStore objectForKey:UARemoteDataLastRefreshAppVersionKey]);
    NSString *currentAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (currentAppVersion && ![appVersionAtTimeOfLastRefresh isEqualToString:currentAppVersion]) {
        return false;
    }

    return true;
}


-(BOOL)isMetadataCurrent:(NSDictionary *)metadata {
    NSDictionary *currentMetadata = [self createMetadata:[NSLocale autoupdatingCurrentLocale]];

    return [currentMetadata isEqualToDictionary:metadata];
}

-(BOOL)isLastMetadataCurrent {
    NSDictionary *metadataAtTimeOfLastRefresh = self.lastMetadata;
    NSDictionary *currentMetadata = [self createMetadata:[NSLocale autoupdatingCurrentLocale]];

    return [metadataAtTimeOfLastRefresh isEqualToDictionary:currentMetadata];
}

-(NSDictionary *)createMetadata:(NSLocale *)locale {
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];

    [metadata setValue:[UAUtils nilIfEmpty:locale.languageCode] forKey:UARemoteDataMetadataLanguageKey];
    [metadata setValue:[UAUtils nilIfEmpty:locale.countryCode] forKey:UARemoteDataMetadataCountryKey];
    [metadata setObject:[UAirshipVersion get] forKey:UARemoteDataMetadataSDKVersionKey];

    return metadata;
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

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(type IN %@)", subscription.payloadTypes];
        NSArray *filteredPayloads = [remoteDataPayloads filteredArrayUsingPredicate:predicate];

        NSArray *sorted = [filteredPayloads sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            UARemoteDataPayload *payload1 = (UARemoteDataPayload *)obj1;
            UARemoteDataPayload *payload2 = (UARemoteDataPayload *)obj2;
            NSUInteger indexObj1 = [subscription.payloadTypes indexOfObject:payload1.type];
            NSUInteger indexObj2 = [subscription.payloadTypes indexOfObject:payload2.type];
            if (indexObj1 == indexObj2) {
                return NSOrderedSame;
            }
            return indexObj1 > indexObj2 ? NSOrderedDescending : NSOrderedAscending;
        }];

        [subscription notifyRemoteData:sorted dispatcher:self.dispatcher completionHandler:^{
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
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"(type IN %@)", subscription.payloadTypes];

    UA_WEAKIFY(self);
    [self.remoteDataStore fetchRemoteDataFromCacheWithPredicate:fetchPredicate completionHandler:^(NSArray<UARemoteDataStorePayload *> *payloads) {
        UA_STRONGIFY(self);
        NSMutableArray<UARemoteDataPayload *> *remoteDataPayloads = [NSMutableArray arrayWithCapacity:payloads.count];

        for (UARemoteDataStorePayload *payload in payloads) {
            UARemoteDataPayload *remoteData = [[UARemoteDataPayload alloc] initWithType:payload.type timestamp:payload.timestamp data:payload.data metadata:payload.metadata];
            [remoteDataPayloads addObject:remoteData];
        }

        [subscription notifyRemoteData:remoteDataPayloads dispatcher:self.dispatcher completionHandler:nil];
    }];
}

#pragma mark -
#pragma mark UAPushableComponent

-(void)receivedRemoteNotification:(UANotificationContent *)notification completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if (!notification.notificationInfo[UARemoteDataRefreshPayloadKey]) {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }

    [self refreshWithCompletionHandler:^(BOOL success) {
        completionHandler(success ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultFailed);
    }];
}

#pragma mark -

@end
