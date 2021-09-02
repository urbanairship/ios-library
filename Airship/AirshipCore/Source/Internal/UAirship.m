/* Copyright Airship and Contributors */

#import "UAirship+Internal.h"
#import "UAKeychainUtils+Internal.h"
#import "UAGlobal.h"
#import "UAAutoIntegration.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAFeature.h"
#import "UALocationProvider.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

NSString * const UAirshipDeepLinkScheme = @"uairship";

// Notifications
NSString * const UAAirshipReadyNotification = @"com.urbanairship.airship_ready";

static NSString *const UAResetKeychainKey = @"com.urbanairship.reset_keychain";

// Exceptions
NSString * const UAirshipTakeOffBackgroundThreadException = @"UAirshipTakeOffBackgroundThreadException";

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
    UAirshipLogger.loggingEnabled = value;
}

+ (void)setLogLevel:(UALogLevel)level {
    uaLogLevel = level;
    UAirshipLogger.logLevel = level;
}

+ (void)setLoudImpErrorLogging:(BOOL)enabled{
    uaLoudImpErrorLoggingEnabled = enabled;
    UAirshipLogger.implementationErrorLoggingEnabled = enabled;
}

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:[UAirship class]
                                             selector:@selector(applicationDidFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification
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

        self.sharedPrivacyManager = [[UAPrivacyManager alloc] initWithDataStore:dataStore defaultEnabledFeatures:self.config.enabledFeatures];

        self.actionRegistry = [UAActionRegistry defaultRegistry];
        self.URLAllowList = [UAURLAllowList allowListWithConfig:config];
        self.applicationMetrics = [[UAApplicationMetrics alloc] initWithDataStore:self.dataStore privacyManager:self.sharedPrivacyManager];
        self.sharedLocaleManager = [[UALocaleManager alloc] initWithDataStore:self.dataStore];

        self.sharedChannel = [[UAChannel alloc] initWithDataStore:self.dataStore
                                                           config:self.config
                                                   privacyManager:self.sharedPrivacyManager
                                                    localeManager:self.sharedLocaleManager];

        [components addObject:self.sharedChannel];

        self.sharedAnalytics = [[UAAnalytics alloc] initWithConfig:self.config
                                                         dataStore:self.dataStore
                                                           channel:self.sharedChannel
                                                     localeManager:self.sharedLocaleManager
                                                    privacyManager:self.sharedPrivacyManager];
        
        [components addObject:self.sharedAnalytics];

        self.sharedPush = [[UAPush alloc] initWithConfig:self.config
                                               dataStore:self.dataStore
                                                 channel:self.sharedChannel
                                               analytics:self.sharedAnalytics
                                          privacyManager:self.sharedPrivacyManager];

        [components addObject:self.sharedPush];


        
        self.sharedContact = [[UAContact alloc] initWithDataStore:self.dataStore
                                                           config:self.config
                                                          channel:self.sharedChannel
                                                   privacyManager:self.sharedPrivacyManager];
        [components addObject:self.sharedContact];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

        self.sharedNamedUser = [[UANamedUser alloc] initWithDataStore:self.dataStore contact:self.sharedContact];
        [components addObject:self.sharedNamedUser];

#pragma clang diagnostic popu

        self.sharedRemoteDataManager = [[UARemoteDataManager alloc] initWithConfig:self.config
                                                                         dataStore:self.dataStore
                                                                          localeManager:self.sharedLocaleManager
                                                                         privacyManager:self.sharedPrivacyManager];
        [components addObject:self.sharedRemoteDataManager];

        
        self.sharedRemoteConfigManager = [[UARemoteConfigManager alloc] initWithRemoteDataManager:self.sharedRemoteDataManager
                                                                                   privacyManager:self.sharedPrivacyManager];

#if !TARGET_OS_TV
        // UIPasteboard is not available in tvOS
        self.channelCapture = [[UAChannelCapture alloc] initWithConfig:self.config
                                                             dataStore:self.dataStore
                                                               channel:self.sharedChannel];
#endif

        UAModuleLoader *moduleLoader = [[UAModuleLoader alloc] initWithConfig:self.config
                                                                    dataStore:self.dataStore
                                                                      channel:self.sharedChannel
                                                                      contact:self.sharedContact
                                                                         push:self.sharedPush
                                                                   remoteData:self.sharedRemoteDataManager
                                                                    analytics:self.sharedAnalytics
                                                               privacyManager:self.sharedPrivacyManager];
        [components addObjectsFromArray:moduleLoader.components];
        self.components = components;

        for (NSString *plist in moduleLoader.actionPlists) {
            [self.actionRegistry registerActionsFromFile:plist];
        }

        NSMutableDictionary *componentClassMap = [NSMutableDictionary dictionary];
        for (id<UAComponent> component in self.components) {
            componentClassMap[NSStringFromClass([component class])] = component;
            
            if ([component conformsToProtocol:@protocol(UALocationProvider)]) {
                self.locationProvider = (id<UALocationProvider>) component;
            }
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
    
    // Ensure that app credentials are valid
    if (![config validate]) {
        UA_LIMPERR(@"The UAConfig is invalid, no application credentials were specified at runtime.");
        // Bail now. Don't continue the takeOff sequence.
        return;
    }


    // Clearing the key chain
    if ([[NSUserDefaults standardUserDefaults] boolForKey:UAResetKeychainKey]) {
        UA_LDEBUG(@"Deleting the keychain credentials");
        [UAKeychainUtils deleteKeychainValue:config.appKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAResetKeychainKey];
    }

    // Data store
    UAPreferenceDataStore *dataStore = [[UAPreferenceDataStore alloc] initWithKeyPrefix:[NSString stringWithFormat:@"com.urbanairship.%@.", config.appKey]];

    UARuntimeConfig *runtimeConfig = [[UARuntimeConfig alloc] initWithConfig:config dataStore:dataStore];
    
    [UAirship setLogLevel:runtimeConfig.logLevel];

    if (runtimeConfig.inProduction) {
        [UAirship setLoudImpErrorLogging:NO];
    }

    UA_LINFO(@"UAirship Take Off! Lib Version: %@ App Key: %@ Production: %@.",
             [UAirshipVersion get], runtimeConfig.appKey, runtimeConfig.inProduction ?  @"YES" : @"NO");

    // Create Airship
    [UAirship setSharedAirship:[[UAirship alloc] initWithRuntimeConfig:runtimeConfig
                                                             dataStore:dataStore]];

    // Validate any setup issues
    if (!runtimeConfig.inProduction) {
        [sharedAirship_ validate];
    }
    
    UADefaultAppIntegrationDelegate *integrationDelegate = [[UADefaultAppIntegrationDelegate alloc] init];
    // Automatic setup
    if (sharedAirship_.config.isAutomaticSetupEnabled) {
        UA_LINFO(@"Automatic setup enabled.");
        [UAAutoIntegration integrateWithDelegate:integrationDelegate];
    } else {
        UAAppIntegration.integrationDelegate = integrationDelegate;
    }

    if (!handledLaunch_) {
        // Set up can occur after takeoff, so handle the launch notification on the
        // next run loop to allow app setup to finish
        [UADispatcher.main dispatchAsync: ^() {
            [UAirship applicationDidFinishLaunching:launchNotification_];
        }];
    }

    // Notify all the components that airship is ready
    for (id<UAComponent> component in sharedAirship_.components) {
        if ([component respondsToSelector:@selector(airshipReady)]) {
            [component airshipReady];
        }
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
        [UADispatcher.main dispatchAsync:^{
            if (!sharedAirship_) {
                UA_LERR(@"[UAirship takeOff] was not called in application:didFinishLaunchingWithOptions:");
                UA_LERR(@"Please ensure that [UAirship takeOff] is called synchronously before application:didFinishLaunchingWithOptions: returns");
            }
        }];

        return;
    }
    
    // If we are inactive the app is launching
    if ([UAAppStateTracker shared].state != UAApplicationStateBackground) {

#if !TARGET_OS_TV    // UIApplicationLaunchOptionsRemoteNotificationKey not available on tvOS
        NSDictionary *remoteNotification = [notification.userInfo objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];

        // Required before the app init event to track conversion push ID
        if (remoteNotification) {
            [sharedAirship_.sharedAnalytics launchedFromNotification:remoteNotification];
        }

#endif
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
    [UAirship.analytics addEvent:[[UAAppExitEvent alloc] init]];

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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

+ (UANamedUser *)namedUser {
    return sharedAirship_.sharedNamedUser;
}

#pragma clang diagnostic pop

+ (id<UAContactProtocol>)contact {
    return sharedAirship_.sharedContact;
}

+ (UAAnalytics *)analytics {
    return sharedAirship_.sharedAnalytics;
}

+ (UALocaleManager *)locale {
    return sharedAirship_.sharedLocaleManager;
}

+ (UAPrivacyManager *)privacyManager {
    return sharedAirship_.sharedPrivacyManager;
}

- (UAAnalytics *)analytics {
    return self.sharedAnalytics;
}

- (UALocaleManager *)locale {
    return self.sharedLocaleManager;
}

- (UAPrivacyManager *)privacyManager {
    return self.sharedPrivacyManager;
}

+ (UARemoteDataManager *)remoteDataManager {
    return sharedAirship_.sharedRemoteDataManager;
}

- (void)validate NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    // Background notification validation
    if (self.remoteNotificationBackgroundModeEnabled) {

        if (self.config.isAutomaticSetupEnabled) {
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

+ (id<UAComponent>)componentForClassName:(NSString *)className {
    return sharedAirship_.componentClassMap[className];;
}

- (void)setDataCollectionEnabled:(BOOL)enabled {
    if (enabled) {
        self.sharedPrivacyManager.enabledFeatures = UAFeaturesNone;
    } else {
        self.sharedPrivacyManager.enabledFeatures = UAFeaturesAll;
    }
}

- (BOOL)isDataCollectionEnabled {
    return [self.sharedPrivacyManager isAnyFeatureEnabled];
}

- (void)deepLink:(NSURL *)deepLink completionHandler:(void (^)(BOOL result))completionHandler {
    if ([deepLink.scheme isEqualToString:UAirshipDeepLinkScheme]) {
        for (id<UAComponent> component in self.components) {
            
            if ([component respondsToSelector:@selector(deepLink:)]) {
                if ([component deepLink:deepLink]) {
                    break;
                }
            }
        }
        completionHandler(YES);
    } else {
        id strongDelegate = self.deepLinkDelegate;
        if ([strongDelegate respondsToSelector:@selector(receivedDeepLink:completionHandler:)]) {
            [strongDelegate receivedDeepLink:deepLink completionHandler:^{
                completionHandler(YES);
            }];
        } else{
            completionHandler(NO);
        }
    }
}

@end
