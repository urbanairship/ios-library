/* Copyright Airship and Contributors */

#import "UARemoteConfigManager+Internal.h"
#import "UAAirshipBaseTest.h"
#import "UARemoteDataManager+Internal.h"
#import "UAirship+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAComponent+Internal.h"
#import "UARemoteConfigModuleAdapter+Internal.h"
#import "UARemoteConfigModuleNames+Internal.h"
#import "UAVersionMatcher.h"
#import "UAJSONMatcher.h"
#import "UAJSONPredicate.h"

@interface UATestRemoteConfigModuleAdapter : UARemoteConfigModuleAdapter
@property (nonatomic, strong, nonnull) NSMutableSet *disabledModuleNames;
@property (nonatomic, strong, nonnull) NSMutableSet *enabledModuleNames;
@property (nonatomic, strong, nonnull) NSMutableDictionary *appliedConfig;
@end

@interface UARemoteConfigManagerTest : UAAirshipBaseTest
@property(nonatomic, strong) id mockRemoteDataManager;
@property(nonatomic, strong) UATestRemoteConfigModuleAdapter *testModuleAdapter;
@property(nonatomic, strong) UARemoteDataPublishBlock publishBlock;
@property(nonatomic, strong) UARemoteConfigManager *remoteConfigManager;
@property(nonatomic, strong) UAPrivacyManager *privacyManager;
@property(nonatomic, copy) NSString *appVersion;

@end

@implementation UARemoteConfigManagerTest

- (void)setUp {
    [super setUp];
    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];

    UADisposable *disposable = [[UADisposable alloc] init:^{
        self.publishBlock = nil;
    }];

    // Mock remote data
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
        [invocation setReturnValue:(void *)&disposable];
    }] subscribeWithTypes:OCMOCK_ANY block:OCMOCK_ANY];

    // Mock module adapter
    self.testModuleAdapter = [[UATestRemoteConfigModuleAdapter alloc] init];

    UA_WEAKIFY(self);
    self.remoteConfigManager = [UARemoteConfigManager remoteConfigManagerWithRemoteDataManager:self.mockRemoteDataManager
                                                                                privacyManager:self.privacyManager
                                                                                 moduleAdapter:self.testModuleAdapter versionBlock:^NSString *{
        UA_STRONGIFY(self);
        return self.appVersion;
    }];

    self.appVersion = @"0.0.0";
}

- (void)tearDown {
    self.publishBlock = nil;
    [super tearDown];
}

- (void)testSubscription {
    XCTAssertNotNil(self.publishBlock);

    self.privacyManager.enabledFeatures = UAFeaturesNone;
    XCTAssertNil(self.publishBlock);

    self.privacyManager.enabledFeatures = UAFeaturesChat;
    XCTAssertNotNil(self.publishBlock);
}

/**
 * Test current modules list matches hardcoded expectation.
 */
- (void)testCurrentModules {
    NSArray *expectedModules = @[kUARemoteConfigModulePush, kUARemoteConfigModuleChannel, kUARemoteConfigModuleAnalytics, kUARemoteConfigModuleMessageCenter, kUARemoteConfigModuleInAppMessaging, kUARemoteConfigModuleAutomation, kUARemoteConfigModuleNamedUser, kUARemoteConfigModuleLocation, kUARemoteConfigModuleChat, kUARemoteConfigModuleContact];

    NSArray *currentModules = kUARemoteConfigModuleAllModules;
    XCTAssertEqualObjects(currentModules, expectedModules);
}

/**
 * Test disabling components is overriden by the platform.
 */
- (void)testPlatformDisableOverridesCommon {
    UARemoteDataPayload *common = [UARemoteConfigManagerTest disablePayloadWithName:@"app_config"
                                                                    refreshInterval:nil
                                                                     disableModules:kUARemoteConfigModuleAllModules];

    UARemoteDataPayload *platform = [UARemoteConfigManagerTest disablePayloadWithName:@"app_config:ios"
                                                                      refreshInterval:nil
                                                                       disableModules:@[kUARemoteConfigModulePush]];

    self.publishBlock(@[common, platform]);
    id expected = [NSSet setWithObject:kUARemoteConfigModulePush];
    XCTAssertEqualObjects(expected, self.testModuleAdapter.disabledModuleNames);
}

/**
 * Test overiding disable comonents with an empty module array does not disable any modules.
 */
- (void)testPlatformDisableOverrideEmptyModules {
    UARemoteDataPayload *common = [UARemoteConfigManagerTest disablePayloadWithName:@"app_config"
                                                                    refreshInterval:nil
                                                                     disableModules:kUARemoteConfigModuleAllModules];


    UARemoteDataPayload *platform = [UARemoteConfigManagerTest disablePayloadWithName:@"app_config:ios"
                                                                      refreshInterval:nil
                                                                       disableModules:@[]];

    self.publishBlock(@[common, platform]);
    id expected = [NSSet set];
    XCTAssertEqualObjects(expected, self.testModuleAdapter.disabledModuleNames);
}

