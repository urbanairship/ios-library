/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UARemoteConfigManager+Internal.h"
#import "UABaseTest.h"
#import "UARemoteDataManager+Internal.h"
#import "UAirship+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAComponent+Internal.h"
#import "UAComponentDisabler+Internal.h"

@interface UARemoteConfigManagerTests : UABaseTest
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockRemoteDataManager;
@property(nonatomic, strong) id mockComponentDisabler;
@property(nonatomic, strong) id mockModules;
@property(nonatomic, strong) UARemoteDataPublishBlock publishBlock;
@property(nonatomic, strong) UARemoteConfigManager *remoteConfigManager;
@end

@implementation UARemoteConfigManagerTests

- (void)setUp {
    [super setUp];
    // mock remote data
    self.mockRemoteDataManager = [self mockForClass:[UARemoteDataManager class]];
    [[[self.mockRemoteDataManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<NSString *> *types = (__bridge NSArray<NSString *> *)arg;
        XCTAssertTrue(types.count == 2);
        XCTAssertTrue([types containsObject:@"app_config"]);
        XCTAssertTrue([types containsObject:@"app_config:ios"]);

        [invocation getArgument:&arg atIndex:3];
        self.publishBlock = (__bridge UARemoteDataPublishBlock)arg;
    }] subscribeWithTypes:OCMOCK_ANY block:OCMOCK_ANY];

    self.mockModules = [self mockForClass:[UAModules class]];
    
    self.mockComponentDisabler = [self mockForClass:[UAComponentDisabler class]];

    // create test instance of remote config manager
    self.remoteConfigManager = [UARemoteConfigManager remoteConfigManagerWithRemoteDataManager:self.mockRemoteDataManager
                                                                             componentDisabler:self.mockComponentDisabler
                                                                                       modules:self.mockModules];
}

- (void)tearDown {
    self.remoteConfigManager = nil;
    [super tearDown];
}

- (void)testNoRemoteConfig {
    // expectations
    __block NSArray *expectedRemoteConfigForDisable = @[];
    [[self.mockComponentDisabler expect] processDisableInfo:[OCMArg checkWithBlock:^BOOL(NSArray *remoteConfigForDisable) {
        XCTAssertEqualObjects(remoteConfigForDisable,expectedRemoteConfigForDisable);
        return YES;
    }]];

    // test
    self.publishBlock(@[]);
    
    // verify
    [self.mockComponentDisabler verify];
}

- (void)testEmptyRemoteConfig {
    // create test data
    NSDictionary *commonConfig = @{};
    NSDictionary *iosConfig = @{};
    UARemoteDataPayload *commonConfigDataPayload = [[UARemoteDataPayload alloc] initWithType:@"app_config" timestamp:[NSDate date] data:commonConfig];
    UARemoteDataPayload *iosConfigDataPayload = [[UARemoteDataPayload alloc] initWithType:@"app_config:ios" timestamp:[NSDate date] data:iosConfig];

    // set expectations
    __block NSArray *expectedRemoteConfigForDisable = @[];
    __block NSDictionary *expectedRemoteConfigsForModules = @{};

    [[self.mockComponentDisabler expect] processDisableInfo:[OCMArg checkWithBlock:^BOOL(NSArray *remoteConfigForDisable) {
        XCTAssertEqualObjects(remoteConfigForDisable,expectedRemoteConfigForDisable);
        return YES;
    }]];

    [[self.mockModules expect] processConfigs:[OCMArg checkWithBlock:^BOOL(NSDictionary *remoteConfigsForModules) {
        XCTAssertEqualObjects(remoteConfigsForModules, expectedRemoteConfigsForModules);
        return YES;
    }]];

    // execute
    self.publishBlock(@[commonConfigDataPayload,iosConfigDataPayload]);

    // verify
    [self.mockComponentDisabler verify];
    [self.mockModules verify];
}

- (void)testOnlyCommonRemoteConfig {
    // create test data
    NSDictionary *sampleRemoteConfig = @{
                                         @"blah": @"BLAH",
                                         @"goof": @"ball"
                                         };

    NSArray *expectedRemoteConfigForDisable = @[
                                            @{
                                                @"modules":@"in_app_v2",
                                                @"remote_data_refresh_interval":@10,
                                                @"sdk_versions":@"[8.0,99.0["
                                                },
                                            @{
                                                @"modules":@"push",
                                                }
                                            ];

    NSDictionary *commonConfig = @{@"someclient":sampleRemoteConfig,
                                   @"disable_features":expectedRemoteConfigForDisable};

    NSDictionary *expectedRemoteConfigsForModules = @{@"someclient" : @[sampleRemoteConfig]};

    UARemoteDataPayload *commonConfigDataPayload = [[UARemoteDataPayload alloc] initWithType:@"app_config" timestamp:[NSDate date] data:commonConfig];

    // set expectations
    [[self.mockComponentDisabler expect] processDisableInfo:[OCMArg checkWithBlock:^BOOL(NSArray *remoteConfigForDisable) {
        XCTAssertEqualObjects(remoteConfigForDisable,expectedRemoteConfigForDisable);
        return YES;
    }]];

    [[self.mockModules expect] processConfigs:[OCMArg checkWithBlock:^BOOL(NSDictionary *remoteConfigsForModules) {
        XCTAssertEqualObjects(remoteConfigsForModules, expectedRemoteConfigsForModules);
        return YES;
    }]];

    // execute
    self.publishBlock(@[commonConfigDataPayload]);
    
    // verify
    [self.mockComponentDisabler verify];
    [self.mockModules verify];
}

