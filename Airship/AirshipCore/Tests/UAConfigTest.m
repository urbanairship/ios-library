/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UAConfigTest : UABaseTest
@end

@implementation UAConfigTest

- (void)testUnknownKeyHandling {
    // ensure that unknown values don't crash the app with an unkown key exception
    UAConfig *config =[[UAConfig alloc] init];
    XCTAssertNoThrow([config setValue:@"someValue" forKey:@"thisKeyDoesNotExist"], @"Invalid key incorrectly throws an exception.");
}

- (void)testProductionProfileParsing {
    NSString *profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"production-embedded" ofType:@"mobileprovision"];
    XCTAssertTrue([UAConfig isProductionProvisioningProfile:profilePath], @"Incorrectly evaluated a production profile");
}

- (void)testDevelopmentProfileParsing {
    NSString *profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"development-embedded" ofType:@"mobileprovision"];
    XCTAssertFalse([UAConfig isProductionProvisioningProfile:profilePath], @"Incorrectly evaluated a development profile");
}

- (void)testMissingEmbeddedProfile {
    XCTAssertTrue([UAConfig isProductionProvisioningProfile:@""], @"Missing profiles should result in a production mode determination.");
}

- (void)testSimulatorFallback {
    // Ensure that the simulator falls back to the inProduction flag as it was set if there isn't a profile
    UAConfig *configInProduction = [[UAConfig alloc] init];
    configInProduction.profilePath = nil;
    configInProduction.inProduction = YES;
    configInProduction.detectProvisioningMode = YES;
    XCTAssertTrue(configInProduction.inProduction);

    UAConfig *configInDevelopment = [[UAConfig alloc] init];
    configInDevelopment.profilePath = nil;
    configInDevelopment.inProduction = NO;
    configInDevelopment.detectProvisioningMode = YES;
    XCTAssertFalse(configInDevelopment.inProduction);
}

- (void)testMissingProvisioningOnDeviceFallback {

    // Ensure that a device falls back to YES rather than inProduction when there isn't a profile

    UAConfig *configInDevelopment =[[UAConfig alloc] init];
    configInDevelopment.profilePath = nil;
    configInDevelopment.inProduction = NO;
    configInDevelopment.detectProvisioningMode = YES;
    XCTAssertFalse(configInDevelopment.inProduction, @"Devices without embedded provisioning profiles AND provisioning detection enabled should return YES for inProduction as a safety measure.");
}

- (void)testProductionFlag {
    UAConfig *config = [[UAConfig alloc] init];

    // initialize with a custom profile path that is accessible from this test environment
    config.profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"production-embedded" ofType:@"mobileprovision"];

    // populate dev and prod keys, then toggle between them
    config.developmentAppKey = @"devAppKey";
    config.developmentAppSecret = @"devAppSecret";
    config.developmentLogLevel = UALogLevelVerbose;//not the default
    
    config.productionAppKey = @"prodAppKey";
    config.productionAppSecret = @"prodAppSecret";
    config.productionLogLevel = UALogLevelNone;//not the default

    XCTAssertTrue(config.inProduction, @"inProduction defaults to YES.");
    XCTAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode defaults to YES.");
    XCTAssertEqualObjects(config.appKey, config.productionAppKey, @"Incorrect app key resolution.");
    XCTAssertEqualObjects(config.appSecret, config.productionAppSecret, @"Incorrect app secret resolution.");
    XCTAssertEqual(config.logLevel, config.productionLogLevel, @"Incorrect log level resolution.");

    config.inProduction = NO;
    XCTAssertFalse(config.detectProvisioningMode, @"detectProvisioningMode defaults to NO.");
    XCTAssertEqualObjects(config.appKey, config.developmentAppKey, @"Incorrect app key resolution.");
    XCTAssertEqualObjects(config.appSecret, config.developmentAppSecret, @"Incorrect app secret resolution.");
    XCTAssertEqual(config.logLevel, config.developmentLogLevel, @"Incorrect log level resolution.");

    config.inProduction = YES;
    XCTAssertFalse(config.detectProvisioningMode, @"detectProvisioningMode defaults to NO.");
    XCTAssertEqualObjects(config.appKey, config.productionAppKey, @"Incorrect app key resolution.");
    XCTAssertEqualObjects(config.appSecret, config.productionAppSecret, @"Incorrect app secret resolution.");
    XCTAssertEqual(config.logLevel, config.productionLogLevel, @"Incorrect log level resolution.");

    config.detectProvisioningMode = YES;
    XCTAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode defaults to YES.");
    XCTAssertTrue(config.inProduction, @"The embedded provisioning profile is a production profile.");
}

/**
 * Test detectProvisioningMode = YES when neither detectProvisioningMode or inProduction
 * is explicity set in AirshipConfig.plist
 */
- (void)testDetectProvisioningModeDefault {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Without-InProduction-And-DetectProvisioningMode" ofType:@"plist"];

    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    XCTAssertTrue([config validate], @"AirshipConfig (modern) File is invalid.");
    XCTAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode should default to true");
}

