/* Copyright Airship and Contributors */

#import "UAAnalytics+Internal.h"
#import "UAEventManager+Internal.h"
#import "UARuntimeConfig.h"
#import "UAEvent.h"
#import "UAUtils+Internal.h"

#import "UAAppBackgroundEvent+Internal.h"
#import "UAAppForegroundEvent+Internal.h"
#import "UAScreenTrackingEvent+Internal.h"
#import "UARegionEvent+Internal.h"
#import "UAAssociateIdentifiersEvent+Internal.h"
#import "UAAssociatedIdentifiers.h"
#import "UACustomEvent.h"
#import "UAUtils+Internal.h"
#import "UAirship.h"
#import "UAPush+Internal.h"
#import "UAChannel.h"
#import "UALocaleManager.h"

#define kUAAssociatedIdentifiers @"UAAssociatedIdentifiers"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@interface UAAnalytics()
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAChannel *channel;
@property (nonatomic, strong) UAEventManager *eventManager;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UADate *date;
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) NSMutableArray<NSString *> *SDKExtensions;
@property (nonatomic, strong) NSMutableArray<UAAnalyticsHeadersBlock> *headerBlocks;
@property (nonatomic, strong) UALocaleManager *localeManager;
@property (nonatomic, strong) UAAppStateTracker *appStateTracker;
@property (nonatomic, assign) BOOL handledFirstForegroundTransition;
@property (nonatomic, assign) dispatch_once_t ensureInitToken;

// Screen tracking state
@property (nonatomic, copy) NSString *currentScreen;
@property (nonatomic, copy) NSString *previousScreen;
@property (nonatomic, assign) NSTimeInterval startTime;

@end

NSString *const UACustomEventAdded = @"UACustomEventAdded";
NSString *const UARegionEventAdded = @"UARegionEventAdded";
NSString *const UAScreenTracked = @"UAScreenTracked";
NSString *const UAScreenKey = @"screen";
NSString *const UAEventKey = @"event";

@implementation UAAnalytics

- (instancetype)initWithConfig:(UARuntimeConfig *)airshipConfig
                     dataStore:(UAPreferenceDataStore *)dataStore
                       channel:(UAChannel *)channel
                  eventManager:(UAEventManager *)eventManager
            notificationCenter:(NSNotificationCenter *)notificationCenter
                          date:(UADate *)date
                    dispatcher:(UADispatcher *)dispatcher
                 localeManager:(UALocaleManager *)localeManager
               appStateTracker:(UAAppStateTracker *)appStateTracker
                privacyManager:(UAPrivacyManager *)privacyManager {

    self = [super initWithDataStore:dataStore];

    if (self) {
        // Set server to default if not specified in options
        self.config = airshipConfig;
        self.dataStore = dataStore;
        self.channel = channel;
        self.eventManager = eventManager;
        self.notificationCenter = notificationCenter;
        self.date = date;
        self.dispatcher = dispatcher;
        self.localeManager = localeManager;
        self.privacyManager = privacyManager;
        self.appStateTracker = appStateTracker;
        self.SDKExtensions = [NSMutableArray array];
        self.headerBlocks = [NSMutableArray array];
        self.eventManager.delegate = self;
        [self updateEventManagerUploadsEnabled];

        [self startSession];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationDidTransitionToForeground)
                                        name:UAAppStateTracker.didTransitionToForeground
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationWillEnterForeground)
                                        name:UAAppStateTracker.willEnterForegroundNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationDidEnterBackground)
                                        name:UAAppStateTracker.didEnterBackgroundNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationWillTerminate)
                                        name:UAAppStateTracker.willTerminateNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                               selector:@selector(onEnabledFeaturesChanged)
                                   name:UAPrivacyManager.changeEvent
                                 object:nil];


        // If analytics is initialized in the background state, we are responding to a
        // content-available push. If it's initialized in the foreground state takeOff
        // was probably called late. We should ensure an init event in either case.
        if (self.appStateTracker.state != UAApplicationStateInactive) {
            [self ensureInit];
        }
    }

    return self;
}

+ (instancetype)analyticsWithConfig:(UARuntimeConfig *)config
                          dataStore:(UAPreferenceDataStore *)dataStore
                            channel:(UAChannel *)channel
                      localeManager:(UALocaleManager *)localeManager
                     privacyManager:(UAPrivacyManager *)privacyManager {
    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                channel:channel
                           eventManager:[UAEventManager eventManagerWithConfig:config dataStore:dataStore channel:channel]
                     notificationCenter:[NSNotificationCenter defaultCenter]
                                   date:[[UADate alloc] init]
                             dispatcher:UADispatcher.main
                          localeManager:localeManager
                        appStateTracker:[UAAppStateTracker shared]
                         privacyManager:privacyManager];
}

