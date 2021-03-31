/* Copyright Airship and Contributors */
#import "UAirship+Internal.h"
#import "UAAnalytics+Internal.h"
#import "UAUtils+Internal.h"
#import "UAKeychainUtils+Internal.h"
#import "UAGlobal.h"
#import "UAPush+Internal.h"
#import "UAConfig.h"
#import "UARuntimeConfig+Internal.h"
#import "UAApplicationMetrics+Internal.h"
#import "UAActionRegistry.h"
#import "UAAutoIntegration+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAAppInitEvent+Internal.h"
#import "UAAppExitEvent+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UANamedUser+Internal.h"
#import "UAAppIntegration.h"
#import "UARemoteDataManager+Internal.h"
#import "UARemoteConfigManager+Internal.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UAPendingTagGroupStore+Internal.h"
#import "UAChannel+Internal.h"
#import "UAAppStateTracker.h"
#import "UALocationModuleLoaderFactory.h"
#import "UAAutomationModuleLoaderFactory.h"
#import "UAExtendedActionsModuleLoaderFactory.h"
#import "UAMessageCenterModuleLoaderFactory.h"
#import "UAAccengageModuleLoaderFactory.h"
#import "UADebugLibraryModuleLoaderFactory.h"
#import "UALocaleManager+Internal.h"
#import "UARemoteConfigURLManager.h"
#import "UAAirshipChatModuleLoaderFactory.h"

#if !TARGET_OS_TV
#import "UAChannelCapture+Internal.h"
#endif

// Notifications
NSString * const UADeviceIDChangedNotification = @"com.urbanairship.device_id_changed";
NSString * const UAAirshipReadyNotification = @"com.urbanairship.airship_ready";

// Exceptions
NSString * const UAirshipTakeOffBackgroundThreadException = @"UAirshipTakeOffBackgroundThreadException";

NSString * const UAResetKeychainKey = @"com.urbanairship.reset_keychain";
NSString * const UALibraryVersion = @"com.urbanairship.library_version";

// Optional components
NSString * const UALocationModuleLoaderClassName = @"UALocationModuleLoader";
NSString * const UAAutomationModuleLoaderClassName = @"UAAutomationModuleLoader";
NSString * const UAMessageCenterModuleLoaderClassName = @"UAMessageCenterModuleLoader";
NSString * const UAExtendedActionsModuleLoaderClassName = @"UAExtendedActionsModuleLoader";
NSString * const UAAccengageModuleLoaderClassName = @"UAAccengageModuleLoader";
NSString * const UADebugLibraryModuleLoaderClassName = @"AirshipDebug.UADebugLibraryModuleLoader";

NSString * const UAAirshipChatModuleLoaderClassName = @"AirshipChat.AirshipChatModuleLoader";


// AirshipReady payload
NSString * const UAAirshipReadyChannelIdentifier = @"channel_id";
NSString * const UAAirshipReadyAppKey = @"appKey";
NSString * const UAAirshipReadyPayloadVersion = @"payload_version";

static UAirship *sharedAirship_;

static NSBundle *resourcesBundle_;

static dispatch_once_t takeOffPred_;

// Its possible that plugins that use load to call takeoff will trigger after
// didFinishLaunching. We need to store the launch notification
// and call didFinishLaunching in takeoff.
static NSNotification *launchNotification_;

static BOOL handledLaunch_;

// Logging info
// Default to ON and ERROR - options/plist will override
BOOL uaLoggingEnabled = YES;
UALogLevel uaLogLevel = UALogLevelError;
BOOL uaLoudImpErrorLoggingEnabled = YES;

@implementation UAirship

#pragma mark -
#pragma mark Logging
+ (void)setLogging:(BOOL)value {
    uaLoggingEnabled = value;
}

+ (void)setLogLevel:(UALogLevel)level {
    uaLogLevel = level;
}

+ (void)setLoudImpErrorLogging:(BOOL)enabled{
    uaLoudImpErrorLoggingEnabled = enabled;
}

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:[UAirship class]
                                             selector:@selector(applicationDidFinishLaunching:)
                                                 name:UAApplicationDidFinishLaunchingNotification
                                               object:nil];
}

