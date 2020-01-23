/* Copyright Airship and Contributors */

#import "UAAnalytics+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
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
#import "UAAppStateTracker.h"
#import "UAUtils+Internal.h"
#import "UAirship.h"
#import "UAPush+Internal.h"
#import "UAChannel.h"

#define kUAAssociatedIdentifiers @"UAAssociatedIdentifiers"

@interface UAAnalytics()
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAChannel *channel;
@property (nonatomic, strong) UAEventManager *eventManager;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UADate *date;
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) NSMutableArray<NSString *> *SDKExtensions;
@property (nonatomic, assign) BOOL isEnteringForeground;
@property (nonatomic, strong) NSMutableArray<UAAnalyticsHeadersBlock> *headerBlocks;

// Screen tracking state
@property (nonatomic, strong) NSString *currentScreen;
@property (nonatomic, strong) NSString *previousScreen;
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
                    dispatcher:(UADispatcher *)dispatcher {

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
        self.SDKExtensions = [NSMutableArray array];
        self.headerBlocks = [NSMutableArray array];

        // Default analytics value
        if (![self.dataStore objectForKey:kUAAnalyticsEnabled]) {
            [self.dataStore setBool:YES forKey:kUAAnalyticsEnabled];
        }

        self.eventManager.uploadsEnabled = self.isEnabled && self.componentEnabled && self.isDataOptIn;
        self.eventManager.delegate = self;
        
        [self startSession];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationWillEnterForeground)
                                        name:UAApplicationWillEnterForegroundNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationDidEnterBackground)
                                        name:UAApplicationDidEnterBackgroundNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationWillTerminate)
                                        name:UAApplicationWillTerminateNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationDidBecomeActive)
                                        name:UAApplicationDidBecomeActiveNotification
                                      object:nil];

        if (!self.isEnabled) {
            [self.eventManager deleteAllEvents];
        }
    }

    return self;
}

+ (instancetype)analyticsWithConfig:(UARuntimeConfig *)config
                          dataStore:(UAPreferenceDataStore *)dataStore
                            channel:(UAChannel *)channel {
    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                channel:channel
                           eventManager:[UAEventManager eventManagerWithConfig:config dataStore:dataStore channel:channel]
                     notificationCenter:[NSNotificationCenter defaultCenter]
                                   date:[[UADate alloc] init]
                             dispatcher:[UADispatcher mainDispatcher]];
}

+ (instancetype)analyticsWithConfig:(UARuntimeConfig *)airshipConfig
                          dataStore:(UAPreferenceDataStore *)dataStore
                            channel:(UAChannel *)channel
                       eventManager:(UAEventManager *)eventManager
                 notificationCenter:(NSNotificationCenter *)notificationCenter
                               date:(UADate *)date
                         dispatcher:(UADispatcher *)dispatcher {

    return [[self alloc] initWithConfig:airshipConfig
                              dataStore:dataStore
                                channel:channel
                           eventManager:eventManager
                     notificationCenter:notificationCenter
                                   date:date
                             dispatcher:dispatcher];
}

#pragma mark -
#pragma mark Application State

- (void)applicationWillEnterForeground {
    UA_LTRACE(@"Enter Foreground.");

    // Start tracking previous screen before backgrounding began
    [self trackScreen:self.previousScreen];

    // do not send the foreground event yet, as we are not actually in the foreground
    // (we are merely in the process of foregorunding)
    // set this flag so that the even will be sent as soon as the app is active.
    self.isEnteringForeground = YES;
}

- (void)applicationDidEnterBackground {
    UA_LTRACE(@"Enter Background.");

    [self stopTrackingScreen];

    // add app_background event
    [self addEvent:[UAAppBackgroundEvent event]];

    [self startSession];
    self.conversionSendID = nil;
    self.conversionPushMetadata = nil;
}

- (void)applicationWillTerminate {
    UA_LTRACE(@"Application is terminating.");
    [self stopTrackingScreen];
}

- (void)applicationDidBecomeActive {
    UA_LTRACE(@"Application did become active.");

    // If this is the first 'inactive->active' transition in this session,
    // send
    if (self.isEnteringForeground) {

        self.isEnteringForeground = NO;

        // Start a new session
        [self startSession];

        //add app_foreground event
        [self addEvent:[UAAppForegroundEvent event]];
    }
}


#pragma mark -
#pragma mark Analytics

