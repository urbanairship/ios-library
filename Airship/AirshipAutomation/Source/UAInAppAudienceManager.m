/* Copyright Airship and Contributors */

#import "UAInAppAudienceManager+Internal.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UATagGroupsLookupResponse+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#define kUAInAppAudienceManagerEnabledKey @"com.urbanairship.tag_groups.FETCH_ENABLED"

#define kUAInAppAudienceManagerPreferLocalTagDataTimeKey @"com.urbanairship.tag_groups.PREFER_LOCAL_TAG_DATA_TIME"


NSTimeInterval const UAInAppAudienceManagerDefaultPreferLocalAudienceDataTimeSeconds = 60 * 10; // 10 minutes

NSString * const UAInAppAudienceManagerErrorDomain = @"com.urbanairship.in_app_audience_manager";

@interface UAInAppAudienceManager ()

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAInAppAudienceHistorian *historian;
@property (nonatomic, strong) UATagGroupsLookupAPIClient *lookupAPIClient;
@property (nonatomic, strong) UATagGroupsLookupResponseCache *cache;
@property (nonatomic, strong) UADate *currentTime;
@property (nonatomic, strong) UANamedUser *namedUser;
@property (nonatomic, strong) UAChannel *channel;

@property (nonatomic, readonly) NSTimeInterval maxSentMutationAge;

@end

@implementation UAInAppAudienceManager

- (instancetype)initWithAPIClient:(UATagGroupsLookupAPIClient *)client
                        dataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                        namedUser:(UANamedUser *)namedUser
                            cache:(UATagGroupsLookupResponseCache *)cache
                        historian:(UAInAppAudienceHistorian *)historian
                      currentTime:(UADate *)currentTime {

    self = [super init];

    if (self) {
        self.dataStore = dataStore;
        self.cache = cache;
        self.historian = historian;
        self.lookupAPIClient = client;
        self.currentTime = currentTime;
        self.namedUser = namedUser;
        self.channel = channel;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(namedUserChanged:)
                                                     name:UANamedUserIdentifierChangedNotification
                                                   object:nil];
    }

    return self;
}

+ (instancetype)managerWithConfig:(UARuntimeConfig *)config
                        dataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                        namedUser:(UANamedUser *)namedUser {

    return [[self alloc] initWithAPIClient:[UATagGroupsLookupAPIClient clientWithConfig:config]
                                 dataStore:dataStore
                                   channel:channel
                                 namedUser:namedUser
                                     cache:[UATagGroupsLookupResponseCache cacheWithDataStore:dataStore]
                                 historian:[UAInAppAudienceHistorian historianWithChannel:channel namedUser:namedUser]
                               currentTime:[[UADate alloc] init]];
}

+ (instancetype)managerWithAPIClient:(UATagGroupsLookupAPIClient *)client
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           namedUser:(UANamedUser *)namedUser
                               cache:(UATagGroupsLookupResponseCache *)cache
                           historian:(UAInAppAudienceHistorian *)historian
                         currentTime:(UADate *)currentTime {

    return [[self alloc] initWithAPIClient:client
                                 dataStore:dataStore
                                   channel:channel
                                 namedUser:namedUser
                                     cache:cache
                                 historian:historian
                               currentTime:currentTime];
}

- (BOOL)enabled {
    return [self.dataStore boolForKey:kUAInAppAudienceManagerEnabledKey defaultValue:YES];
}

- (void)setEnabled:(BOOL)enabled {
    [self.dataStore setBool:enabled forKey:kUAInAppAudienceManagerEnabledKey];
}

- (NSTimeInterval)preferLocalTagDataTime {
    return [self.dataStore doubleForKey:kUAInAppAudienceManagerPreferLocalTagDataTimeKey
                           defaultValue:UAInAppAudienceManagerDefaultPreferLocalAudienceDataTimeSeconds];
}

- (void)setPreferLocalTagDataTime:(NSTimeInterval)preferLocalTagDataTime {
    [self.dataStore setDouble:preferLocalTagDataTime forKey:kUAInAppAudienceManagerPreferLocalTagDataTimeKey];
}

- (NSTimeInterval)cacheMaxAgeTime {
    return self.cache.maxAgeTime;
}

- (void)setCacheMaxAgeTime:(NSTimeInterval)cacheMaxAgeTime {
    self.cache.maxAgeTime = cacheMaxAgeTime;
}

- (NSTimeInterval)cacheStaleReadTime {
    return self.cache.staleReadTime;
}

- (void)setCacheStaleReadTime:(NSTimeInterval)cacheStaleReadTime {
    self.cache.staleReadTime = cacheStaleReadTime;
}

- (NSTimeInterval)maxSentMutationAge {
    return self.cache.staleReadTime + self.preferLocalTagDataTime;
}

- (NSError *)errorWithCode:(UAInAppAudienceManagerErrorCode)code message:(NSString *)message {
    return [NSError errorWithDomain:UAInAppAudienceManagerErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey:message}];
}

- (NSArray<UATagGroupsMutation *> *)tagOverrides {
    NSDate *date = [self.currentTime.now dateByAddingTimeInterval:-self.preferLocalTagDataTime];
    return [self tagOverridesNewerThan:date];
}

