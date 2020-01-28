/* Copyright Airship and Contributors */

#import "UARuntimeConfig+Internal.h"

@interface UARuntimeConfig()

@property (nonatomic, copy) NSString *appKey;
@property (nonatomic, copy) NSString *appSecret;
@property (nonatomic, assign) UALogLevel logLevel;
@property (nonatomic, assign, getter=isInProduction) BOOL inProduction;
@property (nonatomic, assign, getter=isAutomaticSetupEnabled) BOOL automaticSetupEnabled;
@property (nonatomic, copy) NSArray<NSString *> *whitelist;
@property (nonatomic, copy) NSString *itunesID;
@property (nonatomic, assign, getter=isAnalyticsEnabled) BOOL analyticsEnabled;
@property (nonatomic, assign) BOOL detectProvisioningMode;
@property (nonatomic, copy) NSString *messageCenterStyleConfig;
@property (nonatomic, assign) BOOL clearUserOnAppRestore;
@property (nonatomic, assign) BOOL clearNamedUserOnAppRestore;
@property (nonatomic, assign, getter=isChannelCaptureEnabled) BOOL channelCaptureEnabled;
@property (nonatomic, assign, getter=isOpenURLWhitelistingEnabled) BOOL openURLWhitelistingEnabled;
@property (nonatomic, assign, getter=isChannelCreationDelayEnabled) BOOL channelCreationDelayEnabled;
@property (nonatomic, copy) NSDictionary *customConfig;
@property (nonatomic, assign) BOOL requestAuthorizationToUseNotifications;
@property (nonatomic, assign, getter=isDataCollectionOptInEnabled) BOOL dataCollectionOptInEnabled;

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

- (instancetype)initWithConfig:(UAConfig *)config {
    self = [super init];
    if (self) {
        self.logLevel = config.logLevel;
        self.appKey = config.appKey;
        self.appSecret = config.appSecret;

        switch (config.site) {
            case UACloudSiteEU:
                self.deviceAPIURL = config.deviceAPIURL ?: UARuntimeConfigEUDeviceAPIURL;
                self.analyticsURL = config.analyticsURL ?: UARuntimeConfigEUAnalyticsURL;
                self.remoteDataAPIURL = config.remoteDataAPIURL ?: UARuntimeConfigEURemoteDataAPIURL;
                break;

            case UACloudSiteUS:
            default:
                self.deviceAPIURL = config.deviceAPIURL ?: UARuntimeConfigUSDeviceAPIURL;
                self.analyticsURL = config.analyticsURL ?: UARuntimeConfigUSAnalyticsURL;
                self.remoteDataAPIURL = config.remoteDataAPIURL ?: UARuntimeConfigUSRemoteDataAPIURL;
                break;
        }

        self.inProduction = config.inProduction;
        self.detectProvisioningMode = config.detectProvisioningMode;
        self.requestAuthorizationToUseNotifications = config.requestAuthorizationToUseNotifications;
        self.automaticSetupEnabled = config.automaticSetupEnabled;
        self.analyticsEnabled = config.analyticsEnabled;
        self.clearUserOnAppRestore = config.clearUserOnAppRestore;
        self.whitelist = config.whitelist;
        self.clearNamedUserOnAppRestore = config.clearNamedUserOnAppRestore;
        self.channelCaptureEnabled = config.channelCaptureEnabled;
        self.openURLWhitelistingEnabled = config.openURLWhitelistingEnabled;
        self.customConfig = config.customConfig;
        self.channelCreationDelayEnabled = config.channelCreationDelayEnabled;
        self.messageCenterStyleConfig = config.messageCenterStyleConfig;
        self.itunesID = config.itunesID;
        self.dataCollectionOptInEnabled = config.dataCollectionOptInEnabled;
    }

    return self;
}

+ (nullable instancetype)runtimeConfigWithConfig:(UAConfig *)config {
    if (![config validate]) {
        return nil;
    }

    return [[UARuntimeConfig alloc] initWithConfig:config];
}

@end
