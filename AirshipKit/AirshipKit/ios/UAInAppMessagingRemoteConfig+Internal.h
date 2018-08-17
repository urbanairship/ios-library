/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARemoteConfig+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessagingTagGroupsRemoteConfig : UARemoteConfig

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) NSTimeInterval cacheMaxAgeTime;
@property (nonatomic, readonly) NSTimeInterval cacheStaleReadTime;
@property (nonatomic, readonly) NSTimeInterval cachePreferLocalUntil;

+ (instancetype)configWithJSON:(NSDictionary *)json;

+ (instancetype)configWithCacheMaxAgeTime:(NSTimeInterval)cacheMaxAgeTime
                       cacheStaleReadTime:(NSTimeInterval)cacheStaleReadTime
                    cachePreferLocalUntil:(NSTimeInterval)cachePreferLocalUntil
                                  enabled:(BOOL)enabled;

@end

@interface UAInAppMessagingRemoteConfig : UARemoteConfig

@property (nonatomic, readonly) UAInAppMessagingTagGroupsRemoteConfig *tagGroupsConfig;

+ (instancetype)configWithTagGroupsConfig:(UAInAppMessagingTagGroupsRemoteConfig *)tagGroupsConfig;

- (UAInAppMessagingRemoteConfig *)combineWithConfig:(UAInAppMessagingRemoteConfig *)config;

@end

NS_ASSUME_NONNULL_END