- (void)testCommonAndiOSRemoteConfig {

    NSDictionary *sampleRemoteConfig = @{
                                         @"blah": @"BLAH",
                                         @"goof": @"ball"
                                         };
    NSDictionary *otherRemoteConfig = @{
                                        @"blah": @"BLAH",
                                        @"goof": @"ball"
                                        };

    // create test data
    NSDictionary *expectedCommonRemoteConfigForDisable = @{
                                                      @"modules":@"in_app_v2",
                                                      @"remote_data_refresh_interval":@10,
                                                      @"sdk_versions":@"[8.0,99.0["
                                                      };
    NSDictionary *expectediOSRemoteConfigForDisable = @{
                                                   @"modules":@"push",
                                                   };

    NSDictionary *commonConfig = @{@"disable_features":@[expectedCommonRemoteConfigForDisable], @"someclient": sampleRemoteConfig};
    NSDictionary *iosConfig = @{@"disable_features":@[expectediOSRemoteConfigForDisable], @"someclient" : otherRemoteConfig};
    
    NSArray *expectedRemoteConfigForDisable = @[
                                                expectedCommonRemoteConfigForDisable,
                                                expectediOSRemoteConfigForDisable
                                                ];

    NSDictionary *expectedRemoteConfigsForModules = @{@"someclient": @[sampleRemoteConfig, otherRemoteConfig]};

    UARemoteDataPayload *commonConfigDataPayload = [[UARemoteDataPayload alloc] initWithType:@"app_config" timestamp:[NSDate date] data:commonConfig];
    UARemoteDataPayload *iosConfigDataPayload = [[UARemoteDataPayload alloc] initWithType:@"app_config:ios" timestamp:[NSDate date] data:iosConfig];

    // set expectations
    [[self.mockComponentDisabler expect] processDisableInfo:[OCMArg checkWithBlock:^BOOL(NSArray *remoteConfigForDisable) {
        XCTAssertEqualObjects(remoteConfigForDisable,expectedRemoteConfigForDisable);
        return YES;
    }]];

    [[self.mockModules expect] processConfigs:[OCMArg checkWithBlock:^BOOL(NSDictionary *remoteConfigsForModules) {
        XCTAssertEqualObjects(remoteConfigsForModules, expectedRemoteConfigsForModules);
        return YES;
    }]];

    // execute
    self.publishBlock(@[commonConfigDataPayload,iosConfigDataPayload]);
    
    // verify
    [self.mockComponentDisabler verify];
    [self.mockModules verify];
}

- (void)testDefaultingSomeOfRemoteConfig {
    // create test data
    NSDictionary *commonRemoteConfigForSomeClient = @{@"some_client": @{
                                                              @"blah": @"BLAH",
                                                              @"goof": @"ball"
                                                              }
                                                      };
    NSDictionary *iosRemoteConfigForSomeClient = @{@"some_client": @{
                                                           @"blah": @"BLAHBLAHBLAH",
                                                           @"foot": @"ball"
                                                           }
                                                   };
    UARemoteDataPayload *commonConfigDataPayload = [[UARemoteDataPayload alloc] initWithType:@"app_config" timestamp:[NSDate date] data:commonRemoteConfigForSomeClient];
    UARemoteDataPayload *iosConfigDataPayload = [[UARemoteDataPayload alloc] initWithType:@"app_config:ios" timestamp:[NSDate date] data:iosRemoteConfigForSomeClient];

    // set expectations
    __block NSArray *expectedRemoteConfigForDisable = @[];
    [[self.mockComponentDisabler expect] processDisableInfo:[OCMArg checkWithBlock:^BOOL(NSArray *remoteConfigForDisable) {
        XCTAssertEqualObjects(remoteConfigForDisable,expectedRemoteConfigForDisable);
        return YES;
    }]];

    // execute
    self.publishBlock(@[commonConfigDataPayload,iosConfigDataPayload]);

    // verify
    [self.mockComponentDisabler verify];
}

@end