#pragma mark -
#pragma mark Object Lifecycle

- (instancetype)initWithRuntimeConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {

        NSMutableArray *components = [NSMutableArray array];

        self.remoteNotificationBackgroundModeEnabled = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"] containsObject:@"remote-notification"];
        self.dataStore = dataStore;
        self.config = config;

        // Default data collection enabled value
        // Note: UAComponent depends on this value, so it should be initialized first
        if (![self.dataStore objectForKey:UAirshipDataCollectionEnabledKey]) {
            [self.dataStore setBool:!(config.isDataCollectionOptInEnabled) forKey:UAirshipDataCollectionEnabledKey];
        }

        self.actionRegistry = [UAActionRegistry defaultRegistry];
        self.URLAllowList = [UAURLAllowList allowListWithConfig:config];
        self.applicationMetrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore];
        self.sharedLocaleManager = [UALocaleManager localeManagerWithDataStore:self.dataStore];

        self.sharedChannel = [UAChannel channelWithDataStore:self.dataStore
                                                      config:self.config
                                               localeManager:self.sharedLocaleManager];

        [components addObject:self.sharedChannel];

        self.sharedAnalytics = [UAAnalytics analyticsWithConfig:self.config
                                                      dataStore:self.dataStore
                                                        channel:self.sharedChannel
                                                  localeManager:self.sharedLocaleManager];
        [components addObject:self.sharedAnalytics];


        self.sharedPush = [UAPush pushWithConfig:self.config
                                       dataStore:self.dataStore
                                         channel:self.sharedChannel
                                       analytics:self.sharedAnalytics];
        [components addObject:self.sharedPush];


        self.sharedNamedUser = [UANamedUser namedUserWithChannel:self.sharedChannel
                                                          config:self.config
                                                       dataStore:self.dataStore];
        [components addObject:self.sharedNamedUser];

        self.sharedRemoteDataManager = [UARemoteDataManager remoteDataManagerWithConfig:self.config
                                                                              dataStore:self.dataStore
                                                                          localeManager:self.sharedLocaleManager];
        [components addObject:self.sharedRemoteDataManager];

        self.sharedRemoteConfigManager = [UARemoteConfigManager remoteConfigManagerWithRemoteDataManager:self.sharedRemoteDataManager
                                                                                      applicationMetrics:self.applicationMetrics];

#if !TARGET_OS_TV
        // UIPasteboard is not available in tvOS
        self.channelCapture = [UAChannelCapture channelCaptureWithConfig:self.config
                                                                 channel:self.sharedChannel
                                                               dataStore:self.dataStore];
