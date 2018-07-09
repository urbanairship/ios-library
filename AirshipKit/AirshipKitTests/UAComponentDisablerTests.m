/* Copyright 2018 Urban Airship and Contributors */

#import "UAComponentDisabler+Internal.h"
#import "UABaseTest.h"
#import "UARemoteDataManager+Internal.h"
#import "UAirship+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAComponent+Internal.h"
#import "UAApplicationMetrics.h"
#import "UAJSONValueMatcher.h"
#import "UAJSONMatcher.h"
#import "UAJSONPredicate.h"


@interface UAComponentDisablerTests : UABaseTest
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockRemoteDataManager;
@property(nonatomic, strong) id mockPushComponent;
@property(nonatomic, strong) id mockIAMComponent;
@property(nonatomic, strong) UAComponentDisabler *componentDisabler;
@end

@implementation UAComponentDisablerTests

- (void)setUp {
    [super setUp];
    self.mockRemoteDataManager = [self mockForClass:[UARemoteDataManager class]];
    self.mockIAMComponent = [self mockForClass:[UAComponent class]];
    self.mockPushComponent = [self mockForClass:[UAComponent class]];
    self.mockAirship = [self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockRemoteDataManager] remoteDataManager];

    // mock uairship to return mocked airship components
    [[[self.mockAirship stub] andDo:^(NSInvocation *invocation) {
        NSString *key;
        [invocation getArgument:&key atIndex:2];
        if ([key isEqualToString:@"sharedInAppMessageManager"]) {
            [invocation setReturnValue:&self->_mockIAMComponent];
        } else if ([key isEqualToString:@"sharedPush"]) {
            [invocation setReturnValue:&self->_mockPushComponent];
        }
    }] valueForKey:OCMOCK_ANY];

    //
    // create test instance of component disabler
    self.componentDisabler = [[UAComponentDisabler alloc] init];
}

- (void)tearDown {
    self.componentDisabler = nil;
    [super tearDown];
}

- (void)testEmptyRemoteConfig {
    // test
    [self.componentDisabler processDisableInfo:@[]];

    // verify
    [[self.mockIAMComponent verify] setComponentEnabled:YES];
    [[self.mockPushComponent verify] setComponentEnabled:YES];
    [[self.mockRemoteDataManager verify] setRemoteDataRefreshInterval:0];
}

- (void)testSimpleRemoteConfig {
    // create test data
    NSArray *disableInfos = @[
                              @{
                                  @"modules":@[@"in_app_v2"],
                                  @"sdk_versions":@[@"[8.0,99.0["]
                                  }
                              ];
    // test
    [self.componentDisabler processDisableInfo:disableInfos];

    // verify
    [[self.mockIAMComponent verify] setComponentEnabled:NO];
    [[self.mockPushComponent verify] setComponentEnabled:YES];
    [[self.mockRemoteDataManager verify] setRemoteDataRefreshInterval:0];
}

- (void)testComplexRemoteConfig {
    // create test data
    NSUInteger expectedRemoteDataRefreshInterval = 86400;
    NSArray *disableInfos = @[
                              @{
                                  @"modules":@[@"in_app_v2"],
                                  @"remote_data_refresh_interval":[NSNumber numberWithInteger:expectedRemoteDataRefreshInterval],
                                  @"sdk_versions":@[@"[8.0,99.0["]
                                  },
                              @{
                                  @"modules":@[@"push"],
                                  }
                              ];

    // test
    [self.componentDisabler processDisableInfo:disableInfos];

    // verify
    [[self.mockIAMComponent verify] setComponentEnabled:NO];
    [[self.mockPushComponent verify] setComponentEnabled:NO];
    [[self.mockRemoteDataManager verify] setRemoteDataRefreshInterval:expectedRemoteDataRefreshInterval];
}

- (void)testFailingAVersionMatch {
    // create test data
    NSUInteger expectedRemoteDataRefreshInterval = 86400;
    NSArray *disableInfos = @[
                              @{
                                  @"modules":@[@"in_app_v2"],
                                  @"remote_data_refresh_interval":[NSNumber numberWithInteger:expectedRemoteDataRefreshInterval],
                                  @"sdk_versions":@[@"[8.0,99.0["]
                                  },
                              @{
                                  @"modules":@[@"push"],
                                  @"sdk_versions":@[@"8.4+"]
                                  }
                              ];

    // test
    [self.componentDisabler processDisableInfo:disableInfos];
    
    // verify
    [[self.mockIAMComponent verify] setComponentEnabled:NO];
    [[self.mockPushComponent verify] setComponentEnabled:YES];
    [[self.mockRemoteDataManager verify] setRemoteDataRefreshInterval:expectedRemoteDataRefreshInterval];
}

