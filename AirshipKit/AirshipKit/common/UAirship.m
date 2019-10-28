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
#import "UATagGroupsMutationHistory+Internal.h"
#import "UAChannel+Internal.h"
#import "UAAppStateTrackerFactory+Internal.h"

#import "UALocationModuleLoaderFactory.h"
#import "UAAutomationModuleLoaderFactory.h"

#if !TARGET_OS_TV   // Inbox and other features not supported on tvOS
#import "UAMessageCenterModuleLoaderFactory.h"
#endif

#if !TARGET_OS_TV
#import "UAChannelCapture+Internal.h"
#endif

// Notifications
NSString * const UADeviceIDChangedNotification = @"com.urbanairship.device_id_changed";

// Exceptions
NSString * const UAirshipTakeOffBackgroundThreadException = @"UAirshipTakeOffBackgroundThreadException";
NSString * const UAResetKeychainKey = @"com.urbanairship.reset_keychain";

NSString * const UALibraryVersion = @"com.urbanairship.library_version";

// Optional components
NSString * const UALocationModuleLoaderClassName = @"UALocationModuleLoader";
NSString * const UAAutomationModuleLoaderClassName = @"UAAutomationModuleLoader";
NSString * const UAMessageCenterModuleLoaderClassName = @"UAMessageCenterModuleLoader";

static UAirship *sharedAirship_;

static NSBundle *resourcesBundle_;

static dispatch_once_t takeOffPred_;

static id<UAAppStateTracker> appStateTracker_;

// Its possible that plugins that use load to call takeoff will trigger after
// didFinishLaunching. We need to store the launch notification
// and call didFinishLaunching in takeoff.
static NSDictionary *launchNotification_;

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
    appStateTracker_ = [UAAppStateTrackerFactory tracker];
    appStateTracker_.stateTrackerDelegate = (id<UAAppStateTrackerDelegate>)self;
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

        self.actionRegistry = [UAActionRegistry defaultRegistry];
        self.whitelist = [UAWhitelist whitelistWithConfig:config];
        self.applicationMetrics = [UAApplicationMetrics applicationMetricsWithDataStore:dataStore];

        UATagGroupsMutationHistory<UATagGroupsHistory> *tagGroupsMutationHistory = [UATagGroupsMutationHistory historyWithDataStore:self.dataStore];
        UATagGroupsRegistrar *tagGroupsRegistrar = [UATagGroupsRegistrar tagGroupsRegistrarWithConfig:self.config
                                                                                            dataStore:self.dataStore
                                                                                      mutationHistory:tagGroupsMutationHistory];

        self.sharedChannel = [UAChannel channelWithDataStore:self.dataStore
                                                      config:self.config
                                          tagGroupsRegistrar:tagGroupsRegistrar];
        [components addObject:self.sharedChannel];


        self.sharedPush = [UAPush pushWithConfig:self.config
                                       dataStore:self.dataStore
                                         channel:self.sharedChannel];
        [components addObject:self.sharedPush];

        self.sharedNamedUser = [UANamedUser namedUserWithChannel:self.sharedChannel
                                                          config:self.config
                                                       dataStore:self.dataStore
                                              tagGroupsRegistrar:tagGroupsRegistrar];
        [components addObject:self.sharedNamedUser];


        self.sharedAnalytics = [UAAnalytics analyticsWithConfig:self.config
                                                      dataStore:self.dataStore];
        [components addObject:self.sharedAnalytics];



        self.sharedRemoteDataManager = [UARemoteDataManager remoteDataManagerWithConfig:self.config
                                                                              dataStore:self.dataStore];
        [components addObject:self.sharedRemoteDataManager];

        self.sharedRemoteConfigManager = [UARemoteConfigManager remoteConfigManagerWithRemoteDataManager:self.sharedRemoteDataManager
                                                                                      applicationMetrics:self.applicationMetrics];

#if !TARGET_OS_TV
        // UIPasteboard is not available in tvOS
        self.channelCapture = [UAChannelCapture channelCaptureWithConfig:self.config
                                                                 channel:self.sharedChannel
                                                    pushProviderDelegate:self.sharedPush
                                                               dataStore:self.dataStore];
#endif

        NSMutableArray<id<UAModuleLoader>> *loaders = [NSMutableArray array];

        id<UAModuleLoader> locationLoader = [UAirship locationLoaderWithDataStore:self.dataStore];
        if (locationLoader) {
            [loaders addObject:locationLoader];
        }

        id<UAModuleLoader> automationLoader = [UAirship automationModuleLoaderWithDataStore:self.dataStore
                                                                                     config:self.config
                                                                                    channel:self.sharedChannel
                                                                                  analytics:self.sharedAnalytics
                                                                          remoteDataManager:self.sharedRemoteDataManager
                                                                           tagGroupsHistory:tagGroupsMutationHistory];
        if (automationLoader) {
            [loaders addObject:automationLoader];
        }

        id<UAModuleLoader> messageCenterLoader = [UAirship messageCenterLoaderWithDataStore:self.dataStore
                                                                                     config:self.config
                                                                                    channel:self.sharedChannel];
        if (messageCenterLoader) {
            [loaders addObject:messageCenterLoader];
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
}