#endif

        NSMutableArray<id<UAModuleLoader>> *loaders = [NSMutableArray array];

        id<UAModuleLoader, UALocationProviderLoader> locationLoader = [UAirship locationLoaderWithDataStore:self.dataStore
                                                                                                    channel:self.sharedChannel
                                                                                                  analytics:self.sharedAnalytics];
        if (locationLoader) {
            [loaders addObject:locationLoader];
            self.locationProvider = locationLoader.locationProvider;
        }

        id<UAModuleLoader> automationLoader = [UAirship automationModuleLoaderWithDataStore:self.dataStore
                                                                                     config:self.config
                                                                                    channel:self.sharedChannel
                                                                                  namedUser:self.sharedNamedUser
                                                                                  analytics:self.sharedAnalytics
                                                                          remoteDataManager:self.sharedRemoteDataManager];
        if (automationLoader) {
            [loaders addObject:automationLoader];
        }

        id<UAModuleLoader> messageCenterLoader = [UAirship messageCenterLoaderWithDataStore:self.dataStore
                                                                                     config:self.config
                                                                                    channel:self.sharedChannel];
        if (messageCenterLoader) {
            [loaders addObject:messageCenterLoader];
        }

        id<UAModuleLoader> accengageLoader = [UAirship accengageModuleLoaderWithDataStore:self.dataStore
                                                                                  channel:self.sharedChannel
                                                                                     push:self.sharedPush
                                                                                analytics:self.sharedAnalytics];
        if (accengageLoader) {
            [loaders addObject:accengageLoader];
        }

        id<UAModuleLoader> extendedActionsLoader = [UAirship extendedActionsModuleLoader];
        if (extendedActionsLoader) {
            [loaders addObject:extendedActionsLoader];
        }

        id<UAModuleLoader> airshipChatLoader = [UAirship airshipChatModuleLoaderWithDataStore:self.dataStore channel:self.sharedChannel push:self.sharedPush];

        if (airshipChatLoader) {
            [loaders addObject:airshipChatLoader];
        }

        id<UAModuleLoader> debugLibraryLoader = [UAirship debugLibraryModuleLoaderWithAnalytics:self.sharedAnalytics];
        if (debugLibraryLoader) {
            [loaders addObject:debugLibraryLoader];
        }

        for (id<UAModuleLoader> loader in loaders) {
            if ([loader respondsToSelector:@selector(components)]) {
                [components addObjectsFromArray:[loader components]];
            }

            if ([loader respondsToSelector:@selector(registerActions:)]) {
                [loader registerActions:self.actionRegistry];
            }
        }

        self.components = components;

        NSMutableDictionary *componentClassMap = [NSMutableDictionary dictionary];
        for (UAComponent *component in self.components) {
            componentClassMap[NSStringFromClass([component class])] = component;
        }

        self.componentClassMap = componentClassMap;
    }

    return self;
}

+ (void)takeOff {
    if (![[NSBundle mainBundle] pathForResource:@"AirshipConfig" ofType:@"plist"]) {
        UA_LIMPERR(@"AirshipConfig.plist file is missing. Unable to takeOff.");
        // Bail now. Don't continue the takeOff sequence.
        return;
    }

    [UAirship takeOff:[UAConfig defaultConfig]];
}

+ (void)takeOff:(UAConfig *)config {
    UA_BUILD_WARNINGS;

    // takeOff needs to be run on the main thread
    if (![[NSThread currentThread] isMainThread]) {
        NSException *mainThreadException = [NSException exceptionWithName:UAirshipTakeOffBackgroundThreadException
                                                                   reason:@"UAirship takeOff must be called on the main thread."
                                                                 userInfo:nil];
        [mainThreadException raise];
    }

    dispatch_once(&takeOffPred_, ^{
        [UAirship executeUnsafeTakeOff:[config copy]];
    });

    if ([UAirship shared].config.isExtendedBroadcastsEnabled) {
        NSMutableDictionary *airshipReadyPayload = [NSMutableDictionary dictionary];

        NSString *channelIdentifier = [UAirship channel].identifier;
        NSString *appKey = [UAirship shared].config.appKey;

        [airshipReadyPayload setValue:channelIdentifier forKey:UAAirshipReadyChannelIdentifier];
        [airshipReadyPayload setValue:appKey forKey:UAAirshipReadyAppKey];
        [airshipReadyPayload setValue:@1 forKey:UAAirshipReadyPayloadVersion];

        [[NSNotificationCenter defaultCenter] postNotificationName:UAAirshipReadyNotification object:airshipReadyPayload];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:UAAirshipReadyNotification object:nil];
    }
}

/*
 * This is an unsafe version of takeOff - use takeOff: instead for dispatch_once
 */