/**
 * Test disabling all components from common
 */
- (void)testDisableCommon {
    UARemoteDataPayload *common = [UARemoteConfigManagerTest disablePayloadWithName:@"app_config"
                                                                    refreshInterval:nil
                                                                     disableModules:kUARemoteConfigModuleAllModules];


    UARemoteDataPayload *platform = [[UARemoteDataPayload alloc] initWithType:@"app_config:ios"
                                                                    timestamp:[NSDate date]
                                                                         data:@{}
                                                                     metadata:@{}];

    self.publishBlock(@[common, platform]);
    id expected = [NSSet setWithArray:kUARemoteConfigModuleAllModules];
    XCTAssertEqualObjects(expected, self.testModuleAdapter.disabledModuleNames);
}

/**
 * Test filtering disable infos by app version.
 */
- (void)testFilterDisableInfosByAppVersion {
    id appVersionFilteredPayload = @{
        @"disable_features": @[
                @{
                    @"modules": @[@"push"],
                    @"app_versions": @{ @"value": @{ @"version_matches": @"+" }, @"scope": @[@"ios", @"version"] }
                },
                @{
                    @"modules": @[@"location"],
                    @"app_versions": @{ @"value": @{ @"version_matches": @"8.0.+" }, @"scope": @[@"ios", @"version"] }
                },
                @{
                    @"modules": @"all",
                    @"app_versions": @{ @"value": @{ @"version_matches": @"[1.0, 8.0]" }, @"scope": @[@"ios", @"version"] }
                },
        ]
    };

    UARemoteDataPayload *platform = [[UARemoteDataPayload alloc] initWithType:@"app_config:ios"
                                                                    timestamp:[NSDate date]
                                                                         data:appVersionFilteredPayload
                                                                     metadata:@{}];
    self.appVersion = @"0.0.0";
    self.publishBlock(@[platform]);
    id expected = [NSSet setWithObject:kUARemoteConfigModulePush];
    XCTAssertEqualObjects(expected, self.testModuleAdapter.disabledModuleNames);

    self.appVersion = @"1.0.0";
    [self.testModuleAdapter.disabledModuleNames removeAllObjects];
    self.publishBlock(@[platform]);
    expected = [NSSet setWithArray:kUARemoteConfigModuleAllModules];
    XCTAssertEqualObjects(expected, self.testModuleAdapter.disabledModuleNames);

    self.appVersion = @"9.0.0";
    [self.testModuleAdapter.disabledModuleNames removeAllObjects];
    self.publishBlock(@[platform]);
    expected = [NSSet setWithObject:kUARemoteConfigModulePush];
    XCTAssertEqualObjects(expected, self.testModuleAdapter.disabledModuleNames);
}

/**
 * Test filtering disable infos by SDK versions
 */
- (void)testFilterDisableInfosBySDKVersion {
    id appVersionFilteredPayload = @{
        @"disable_features": @[
                @{
                    @"modules": @[@"push"],
                    @"sdk_versions": @[@"+"]
                },
                @{
                    @"modules": @[@"all"],
                    @"sdk_versions": @[@"4.0.0"]
                },
                @{
                    @"modules": @[@"location"],
                    @"sdk_versions": @[@"1.0.0", @"[1.0,99.0["]
                },
        ]
    };

    UARemoteDataPayload *platform = [[UARemoteDataPayload alloc] initWithType:@"app_config:ios"
                                                                    timestamp:[NSDate date]
                                                                         data:appVersionFilteredPayload
                                                                     metadata:@{}];
    self.publishBlock(@[platform]);
    id expected = [NSSet setWithArray:@[kUARemoteConfigModulePush, kUARemoteConfigModuleLocation]];
    XCTAssertEqualObjects(expected, self.testModuleAdapter.disabledModuleNames);
}

/**
 * Test refresh interval
 */
- (void)testRefreshInterval {
    UARemoteDataPayload *commonRefreshInterval = [UARemoteConfigManagerTest disablePayloadWithName:@"app_config"
                                                                                   refreshInterval:@(1)
                                                                                    disableModules:nil];

    UARemoteDataPayload *platformRefreshInterval = [UARemoteConfigManagerTest disablePayloadWithName:@"app_config:ios"
                                                                                     refreshInterval:@(100)
                                                                                      disableModules:nil];

    [[self.mockRemoteDataManager expect] setRemoteDataRefreshInterval:100];
    self.publishBlock(@[commonRefreshInterval, platformRefreshInterval]);

    [self.mockRemoteDataManager verify];
}

/**
 * Test refresh interval is the max value of all the eligible disable infos.
 */
