/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UARemoteConfig.h"
#import "UAConfig+Internal.h"

@interface UARemoteConfigTest : UABaseTest
@end

@implementation UARemoteConfigTest

- (void)testURLNormalized {
    NSString *deviceAPITestString = @"https://device-api.example.com/";
    NSString *remoteDataTestString = @"https://remote-api.example.com/";
    NSString *analyticsTestString = @"https://analytics-api.example.com/";
    
    UARemoteConfig *remoteConfig = [UARemoteConfig configWithRemoteDataURL:remoteDataTestString deviceAPIURL:deviceAPITestString analyticsURL:analyticsTestString];
    
    XCTAssertEqualObjects(remoteConfig.remoteDataURL, @"https://remote-api.example.com", @"The URL still contains trailing slash.");
    XCTAssertEqualObjects(remoteConfig.analyticsURL, @"https://analytics-api.example.com", @"The URL still contains trailing slash.");
    XCTAssertEqualObjects(remoteConfig.deviceAPIURL, @"https://device-api.example.com", @"The URL still contains trailing slash.");
}

- (void)testURLsSet {
    NSString *deviceAPITestString = @"https://device-api.example.com";
    NSString *remoteDataTestString = @"https://remote-api.example.com";
    NSString *analyticsTestString = @"https://analytics-api.example.com";
    
    UARemoteConfig *remoteConfig = [UARemoteConfig configWithRemoteDataURL:remoteDataTestString deviceAPIURL:deviceAPITestString analyticsURL:analyticsTestString];
    
    XCTAssertEqualObjects(remoteConfig.remoteDataURL, @"https://remote-api.example.com", @"The URL not set correctly.");
    XCTAssertEqualObjects(remoteConfig.analyticsURL, @"https://analytics-api.example.com", @"The URL not set correctly.");
    XCTAssertEqualObjects(remoteConfig.deviceAPIURL, @"https://device-api.example.com", @"The URL not set correctly.");
}

@end