+ (void)executeUnsafeTakeOff:(UAConfig *)config {

    // Airships only take off once!
    if (sharedAirship_) {
        return;
    }

    // Data store
    UAPreferenceDataStore *dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:[NSString stringWithFormat:@"com.urbanairship.%@.", config.appKey]];
    [dataStore migrateUnprefixedKeys:@[UALibraryVersion]];

    UARemoteConfigURLManager *remoteConfigURLManager = [UARemoteConfigURLManager remoteConfigURLManagerWithDataStore:dataStore];
    UARuntimeConfig *runtimeConfig = [UARuntimeConfig runtimeConfigWithConfig:config urlManager:remoteConfigURLManager];

    // Ensure that app credentials are valid
    if (!runtimeConfig) {
        UA_LIMPERR(@"The UAConfig is invalid, no application credentials were specified at runtime.");
        // Bail now. Don't continue the takeOff sequence.
        return;
    }

    [UAirship setLogLevel:runtimeConfig.logLevel];

    if (runtimeConfig.inProduction) {
        [UAirship setLoudImpErrorLogging:NO];
    }

    UA_LINFO(@"UAirship Take Off! Lib Version: %@ App Key: %@ Production: %@.",
             [UAirshipVersion get], runtimeConfig.appKey, runtimeConfig.inProduction ?  @"YES" : @"NO");

    // Clearing the key chain
    if ([[NSUserDefaults standardUserDefaults] boolForKey:UAResetKeychainKey]) {
        UA_LDEBUG(@"Deleting the keychain credentials");
        [UAKeychainUtils deleteKeychainValue:runtimeConfig.appKey];

        UA_LDEBUG(@"Deleting the Airship device ID");
        [UAKeychainUtils deleteKeychainValue:UAKeychainDeviceIDKey];

        // Delete the Device ID in the data store so we don't clear the channel
        [dataStore removeObjectForKey:@"deviceId"];

        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAResetKeychainKey];
    }

    [UAUtils getDeviceID:^(NSString *currentDeviceID) {
        NSString *previousDeviceID = [dataStore stringForKey:@"deviceId"];
        if (previousDeviceID && ![previousDeviceID isEqualToString:currentDeviceID]) {
            // Device ID changed since the last open. Most likely due to an app restore
            // on a different device.
            UA_LDEBUG(@"Device ID changed.");
            [[NSNotificationCenter defaultCenter] postNotificationName:UADeviceIDChangedNotification
                                                                object:nil];
        }
        // Save the Device ID to the data store to detect when it changes
        [dataStore setObject:currentDeviceID forKey:@"deviceId"];
    } dispatcher:[UADispatcher mainDispatcher]];

    // Create Airship
    [UAirship setSharedAirship:[[UAirship alloc] initWithRuntimeConfig:runtimeConfig
                                                             dataStore:dataStore]];

    // Save the version
    if ([[UAirshipVersion get] isEqualToString:@"0.0.0"]) {
        UA_LIMPERR(@"_UA_VERSION is undefined - this commonly indicates an issue with the build configuration, UA_VERSION will be set to \"0.0.0\".");
    } else {
        NSString *previousVersion = [sharedAirship_.dataStore stringForKey:UALibraryVersion];
        if (![[UAirshipVersion get] isEqualToString:previousVersion]) {
            [dataStore setObject:[UAirshipVersion get] forKey:UALibraryVersion];
            if (previousVersion) {
                UA_LINFO(@"Airship library version changed from %@ to %@.", previousVersion, [UAirshipVersion get]);
            }
        }
    }

    // Validate any setup issues
    if (!runtimeConfig.inProduction) {
        [sharedAirship_ validate];
    }

    // Automatic setup
    if (sharedAirship_.config.automaticSetupEnabled) {
        UA_LINFO(@"Automatic setup enabled.");
        [UAAutoIntegration integrate];
    }

    if (!handledLaunch_) {
        // Set up can occur after takeoff, so handle the launch notification on the
        // next run loop to allow app setup to finish
        [[UADispatcher mainDispatcher] dispatchAsync: ^() {
            [UAirship applicationDidFinishLaunching:launchNotification_];
        }];
    }

    // Notify all the components that airship is ready
    for (UAComponent *component in sharedAirship_.components) {
        [component airshipReady:sharedAirship_];
    }
}