/*
 * This is an unsafe version of takeOff - use takeOff: instead for dispatch_once
 */
+ (void)executeUnsafeTakeOff:(UAConfig *)config {

    // Airships only take off once!
    if (sharedAirship_) {
        return;
    }

    UARuntimeConfig *runtimeConfig = [UARuntimeConfig runtimeConfigWithConfig:config];

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

    // Data store
    UAPreferenceDataStore *dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:[NSString stringWithFormat:@"com.urbanairship.%@.", runtimeConfig.appKey]];
    [dataStore migrateUnprefixedKeys:@[UALibraryVersion]];

    // Clearing the key chain
    if ([[NSUserDefaults standardUserDefaults] boolForKey:UAResetKeychainKey]) {
        UA_LDEBUG(@"Deleting the keychain credentials");
        [UAKeychainUtils deleteKeychainValue:runtimeConfig.appKey];

        UA_LDEBUG(@"Deleting the Airship device ID");
        [UAKeychainUtils deleteKeychainValue:kUAKeychainDeviceIDKey];

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

+ (void)applicationDidFinishLaunching:(nullable NSDictionary *)remoteNotification {
    if (handledLaunch_) {
        return;
    }

    if (!sharedAirship_) {
        launchNotification_ = remoteNotification;

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

    // Required before the app init event to track conversion push ID
    if (remoteNotification) {
        [sharedAirship_.sharedAnalytics launchedFromNotification:remoteNotification];
    }

    // Init event
    [sharedAirship_.sharedAnalytics addEvent:[UAAppInitEvent event]];

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

- (UAAnalytics *)analytics {
    return self.sharedAnalytics;
}

+ (UARemoteDataManager *)remoteDataManager {
    return sharedAirship_.sharedRemoteDataManager;
}

+ (NSBundle *)resources {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Don't assume that we are within the main bundle
        NSBundle *containingBundle = [NSBundle bundleForClass:self];
#if !TARGET_OS_TV
        NSURL *resourcesBundleURL = [containingBundle URLForResource:@"AirshipResources" withExtension:@"bundle"];
#else
        NSURL *resourcesBundleURL = [containingBundle URLForResource:@"AirshipResources tvOS" withExtension:@"bundle"];
#endif
        if (resourcesBundleURL) {
            resourcesBundle_ = [NSBundle bundleWithURL:resourcesBundleURL];
        }
        if (!resourcesBundle_) {
            UA_LIMPERR(@"AirshipResources.bundle could not be found. If using the static library, you must add this file to your application's Copy Bundle Resources phase, or use the AirshipKit embedded framework");
        }
    });
    return resourcesBundle_;
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
}


- (UAComponent *)componentForClassName:(NSString *)className {
    return self.componentClassMap[className];
}


+ (nullable id<UAModuleLoader>)messageCenterLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                config:(UARuntimeConfig *)config
                                               channel:(UAChannel<UAExtendableChannelRegistration> *)channel {
#if !TARGET_OS_TV   // MC not supported on tvOS
    Class cls = NSClassFromString(UAMessageCenterModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UAMessageCenterModuleLoaderFactory)]) {
        return [cls messageCenterModuleLoaderWithDataStore:dataStore config:config channel:channel];
    }
#endif

    return nil;
}


+ (nullable id<UAModuleLoader>)locationLoaderWithDataStore:(UAPreferenceDataStore *)dataStore {
    Class cls = NSClassFromString(UALocationModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UALocationModuleLoaderFactory)]) {
        return [cls locationModuleLoaderWithDataStore:dataStore];
    }
    return nil;
}

+ (nullable id<UAModuleLoader>)automationModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                   config:(UARuntimeConfig *)config
                                                  channel:(UAChannel *)channel
                                                analytics:(UAAnalytics *)analytics
                                        remoteDataManager:(UARemoteDataManager *)remoteDataManager
                                         tagGroupsHistory:(id<UATagGroupsHistory>)tagGroupsHistory {

    Class cls = NSClassFromString(UAAutomationModuleLoaderClassName);
    if ([cls conformsToProtocol:@protocol(UAAutomationModuleLoaderFactory)]) {
        return [cls inAppModuleLoaderWithDataStore:dataStore
                                            config:config
                                           channel:channel
                                         analytics:analytics
                                remoteDataProvider:remoteDataManager
                                  tagGroupsHistory:tagGroupsHistory];
    }
    return nil;
}

@end

