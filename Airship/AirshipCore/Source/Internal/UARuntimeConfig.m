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
@property (nonatomic, assign) BOOL requireInitialRemoteConfigEnabled;
@property (nonatomic, assign, getter=isDataCollectionOptInEnabled) BOOL dataCollectionOptInEnabled;
@property (nonatomic, strong) UARemoteConfigURLManager *urlManager;

@property (nonatomic, copy) NSString *internalDeviceAPIURL;
@property (nonatomic, copy) NSString *internalAnalyticsURL;
@property (nonatomic, copy) NSString *internalRemoteDataAPIURL;
@property (nonatomic, copy) NSString *internalChatURL;
@property (nonatomic, copy) NSString *internalChatWebSocketURL;

@end

// US
NSString *const UARuntimeConfigUSDeviceAPIURL = @"https://device-api.urbanairship.com";
NSString *const UARuntimeConfigUSAnalyticsURL = @"https://combine.urbanairship.com";
NSString *const UARuntimeConfigUSRemoteDataAPIURL = @"https://remote-data.urbanairship.com";
NSString *const UARuntimeConfigUSChatAPIURL = @"https://rb2socketscontacts.replybuy.net";
NSString *const UARuntimeConfigUSChatWebSocketAPIURL = @"wss://rb2socketscontacts.replybuy.net";

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
        self.requireInitialRemoteConfigEnabled = config.requireInitialRemoteConfigEnabled;
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
        self.internalAnalyticsURL = config.analyticsURL;
        self.internalDeviceAPIURL = config.deviceAPIURL;
        self.internalRemoteDataAPIURL = config.remoteDataAPIURL;
        self.internalChatURL = config.chatURL;
        self.internalChatWebSocketURL = config.chatWebSocketURL;
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

    if (self.internalDeviceAPIURL) {
        return self.internalDeviceAPIURL;
    }

    if (self.requireInitialRemoteConfigEnabled) {
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

    if (self.internalRemoteDataAPIURL) {
        return self.internalRemoteDataAPIURL;
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

    if (self.internalAnalyticsURL) {
        return self.internalAnalyticsURL;
    }

    if (self.requireInitialRemoteConfigEnabled) {
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

- (NSString *)chatURL {
    if (self.internalChatURL) {
        return self.internalChatURL;
    }

    switch (self.config.site) {
        case UACloudSiteEU:
            return nil;
        case UACloudSiteUS:
        default:
            return UARuntimeConfigUSRemoteDataAPIURL;
    }
}

- (NSString *)chatWebSocketURL {
    if (self.internalChatWebSocketURL) {
        return self.internalChatWebSocketURL;
    }

    switch (self.config.site) {
        case UACloudSiteEU:
            return nil;
        case UACloudSiteUS:
        default:
            return UARuntimeConfigUSChatWebSocketAPIURL;
    }
}


@end