- (void)addEvent:(UAEvent *)event {
    if (!event.isValid) {
        UA_LERR(@"Dropping invalid event %@.", event);
        return;
    }

    if (!self.isEnabled || !self.isDataOptIn) {
        UA_LTRACE(@"Analytics disabled, ignoring event: %@", event.eventType);
        return;
    }


    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)

        UA_LDEBUG(@"Adding %@ event %@.", event.eventType, event.eventID);
        [self.eventManager addEvent:event sessionID:self.sessionID];
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


- (void)launchedFromNotification:(NSDictionary *)notification {
    if (!notification) {
        return;
    }

    // If the server did not send a push ID (likely because the payload did not have room)
    // then send "MISSING_SEND_ID"
    if ([UAUtils isAlertingPush:notification]) {
        self.conversionSendID = [notification objectForKey:@"_"] ?: kUAMissingSendID;
    } else {
        self.conversionSendID = nil;
    }

    // If the server did not send the metadata, then set it to nil
    self.conversionPushMetadata = [notification objectForKey:kUAPushMetadata] ?: nil;
}

- (void)startSession {
    self.sessionID = [NSUUID UUID].UUIDString;
}

- (BOOL)isEnabled {
    return [self.dataStore boolForKey:kUAAnalyticsEnabled] && self.config.analyticsEnabled;
}

- (void)setEnabled:(BOOL)enabled {
    // If we are disabling the runtime flag clear all events
    if ([self.dataStore boolForKey:kUAAnalyticsEnabled] && !enabled) {
        UA_LINFO(@"Deleting all analytics events.");
        [self.eventManager deleteAllEvents];
    }

    [self.dataStore setBool:enabled forKey:kUAAnalyticsEnabled];
    self.eventManager.uploadsEnabled = self.isEnabled && self.componentEnabled && self.isDataOptIn;
}

- (void)associateDeviceIdentifiers:(UAAssociatedIdentifiers *)associatedIdentifiers {
    NSDictionary *previous = [self.dataStore objectForKey:kUAAssociatedIdentifiers];

    if ([previous isEqualToDictionary:associatedIdentifiers.allIDs]) {
        UA_LINFO(@"Skipping analytics event addition for duplicate associated identifiers.");
        return;
    }

    [self.dataStore setObject:associatedIdentifiers.allIDs forKey:kUAAssociatedIdentifiers];
    [self addEvent:[UAAssociateIdentifiersEvent eventWithIDs:associatedIdentifiers]];
}

- (UAAssociatedIdentifiers *)currentAssociatedDeviceIdentifiers {
    NSDictionary *storedIDs = [self.dataStore objectForKey:kUAAssociatedIdentifiers];
    return [UAAssociatedIdentifiers identifiersWithDictionary:storedIDs];
}

- (void)trackScreen:(nullable NSString *)screen {

    // Prevent duplicate calls to track same screen
    if ([screen isEqualToString:self.currentScreen]) {
        return;
    }

    [self.notificationCenter postNotificationName:UAScreenTracked
                                           object:self
                                         userInfo:screen == nil ? @{} : @{UAScreenKey: screen}];

    // If there's a screen currently being tracked set it's stop time and add it to analytics
    if (self.currentScreen) {
        UAScreenTrackingEvent *ste = [UAScreenTrackingEvent eventWithScreen:self.currentScreen startTime:self.startTime];
        ste.stopTime = self.date.now.timeIntervalSince1970;
        ste.previousScreen = self.previousScreen;

        // Set previous screen to last tracked screen
        self.previousScreen = self.currentScreen;

        // Add screen tracking event to next analytics batch
        [self addEvent:ste];
    }

    self.currentScreen = screen;
    self.startTime = self.date.now.timeIntervalSince1970;
}

- (void)stopTrackingScreen {
    [self trackScreen:nil];
}

- (void)cancelUpload {
    [self.eventManager cancelUpload];
}

- (void)scheduleUpload {
    [self.eventManager scheduleUpload];
}

- (void)onComponentEnableChange {
    self.eventManager.uploadsEnabled = self.isEnabled && self.componentEnabled && self.isDataOptIn;
    if (self.componentEnabled) {
        // if component was disabled and is now enabled, schedule an upload just in case
        [self scheduleUpload];
    } else {
        // if component was enabled and is now disabled, cancel any pending uploads
        [self cancelUpload];
    }
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
    [headers setValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] ?: @"" forKey:@"X-UA-Package-Version"];

    // Time zone
    [headers setValue:[[NSTimeZone defaultTimeZone] name] forKey:@"X-UA-Timezone"];
    [headers setValue:[[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode] forKey:@"X-UA-Locale-Language"];
    [headers setValue:[[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode] forKey:@"X-UA-Locale-Country"];
    [headers setValue:[[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleVariantCode] forKey:@"X-UA-Locale-Variant"];

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

@end
