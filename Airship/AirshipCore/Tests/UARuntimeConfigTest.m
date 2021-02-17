/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARuntimeConfig+Internal.h"
#import "UAConfig.h"
#import "UARemoteConfigURLManager.h"

@interface UARuntimeConfigTest : UAAirshipBaseTest
@property (nonatomic, strong) UAConfig *appConfig;
@property (nonatomic, strong) UARemoteConfigURLManager *urlManager;
@end

@implementation UARuntimeConfigTest

- (void)setUp {
    [super setUp];
    self.appConfig = [UAConfig config];
    self.appConfig.defaultAppKey = @"0000000000000000000000";
    self.appConfig.defaultAppSecret = @"0000000000000000000000";
    self.urlManager = [UARemoteConfigURLManager remoteConfigURLManagerWithDataStore:self.dataStore];
}

- (void)testUSSite {
    self.appConfig.site = UACloudSiteUS;
    UARuntimeConfig *config = [UARuntimeConfig runtimeConfigWithConfig:self.appConfig urlManager:self.urlManager];

    XCTAssertEqualObjects(@"https://device-api.urbanairship.com", config.deviceAPIURL);
    XCTAssertEqualObjects(@"https://combine.urbanairship.com", config.analyticsURL);
    XCTAssertEqualObjects(@"https://remote-data.urbanairship.com", config.remoteDataAPIURL);
}

- (void)testEUSite {
    self.appConfig.site = UACloudSiteEU;
    UARuntimeConfig *config = [UARuntimeConfig runtimeConfigWithConfig:self.appConfig urlManager:self.urlManager];

    XCTAssertEqualObjects(@"https://device-api.asnapieu.com", config.deviceAPIURL);
    XCTAssertEqualObjects(@"https://combine.asnapieu.com", config.analyticsURL);
    XCTAssertEqualObjects(@"https://remote-data.asnapieu.com", config.remoteDataAPIURL);
}

- (void)testURLOverride {
    self.appConfig.site = UACloudSiteEU;
    self.appConfig.deviceAPIURL = @"cool://devices";
    self.appConfig.analyticsURL = @"cool://analytics";
    self.appConfig.remoteDataAPIURL = @"cool://remote";

    self.urlManager = [UARemoteConfigURLManager remoteConfigURLManagerWithDataStore:self.dataStore];
    UARuntimeConfig *config = [UARuntimeConfig runtimeConfigWithConfig:self.appConfig urlManager:self.urlManager];

    XCTAssertEqualObjects(@"cool://devices", config.deviceAPIURL);
    XCTAssertEqualObjects(@"cool://analytics", config.analyticsURL);
    XCTAssertEqualObjects(@"cool://remote", config.remoteDataAPIURL);
}


@end
