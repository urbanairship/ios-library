/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAConfigTest.h"

#import "UAConfig+Internal.h"

@implementation UAConfigTest

/* setup and teardown */

- (void)setUp {
    [super setUp];

}

- (void)tearDown {
    [super tearDown];
}

/* tests */

- (void)testUnknownKeyHandling {
    // ensure that unknown values don't crash the app with an unkown key exception

    UAConfig *config =[[UAConfig alloc] init];
    STAssertNoThrow([config setValue:@"someValue" forKey:@"thisKeyDoesNotExist"], @"Invalid key incorrectly throws an exception.");
}

- (void)testProductionProfileParsing {
    NSString *profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"production-embedded" ofType:@"mobileprovision"];
    STAssertTrue([UAConfig isProductionProvisioningProfile:profilePath], @"Incorrectly evaluated a production profile");
}

- (void)testDevelopmentProfileParsing {
    NSString *profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"development-embedded" ofType:@"mobileprovision"];
    STAssertFalse([UAConfig isProductionProvisioningProfile:profilePath], @"Incorrectly evaluated a development profile");
}

- (void)testMissingEmbeddedProfile {
    STAssertTrue([UAConfig isProductionProvisioningProfile:nil], @"Missing profiles should result in a production mode determination.");
}

- (void)testSimulatorFallback {

    // Ensure that the simulator falls back to the inProduction flag as it was set

    UAConfig *configInProduction =[[UAConfig alloc] init];
    configInProduction.inProduction = YES;
    configInProduction.detectProvisioningMode = YES;
    STAssertTrue(configInProduction.inProduction, @"Simulators with provisioning detection enabled should return the production value as set.");

    UAConfig *configInDevelopment =[[UAConfig alloc] init];
    configInDevelopment.inProduction = NO;
    configInDevelopment.detectProvisioningMode = YES;
    STAssertFalse(configInDevelopment.inProduction, @"Simulators with provisioning detection enabled should return the production value as set.");
}

- (void)testProductionFlag {
    UAConfig *config = [[UAConfig alloc] init];

    // initialize with a custom profile path that is accessible from this test environment
    config.profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"production-embedded" ofType:@"mobileprovision"];

    // populate dev and prod keys, then toggle between them
    config.developmentAppKey = @"devAppKey";
    config.developmentAppSecret = @"devAppSecret";
    config.developmentLogLevel = UALogLevelTrace;//not the default
    
    config.productionAppKey = @"prodAppKey";
    config.productionAppSecret = @"prodAppSecret";
    config.productionLogLevel = UALogLevelNone;//not the default

    STAssertFalse(config.inProduction, @"inProduction defaults to NO.");
    STAssertFalse(config.detectProvisioningMode, @"detectProvisioningMode defaults to NO.");

    STAssertEqualObjects(config.appKey, config.developmentAppKey, @"Incorrect app key resolution.");
    STAssertEqualObjects(config.appSecret, config.developmentAppSecret, @"Incorrect app secret resolution.");
    STAssertEquals(config.logLevel, config.developmentLogLevel, @"Incorrect log level resolution.");

    config.inProduction = YES;
    STAssertEqualObjects(config.appKey, config.productionAppKey, @"Incorrect app key resolution.");
    STAssertEqualObjects(config.appSecret, config.productionAppSecret, @"Incorrect app secret resolution.");
    STAssertEquals(config.logLevel, config.productionLogLevel, @"Incorrect log level resolution.");

    config.inProduction = NO;
    config.detectProvisioningMode = YES;

    STAssertTrue(config.inProduction, @"The embedded provisioning profile is a production profile.");

    // ensure that our dispatch_once block works when wrapping the in production flag
    config.profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"development-embedded" ofType:@"mobileprovision"];
    STAssertTrue(config.inProduction, @"The development profile path should not be used as the file will only be read once.");
}

- (void)testOldPlistFormat {
    NSString *legacyPlistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid-Legacy-NeXTStep" ofType:@"plist"];


    NSString *validAppValue = @"0A00000000000000000000";
    UAConfig *config = [UAConfig configWithContentsOfFile:legacyPlistPath];

    STAssertTrue([config validate], @"Legacy Config File is invalid.");

    STAssertEqualObjects(config.productionAppKey, validAppValue, @"Production app key was improperly loaded.");
    STAssertEqualObjects(config.productionAppSecret, validAppValue, @"Production app secret was improperly loaded.");
    STAssertEqualObjects(config.developmentAppKey, validAppValue, @"Development app key was improperly loaded.");
    STAssertEqualObjects(config.developmentAppSecret, validAppValue, @"Development app secret was improperly loaded.");

    STAssertEquals(config.developmentLogLevel, 5, @"Development log level was improperly loaded.");
    STAssertTrue(config.clearKeychain, @"Clear keychain was improperly loaded.");
    STAssertTrue(config.inProduction, @"inProduction was improperly loaded.");

}

