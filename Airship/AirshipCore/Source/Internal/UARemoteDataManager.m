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
#import "UALocaleManager+Internal.h"
#import "UATaskManager.h"
#import "UATask.h"
#import "UASemaphore.h"
#import "UARemoteConfigURLManager.h"

static NSString * const UACoreDataStoreName = @"RemoteData-%@.sqlite";
static NSString * const UARemoteDataRefreshPayloadKey = @"com.urbanairship.remote-data.update";
static NSString * const UARemoteDataRefreshTask = @"UARemoteDataManager.refresh";
static NSInteger const UARemoteDataRefreshIntervalDefault = 0;
static NSString * const UARemoteDataURLMetadataKey = @"url";

// Datastore keys
static NSString * const UARemoteDataRefreshIntervalKey = @"remotedata.REFRESH_INTERVAL";
static NSString * const UARemoteDataLastRefreshMetadataKey = @"remotedata.LAST_REFRESH_METADATA";
static NSString * const UARemoteDataLastRefreshTimeKey = @"remotedata.LAST_REFRESH_TIME";
static NSString * const UARemoteDataLastRefreshAppVersionKey = @"remotedata.LAST_REFRESH_APP_VERSION";
static NSString * const UALastRemoteDataModifiedTime = @"UALastRemoteDataModifiedTime";

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
 * @param completionHandler Completion handler called after the subscriber has been notified.
 */