- (void)testRefreshIntervalMaxValue {
    id appVersionFilteredPayload = @{
        @"disable_features": @[
                @{
                    @"remote_data_refresh_interval": @(200),
                    @"app_versions": @{ @"value": @{ @"version_matches": @"+" }, @"scope": @[@"ios", @"version"] }
                },
                @{
                    @"remote_data_refresh_interval": @(400),
                    @"app_versions": @{ @"value": @{ @"version_matches": @"9.+" }, @"scope": @[@"ios", @"version"] }
                },
                @{
                    @"remote_data_refresh_interval": @(200),
                    @"app_versions": @{ @"value": @{ @"version_matches": @"[1.0, 8.0]" }, @"scope": @[@"ios", @"version"] }
                },
        ]
    };

    UARemoteDataPayload *platform = [[UARemoteDataPayload alloc] initWithType:@"app_config:ios"
                                                                    timestamp:[NSDate date]
                                                                         data:appVersionFilteredPayload
                                                                     metadata:@{}];
    self.appVersion = @"9.0.0";
    self.publishBlock(@[platform]);

    [[self.mockRemoteDataManager expect] setRemoteDataRefreshInterval:400];
    self.publishBlock(@[platform]);

    [self.mockRemoteDataManager verify];
}


/**
 * Test remote config
 */
- (void)testRemoteConfig {
    UARemoteDataPayload *common = [UARemoteConfigManagerTest remoteConfigWithName:@"app_config"
                                                                           config:@{
                                                                               kUARemoteConfigModulePush: @"some config",
                                                                               kUARemoteConfigModuleLocation: @"some other config"
                                                                           }];

    UARemoteDataPayload *platform = [UARemoteConfigManagerTest remoteConfigWithName:@"app_config:ios"
                                                                             config:@{
                                                                                 kUARemoteConfigModuleLocation: @"ios override"
                                                                             }];

    self.publishBlock(@[common, platform]);

    // Verify push and location contains data
    XCTAssertEqualObjects(@"some config", self.testModuleAdapter.appliedConfig[kUARemoteConfigModulePush]);
    XCTAssertEqualObjects(@"ios override", self.testModuleAdapter.appliedConfig[kUARemoteConfigModuleLocation]);

    // Verify the rest of the modules where applied with nil
    for (NSString *module in kUARemoteConfigModuleAllModules) {
        if ([module isEqualToString:kUARemoteConfigModulePush] || [module isEqualToString:kUARemoteConfigModuleLocation]) {
            continue;
        }

        XCTAssertEqualObjects([NSNull null], self.testModuleAdapter.appliedConfig[module]);
    }
}


+ (UARemoteDataPayload *)remoteConfigWithName:(NSString *)name
                                       config:(NSDictionary *)config {


    return [[UARemoteDataPayload alloc] initWithType:name
                                           timestamp:[NSDate date]
                                                data:config
                                            metadata:@{}];
}

+ (UARemoteDataPayload *)disablePayloadWithName:(NSString *)name
                                refreshInterval:(NSNumber *)refreshInterval
                                 disableModules:(NSArray *)disableModules {

    return [self disablePayloadWithName:name
                        refreshInterval:refreshInterval
                         disableModules:disableModules
                  appVersionConstraints:nil
                  sdkVersionConstraints:nil];
}

+ (UARemoteDataPayload *)disablePayloadWithName:(NSString *)name
                                refreshInterval:(NSNumber *)refreshInterval
                                 disableModules:(NSArray *)disableModules
                          appVersionConstraints:(NSString *)appVersionConstraints
                          sdkVersionConstraints:(NSArray *)sdkVersionConstraints {


    NSMutableDictionary *disableInfo = [NSMutableDictionary dictionary];
    [disableInfo setValue:refreshInterval forKey:@"remote_data_refresh_interval"];
    [disableInfo setValue:disableModules forKey:@"modules"];
    [disableInfo setValue:sdkVersionConstraints forKey:@"sdk_versions"];

    if (appVersionConstraints) {
        UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:appVersionConstraints] scope:@[@"ios", @"version"]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:matcher];
        [disableInfo setValue:[predicate payload] forKey:@"app_versions"];
    }

    return [[UARemoteDataPayload alloc] initWithType:name
                                           timestamp:[NSDate date]
                                                data:@{ @"disable_features": @[disableInfo] }
                                            metadata:@{}];
}

@end

@implementation UATestRemoteConfigModuleAdapter

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.enabledModuleNames = [NSMutableSet set];
        self.disabledModuleNames = [NSMutableSet set];
        self.appliedConfig = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setComponentsEnabled:(BOOL)enabled forModuleName:(NSString *)moduleName {
    if (enabled) {
        [self.enabledModuleNames addObject:moduleName];
    } else {
        [self.disabledModuleNames addObject:moduleName];
    }
}


- (void)applyConfig:(nullable id)config forModuleName:(NSString *)moduleName {
    self.appliedConfig[moduleName] = config ?: [NSNull null];
}

@end


