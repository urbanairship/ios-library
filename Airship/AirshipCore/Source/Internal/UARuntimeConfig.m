/* Copyright Airship and Contributors */

#import "UARuntimeConfig+Internal.h"

@interface UARuntimeConfig()

@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, copy) NSString *appKey;
@property (nonatomic, copy) NSString *appSecret;
@property (nonatomic, assign) UALogLevel logLevel;
@property (nonatomic, assign, getter=isInProduction) BOOL inProduction;
@property (nonatomic, assign, getter=isAutomaticSetupEnabled) BOOL automaticSetupEnabled;
@property (nonatomic, copy) NSArray<NSString *> *URLAllowList;
@property (nonatomic, copy) NSArray<NSString *> *URLAllowListScopeJavaScriptInterface;
@property (nonatomic, copy) NSArray<NSString *> *URLAllowListScopeOpenURL;
@property (nonatomic, assign) BOOL suppressAllowListError;
@property (nonatomic, copy) NSString *itunesID;
@property (nonatomic, assign, getter=isAnalyticsEnabled) BOOL analyticsEnabled;
@property (nonatomic, assign) BOOL detectProvisioningMode;
@property (nonatomic, copy) NSString *messageCenterStyleConfig;
@property (nonatomic, assign) BOOL clearUserOnAppRestore;
@property (nonatomic, assign) BOOL clearNamedUserOnAppRestore;
@property (nonatomic, assign, getter=isChannelCaptureEnabled) BOOL channelCaptureEnabled;
@property (nonatomic, assign, getter=isChannelCreationDelayEnabled) BOOL channelCreationDelayEnabled;
@property (nonatomic, assign, getter=isExtendedBroadcastsEnabled) BOOL extendedBroadcastsEnabled;
@property (nonatomic, copy) NSDictionary *customConfig;
@property (nonatomic, assign) BOOL requestAuthorizationToUseNotifications;
@property (nonatomic, assign) BOOL requireInitialRemoteConfig;
@property (nonatomic, assign, getter=isDataCollectionOptInEnabled) BOOL dataCollectionOptInEnabled;
@property (nonatomic, strong) UARemoteConfigURLManager *urlManager;

@property (nonatomic, copy) NSString *deviceAPIURL;
@property (nonatomic, copy) NSString *analyticsURL;
@property (nonatomic, copy) NSString *remoteDataAPIURL;

@end

// US
NSString *const UARuntimeConfigUSDeviceAPIURL = @"https://device-api.urbanairship.com";
NSString *const UARuntimeConfigUSAnalyticsURL = @"https://combine.urbanairship.com";
NSString *const UARuntimeConfigUSRemoteDataAPIURL = @"https://remote-data.urbanairship.com";

// EU
NSString *const UARuntimeConfigEUDeviceAPIURL = @"https://device-api.asnapieu.com";
NSString *const UARuntimeConfigEUAnalyticsURL = @"https://combine.asnapieu.com";
NSString *const UARuntimeConfigEURemoteDataAPIURL = @"https://remote-data.asnapieu.com";

@implementation UARuntimeConfig

- (instancetype)initWithConfig:(UAConfig *)config urlManager:(UARemoteConfigURLManager *)urlManager {
    self = [super init];
    if (self) {
        self.config = config;
        self.logLevel = config.logLevel;
        self.appKey = config.appKey;
        self.appSecret = config.appSecret;        
        self.urlManager = urlManager;
        self.inProduction = config.inProduction;
        self.detectProvisioningMode = config.detectProvisioningMode;
        self.requestAuthorizationToUseNotifications = config.requestAuthorizationToUseNotifications;
        self.requireInitialRemoteConfig = config.requireInitialRemoteConfig;
        self.automaticSetupEnabled = config.automaticSetupEnabled;
        self.analyticsEnabled = config.analyticsEnabled;
        self.clearUserOnAppRestore = config.clearUserOnAppRestore;
        self.URLAllowList = config.URLAllowList;
        self.URLAllowListScopeJavaScriptInterface = config.URLAllowListScopeJavaScriptInterface;
        self.URLAllowListScopeOpenURL = config.URLAllowListScopeOpenURL;
        self.suppressAllowListError = config.suppressAllowListError;
        self.clearNamedUserOnAppRestore = config.clearNamedUserOnAppRestore;
        self.channelCaptureEnabled = config.channelCaptureEnabled;
        self.customConfig = config.customConfig;
        self.channelCreationDelayEnabled = config.channelCreationDelayEnabled;
        self.extendedBroadcastsEnabled = config.extendedBroadcastsEnabled;
        self.messageCenterStyleConfig = config.messageCenterStyleConfig;
        self.itunesID = config.itunesID;
        self.dataCollectionOptInEnabled = config.dataCollectionOptInEnabled;
    }

    return self;
}

+ (nullable instancetype)runtimeConfigWithConfig:(UAConfig *)config urlManager:(UARemoteConfigURLManager *)urlManager {
    if (![config validate]) {
        return nil;
    }

    return [[UARuntimeConfig alloc] initWithConfig:config urlManager:urlManager];
}

- (NSString *)deviceAPIURL {
    if (self.urlManager.deviceAPIURL) {
        return self.urlManager.deviceAPIURL;
    }
    if (self.config.deviceAPIURL) {
        return self.config.deviceAPIURL;
    }

    if (self.requireInitialRemoteConfig) {
        return nil;
    }
    
    switch (self.config.site) {
        case UACloudSiteEU:
            return UARuntimeConfigEUDeviceAPIURL;
        case UACloudSiteUS:
        default:
            return UARuntimeConfigUSDeviceAPIURL;
    }
}

- (NSString *)remoteDataAPIURL {
    if (self.urlManager.remoteDataURL) {
        return self.urlManager.remoteDataURL;
    }

    if (self.config.remoteDataAPIURL) {
        return self.config.remoteDataAPIURL;
    }
    
    switch (self.config.site) {
        case UACloudSiteEU:
            return UARuntimeConfigEURemoteDataAPIURL;
        case UACloudSiteUS:
        default:
            return UARuntimeConfigUSRemoteDataAPIURL;
    }
}

- (NSString *)analyticsURL {
    if (self.urlManager.analyticsURL) {
        return self.urlManager.analyticsURL;
    }

    if (self.config.analyticsURL) {
        return self.config.analyticsURL;
    }

    if (self.requireInitialRemoteConfig) {
        return nil;
    }
    
    switch (self.config.site) {
        case UACloudSiteEU:
            return UARuntimeConfigEUAnalyticsURL;
        case UACloudSiteUS:
        default:
            return UARuntimeConfigUSAnalyticsURL;
    }
}

@end
