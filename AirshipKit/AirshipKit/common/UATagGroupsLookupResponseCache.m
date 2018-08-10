
#import "UATagGroupsLookupResponseCache+Internal.h"

#define kUATagGroupsLookupResponseCacheResponseKey @"com.urbanairship.tag_groups.CACHED_RESPONSE"
#define kUATagGroupsLookupResponseCacheCreationDateKey @"com.urbanairship.tag_groups.CACHE_CREATION_DATE"
#define kUATagGroupsLookupResponseCacheRequestTagGroupsKey @"com.urbanairship.tag_groups.CACHED_REQUEST_TAG_GROUPS"
#define kUATagGroupsLookupResponseCacheMaxAgeTimeKey @"com.urbanairship.tag_groups.CACHE_MAX_AGE_TIME"
#define kUATagGroupsLookupResponseCacheStaleReadTimeKey @"com.urbanairship.tag_groups.CACHE_STALE_READ_TIME"

#define kUATagGroupsLookupManagerMinCacheMaxAgeTimeSeconds 60 // 1 minute
#define kUATagGroupsLookupResponseCacheDefaultMaxAgeTimeSeconds 60 * 10 // 10 minutes
#define kUATagGroupsLookupResponseCacheDefaultStaleReadTimeSeconds 60 * 60 // 1 hour

@interface UATagGroupsLookupResponseCache ()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) NSDate *creationDate;
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
                                            defaultValue:kUATagGroupsLookupResponseCacheDefaultMaxAgeTimeSeconds];

    return MAX(maxAge, kUATagGroupsLookupManagerMinCacheMaxAgeTimeSeconds);
}

- (void)setMaxAgeTime:(NSTimeInterval)maxAgeTime {
    [self.dataStore setDouble:maxAgeTime forKey:kUATagGroupsLookupResponseCacheMaxAgeTimeKey];
}

- (NSTimeInterval)staleReadTime {
    return [self.dataStore doubleForKey:kUATagGroupsLookupResponseCacheStaleReadTimeKey
                           defaultValue:kUATagGroupsLookupResponseCacheDefaultStaleReadTimeSeconds];
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
    
    self.creationDate = [NSDate date];
}

- (NSDate *)creationDate {
    return [self.dataStore objectForKey:kUATagGroupsLookupResponseCacheCreationDateKey];
}

- (void)setCreationDate:(NSDate *)creationDate {
    [self.dataStore setObject:creationDate forKey:kUATagGroupsLookupResponseCacheCreationDateKey];
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
    return self.response && self.creationDate && self.maxAgeTime <= [[NSDate date] timeIntervalSinceDate:self.creationDate];
}

- (BOOL)isStale {
    return self.staleReadTime <= [[NSDate date] timeIntervalSinceDate:self.creationDate];
}

@end