+ (instancetype)analyticsWithConfig:(UARuntimeConfig *)airshipConfig
                          dataStore:(UAPreferenceDataStore *)dataStore
                            channel:(UAChannel *)channel
                       eventManager:(UAEventManager *)eventManager
                 notificationCenter:(NSNotificationCenter *)notificationCenter
                               date:(UADate *)date
                         dispatcher:(UADispatcher *)dispatcher
                      localeManager:(UALocaleManager *)localeManager
                    appStateTracker:(UAAppStateTracker *)appStateTracker
                     privacyManager:(UAPrivacyManager *)privacyManager {

    return [[self alloc] initWithConfig:airshipConfig
                              dataStore:dataStore
                                channel:channel
                           eventManager:eventManager
                     notificationCenter:notificationCenter
                                   date:date
                             dispatcher:dispatcher
                          localeManager:localeManager
                        appStateTracker:appStateTracker
                         privacyManager:privacyManager];
}

#pragma mark -
#pragma mark Application State

- (void)applicationDidTransitionToForeground {
    UA_LTRACE(@"Application transitioned to foreground.");

    // If the app is transitioning to foreground for the first time, ensure an app init event
    if (!self.handledFirstForegroundTransition) {
        self.handledFirstForegroundTransition = YES;
        [self ensureInit];
        return;
    }

    // Otherwise start a new session and emit a foreground event.
    [self startSession];

    // Add app_foreground event
    [self addEvent:[UAAppForegroundEvent event]];
}

- (void)applicationWillEnterForeground {
    UA_LTRACE(@"Application will enter foreground.");

    // Start tracking previous screen before backgrounding began
    [self trackScreen:self.previousScreen];
}

- (void)applicationDidEnterBackground {
    UA_LTRACE(@"Application did enter background.");

    [self stopTrackingScreen];

    // Ensure an app init event
    [self ensureInit];

    // Add app_background event
    [self addEvent:[UAAppBackgroundEvent event]];

    [self startSession];
    self.conversionSendID = nil;
    self.conversionPushMetadata = nil;
}

- (void)applicationWillTerminate {
    UA_LTRACE(@"Application is terminating.");
    [self stopTrackingScreen];
}

#pragma mark -
#pragma mark Analytics

- (void)addEvent:(UAEvent *)event {
    if (!event.isValid) {
        UA_LERR(@"Dropping invalid event %@.", event);
        return;
    }


    NSString *sessionID = self.sessionID;

    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)

        if (!self.isAnalyticsEnabled) {
            UA_LTRACE(@"Analytics disabled, ignoring event: %@", event.eventType);
            return;
        }

        UA_LDEBUG(@"Adding %@ event %@.", event.eventType, event.eventID);
        [self.eventManager addEvent:event sessionID:sessionID];
        UA_LTRACE(@"Event added: %@.", event);

        if (self.eventConsumer) {
            [self.eventConsumer eventAdded:event];
        }

        if ([event isKindOfClass:[UACustomEvent class]]) {
            [self.notificationCenter postNotificationName:UACustomEventAdded
                                                   object:self
                                                 userInfo:@{UAEventKey: event}];
        }

        if ([event isKindOfClass:[UARegionEvent class]]) {
            [self.notificationCenter postNotificationName:UARegionEventAdded
                                                   object:self
                                                 userInfo:@{UAEventKey: event}];
        }
    }];
}

- (void)ensureInit {
    dispatch_once(&_ensureInitToken, ^{
        [self addEvent:[UAAppInitEvent event]];
    });
}

- (void)launchedFromNotification:(NSDictionary *)notification {
    if (!notification) {
        return;
    }

    if ([UAUtils isAlertingPush:notification]) {
        self.conversionSendID = [notification objectForKey:@"_"] ?: kUAMissingSendID;
        self.conversionPushMetadata = [notification objectForKey:kUAPushMetadata];

        [self ensureInit];
    } else {
        self.conversionSendID = nil;
        self.conversionPushMetadata = nil;
    }
}

- (void)startSession {
    self.sessionID = [NSUUID UUID].UUIDString;
}

- (BOOL)isEnabled {
    return [self.privacyManager isEnabled:UAFeaturesAnalytics];
}

- (void)setEnabled:(BOOL)enabled {
    if (enabled) {
        [self.privacyManager enableFeatures:UAFeaturesAnalytics];
    } else {
        [self.privacyManager disableFeatures:UAFeaturesAnalytics];
    }
}

- (void)associateDeviceIdentifiers:(UAAssociatedIdentifiers *)associatedIdentifiers {
    if (!self.isAnalyticsEnabled) {
        UA_LWARN(@"Unable to associate identifiers %@ when analytics is disabled", associatedIdentifiers.allIDs);
        return;
    }

    NSDictionary *previous = [self.dataStore objectForKey:kUAAssociatedIdentifiers];

    if ([previous isEqualToDictionary:associatedIdentifiers.allIDs]) {
        UA_LINFO(@"Skipping analytics event addition for duplicate associated identifiers.");
        return;
    }

    [self.dataStore setObject:associatedIdentifiers.allIDs forKey:kUAAssociatedIdentifiers];
    [self addEvent:[UAAssociateIdentifiersEvent eventWithIDs:associatedIdentifiers]];
}

- (UAAssociatedIdentifiers *)currentAssociatedDeviceIdentifiers {
    NSDictionary *storedIDs = [self.dataStore objectForKey:kUAAssociatedIdentifiers] ? : @{};
    return [UAAssociatedIdentifiers identifiersWithDictionary:storedIDs];
}

