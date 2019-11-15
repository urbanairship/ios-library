
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
    NSDictionary *JSON = @{ @"tag_groups" : @{ @"enabled" : @(NO),
                                             @"cache_max_age_seconds" : @(123),
                                             @"cache_stale_read_time_seconds" : @(234),
                                             @"cache_prefer_local_until_seconds" : @(345)}};

    UAInAppMessagingRemoteConfig *config = [UAInAppMessagingRemoteConfig configWithJSON:JSON];

    XCTAssertNotNil(config);
    XCTAssertNotNil(config.tagGroupsConfig);
    XCTAssertEqual(config.tagGroupsConfig.enabled, NO);
    XCTAssertEqual(config.tagGroupsConfig.cacheMaxAgeTime, 123);
    XCTAssertEqual(config.tagGroupsConfig.cacheStaleReadTime, 234);
    XCTAssertEqual(config.tagGroupsConfig.cachePreferLocalUntil, 345);
}

- (void)testConfigWithJSONDefaultValues {
    UAInAppMessagingRemoteConfig *config = [UAInAppMessagingRemoteConfig defaultConfig];
    XCTAssertNotNil(config);
    XCTAssertNotNil(config.tagGroupsConfig);
    XCTAssertEqual(config.tagGroupsConfig.enabled, YES);
    XCTAssertEqual(config.tagGroupsConfig.cacheMaxAgeTime, 600);
    XCTAssertEqual(config.tagGroupsConfig.cacheStaleReadTime, 3600);
    XCTAssertEqual(config.tagGroupsConfig.cachePreferLocalUntil, 600);
}

@end