- (void)testMultipleMatchingDisables {
    // create test data
    NSUInteger expectedRemoteDataRefreshInterval = 86400;
    NSArray *disableInfos = @[
                              @{
                                  @"modules":@[@"in_app_v2"],
                                  @"remote_data_refresh_interval":[NSNumber numberWithInteger:expectedRemoteDataRefreshInterval],
                                  @"sdk_versions":@[@"[8.0,99.0["]
                                  },
                              @{
                                  @"modules":@[@"push"],
                                  @"sdk_versions":@[@"+"]
                                  }
                              ];

    // test
    [self.componentDisabler processDisableInfo:disableInfos];
    
    // verify
    [[self.mockIAMComponent verify] setComponentEnabled:NO];
    [[self.mockPushComponent verify] setComponentEnabled:NO];
    [[self.mockRemoteDataManager verify] setRemoteDataRefreshInterval:expectedRemoteDataRefreshInterval];
}

- (void)testMultipleModuleDisables {
    // create test data
    NSUInteger expectedRemoteDataRefreshInterval = 86400;
    NSArray *disableInfos = @[
                              @{
                                  @"modules":@[@"in_app_v2",@"push"],
                                  @"remote_data_refresh_interval":[NSNumber numberWithInteger:expectedRemoteDataRefreshInterval],
                                  @"sdk_versions":@[@"[8.0,99.0["]
                                  }
                              ];

    // test
    [self.componentDisabler processDisableInfo:disableInfos];
    
    // verify
    [[self.mockIAMComponent verify] setComponentEnabled:NO];
    [[self.mockPushComponent verify] setComponentEnabled:NO];
    [[self.mockRemoteDataManager verify] setRemoteDataRefreshInterval:expectedRemoteDataRefreshInterval];
}

- (void)testAllModuleDisables {
    // create test data
    NSUInteger expectedRemoteDataRefreshInterval = 86400;
    NSArray *disableInfos = @[
                              @{
                                  @"modules":@"all",
                                  @"remote_data_refresh_interval":[NSNumber numberWithInteger:expectedRemoteDataRefreshInterval],
                                  @"sdk_versions":@[@"[8.0,99.0["]
                                  }
                              ];

    // test
    [self.componentDisabler processDisableInfo:disableInfos];
    
    // verify
    [[self.mockIAMComponent verify] setComponentEnabled:NO];
    [[self.mockPushComponent verify] setComponentEnabled:NO];
    [[self.mockRemoteDataManager verify] setRemoteDataRefreshInterval:expectedRemoteDataRefreshInterval];
}

- (void)testAppVersion {
    NSUInteger expectedRemoteDataRefreshInterval = 86400;

    // setup
    __block NSString *mockVersion;
    id mockApplicationMetrics = [self mockForClass:[UAApplicationMetrics class]];
    [[[mockApplicationMetrics stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&mockVersion];
    }] currentAppVersion];
    [[[self.mockAirship stub] andReturn:mockApplicationMetrics] applicationMetrics];

    mockVersion = @"1";

    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"] scope:@[@"ios",@"version"]];

    UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:matcher];

    NSArray *disableInfos = @[
                              @{
                                  @"modules":@"all",
                                  @"remote_data_refresh_interval":[NSNumber numberWithInteger:expectedRemoteDataRefreshInterval],
                                  @"app_versions":predicate.payload
                                  }
                              ];

    // test
    [self.componentDisabler processDisableInfo:disableInfos];

    // verify
    [[self.mockIAMComponent verify] setComponentEnabled:NO];
    [[self.mockPushComponent verify] setComponentEnabled:NO];

    mockVersion = @"3";

    disableInfos = @[
                     @{
                         @"modules":@"all",
                         @"remote_data_refresh_interval":[NSNumber numberWithInteger:expectedRemoteDataRefreshInterval],
                         @"app_versions":predicate.payload
                         }
                     ];

    // test
    [self.componentDisabler processDisableInfo:disableInfos];

    // verify
    [[self.mockIAMComponent verify] setComponentEnabled:YES];
    [[self.mockPushComponent verify] setComponentEnabled:YES];
}


@end
