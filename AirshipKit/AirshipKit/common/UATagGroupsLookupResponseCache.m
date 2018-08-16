
#import "UATagGroupsLookupResponseCache+Internal.h"

#define kUATagGroupsLookupResponseCacheResponseKey @"com.urbanairship.tag_groups.CACHED_RESPONSE"
#define kUATagGroupsLookupResponseCacheRefreshDateKey @"com.urbanairship.tag_groups.CACHE_REFRESH_DATE"
#define kUATagGroupsLookupResponseCacheRequestTagGroupsKey @"com.urbanairship.tag_groups.CACHED_REQUEST_TAG_GROUPS"
#define kUATagGroupsLookupResponseCacheMaxAgeTimeKey @"com.urbanairship.tag_groups.CACHE_MAX_AGE_TIME"
#define kUATagGroupsLookupResponseCacheStaleReadTimeKey @"com.urbanairship.tag_groups.CACHE_STALE_READ_TIME"

#define kUATagGroupsLookupManagerMinCacheMaxAgeTimeSeconds 60 // 1 minute

NSTimeInterval const UATagGroupsLookupResponseCacheDefaultMaxAgeTimeSeconds = 60 * 10; // 10 minutes
NSTimeInterval const UATagGroupsLookupResponseCacheDefaultStaleReadTimeSeconds = 60 * 60; // 1 hour

@interface UATagGroupsLookupResponseCache ()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) NSDate *refreshDate;
@end

@implementation UATagGroupsLookupResponseCache

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];

    if (self) {
        self.dataStore = dataStore;
    }

    return self;
}

+ (instancetype)cacheWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithDataStore:dataStore];
}

- (NSTimeInterval)maxAgeTime {
    NSTimeInterval maxAge = [self.dataStore doubleForKey:kUATagGroupsLookupResponseCacheMaxAgeTimeKey
                                            defaultValue:UATagGroupsLookupResponseCacheDefaultMaxAgeTimeSeconds];

    return MAX(maxAge, kUATagGroupsLookupManagerMinCacheMaxAgeTimeSeconds);
}

- (void)setMaxAgeTime:(NSTimeInterval)maxAgeTime {
    [self.dataStore setDouble:maxAgeTime forKey:kUATagGroupsLookupResponseCacheMaxAgeTimeKey];
}

- (NSTimeInterval)staleReadTime {
    return [self.dataStore doubleForKey:kUATagGroupsLookupResponseCacheStaleReadTimeKey
                           defaultValue:UATagGroupsLookupResponseCacheDefaultStaleReadTimeSeconds];
}

- (void)setStaleReadTime:(NSTimeInterval)staleReadTime {
    [self.dataStore setDouble:staleReadTime forKey:kUATagGroupsLookupResponseCacheStaleReadTimeKey];
}

- (UATagGroupsLookupResponse *)response {
    NSData *encodedResponse = [self.dataStore objectForKey:kUATagGroupsLookupResponseCacheResponseKey];
    return [NSKeyedUnarchiver unarchiveObjectWithData:encodedResponse];
}

- (void)setResponse:(UATagGroupsLookupResponse *)response {
    NSData *encodedResonse = [NSKeyedArchiver archivedDataWithRootObject:response];
    [self.dataStore setObject:encodedResonse forKey:kUATagGroupsLookupResponseCacheResponseKey];
    
    self.refreshDate = [NSDate date];
}

- (NSDate *)refreshDate {
    return [self.dataStore objectForKey:kUATagGroupsLookupResponseCacheRefreshDateKey];
}

- (void)setRefreshDate:(NSDate *)refreshDate {
    [self.dataStore setObject:refreshDate forKey:kUATagGroupsLookupResponseCacheRefreshDateKey];
}

- (UATagGroups *)requestedTagGroups {
    NSData *encodedTagGroups = [self.dataStore objectForKey:kUATagGroupsLookupResponseCacheRequestTagGroupsKey];
    return [NSKeyedUnarchiver unarchiveObjectWithData:encodedTagGroups];
}

- (void)setRequestedTagGroups:(UATagGroups *)tagGroups {
    NSData *encodedTagGroups = [NSKeyedArchiver archivedDataWithRootObject:tagGroups];
    [self.dataStore setObject:encodedTagGroups forKey:kUATagGroupsLookupResponseCacheRequestTagGroupsKey];
}

- (BOOL)needsRefresh {
    return self.response && self.refreshDate && self.maxAgeTime <= [[NSDate date] timeIntervalSinceDate:self.refreshDate];
}

- (BOOL)isStale {
    return self.staleReadTime <= [[NSDate date] timeIntervalSinceDate:self.refreshDate];
}

@end
