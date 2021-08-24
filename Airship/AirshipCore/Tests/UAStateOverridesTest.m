/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
#import "UAStateOverrides+Internal.h"
#import "UAirship+Internal.h"

@import AirshipCore;

@interface UAStateOverridesTest : UABaseTest
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockAirshipVersion;
@property(nonatomic, strong) id mockUtils;
@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockLocaleManager;

@end

@implementation UAStateOverridesTest

- (void)setUp {
    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    
    self.mockAirshipVersion = [self mockForClass:[UAirshipVersion class]];
    self.mockUtils = [self mockForClass:[UAUtils class]];
    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockLocaleManager = [self mockForClass:[UALocaleManager class]];

    [[[self.mockUtils stub] andReturn:@"1.2.3"] bundleShortVersionString];
    [[[self.mockAirshipVersion stub] andReturn:@"2.3.4"] get];

    [[[self.mockAirship stub] andReturn:self.mockPush] push];
    [[[self.mockAirship stub] andReturn:self.mockLocaleManager] locale];

    [[[self.mockPush stub] andReturnValue:@(YES)] userPushNotificationsEnabled];
    [[[self.mockPush stub] andReturnValue:@(UAAuthorizedNotificationSettingsAlert)] authorizedNotificationSettings];

    [[[self.mockLocaleManager stub] andReturn:[NSLocale localeWithLocaleIdentifier:@"en-US"]] currentLocale];

}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockAirshipVersion stopMocking];
    [self.mockUtils stopMocking];
}

- (void)testDefaultStateOverrides {
    UAStateOverrides *overrides = [UAStateOverrides defaultStateOverrides];
    XCTAssertNotNil(overrides);
    XCTAssertEqualObjects(overrides.appVersion, @"1.2.3");
    XCTAssertEqualObjects(overrides.sdkVersion, @"2.3.4");
    XCTAssertEqualObjects(overrides.localeCountry, @"US");
    XCTAssertEqualObjects(overrides.localeLanguage, @"en");
    XCTAssertTrue(overrides.notificationOptIn);
}

@end
