/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARemoteConfigURLManager.h"
#import "UARemoteConfigManager+Internal.h"

@interface UARemoteConfigURLManagerTest : UAAirshipBaseTest
@property (nonatomic, strong) UARemoteConfigURLManager *manager;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UARemoteConfigURLManagerTest

- (void)setUp {
    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.manager = [UARemoteConfigURLManager remoteConfigURLManagerWithDataStore:self.dataStore
                                                              notificationCenter:self.notificationCenter];
}

- (void)testUpdateConfig {
    XCTAssertNil(self.manager.remoteDataURL);
    XCTAssertNil(self.manager.deviceAPIURL);
    XCTAssertNil(self.manager.analyticsURL);

    id remoteConfigData = @{
        @"remote_data_url": @"remote-data",
        @"device_api_url": @"device-api",
        @"analytics_url": @"analytics"
    };

    [self.notificationCenter postNotificationName:UAAirshipRemoteConfigUpdatedEvent
                                           object:nil
                                         userInfo:@{UAAirshipRemoteConfigUpdatedKey: remoteConfigData}];

    XCTAssertEqualObjects(@"remote-data", self.manager.remoteDataURL);
    XCTAssertEqualObjects(@"device-api", self.manager.deviceAPIURL);
    XCTAssertEqualObjects(@"analytics", self.manager.analyticsURL);
}

- (void)testConfigPersists {
    id remoteConfigData = @{
        @"remote_data_url": @"remote-data",
        @"device_api_url": @"device-api",
        @"analytics_url": @"analytics"
    };

    [self.notificationCenter postNotificationName:UAAirshipRemoteConfigUpdatedEvent
                                           object:nil
                                         userInfo:@{UAAirshipRemoteConfigUpdatedKey: remoteConfigData}];

    self.manager = [UARemoteConfigURLManager remoteConfigURLManagerWithDataStore:self.dataStore
                                                              notificationCenter:self.notificationCenter];

    XCTAssertEqualObjects(@"remote-data", self.manager.remoteDataURL);
    XCTAssertEqualObjects(@"device-api", self.manager.deviceAPIURL);
    XCTAssertEqualObjects(@"analytics", self.manager.analyticsURL);

    id otherRemoteConfigData = @{
        @"remote_data_url": @"other-remote-data",
        @"device_api_url": @"other-device-api",
        @"analytics_url": @"other-analytics"
    };

    [self.notificationCenter postNotificationName:UAAirshipRemoteConfigUpdatedEvent
                                           object:nil
                                         userInfo:@{UAAirshipRemoteConfigUpdatedKey: otherRemoteConfigData}];

    XCTAssertEqualObjects(@"other-remote-data", self.manager.remoteDataURL);
    XCTAssertEqualObjects(@"other-device-api", self.manager.deviceAPIURL);
    XCTAssertEqualObjects(@"other-analytics", self.manager.analyticsURL);

}

- (void)testUpdateConfigNSNotification {
    __block NSUInteger count;
    [self.notificationCenter addObserverForName:UARemoteConfigURLManagerConfigUpdated
                                         object:nil
                                          queue:nil
                                     usingBlock:^(NSNotification * _Nonnull note) {
        count++;
    }];

    id remoteConfigData = @{
        @"remote_data_url": @"remote-data",
        @"device_api_url": @"device-api",
        @"analytics_url": @"analytics"
    };

    [self.notificationCenter postNotificationName:UAAirshipRemoteConfigUpdatedEvent
                                           object:nil
                                         userInfo:@{UAAirshipRemoteConfigUpdatedKey: remoteConfigData}];

    XCTAssertEqual(1, count);

    id otherRemoteConfigData = @{
        @"remote_data_url": @"other-remote-data",
        @"device_api_url": @"other-device-api",
        @"analytics_url": @"other-analytics"
    };

    [self.notificationCenter postNotificationName:UAAirshipRemoteConfigUpdatedEvent
                                           object:nil
                                         userInfo:@{UAAirshipRemoteConfigUpdatedKey: otherRemoteConfigData}];
    XCTAssertEqual(2, count);
}

@end