/**
 * Test detectProvisioningMode = YES when detectProvisioningMode is explicity set in AirshipConfig.plist
 */
- (void)testDetectProvisioningModeExplicitlySet {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-DetectProvisioningMode" ofType:@"plist"];

    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    XCTAssertTrue([config validate], @"AirshipConfig (modern) File is invalid.");
    XCTAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode should be true");
}

/**
 * Test inProduction = YES when inProduction is explicitly set in AirshipConfig.plist
 */
- (void)testInProductionExplicitlySet {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-InProduction" ofType:@"plist"];

    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    XCTAssertTrue([config validate], @"AirshipConfig (modern) File is invalid.");
    XCTAssertTrue(config.inProduction, @"inProduction should be true");
}

/**
 * Test when both detectProvisioningMode and inProduction is explicitly set in AirshipConfig.plist
 */
- (void)testDetectProvisioningModeAndInProductionExplicitlySet {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid" ofType:@"plist"];

    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    XCTAssertTrue([config validate], @"AirshipConfig (modern) File is invalid.");
    XCTAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode should be true");
    XCTAssertTrue(config.inProduction, @"inProduction should be true");
    XCTAssertEqual(UACloudSiteEU, config.site);
    XCTAssertEqualObjects(@"https://some-chat-url", config.chatURL);
    XCTAssertEqualObjects(@[@"*"], config.URLAllowListScopeOpenURL);

}

- (void)testOldPlistFormat {
    NSString *legacyPlistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid-Legacy-NeXTStep" ofType:@"plist"];


    NSString *validAppValue = @"0A00000000000000000000";
    UAConfig *config = [UAConfig configWithContentsOfFile:legacyPlistPath];

    XCTAssertTrue([config validate], @"Legacy Config File is invalid.");

    XCTAssertEqualObjects(config.productionAppKey, validAppValue, @"Production app key was improperly loaded.");
    XCTAssertEqualObjects(config.productionAppSecret, validAppValue, @"Production app secret was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppKey, validAppValue, @"Development app key was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppSecret, validAppValue, @"Development app secret was improperly loaded.");

    XCTAssertEqual(config.developmentLogLevel, 5, @"Development log level was improperly loaded.");
    XCTAssertTrue(config.inProduction, @"inProduction was improperly loaded.");

}

- (void)testPlistParsing {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid" ofType:@"plist"];


    NSString *validAppValue = @"0A00000000000000000000";
    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    XCTAssertTrue([config validate], @"AirshipConfig (modern) File is invalid.");

    XCTAssertEqualObjects(config.productionAppKey, validAppValue, @"Production app key was improperly loaded.");
    XCTAssertEqualObjects(config.productionAppSecret, validAppValue, @"Production app secret was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppKey, validAppValue, @"Development app key was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppSecret, validAppValue, @"Development app secret was improperly loaded.");

    XCTAssertEqual(config.developmentLogLevel, 1, @"Development log level was improperly loaded.");
    XCTAssertEqual(config.productionLogLevel, 5, @"Production log level was improperly loaded.");
    XCTAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode was improperly loaded.");
    XCTAssertTrue(config.isChannelCreationDelayEnabled, @"channelCreationDelayEnabled was improperly loaded.");
    XCTAssertTrue(config.isExtendedBroadcastsEnabled, @"extendedBroadcastsEnabled was improperly loaded.");

    //special case this one since we have to disable detectProvisioningMode
    config.detectProvisioningMode = NO;
    XCTAssertTrue(config.inProduction, @"inProduction was improperly loaded.");
    
    XCTAssertEqual(UAFeaturesPush | UAFeaturesInAppAutomation, config.enabledFeatures);
}

- (void)testNeXTStepPlistParsing {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid-NeXTStep" ofType:@"plist"];

    NSString *validAppValue = @"0A00000000000000000000";
    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    XCTAssertTrue([config validate], @"NeXTStep plist file is invalid.");

    XCTAssertEqualObjects(config.productionAppKey, validAppValue, @"Production app key was improperly loaded.");
    XCTAssertEqualObjects(config.productionAppSecret, validAppValue, @"Production app secret was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppKey, validAppValue, @"Development app key was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppSecret, validAppValue, @"Development app secret was improperly loaded.");

    XCTAssertEqual(config.developmentLogLevel, 1, @"Development log level was improperly loaded.");
    XCTAssertEqual(config.productionLogLevel, 5, @"Production log level was improperly loaded.");
    XCTAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode was improperly loaded.");
    XCTAssertTrue(config.isChannelCreationDelayEnabled, @"channelCreationDelayEnabled was improperly loaded.");

    //special case this one since we have to disable detectProvisioningMode
    config.detectProvisioningMode = NO;
    XCTAssertTrue(config.inProduction, @"inProduction was improperly loaded.");
}

