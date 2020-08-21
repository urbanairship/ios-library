/* Copyright Airship and Contributors */

#import "UAInAppMessagingTagGroupsConfig+Internal.h"
#import "UATagGroupsLookupResponse+Internal.h"
#import "UATagGroupsLookupResponseCache+Internal.h"
#import "UAInAppAudienceManager+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#define kUAInAppMessagingTagGroupsRemoteConfigFetchEnabledKey @"enabled"
#define kUAInAppMessagingTagGroupsRemoteConfigCacheMaxAgeSeconds @"cache_max_age_seconds"
#define kUAInAppMessagingTagGroupsRemoteConfigCacheStaleReadTimeSeconds @"cache_stale_read_time_seconds"
#define kUAInAppMessagingTagGroupsRemoteConfigCachePreferLocalUntilSeconds @"cache_prefer_local_until_seconds"

@interface UAInAppMessagingTagGroupsConfig ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSTimeInterval cacheMaxAgeTime;
@property (nonatomic, assign) NSTimeInterval cacheStaleReadTime;
@property (nonatomic, assign) NSTimeInterval cachePreferLocalUntil;
@end

@implementation UAInAppMessagingTagGroupsConfig

- (instancetype)initWithCacheMaxAgeTime:(NSTimeInterval)cacheMaxAgeTime
                     cacheStaleReadTime:(NSTimeInterval)cacheStaleReadTime
                  cachePreferLocalUntil:(NSTimeInterval)cachePreferLocalUntil
                                enabled:(BOOL)enabled {

    self = [super init];

    if (self) {
        self.cacheMaxAgeTime = cacheMaxAgeTime;
        self.cacheStaleReadTime = cacheStaleReadTime;
        self.cachePreferLocalUntil = cachePreferLocalUntil;
        self.enabled = enabled;
    }

    return self;
}

+ (instancetype)configWithCacheMaxAgeTime:(NSTimeInterval)cacheMaxAgeTime
                       cacheStaleReadTime:(NSTimeInterval)cacheStaleReadTime
                    cachePreferLocalUntil:(NSTimeInterval)cachePreferLocalUntil
                                  enabled:(BOOL)enabled {

    return [[self alloc] initWithCacheMaxAgeTime:cacheMaxAgeTime
                              cacheStaleReadTime:cacheStaleReadTime
                           cachePreferLocalUntil:cachePreferLocalUntil
                                         enabled:enabled];
}

+ (instancetype)defaultConfig {
    return [[self alloc] initWithCacheMaxAgeTime:UATagGroupsLookupResponseCacheDefaultMaxAgeTimeSeconds
                              cacheStaleReadTime:UATagGroupsLookupResponseCacheDefaultStaleReadTimeSeconds
                           cachePreferLocalUntil:UAInAppAudienceManagerDefaultPreferLocalTagDataTimeSeconds
                                         enabled:YES];
}

+ (nullable instancetype)configWithJSON:(id)JSON {
    if (![JSON isKindOfClass:[NSDictionary class]]) {
        UA_LERR(@"Invalid in-app config: %@", JSON);
        return nil;
    }

    NSNumber *maxAgeNumber = JSON[kUAInAppMessagingTagGroupsRemoteConfigCacheMaxAgeSeconds];
    NSNumber *staleReadNumber = JSON[kUAInAppMessagingTagGroupsRemoteConfigCacheStaleReadTimeSeconds];
    NSNumber *preferLocalUntilNumber = JSON[kUAInAppMessagingTagGroupsRemoteConfigCachePreferLocalUntilSeconds];
    NSNumber *enabledNumber = JSON[kUAInAppMessagingTagGroupsRemoteConfigFetchEnabledKey];

    NSTimeInterval maxAge = maxAgeNumber ? [maxAgeNumber doubleValue] : UATagGroupsLookupResponseCacheDefaultMaxAgeTimeSeconds;
    NSTimeInterval staleRead = staleReadNumber ? [staleReadNumber doubleValue] : UATagGroupsLookupResponseCacheDefaultStaleReadTimeSeconds;
    NSTimeInterval preferLocalUntil = preferLocalUntilNumber ? [preferLocalUntilNumber doubleValue] : UAInAppAudienceManagerDefaultPreferLocalTagDataTimeSeconds;
    BOOL enabled = enabledNumber ? [enabledNumber boolValue] : YES;

    return [[self alloc] initWithCacheMaxAgeTime:maxAge
                              cacheStaleReadTime:staleRead
                           cachePreferLocalUntil:preferLocalUntil
                                         enabled:enabled];

}
@end
