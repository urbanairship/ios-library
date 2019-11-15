/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UARemoteConfigDisableInfo+Internal.h"
#import "UARemoteConfigModuleNames+Internal.h"

@interface UARemoteConfigDisableInfoTest : UABaseTest

@end

@implementation UARemoteConfigDisableInfoTest

/**
 * Test parsing disable info.
 */
- (void)testParse {
    id JSON = @{
           @"modules": @[@"push", @"location"],
           @"app_versions": @{ @"value": @{ @"version_matches": @"+" }, @"scope": @[@"ios", @"version"] },
           @"sdk_versions": @[@"1.0.0", @"[1.0,99.0["],
           @"remote_data_refresh_interval": @(100)
       };

    UARemoteConfigDisableInfo *disableInfo = [UARemoteConfigDisableInfo disableInfoWithJSON:JSON];
    XCTAssertEqualObjects(JSON[@"modules"], disableInfo.disableModuleNames);
    XCTAssertEqualObjects(JSON[@"remote_data_refresh_interval"], disableInfo.remoteDataRefreshInterval);
    XCTAssertEqualObjects(@"1.0.0", disableInfo.sdkVersionConstraints[0].versionConstraint);
    XCTAssertEqualObjects(@"[1.0,99.0[", disableInfo.sdkVersionConstraints[1].versionConstraint);
    XCTAssertEqualObjects(JSON[@"app_versions"], [disableInfo.appVersionConstraint payload]);
}

/**
 * Test all modules results in the exanded module name array.
 */
- (void)testParseAll {
    id JSON = @{
        @"modules": @"all",
        @"app_versions": @{ @"value": @{ @"version_matches": @"+" }, @"scope": @[@"ios", @"version"] },
        @"sdk_versions": @[@"1.0.0", @"[1.0,99.0["],
        @"remote_data_refresh_interval": @(100)
    };

    UARemoteConfigDisableInfo *disableInfo = [UARemoteConfigDisableInfo disableInfoWithJSON:JSON];

    id allModules = kUARemoteConfigModuleAllModules;
    XCTAssertEqualObjects(allModules, disableInfo.disableModuleNames);
}

/**
 * Test parsing invalid values.
 */
- (void)testParseInvalid {
    XCTAssertNil([UARemoteConfigDisableInfo disableInfoWithJSON:@"rad"]);
    XCTAssertNil([UARemoteConfigDisableInfo disableInfoWithJSON:@[]]);
}

@end
