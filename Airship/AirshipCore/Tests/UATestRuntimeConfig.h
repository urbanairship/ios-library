/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARuntimeConfig.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Mutable runtime config for testing.
 */
@interface UATestRuntimeConfig : UARuntimeConfig
@property (nonatomic, copy) NSString *appKey;
@property (nonatomic, copy) NSString *appSecret;
@property (nonatomic, assign) UALogLevel logLevel;
@property (nonatomic, assign, getter=isInProduction) BOOL inProduction;
@property (nonatomic, assign, getter=isAutomaticSetupEnabled) BOOL automaticSetupEnabled;
@property (nonatomic, copy) NSArray<NSString *> *URLAllowList;
@property (nonatomic, copy) NSArray<NSString *> *URLAllowListScopeJavaScriptInterface;
@property (nonatomic, copy) NSArray<NSString *> *URLAllowListScopeOpenURL;
@property (nonatomic, copy) NSString *itunesID;
@property (nonatomic, assign, getter=isAnalyticsEnabled) BOOL analyticsEnabled;
@property (nonatomic, assign) BOOL detectProvisioningMode;
@property (nonatomic, copy) NSString *messageCenterStyleConfig;
@property (nonatomic, assign) BOOL clearUserOnAppRestore;
@property (nonatomic, assign) BOOL clearNamedUserOnAppRestore;
@property (nonatomic, assign, getter=isChannelCaptureEnabled) BOOL channelCaptureEnabled;
@property (nonatomic, assign, getter=isChannelCreationDelayEnabled) BOOL channelCreationDelayEnabled;
@property (nonatomic, copy) NSDictionary *customConfig;
@property (nonatomic, assign) BOOL requestAuthorizationToUseNotifications;

+ (instancetype)testConfig;
@end



NS_ASSUME_NONNULL_END