+ (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if (handledLaunch_) {
        return;
    }

    if (!sharedAirship_) {
        launchNotification_ = notification;

        // Log takeoff errors on the next run loop to give time for apps that
        // use class loader to call takeoff.
        [[UADispatcher mainDispatcher] dispatchAsync:^{
            if (!sharedAirship_) {
                UA_LERR(@"[UAirship takeOff] was not called in application:didFinishLaunchingWithOptions:");
                UA_LERR(@"Please ensure that [UAirship takeOff] is called synchronously before application:didFinishLaunchingWithOptions: returns");
            }
        }];

        return;
    }
    // If we are inactive the app is launching
    if ([UAAppStateTracker shared].state != UAApplicationStateBackground) {
        // Required before the app init event to track conversion push ID
        NSDictionary *remoteNotification = notification.userInfo[UAApplicationLaunchOptionsRemoteNotificationKey];
        if (remoteNotification) {
            [sharedAirship_.sharedAnalytics launchedFromNotification:remoteNotification];
        }
    }

    // Update registration on the next run loop to allow apps to customize
    // finish custom setup
    dispatch_async(dispatch_get_main_queue(), ^() {
        [sharedAirship_.sharedPush updateRegistration];
    });

    handledLaunch_ = YES;
}

+ (void)willTerminate {
    // Add app_exit event
    [UAirship.analytics addEvent:[UAAppExitEvent event]];

    // Land it
    [UAirship land];
}

+ (void)land {
    if (!sharedAirship_) {
        return;
    }

    // Finally, release the airship!
    [UAirship setSharedAirship:nil];

    // Reset the dispatch_once_t flag for testing
    takeOffPred_ = 0;
}

+ (void)setSharedAirship:(UAirship *)airship {
    sharedAirship_ = airship;
}

+ (UAirship *)shared {
    return sharedAirship_;
}

+ (UAChannel *)channel {
    return sharedAirship_.sharedChannel;
}

+ (UAPush *)push {
    return sharedAirship_.sharedPush;
}

+ (UANamedUser *)namedUser {
    return sharedAirship_.sharedNamedUser;
}

+ (UAAnalytics *)analytics {
    return sharedAirship_.sharedAnalytics;
}

+ (UALocaleManager *)locale {
    return sharedAirship_.sharedLocaleManager;
}

- (UAAnalytics *)analytics {
    return self.sharedAnalytics;
}

- (UALocaleManager *)locale {
    return self.sharedLocaleManager;
}

+ (UARemoteDataManager *)remoteDataManager {
    return sharedAirship_.sharedRemoteDataManager;
}

- (void)validate {
    // Background notification validation
    if (self.remoteNotificationBackgroundModeEnabled) {

        if (self.config.automaticSetupEnabled) {
            id delegate = [UIApplication sharedApplication].delegate;

            // If its automatic setup up, make sure if they are implementing their own app delegates, that they are
            // also implementing the new application:didReceiveRemoteNotification:fetchCompletionHandler: call.
            if ([delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:)]
                && ![delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {

                UA_LIMPERR(@"Application is set up to receive background notifications, but the app delegate only implements application:didReceiveRemoteNotification: and not application:didReceiveRemoteNotification:fetchCompletionHandler. application:didReceiveRemoteNotification: will be ignored.");
            }
        } else {
            id delegate = [UIApplication sharedApplication].delegate;

            // They must implement application:didReceiveRemoteNotification:fetchCompletionHandler: to handle background
            // notifications
            if ([delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:)]
                && ![delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {

                UA_LIMPERR(@"Application is set up to receive background notifications, but the app delegate does not implements application:didReceiveRemoteNotification:fetchCompletionHandler:. Use either UAirship automaticSetupEnabled or implement a proper application:didReceiveRemoteNotification:fetchCompletionHandler: in the app delegate.");
            }
        }
    } else {
#if !TARGET_OS_TV   // remote-notification background mode not supported in tvOS
        UA_LIMPERR(@"Application is not configured for background notifications. "
                   @"Please enable remote notifications in the application's background modes.");
#endif
    }

    // -ObjC linker flag is set
    if (![[NSJSONSerialization class] respondsToSelector:@selector(stringWithObject:)]) {
        UA_LIMPERR(@"UAirship library requires the '-ObjC' linker flag set in 'Other linker flags'.");
    }

    if (!self.config.suppressAllowListError) {
        if (!self.config.URLAllowList.count && !self.config.URLAllowListScopeOpenURL.count) {
            UA_LIMPERR(@"The airship config options is missing URL allow list rules for SCOPE_OPEN. By default only Airship, YouTube, mailto, sms, and tel URLs will be allowed. To suppress this error, specify allow list rules by providing rules for URLAllowListScopeOpenURL or URLAllowList. Alternatively you can suppress this error and keep the default rules by using the flag suppressAllowListError. For more information, see https://docs.airship.com/platform/ios/getting-started/#url-allow-list.");
        }
    }
}


- (UAComponent *)componentForClassName:(NSString *)className {
    return self.componentClassMap[className];
}


+ (nullable id<UAModuleLoader>)messageCenterLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                         config:(UARuntimeConfig *)config
                                                        channel:(UAChannel<UAExtendableChannelRegistration> *)channel {
    Class cls = NSClassFromString(UAMessageCenterModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UAMessageCenterModuleLoaderFactory)]) {
        return [cls messageCenterModuleLoaderWithDataStore:dataStore config:config channel:channel];
    }
    return nil;
}

