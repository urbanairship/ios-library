/* Copyright Urban Airship and Contributors */

#import "UAInAppMessagingRemoteConfig+Internal.h"
#import "UATagGroupsLookupManager+Internal.h"

#define kUAInAppMessagingRemoteConfigTagGroupsKey @"tag_groups"
#define kUAInAppMessagingTagGroupsRemoteConfigFetchEnabledKey @"enabled"
#define kUAInAppMessagingTagGroupsRemoteConfigCacheMaxAgeSeconds @"cache_max_age_seconds"
#define kUAInAppMessagingTagGroupsRemoteConfigCacheStaleReadTimeSeconds @"cache_stale_read_time_seconds"
#define kUAInAppMessagingTagGroupsRemoteConfigCachePreferLocalUntilSeconds @"cache_prefer_local_until_seconds"

@interface UAInAppMessagingTagGroupsRemoteConfig ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSTimeInterval cacheMaxAgeTime;
@property (nonatomic, assign) NSTimeInterval cacheStaleReadTime;
@property (nonatomic, assign) NSTimeInterval cachePreferLocalUntil;

- (UAInAppMessagingTagGroupsRemoteConfig *)combineWithConfig:(UAInAppMessagingTagGroupsRemoteConfig *)config;

@end

@implementation UAInAppMessagingTagGroupsRemoteConfig

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

- (instancetype)initWithJSON:(NSDictionary *)json {
    NSNumber *maxAgeNumber = json[kUAInAppMessagingTagGroupsRemoteConfigCacheMaxAgeSeconds];
    NSNumber *staleReadNumber = json[kUAInAppMessagingTagGroupsRemoteConfigCacheStaleReadTimeSeconds];
    NSNumber *preferLocalUntilNumber = json[kUAInAppMessagingTagGroupsRemoteConfigCachePreferLocalUntilSeconds];
    NSNumber *enabledNumber = json[kUAInAppMessagingTagGroupsRemoteConfigFetchEnabledKey];

    NSTimeInterval maxAge = maxAgeNumber ? [maxAgeNumber doubleValue] : UATagGroupsLookupResponseCacheDefaultMaxAgeTimeSeconds;
    NSTimeInterval staleRead = staleReadNumber ? [staleReadNumber doubleValue] : UATagGroupsLookupResponseCacheDefaultStaleReadTimeSeconds;
    NSTimeInterval preferLocalUntil = preferLocalUntilNumber ? [preferLocalUntilNumber doubleValue] : UATagGroupsLookupManagerDefaultPreferLocalTagDataTimeSeconds;
    BOOL enabled = enabledNumber ? [enabledNumber boolValue] : YES;

    return [self initWithCacheMaxAgeTime:maxAge cacheStaleReadTime:staleRead cachePreferLocalUntil:preferLocalUntil enabled:enabled];
}

+ (instancetype)configWithCacheMaxAgeTime:(NSTimeInterval)cacheMaxAgeTime
                       cacheStaleReadTime:(NSTimeInterval)cacheStaleReadTime
                    cachePreferLocalUntil:(NSTimeInterval)cachePreferLocalUntil
                                  enabled:(BOOL)enabled {

    return [[self alloc] initWithCacheMaxAgeTime:cacheMaxAgeTime cacheStaleReadTime:cacheStaleReadTime cachePreferLocalUntil:cachePreferLocalUntil enabled:enabled];
}

+ (instancetype)configWithJSON:(NSDictionary *)json {
    return [[self alloc] initWithJSON:json];
}

- (UAInAppMessagingTagGroupsRemoteConfig *)combineWithConfig:(UAInAppMessagingTagGroupsRemoteConfig *)config {
    return [UAInAppMessagingTagGroupsRemoteConfig configWithCacheMaxAgeTime:MAX(self.cacheMaxAgeTime, config.cacheMaxAgeTime)
                                                         cacheStaleReadTime:MAX(self.cacheStaleReadTime, config.cacheStaleReadTime)
                                                      cachePreferLocalUntil:MAX(self.cachePreferLocalUntil, config.cachePreferLocalUntil)
                                                                    enabled:self.enabled && config.enabled];
}

@end

@interface UAInAppMessagingRemoteConfig ()
@property (nonatomic, strong) UAInAppMessagingTagGroupsRemoteConfig *tagGroupsConfig;
@end

@implementation UAInAppMessagingRemoteConfig

- (instancetype)initWithTagGroupsConfig:(UAInAppMessagingTagGroupsRemoteConfig *)tagGroupsConfig {
    self = [super init];

    if (self) {
        self.tagGroupsConfig = tagGroupsConfig;
    }

    return self;
}

- (instancetype)initWithJSON:(NSDictionary *)json {
    NSDictionary *tagGroupsConfigJSON = json[kUAInAppMessagingRemoteConfigTagGroupsKey];
    UAInAppMessagingTagGroupsRemoteConfig *tagGroupsConfig = [UAInAppMessagingTagGroupsRemoteConfig configWithJSON:tagGroupsConfigJSON];
    return [self initWithTagGroupsConfig:tagGroupsConfig];
}

+ (instancetype)configWithTagGroupsConfig:(UAInAppMessagingTagGroupsRemoteConfig *)tagGroupsConfig {
    return [[self alloc] initWithTagGroupsConfig:tagGroupsConfig];
}

+ (instancetype)configWithJSON:(NSDictionary *)json {
    return [[self alloc] initWithJSON:json];
}

- (instancetype)combineWithConfig:(UAInAppMessagingRemoteConfig *)config {
    UAInAppMessagingTagGroupsRemoteConfig *tagGroupsConfig;

    if (self.tagGroupsConfig && config.tagGroupsConfig) {
        tagGroupsConfig = [self.tagGroupsConfig combineWithConfig:config.tagGroupsConfig];
    } else if (self.tagGroupsConfig) {
        tagGroupsConfig = self.tagGroupsConfig;
    } else if (config.tagGroupsConfig) {
        tagGroupsConfig = config.tagGroupsConfig;
    }

    return [UAInAppMessagingRemoteConfig configWithTagGroupsConfig:tagGroupsConfig];
}

@end
