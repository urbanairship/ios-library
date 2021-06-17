/* Copyright Airship and Contributors */

#import "UATestRuntimeConfig.h"
#import "UARuntimeConfig+Internal.h"
@import AirshipCore;

@implementation UATestRuntimeConfig
@synthesize appKey;
@synthesize appSecret;
@synthesize logLevel;
@synthesize inProduction;
@synthesize automaticSetupEnabled;
@synthesize URLAllowList;
@synthesize URLAllowListScopeJavaScriptInterface;
@synthesize URLAllowListScopeOpenURL;
@synthesize itunesID;
@synthesize analyticsEnabled;
@synthesize detectProvisioningMode;
@synthesize messageCenterStyleConfig;
@synthesize clearUserOnAppRestore;
@synthesize clearNamedUserOnAppRestore;
@synthesize channelCaptureEnabled;
@synthesize channelCreationDelayEnabled;
@synthesize customConfig;
@synthesize requestAuthorizationToUseNotifications;

- (instancetype)init {
    UAConfig *config = [UAConfig config];
    config.defaultAppKey = @"0000000000000000000000";
    config.defaultAppSecret = @"0000000000000000000000";

    UAPreferenceDataStore *dataStore = [[UAPreferenceDataStore alloc] initWithKeyPrefix:[NSString stringWithFormat:@"uaRuntimeConfigTest"]];
    UARemoteConfigURLManager *urlManager = [UARemoteConfigURLManager remoteConfigURLManagerWithDataStore:dataStore];
   
    self = [super initWithConfig:config urlManager:urlManager];
    return self;
}

+ (instancetype)testConfig {
    return [[UATestRuntimeConfig alloc] init];
}

@end