+ (nullable id<UAModuleLoader>)extendedActionsModuleLoader {
    Class cls = NSClassFromString(UAExtendedActionsModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UAExtendedActionsModuleLoaderFactory)]) {
        return [cls extendedActionsModuleLoader];
    }
    return nil;
}

+ (nullable id<UAModuleLoader, UALocationProviderLoader>)locationLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                                             channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                                                                           analytics:(UAAnalytics<UAExtendableAnalyticsHeaders> *)analytics {
    Class cls = NSClassFromString(UALocationModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UALocationModuleLoaderFactory)]) {
        return [cls locationModuleLoaderWithDataStore:dataStore channel:channel analytics:analytics];
    }
    return nil;
}

+ (nullable id<UAModuleLoader>)automationModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                            config:(UARuntimeConfig *)config
                                                           channel:(UAChannel *)channel
                                                         namedUser:(UANamedUser *)namedUser
                                                         analytics:(UAAnalytics *)analytics
                                                 remoteDataManager:(UARemoteDataManager *)remoteDataManager  {

    Class cls = NSClassFromString(UAAutomationModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UAAutomationModuleLoaderFactory)]) {
        return [cls inAppModuleLoaderWithDataStore:dataStore
                                            config:config
                                           channel:channel
                                         namedUser:namedUser
                                         analytics:analytics
                                remoteDataProvider:remoteDataManager];
    }
    return nil;
}

+ (nullable id<UAModuleLoader>)accengageModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                          channel:(UAChannel *)channel
                                                             push:(UAPush *)push
                                                        analytics:(UAAnalytics *)analytics {

    Class cls = NSClassFromString(UAAccengageModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UAAccengageModuleLoaderFactory)]) {
        return [cls moduleLoaderWithDataStore:dataStore
                                      channel:channel
                                         push:push
                                    analytics:analytics];
    }
    return nil;
}

+ (nullable id<UAModuleLoader>)airshipChatModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                            channel:(UAChannel *)channel
                                                               push:(UAPush *)push {

    Class cls = NSClassFromString(UAAirshipChatModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UAAirshipChatModuleLoaderFactory)]) {
        return [cls moduleLoaderWithDataStore:dataStore
                                      channel:channel
                                         push:push];
    }
    return nil;
}

+ (nullable id<UAModuleLoader>)debugLibraryModuleLoaderWithAnalytics:(UAAnalytics *)analytics {
    Class cls = NSClassFromString(UADebugLibraryModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UADebugLibraryModuleLoaderFactory)]) {
        return [cls debugLibraryModuleLoaderWithAnalytics:analytics];
    }
    return nil;
}

- (void)setDataCollectionEnabled:(BOOL)enabled {
    if (self.isDataCollectionEnabled != enabled) {
        // save value to data store
        [self.dataStore setBool:enabled forKey:UAirshipDataCollectionEnabledKey];
        for (UAComponent *component in sharedAirship_.components) {
            [component onDataCollectionEnabledChanged];
        }
    }
}

- (BOOL)isDataCollectionEnabled {
    return [self.dataStore boolForKey:UAirshipDataCollectionEnabledKey];
}

@end