- (void)notifyRemoteData:(NSArray<UARemoteDataPayload *> *)remoteDataPayloads
              dispatcher:(UADispatcher *)dispatcher
       completionHandler:(void (^)(void))completionHandler {


    NSArray *sorted = [remoteDataPayloads sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UARemoteDataPayload *payload1 = (UARemoteDataPayload *)obj1;
        UARemoteDataPayload *payload2 = (UARemoteDataPayload *)obj2;
        NSUInteger indexObj1 = [self.payloadTypes indexOfObject:payload1.type];
        NSUInteger indexObj2 = [self.payloadTypes indexOfObject:payload2.type];
        if (indexObj1 == indexObj2) {
            return NSOrderedSame;
        }
        return indexObj1 > indexObj2 ? NSOrderedDescending : NSOrderedAscending;
    }];

    [dispatcher dispatchAsync:^{
        if (remoteDataPayloads.count && ![self.previousPayloads isEqualToArray:sorted]) {
            @synchronized(self) {
                if (self.publishBlock) {
                    self.publishBlock(sorted);
                }
                self.previousPayloads = sorted;
            }
        }
        completionHandler();
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
@property (nonatomic, strong) UALocaleManager *localeManager;
@property (nonatomic, strong) UATaskManager *taskManager;
@end

@implementation UARemoteDataManager

- (UARemoteDataManager *)initWithConfig:(UARuntimeConfig *)config
                              dataStore:(UAPreferenceDataStore *)dataStore
                        remoteDataStore:(UARemoteDataStore *)remoteDataStore
                    remoteDataAPIClient:(UARemoteDataAPIClient *)remoteDataAPIClient
                     notificationCenter:(NSNotificationCenter *)notificationCenter
                        appStateTracker:(UAAppStateTracker *)appStateTracker
                             dispatcher:(UADispatcher *)dispatcher
                                   date:(UADate *)date
                                 locale:(UALocaleManager *)localeManager
                            taskManager:(UATaskManager *)taskManager {

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
        self.localeManager = localeManager;
        self.taskManager = taskManager;

        // Register for locale change notification
        [self.notificationCenter addObserver:self
                                    selector:@selector(checkRefresh)
                                        name:UALocaleUpdatedEvent
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(checkRefresh)
                                        name:UAApplicationDidTransitionToForeground
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(enqueueRefreshTask)
                                        name:UARemoteConfigURLManagerConfigUpdated
                                      object:nil];

        UA_WEAKIFY(self)
        [self.taskManager registerForTaskWithID:UARemoteDataRefreshTask
                                     dispatcher:[UADispatcher serialDispatcher]
                                  launchHandler:^(id<UATask> task) {
            UA_STRONGIFY(self)
            [self handleRefreshTask:task];
        }];

        [self checkRefresh];
    }

    return self;
}

+ (UARemoteDataManager *)remoteDataManagerWithConfig:(UARuntimeConfig *)config
                                           dataStore:(UAPreferenceDataStore *)dataStore
                                       localeManager:(UALocaleManager *)localeManager {
    UARemoteDataStore *remoteDataStore = [UARemoteDataStore storeWithName:[NSString stringWithFormat:UACoreDataStoreName, config.appKey]];
    return [self remoteDataManagerWithConfig:config
                                   dataStore:dataStore
                             remoteDataStore:remoteDataStore
                         remoteDataAPIClient:[UARemoteDataAPIClient clientWithConfig:config]
                          notificationCenter:[NSNotificationCenter defaultCenter]
                             appStateTracker:[UAAppStateTracker shared]
                                  dispatcher:[UADispatcher mainDispatcher]
                                        date:[[UADate alloc] init]
                               localeManager:localeManager
                                 taskManager:[UATaskManager shared]];
}

+ (instancetype)remoteDataManagerWithConfig:(UARuntimeConfig *)config
                                  dataStore:(UAPreferenceDataStore *)dataStore
                            remoteDataStore:(UARemoteDataStore *)remoteDataStore
                        remoteDataAPIClient:(UARemoteDataAPIClient *)remoteDataAPIClient
                         notificationCenter:(NSNotificationCenter *)notificationCenter
                            appStateTracker:(UAAppStateTracker *)appStateTracker
                                 dispatcher:(UADispatcher *)dispatcher
                                       date:(UADate *)date
                              localeManager:(UALocaleManager *)localeManager
                                taskManager:(UATaskManager *)taskManager {

    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                        remoteDataStore:remoteDataStore
                    remoteDataAPIClient:remoteDataAPIClient
                     notificationCenter:notificationCenter
                        appStateTracker:appStateTracker
                             dispatcher:dispatcher
                                   date:date
                                 locale:localeManager
                            taskManager:taskManager];
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

- (NSDictionary *)lastMetadata {
    return [self.dataStore objectForKey:UARemoteDataLastRefreshMetadataKey];
}

- (void)setLastMetadata:(NSDictionary *)metadata {
    [self.dataStore setObject:metadata forKey:UARemoteDataLastRefreshMetadataKey];
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

- (void)checkRefresh {
    if ([self shouldRefresh]) {
        [self enqueueRefreshTask];
    }
}

- (void)enqueueRefreshTask {
    [self.taskManager enqueueRequestWithID:UARemoteDataRefreshTask
                                   options:[UATaskRequestOptions defaultOptions]];
}

- (BOOL)shouldRefresh {
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

- (void)handleRefreshTask:(id<UATask>)task {
    NSString *lastModified;
    if ([self isLastMetadataCurrent]) {
        lastModified = [self.dataStore stringForKey:UALastRemoteDataModifiedTime];
    }
    NSLocale *locale = self.localeManager.currentLocale;

    UASemaphore *semaphore = [UASemaphore semaphore];

    UA_WEAKIFY(self);
    UADisposable *disposable = [self.remoteDataAPIClient fetchRemoteDataWithLocale:locale
                                                                      lastModified:lastModified
                                                                 completionHandler:^(UARemoteDataResponse *response, NSError * error) {
        UA_STRONGIFY(self)
        if (error) {
            UA_LDEBUG(@"Failed to refresh remote-data with error: %@", error);
            [task taskFailed];
            [semaphore signal];
            return;
        }

        if (response.status == 304) {
            [self.dataStore setValue:self.date.now forKey:UARemoteDataLastRefreshTimeKey];
            [self.dataStore setObject:[UAUtils bundleShortVersionString] forKey:UARemoteDataLastRefreshAppVersionKey];
            [task taskCompleted];
            [semaphore signal];
        } else if (response.isSuccess) {
            NSDictionary *metadata = [self createMetadataWithRemoteDataURL:response.requestURL];
            NSArray<UARemoteDataPayload *> *payloads = [UARemoteDataPayload remoteDataPayloadsFromJSON:response.payloads
                                                                                              metadata:metadata];
            [self.remoteDataStore overwriteCachedRemoteDataWithResponse:payloads completionHandler:^(BOOL success) {
                UA_STRONGIFY(self);
                if (success) {
                    UA_LDEBUG(@"Updated remote-data with payloads: %@", payloads);

                    self.lastMetadata = metadata;
                    [self.dataStore setValue:response.lastModified forKey:UALastRemoteDataModifiedTime];
                    [self.dataStore setObject:[UAUtils bundleShortVersionString] forKey:UARemoteDataLastRefreshAppVersionKey];
                    [self.dataStore setValue:self.date.now forKey:UARemoteDataLastRefreshTimeKey];


                    // notify remote data subscribers
                    [self notifySubscribersWithRemoteData:payloads completionHandler:^{
                        [task taskCompleted];
                        [semaphore signal];
                    }];
                } else {
                    UA_LWARN(@"Failed to save updated remote-data");
                    [task taskFailed];
                    [semaphore signal];
                }
            }];
        } else {
            UA_LDEBUG(@"Failed to refresh remote-data with response: %@", response);
            if (response.isServerError) {
                [task taskFailed];
            } else {
                [task taskCompleted];
            }
            [semaphore signal];
        }
    }];

    task.expirationHandler = ^{
        [disposable dispose];
    };

    [semaphore wait];
}

- (BOOL)isMetadataCurrent:(NSDictionary *)metadata {
    NSDictionary *currentMetadata = [self createMetadataWithLocale:[self.localeManager currentLocale]];
    return [currentMetadata isEqualToDictionary:metadata];
}

- (BOOL)isLastMetadataCurrent {
    NSDictionary *metadataAtTimeOfLastRefresh = self.lastMetadata;
    NSDictionary *currentMetadata = [self createMetadataWithLocale:[self.localeManager currentLocale]];
    return [metadataAtTimeOfLastRefresh isEqualToDictionary:currentMetadata];
}

-(NSDictionary *)createMetadataWithLocale:(NSLocale *)locale {
    NSURL *URL = [self.remoteDataAPIClient remoteDataURLWithLocale:locale];
    return [self createMetadataWithRemoteDataURL:URL];
}

-(NSDictionary *)createMetadataWithRemoteDataURL:(NSURL *)remoteDataURL {
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    [metadata setValue:remoteDataURL.absoluteString forKey:UARemoteDataURLMetadataKey];
    return metadata;
}

-(BOOL)isLastAppVersionCurrent {
    NSString *appVersionAtTimeOfLastRefresh = ([self.dataStore objectForKey:UARemoteDataLastRefreshAppVersionKey]);
    NSString *currentAppVersion = [UAUtils bundleShortVersionString];
    if (currentAppVersion && ![appVersionAtTimeOfLastRefresh isEqualToString:currentAppVersion]) {
        return false;
    }

    return true;
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
        [subscription notifyRemoteData:filteredPayloads dispatcher:self.dispatcher completionHandler:^{
            dispatch_group_leave(dispatchGroup);
        }];
    }

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        completionHandler();
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

        [subscription notifyRemoteData:remoteDataPayloads dispatcher:self.dispatcher completionHandler:^{}];
    }];
}

#pragma mark -
#pragma mark UAPushableComponent

-(void)receivedRemoteNotification:(UANotificationContent *)notification completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if (!notification.notificationInfo[UARemoteDataRefreshPayloadKey]) {
        completionHandler(UIBackgroundFetchResultNoData);
    } else {
        [self enqueueRefreshTask];
        completionHandler(UIBackgroundFetchResultNewData);
    }
}

#pragma mark -

@end

