
#import "UABaseTest.h"
#import "UAInAppMessagingRemoteConfig+Internal.h"

@interface UAInAppMessagingRemoteConfigTest : UABaseTest

@end

@implementation UAInAppMessagingRemoteConfigTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testConfigWithJSON {
    NSDictionary *json = @{@"tag_groups" : @{@"enabled" : @(NO),
                                             @"cache_max_age_seconds" : @(123),
                                             @"cache_stale_read_time_seconds" : @(234),
                                             @"cache_prefer_local_until_seconds" : @(345)}};

    UAInAppMessagingRemoteConfig *config = [UAInAppMessagingRemoteConfig configWithJSON:json];

    XCTAssertNotNil(config);
    XCTAssertNotNil(config.tagGroupsConfig);
    XCTAssertEqual(config.tagGroupsConfig.enabled, NO);
    XCTAssertEqual(config.tagGroupsConfig.cacheMaxAgeTime, 123);
    XCTAssertEqual(config.tagGroupsConfig.cacheStaleReadTime, 234);
    XCTAssertEqual(config.tagGroupsConfig.cachePreferLocalUntil, 345);
}

- (void)testConfigWithJSONDefaultValues {
    NSDictionary *json = @{};

    UAInAppMessagingRemoteConfig *config = [UAInAppMessagingRemoteConfig configWithJSON:json];

    XCTAssertNotNil(config);
    XCTAssertNotNil(config.tagGroupsConfig);
    XCTAssertEqual(config.tagGroupsConfig.enabled, YES);
    XCTAssertEqual(config.tagGroupsConfig.cacheMaxAgeTime, 600);
    XCTAssertEqual(config.tagGroupsConfig.cacheStaleReadTime, 3600);
    XCTAssertEqual(config.tagGroupsConfig.cachePreferLocalUntil, 600);
}

- (void)testCombineWithConfig {

    UAInAppMessagingRemoteConfig *first = [UAInAppMessagingRemoteConfig configWithTagGroupsConfig:[UAInAppMessagingTagGroupsRemoteConfig configWithCacheMaxAgeTime:123 cacheStaleReadTime:234 cachePreferLocalUntil:345 enabled:NO]];

    UAInAppMessagingRemoteConfig *second = [UAInAppMessagingRemoteConfig configWithTagGroupsConfig:[UAInAppMessagingTagGroupsRemoteConfig configWithCacheMaxAgeTime:234 cacheStaleReadTime:345 cachePreferLocalUntil:456 enabled:YES]];

    UAInAppMessagingRemoteConfig *combined = [first combineWithConfig:second];

    XCTAssertNotNil(combined);
    XCTAssertEqual(combined.tagGroupsConfig.enabled, NO);
    XCTAssertEqual(combined.tagGroupsConfig.cacheMaxAgeTime, 234);
    XCTAssertEqual(combined.tagGroupsConfig.cacheStaleReadTime, 345);
    XCTAssertEqual(combined.tagGroupsConfig.cachePreferLocalUntil, 456);
}

@end