- (void)trackScreen:(nullable NSString *)screen {
    [self.dispatcher dispatchAsyncIfNecessary:^{
        // Prevent duplicate calls to track same screen
        if ([screen isEqualToString:self.currentScreen]) {
            return;
        }

        [self.notificationCenter postNotificationName:UAScreenTracked
                                               object:self
                                             userInfo:screen == nil ? @{} : @{UAScreenKey: screen}];

        // If there's a screen currently being tracked set it's stop time and add it to analytics
        if (self.currentScreen) {
            UAScreenTrackingEvent *ste = [UAScreenTrackingEvent eventWithScreen:self.currentScreen
                                                                 previousScreen:self.previousScreen
                                                                      startTime:self.startTime
                                                                       stopTime:self.date.now.timeIntervalSince1970];

            // Set previous screen to last tracked screen
            self.previousScreen = self.currentScreen;

            // Add screen tracking event to next analytics batch
            [self addEvent:ste];
        }

        self.currentScreen = screen;
        self.startTime = self.date.now.timeIntervalSince1970;
    }];
}

- (void)stopTrackingScreen {
    [self trackScreen:nil];
}

- (void)scheduleUpload {
    [self.eventManager scheduleUpload];
}

- (void)onComponentEnableChange {
    [self updateEventManagerUploadsEnabled];
}

- (void)registerSDKExtension:(UASDKExtension)extension version:(NSString *)version {
    NSString *sanitizedVersion = [version stringByReplacingOccurrencesOfString:@"," withString:@""];
    NSString *name = [UAAnalytics nameForSDKExtension:extension];
    [self.SDKExtensions addObject:[NSString stringWithFormat:@"%@:%@", name, sanitizedVersion]];
}

+ (NSString *)nameForSDKExtension:(UASDKExtension)extension {
    switch(extension) {
        case UASDKExtensionCordova:
            return @"cordova";
        case UASDKExtensionXamarin:
            return @"xamarin";
        case UASDKExtensionUnity:
            return @"unity";
        case UASDKExtensionFlutter:
            return @"flutter";
        case UASDKExtensionReactNative:
            return @"react-native";
        case UASDKExtensionTitanium:
            return @"titanium";
    }
}

- (NSDictionary *)analyticsHeaders {
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];

    // Device info
    [headers setValue:[UIDevice currentDevice].systemName forKey:@"X-UA-Device-Family"];
    [headers setValue:[UIDevice currentDevice].systemVersion forKey:@"X-UA-OS-Version"];
    [headers setValue:[UAUtils deviceModelName] forKey:@"X-UA-Device-Model"];

    // App info
    [headers setValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleIdentifierKey] forKey:@"X-UA-Package-Name"];
    [headers setValue:[UAUtils bundleShortVersionString] ?: @"" forKey:@"X-UA-Package-Version"];

    // Time zone
    NSLocale *currentLocale = [self.localeManager currentLocale];
    [headers setValue:[[NSTimeZone defaultTimeZone] name] forKey:@"X-UA-Timezone"];
    [headers setValue:[currentLocale objectForKey:NSLocaleLanguageCode] forKey:@"X-UA-Locale-Language"];
    [headers setValue:[currentLocale objectForKey:NSLocaleCountryCode] forKey:@"X-UA-Locale-Country"];
    [headers setValue:[currentLocale objectForKey:NSLocaleVariantCode] forKey:@"X-UA-Locale-Variant"];

    // Airship identifiers
    [headers setValue:self.channel.identifier forKey:@"X-UA-Channel-ID"];
    [headers setValue:self.config.appKey forKey:@"X-UA-App-Key"];

    // SDK Version
    [headers setValue:[UAirshipVersion get] forKey:@"X-UA-Lib-Version"];

    // SDK Extensions
    if (self.SDKExtensions.count) {
        [headers setValue:[self.SDKExtensions componentsJoinedByString:@", "] forKey:@"X-UA-Frameworks"];
    }

    // Header extenders
    for (UAAnalyticsHeadersBlock block in self.headerBlocks) {
        NSDictionary<NSString *, NSString *> *result = block();
        if (result) {
            [headers addEntriesFromDictionary:result];
        }
    }

    return headers;
}

- (void)addAnalyticsHeadersBlock:(nonnull UAAnalyticsHeadersBlock)headersBlock {
    [self.headerBlocks addObject:headersBlock];
}

- (void)onEnabledFeaturesChanged {
    [self updateEventManagerUploadsEnabled];
}

- (void)updateEventManagerUploadsEnabled {
    if (self.isAnalyticsEnabled) {
        self.eventManager.uploadsEnabled = YES;
        [self.eventManager scheduleUpload];
    } else {
        self.eventManager.uploadsEnabled = NO;
        [self.eventManager deleteAllEvents];
        [self.dataStore setValue:nil forKey:kUAAssociatedIdentifiers];
    }
}

- (BOOL)isAnalyticsEnabled {
    return self.componentEnabled && self.config.isAnalyticsEnabled && [self.privacyManager isEnabled:UAFeaturesAnalytics];
}

@end