- (void)testPlistParsing {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid" ofType:@"plist"];


    NSString *validAppValue = @"0A00000000000000000000";
    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    STAssertTrue([config validate], @"AirshipConfig (modern) File is invalid.");

    STAssertEqualObjects(config.productionAppKey, validAppValue, @"Production app key was improperly loaded.");
    STAssertEqualObjects(config.productionAppSecret, validAppValue, @"Production app secret was improperly loaded.");
    STAssertEqualObjects(config.developmentAppKey, validAppValue, @"Development app key was improperly loaded.");
    STAssertEqualObjects(config.developmentAppSecret, validAppValue, @"Development app secret was improperly loaded.");

    STAssertEquals(config.developmentLogLevel, 1, @"Development log level was improperly loaded.");
    STAssertEquals(config.productionLogLevel, 5, @"Production log level was improperly loaded.");
    STAssertTrue(config.clearKeychain, @"Clear keychain was improperly loaded.");
    STAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode was improperly loaded.");

    //special case this one since we have to disable detectProvisioningMode
    config.detectProvisioningMode = NO;
    STAssertTrue(config.inProduction, @"inProduction was improperly loaded.");
}

- (void)testNeXTStepPlistParsing {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid-NeXTStep" ofType:@"plist"];

    NSString *validAppValue = @"0A00000000000000000000";
    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    STAssertTrue([config validate], @"NeXTStep plist file is invalid.");

    STAssertEqualObjects(config.productionAppKey, validAppValue, @"Production app key was improperly loaded.");
    STAssertEqualObjects(config.productionAppSecret, validAppValue, @"Production app secret was improperly loaded.");
    STAssertEqualObjects(config.developmentAppKey, validAppValue, @"Development app key was improperly loaded.");
    STAssertEqualObjects(config.developmentAppSecret, validAppValue, @"Development app secret was improperly loaded.");

    STAssertEquals(config.developmentLogLevel, 1, @"Development log level was improperly loaded.");
    STAssertEquals(config.productionLogLevel, 5, @"Production log level was improperly loaded.");
    STAssertTrue(config.clearKeychain, @"Clear keychain was improperly loaded.");
    STAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode was improperly loaded.");

    //special case this one since we have to disable detectProvisioningMode
    config.detectProvisioningMode = NO;
    STAssertTrue(config.inProduction, @"inProduction was improperly loaded.");
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
    STAssertFalse([config validate], @"Development App Key is improperly verified.");
    config.developmentAppKey = validAppValue;

    config.developmentAppSecret = invalidValue;
    STAssertFalse([config validate], @"Development App Secret is improperly verified.");
    config.developmentAppSecret = validAppValue;

    //switch to production mode as validation only strictly checks the current keypair
    config.inProduction = YES;

    config.productionAppKey = invalidValue;
    STAssertFalse([config validate], @"Production App Key is improperly verified.");
    config.productionAppKey = validAppValue;

    config.productionAppSecret = invalidValue;
    STAssertFalse([config validate], @"Production App Secret is improperly verified.");
    config.productionAppSecret = validAppValue;

}

- (void) testSetAnalyticsURL {
    UAConfig *config =[[UAConfig alloc] init];

    config.analyticsURL = @"http://some-other-url.com";
    STAssertEqualObjects(@"http://some-other-url.com", config.analyticsURL, @"Analytics URL does not set correctly");
    
    config.analyticsURL = @"http://some-url.com/";
    STAssertEqualObjects(@"http://some-url.com", config.analyticsURL, @"Analytics URL still contains trailing slash");
}

- (void) testSetDeviceAPIURL {
    UAConfig *config =[[UAConfig alloc] init];

    config.deviceAPIURL = @"http://some-other-url.com";
    STAssertEqualObjects(@"http://some-other-url.com", config.deviceAPIURL, @"Device API URL does not set correctly");
    
    config.deviceAPIURL = @"http://some-url.com/";
    STAssertEqualObjects(@"http://some-url.com", config.deviceAPIURL, @"Device API URL still contains trailing slash");
}

@end