- (NSArray<UATagGroupsMutation *> *)tagOverridesNewerThan:(NSDate *)date {
    NSMutableArray *overrides = [[self.historian tagHistoryNewerThan:date] mutableCopy];

    [overrides addObjectsFromArray:self.namedUser.pendingTagGroups];
    [overrides addObjectsFromArray:self.channel.pendingTagGroups];

    // Channel tags
    if (self.channel.isChannelTagRegistrationEnabled) {
        [overrides addObject:[UATagGroupsMutation mutationToSetTags:self.channel.tags group:@"device"]];
    }

    return [UATagGroupsMutation collapseMutations:overrides];
}

- (UAAttributePendingMutations *)attributeOverrides {
    NSDate *date = [self.currentTime.now dateByAddingTimeInterval:-UAInAppAudienceManagerDefaultPreferLocalAudienceDataTimeSeconds];
    NSMutableArray *overrides = [[self.historian attributeHistoryNewerThan:date] mutableCopy];

    [overrides addObject:self.namedUser.pendingAttributes];
    [overrides addObject:self.channel.pendingAttributes];

    return [UAAttributePendingMutations collapseMutations:overrides];
}

- (UATagGroups *)generateTagGroups:(UATagGroups *)requestedTagGroups
                    cachedResponse:(UATagGroupsLookupResponse *)cachedResponse
                       refreshDate:(NSDate *)refreshDate {

    NSDictionary *tags = cachedResponse.tagGroups.tags;

    // Apply local history
    NSDate *date = [refreshDate dateByAddingTimeInterval:-self.preferLocalTagDataTime];
    for (UATagGroupsMutation *mutation in [self tagOverridesNewerThan:date]) {
        tags = [mutation applyToTagGroups:tags];
    }

    // Only return the requested tags if available
    return [requestedTagGroups intersect:[UATagGroups tagGroupsWithTags:tags]];
}

- (void)refreshCacheWithRequestedTagGroups:(UATagGroups *)requestedTagGroups
                         completionHandler:(void(^)(void))completionHandler {

    [self.delegate gatherTagGroupsWithCompletionHandler:^(UATagGroups *tagGroups) {
        tagGroups = [requestedTagGroups merge:tagGroups];
        [self.lookupAPIClient lookupTagGroupsWithChannelID:[UAirship channel].identifier
                                        requestedTagGroups:tagGroups
                                            cachedResponse:self.cache.response
                                         completionHandler:^(UATagGroupsLookupResponse *response) {
            if (response.status != 200) {
                UA_LTRACE(@"Failed to refresh the cache. Status: %lu", (unsigned long)response.status);
            } else {
                self.cache.response = response;
                self.cache.requestedTagGroups = tagGroups;
            }
            completionHandler();
        }];
    }];
}

- (void)getTagGroups:(UATagGroups *)requestedTagGroups completionHandler:(void(^)(UATagGroups  * _Nullable tagGroups, NSError *error)) completionHandler {
    __block NSError *error;

    if (!self.enabled) {
        error = [self errorWithCode:UAInAppAudienceManagerErrorCodeComponentDisabled message:@"Tag group lookup is disabled"];
        return completionHandler(nil, error);
    }

    // Requesting only device tag groups when channel tag registration is enabled
    if ([requestedTagGroups containsOnlyDeviceTags] && [UAirship channel].isChannelTagRegistrationEnabled) {
        NSMutableDictionary *tags = [NSMutableDictionary dictionary];
        [tags setValue:self.channel.tags forKey:@"device"];
        return completionHandler([UATagGroups tagGroupsWithTags:tags], error);
    }

    if (![UAirship channel].identifier) {
        error = [self errorWithCode:UAInAppAudienceManagerErrorCodeChannelRequired message:@"Channel ID is required"];
        return completionHandler(nil, error);
    }

    __block NSDate *cacheRefreshDate = self.cache.refreshDate;
    __block UATagGroupsLookupResponse *cachedResponse;

    if ([self.cache.requestedTagGroups containsAllTags:requestedTagGroups]) {
        cachedResponse = self.cache.response;
    }

    if (cachedResponse && ![self.cache needsRefresh]) {
        return completionHandler([self generateTagGroups:requestedTagGroups
                                          cachedResponse:cachedResponse
                                             refreshDate:cacheRefreshDate], error);
    }

    [self refreshCacheWithRequestedTagGroups:requestedTagGroups completionHandler:^{
        cachedResponse = self.cache.response;
        cacheRefreshDate = self.cache.refreshDate;

        if (!cachedResponse) {
            error = [self errorWithCode:UAInAppAudienceManagerErrorCodeCacheRefresh message:@"Unable to refresh cache, missing response"];
            return completionHandler(nil, error);
        }

        if ([self.cache isStale]) {
            error = [self errorWithCode:UAInAppAudienceManagerErrorCodeCacheRefresh message:@"Unable to refresh cache, read is stale"];
            return completionHandler(nil, error);
        }

        completionHandler([self generateTagGroups:requestedTagGroups
                                   cachedResponse:cachedResponse
                                      refreshDate:cacheRefreshDate], error);
    }];
}

- (void)namedUserChanged:(NSNotification *)notification {
    self.cache.response = nil;
}

@end
