/* Copyright Airship and Contributors */

#import "UATestRuntimeConfig.h"
#import "UARuntimeConfig+Internal.h"

@implementation UATestRuntimeConfig
@synthesize appKey;
@synthesize appSecret;
@synthesize logLevel;
@synthesize inProduction;
@synthesize automaticSetupEnabled;
@synthesize whitelist;
@synthesize itunesID;
@synthesize analyticsEnabled;
@synthesize detectProvisioningMode;
@synthesize messageCenterStyleConfig;
@synthesize clearUserOnAppRestore;
@synthesize clearNamedUserOnAppRestore;
@synthesize channelCaptureEnabled;
@synthesize openURLWhitelistingEnabled;
@synthesize channelCreationDelayEnabled;
@synthesize customConfig;
@synthesize requestAuthorizationToUseNotifications;
@synthesize deviceAPIURL;
@synthesize analyticsURL;
@synthesize remoteDataAPIURL;

- (instancetype)init {
    UAConfig *config = [UAConfig config];
    config.defaultAppKey = @"0000000000000000000000";
    config.defaultAppSecret = @"0000000000000000000000";

    self = [super initWithConfig:config];
    return self;
}

+ (instancetype)testConfig {
    return [[UATestRuntimeConfig alloc] init];
}

@end