- (void)testValidation {

    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid" ofType:@"plist"];

    NSString *validAppValue = @"0A00000000000000000000";
    NSString *invalidValue = @" invalid!!! ";
    
    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    config.inProduction = NO;
    config.detectProvisioningMode = NO;

    // Make it invalid and then valid again, asserting the whole way.
    
    config.developmentAppKey = invalidValue;
    XCTAssertFalse([config validate], @"Development App Key is improperly verified.");
    config.developmentAppKey = validAppValue;

    config.developmentAppSecret = invalidValue;
    XCTAssertFalse([config validate], @"Development App Secret is improperly verified.");
    config.developmentAppSecret = validAppValue;

    //switch to production mode as validation only strictly checks the current keypair
    config.inProduction = YES;

    config.productionAppKey = invalidValue;
    XCTAssertFalse([config validate], @"Production App Key is improperly verified.");
    config.productionAppKey = validAppValue;

    config.productionAppSecret = invalidValue;
    XCTAssertFalse([config validate], @"Production App Secret is improperly verified.");
    config.productionAppSecret = validAppValue;

}

- (void) testCopyConfig {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid" ofType:@"plist"];

    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];
    UAConfig *copy = [config copy];

    XCTAssertEqualObjects(copy.description, config.description);
    XCTAssertTrue(copy.developmentAppKey == config.developmentAppKey);
    XCTAssertTrue(copy.developmentAppSecret == config.developmentAppSecret);
    XCTAssertTrue(copy.productionAppKey == config.productionAppKey);
    XCTAssertTrue(copy.productionAppSecret == config.productionAppSecret);
    XCTAssertTrue(copy.deviceAPIURL == config.deviceAPIURL);
    XCTAssertTrue(copy.remoteDataAPIURL == config.remoteDataAPIURL);
    XCTAssertTrue(copy.analyticsURL == config.analyticsURL);
    XCTAssertTrue(copy.developmentLogLevel == config.developmentLogLevel);
    XCTAssertTrue(copy.productionLogLevel == config.productionLogLevel);
    XCTAssertTrue(copy.inProduction == config.inProduction);
    XCTAssertTrue(copy.detectProvisioningMode == config.detectProvisioningMode);
    XCTAssertTrue(copy.profilePath == config.profilePath);
    XCTAssertTrue(copy.isAnalyticsEnabled == config.isAnalyticsEnabled);
    XCTAssertTrue(copy.clearUserOnAppRestore == config.clearUserOnAppRestore);
    XCTAssertEqualObjects(copy.URLAllowList, config.URLAllowList);
    XCTAssertEqualObjects(copy.URLAllowListScopeJavaScriptInterface, config.URLAllowListScopeJavaScriptInterface);
    XCTAssertEqualObjects(copy.URLAllowListScopeOpenURL, config.URLAllowListScopeOpenURL);
    XCTAssertTrue(copy.clearNamedUserOnAppRestore == config.clearNamedUserOnAppRestore);
    XCTAssertTrue(copy.isChannelCaptureEnabled == config.isChannelCaptureEnabled);
    XCTAssertTrue(copy.isChannelCreationDelayEnabled == config.isChannelCreationDelayEnabled);
    XCTAssertTrue(copy.isExtendedBroadcastsEnabled == config.isExtendedBroadcastsEnabled);
    XCTAssertTrue(copy.messageCenterStyleConfig == config.messageCenterStyleConfig);
    XCTAssertTrue(copy.itunesID == config.itunesID);
    XCTAssertTrue(copy.requestAuthorizationToUseNotifications == config.requestAuthorizationToUseNotifications);
    XCTAssertTrue(copy.requireInitialRemoteConfigEnabled == config.requireInitialRemoteConfigEnabled);
    XCTAssertEqual(copy.enabledFeatures, config.enabledFeatures);

}

- (void)testInitialConfig {
    UAConfig *config = [UAConfig config];
    XCTAssertEqual(UACloudSiteUS, config.site);
    XCTAssertNil(config.deviceAPIURL);
    XCTAssertNil(config.remoteDataAPIURL);
    XCTAssertNil(config.analyticsURL);
    XCTAssertEqual(config.developmentLogLevel, UALogLevelDebug);
    XCTAssertEqual(config.productionLogLevel, UALogLevelError);
    XCTAssertFalse(config.inProduction);
    XCTAssertTrue(config.detectProvisioningMode);
    XCTAssertTrue(config.isAutomaticSetupEnabled);
    XCTAssertTrue(config.isAnalyticsEnabled);
    XCTAssertFalse(config.clearUserOnAppRestore);
    XCTAssertEqual(config.URLAllowList.count, 0);
    XCTAssertEqual(config.URLAllowListScopeJavaScriptInterface.count, 0);
    XCTAssertEqual(config.URLAllowListScopeOpenURL.count, 0);
    XCTAssertFalse(config.clearNamedUserOnAppRestore);
    XCTAssertTrue(config.isChannelCaptureEnabled);
    XCTAssertFalse(config.isChannelCreationDelayEnabled);
    XCTAssertFalse(config.isExtendedBroadcastsEnabled);
    XCTAssertTrue(config.requestAuthorizationToUseNotifications);
    XCTAssertTrue(config.requireInitialRemoteConfigEnabled);

}

@end
