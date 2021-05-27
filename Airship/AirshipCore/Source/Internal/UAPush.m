/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

#import "UAPush+Internal.h"
#import "UAirship+Internal.h"
#import "UAAnalytics+Internal.h"

#import "UAUtils+Internal.h"
#import "UANotificationCategories.h"
#import "UANotificationCategory.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UARuntimeConfig.h"
#import "UANotificationCategory.h"
#import "UATagUtils+Internal.h"
#import "UARegistrationDelegateWrapper+Internal.h"
#import "UADispatcher.h"
#import "UAAppStateTracker.h"
#import "NSObject+UAAdditions.h"
#import "UASemaphore.h"
#import "UAPrivacyManager.h"

NSString *const UAUserPushNotificationsEnabledKey = @"UAUserPushNotificationsEnabled";
NSString *const UABackgroundPushNotificationsEnabledKey = @"UABackgroundPushNotificationsEnabled";
NSString *const UAExtendedPushNotificationPermissionEnabledKey = @"UAExtendedPushNotificationPermissionEnabled";

NSString *const UAPushLegacyTagsSettingsKey = @"UAPushTags";
NSString *const UAPushBadgeSettingsKey = @"UAPushBadge";
NSString *const UAPushDeviceTokenKey = @"UADeviceToken";

NSString *const UAPushQuietTimeSettingsKey = @"UAPushQuietTime";
NSString *const UAPushQuietTimeEnabledSettingsKey = @"UAPushQuietTimeEnabled";
NSString *const UAPushTimeZoneSettingsKey = @"UAPushTimeZone";

NSString *const UAPushTagsMigratedToChannelTagsKey = @"UAPushTagsMigrated";

NSString *const UAPushTypesAuthorizedKey = @"UAPushTypesAuthorized";
NSString *const UAPushAuthorizationStatusKey = @"UAPushAuthorizationStatus";
NSString *const UAPushUserPromptedForNotificationsKey = @"UAPushUserPromptedForNotifications";

// Old push enabled key
NSString *const UAPushEnabledKey = @"UAPushEnabled";

// Quiet time dictionary keys
NSString *const UAPushQuietTimeStartKey = @"start";
NSString *const UAPushQuietTimeEndKey = @"end";

// The default device tag group.
NSString *const UAPushDefaultDeviceTagGroup = @"device";

NSString *const UAReceivedNotificationResponseEvent = @"com.urbanairship.push.received_notification_response";
NSString *const UAReceivedForegroundNotificationEvent = @"com.urbanairship.push.received_foreground_notification";
NSString *const UAReceivedBackgroundNotificationEvent = @"com.urbanairship.push.received_background_notification";

// The foreground presentation options that can be defined from API or dashboard
NSString *const UAPresentationOptionBadge = @"badge";
NSString *const UAPresentationOptionAlert = @"alert";
NSString *const UAPresentationOptionSound = @"sound";
NSString *const UAPresentationOptionList = @"list";
NSString *const UAPresentationOptionBanner = @"banner";

// Foreground presentation keys
NSString *const UAForegroundPresentationLegacykey = @"foreground_presentation";
NSString *const UAForegroundPresentationkey = @"com.urbanairship.foreground_presentation";

NSTimeInterval const UADeviceTokenRegistrationWaitTime = 10;

@interface UAPush()
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) UIApplication *application;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UARegistrationDelegateWrapper *registrationDelegateWrapper;
@property (nonatomic, readonly) BOOL isRegisteredForRemoteNotifications;
@property (nonatomic, readonly) BOOL isBackgroundRefreshStatusAvailable;
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UAChannel<UAExtendableChannelRegistration> *channel;
@property (nonatomic, strong) UAAppStateTracker *appStateTracker;
@property (nonatomic, assign) BOOL waitForDeviceToken;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, assign) BOOL pushEnabled;

@end

@implementation UAPush

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
                       channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                     analytics:(UAAnalytics<UAExtendableAnalyticsHeaders> *)analytics
               appStateTracker:(UAAppStateTracker *)appStateTracker
            notificationCenter:(NSNotificationCenter *)notificationCenter
              pushRegistration:(id<UAAPNSRegistrationProtocol>)pushRegistration
                   application:(UIApplication *)application
                    dispatcher:(UADispatcher *)dispatcher
                privacyManager:(UAPrivacyManager *)privacyManager {

    self = [super initWithDataStore:dataStore];
    if (self) {
        self.config = config;
        self.application = application;
        self.dispatcher = dispatcher;
        self.dataStore = dataStore;
        self.channel = channel;
        self.privacyManager = privacyManager;
        
        self.appStateTracker = appStateTracker;
        self.notificationCenter = notificationCenter;
        self.registrationDelegateWrapper = [[UARegistrationDelegateWrapper alloc] init];

        self.pushRegistration = pushRegistration;
        self.requireAuthorizationForDefaultCategories = YES;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        self.backgroundPushNotificationsEnabledByDefault = YES;
#pragma clang diagnostic pop

        self.shouldUpdateAPNSRegistration = YES;

        self.notificationOptions = UANotificationOptionBadge;
#if !TARGET_OS_TV  // Sound and Alert not supported on tvOS
        self.notificationOptions = self.notificationOptions|UANotificationOptionSound|UANotificationOptionAlert;
#endif

        [self observeNotificationCenterEvents];

        // Migrate push tags to channel tags
        [self migratePushTagsToChannelTags];
        self.defaultPresentationOptions = UNNotificationPresentationOptionNone;
        self.waitForDeviceToken = self.channel.identifier == nil;

        [self updatePushEnablement];

        UA_WEAKIFY(self)
        [self.channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
            UA_STRONGIFY(self)
            [self extendChannelRegistrationPayload:payload completionHandler:completionHandler];
        }];

        [analytics addAnalyticsHeadersBlock:^NSDictionary<NSString *,NSString *> *{
            UA_STRONGIFY(self)
            return [self analyticsHeaders];
        }];
    }

    return self;
}

+ (instancetype)pushWithConfig:(UARuntimeConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
                       channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                     analytics:(UAAnalytics<UAExtendableAnalyticsHeaders> *)analytics
                privacyManager:(UAPrivacyManager *)privacyManager {
    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                channel:channel
                              analytics:analytics
                        appStateTracker:[UAAppStateTracker shared]
                     notificationCenter:[NSNotificationCenter defaultCenter]
                       pushRegistration:[[UAAPNSRegistration alloc] init]
                            application:[UIApplication sharedApplication]
                             dispatcher:[UADispatcher mainDispatcher]
                         privacyManager:privacyManager];
}

+ (instancetype)pushWithConfig:(UARuntimeConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
                       channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                     analytics:(UAAnalytics<UAExtendableAnalyticsHeaders> *)analytics
               appStateTracker:(UAAppStateTracker *)appStateTracker
            notificationCenter:(NSNotificationCenter *)notificationCenter
              pushRegistration:(id<UAAPNSRegistrationProtocol>)pushRegistration
                   application:(UIApplication *)application
                    dispatcher:(UADispatcher *)dispatcher
                privacyManager:(UAPrivacyManager *)privacyManager {
    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                channel:channel
                              analytics:analytics
                        appStateTracker:appStateTracker
                     notificationCenter:notificationCenter
                       pushRegistration:pushRegistration
                            application:application
                             dispatcher:dispatcher
                         privacyManager:privacyManager];
}

- (void)observeNotificationCenterEvents {
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationBackgroundRefreshStatusChanged)
                                    name:UIApplicationBackgroundRefreshStatusDidChangeNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidTransitionToForeground)
                                    name:UAApplicationDidTransitionToForeground
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidEnterBackground)
                                    name:UAApplicationDidEnterBackgroundNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(channelUpdated:)
                                    name:UAChannelUpdatedEvent
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(channelRegistrationFailed)
                                    name:UAChannelRegistrationFailedEvent
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(onEnabledFeaturesChanged)
                                    name:UAPrivacyManagerEnabledFeaturesChangedEvent
                                  object:nil];
}

- (void)updateAuthorizedNotificationTypes {
    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        return;
    }

    [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
        if (![self.privacyManager isEnabled:UAFeaturesPush]) {
            return;
        }

        if (self.userPromptedForNotifications || authorizedSettings != UAAuthorizedNotificationSettingsNone) {
            self.userPromptedForNotifications = YES;
            self.authorizedNotificationSettings = authorizedSettings;
        }

        self.authorizationStatus = status;

        if (!self.config.requestAuthorizationToUseNotifications) {
            // if app is managing notification authorization update channel
            // registration in case notification authorization has changed
            [self.channel updateRegistration];
        }
    }];
}

- (void)onEnabledFeaturesChanged {
    [self updatePushEnablement];
}

- (void)updatePushEnablement {
    if (self.componentEnabled && [self.privacyManager isEnabled:UAFeaturesPush]) {
        if (!self.pushEnabled) {
            [self.application registerForRemoteNotifications];
            self.shouldUpdateAPNSRegistration = YES;
            [self updateAuthorizedNotificationTypes];
            [self updateRegistration];
            self.pushEnabled = YES;
        }
    } else {
        self.pushEnabled = NO;
    }
}

#pragma mark -
#pragma mark Device Token Get/Set Methods

- (UAAuthorizedNotificationSettings)authorizedNotificationSettings {
    return (UAAuthorizedNotificationSettings) [self.dataStore integerForKey:UAPushTypesAuthorizedKey];
}

- (void)setAuthorizedNotificationSettings:(UAAuthorizedNotificationSettings)authorizedSettings {
    if (![self.dataStore objectForKey:UAPushTypesAuthorizedKey] || [self.dataStore integerForKey:UAPushTypesAuthorizedKey] != authorizedSettings) {

        [self.dataStore setInteger:(NSInteger)authorizedSettings forKey:UAPushTypesAuthorizedKey];
        [self updateRegistration];

        [self.registrationDelegateWrapper notificationAuthorizedSettingsDidChange:authorizedSettings
                                                                    legacyOptions:[self legacyOptionsForAuthorizedSettings:authorizedSettings]];
    }
}

- (void)setAuthorizationStatus:(UAAuthorizationStatus)authorizationStatus {
    UAAuthorizationStatus previousValue = self.authorizationStatus;

    if (authorizationStatus != previousValue) {
        [self.dataStore setInteger:authorizationStatus forKey:UAPushAuthorizationStatusKey];
    }
}

- (UAAuthorizationStatus)authorizationStatus {
    return (UAAuthorizationStatus) [self.dataStore integerForKey:UAPushAuthorizationStatusKey];
}

- (void)setDeviceToken:(NSString *)deviceToken {
    if (deviceToken == nil) {
        [self willChangeValueForKey:@"deviceToken"];
        [self.dataStore removeObjectForKey:UAPushDeviceTokenKey];
        [self didChangeValueForKey:@"deviceToken"];
        return;
    }

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^0-9a-fA-F]"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:NULL];

    if ([regex numberOfMatchesInString:deviceToken options:0 range:NSMakeRange(0, [deviceToken length])]) {
        UA_LERR(@"Device token %@ contains invalid characters. Only hex characters are allowed.", deviceToken);
        return;
    }

    // Device tokens are 32 to 100 bytes in binary format, each byte is 2 hex characters
    if (deviceToken.length < 64 || deviceToken.length > 200) {
        UA_LWARN(@"Device token %@ should be 64 to 200 hex characters (32 to 100 bytes) long.", deviceToken);
    }

    [self willChangeValueForKey:@"deviceToken"];
    [self.dataStore setObject:deviceToken forKey:UAPushDeviceTokenKey];
    [self didChangeValueForKey:@"deviceToken"];

    // Log the device token at error level, but without logging
    // it as an error.
    if (uaLogLevel >= UALogLevelError) {
        NSLog(@"Device token: %@", deviceToken);
    }
}

- (NSString *)deviceToken {
    return [self.dataStore stringForKey:UAPushDeviceTokenKey];
}

#pragma mark -
#pragma mark Get/Set Methods

- (BOOL)isAutobadgeEnabled {
    return [self.dataStore boolForKey:UAPushBadgeSettingsKey];
}

- (void)setAutobadgeEnabled:(BOOL)autobadgeEnabled {
    [self.dataStore setBool:autobadgeEnabled forKey:UAPushBadgeSettingsKey];
}

- (BOOL)userPushNotificationsEnabled {
    if (![self.dataStore objectForKey:UAUserPushNotificationsEnabledKey]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return self.userPushNotificationsEnabledByDefault;
#pragma clang diagnostic pop
    }

    return [self.dataStore boolForKey:UAUserPushNotificationsEnabledKey];
}

- (void)setUserPushNotificationsEnabled:(BOOL)enabled {
    BOOL previousValue = self.userPushNotificationsEnabled;
    [self.dataStore setBool:enabled forKey:UAUserPushNotificationsEnabledKey];

    if (enabled != previousValue) {
        self.shouldUpdateAPNSRegistration = YES;
        [self updateRegistration];
    }
}

- (BOOL)extendedPushNotificationPermissionEnabled {
    if (![self.dataStore objectForKey:UAExtendedPushNotificationPermissionEnabledKey]) {
        return NO;
    }

    return [self.dataStore boolForKey:UAExtendedPushNotificationPermissionEnabledKey];
}

- (void)setExtendedPushNotificationPermissionEnabled:(BOOL)enabled {
    if(!self.userPushNotificationsEnabled) {
        return;
    }
    
    BOOL previousValue = self.extendedPushNotificationPermissionEnabled;
    [self.dataStore setBool:enabled forKey:UAExtendedPushNotificationPermissionEnabledKey];

    if (enabled && enabled != previousValue) {
        self.shouldUpdateAPNSRegistration = YES;
        [self updateRegistration];
    }
}

- (void)enableUserPushNotifications:(void(^)(BOOL success))completionHandler {
    [self.dataStore setBool:YES forKey:UAUserPushNotificationsEnabledKey];
    [self updateAPNSRegistration:^(BOOL result){
        [self.channel updateRegistration];
        if (completionHandler) {
            completionHandler(result);
        }
    }];
}

- (BOOL)userPromptedForNotifications {
    return [self.dataStore boolForKey:UAPushUserPromptedForNotificationsKey];
}

- (void)setUserPromptedForNotifications:(BOOL)userPrompted {
    BOOL previousValue = self.userPromptedForNotifications;

    if (userPrompted != previousValue) {
        [self.dataStore setBool:userPrompted forKey:UAPushUserPromptedForNotificationsKey];
    }
}

- (BOOL)backgroundPushNotificationsEnabled {
    if (![self.dataStore objectForKey:UABackgroundPushNotificationsEnabledKey]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return self.backgroundPushNotificationsEnabledByDefault;
#pragma clang diagnostic pop
    }

    return [self.dataStore boolForKey:UABackgroundPushNotificationsEnabledKey];
}

- (void)setBackgroundPushNotificationsEnabled:(BOOL)enabled {
    BOOL previousValue = self.backgroundPushNotificationsEnabled;
    [self.dataStore setBool:enabled forKey:UABackgroundPushNotificationsEnabledKey];

    if (enabled != previousValue) {
        [self.channel updateRegistration];
    }
}

- (BOOL)pushTokenRegistrationEnabled {
    return [self.privacyManager isEnabled:UAFeaturesPush];
}

- (void)setPushTokenRegistrationEnabled:(BOOL)enabled {
    if (enabled) {
        [self.privacyManager enableFeatures:UAFeaturesPush];
    } else {
        [self.privacyManager disableFeatures:UAFeaturesPush];
    }
}

- (void)setCustomCategories:(NSSet<UANotificationCategory *> *)categories {
    _customCategories = [categories filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        UANotificationCategory *category = evaluatedObject;
        if ([category.identifier hasPrefix:@"ua_"]) {
            UA_LWARN(@"Ignoring category %@, only Airship notification categories are allowed to have prefix ua_.", category.identifier);
            return NO;
        }

        return YES;
    }]];

    self.shouldUpdateAPNSRegistration = YES;
}

- (void)setRequireAuthorizationForDefaultCategories:(BOOL)requireAuthorizationForDefaultCategories {
    _requireAuthorizationForDefaultCategories = requireAuthorizationForDefaultCategories;
    self.shouldUpdateAPNSRegistration = YES;
}

- (NSSet<UANotificationCategory *> *)combinedCategories {
    NSMutableSet *categories = [NSMutableSet setWithSet:[UANotificationCategories defaultCategoriesWithRequireAuth:self.requireAuthorizationForDefaultCategories]];
    [categories unionSet:self.customCategories];
    [categories unionSet:self.accengageCategories];
    return categories;
}

- (NSDictionary *)quietTime {
    return [self.dataStore dictionaryForKey:UAPushQuietTimeSettingsKey];
}

- (void)setQuietTime:(NSDictionary *)quietTime {
    [self.dataStore setObject:quietTime forKey:UAPushQuietTimeSettingsKey];
}

- (BOOL)isQuietTimeEnabled {
    return [self.dataStore boolForKey:UAPushQuietTimeEnabledSettingsKey];
}

- (void)setQuietTimeEnabled:(BOOL)quietTimeEnabled {
    [self.dataStore setBool:quietTimeEnabled forKey:UAPushQuietTimeEnabledSettingsKey];
}

- (NSTimeZone *)timeZone {
    NSString *timeZoneName = [self.dataStore stringForKey:UAPushTimeZoneSettingsKey];
    return [NSTimeZone timeZoneWithName:timeZoneName] ?: [self defaultTimeZoneForQuietTime];
}

- (void)setTimeZone:(NSTimeZone *)timeZone {
    [self.dataStore setObject:[timeZone name] forKey:UAPushTimeZoneSettingsKey];
}

- (NSTimeZone *)defaultTimeZoneForQuietTime {
    return [NSTimeZone defaultTimeZone];
}

- (void)setNotificationOptions:(UANotificationOptions)notificationOptions {
    _notificationOptions = notificationOptions;
    self.shouldUpdateAPNSRegistration = YES;
}

- (void)setRegistrationDelegate:(id<UARegistrationDelegate>)registrationDelegate {
    self.registrationDelegateWrapper.delegate = registrationDelegate;
}

- (id<UARegistrationDelegate>)registrationDelegate {
    return self.registrationDelegateWrapper.delegate;
}

#pragma mark -
#pragma mark Open APIs - Property Setters

-(void)setQuietTimeStartHour:(NSUInteger)startHour startMinute:(NSUInteger)startMinute
                     endHour:(NSUInteger)endHour endMinute:(NSUInteger)endMinute {

    if (startHour >= 24 || startMinute >= 60) {
        UA_LERR(@"Unable to set quiet time, invalid start time: %ld:%02ld", (unsigned long)startHour, (unsigned long)startMinute);
        return;
    }

    if (endHour >= 24 || endMinute >= 60) {
        UA_LERR(@"Unable to set quiet time, invalid end time: %ld:%02ld", (unsigned long)endHour, (unsigned long)endMinute);
        return;
    }

    NSString *startTimeStr = [NSString stringWithFormat:@"%ld:%02ld",(unsigned long)startHour, (unsigned long)startMinute];
    NSString *endTimeStr = [NSString stringWithFormat:@"%ld:%02ld",(unsigned long)endHour, (unsigned long)endMinute];

    UA_LDEBUG("Setting quiet time: %@ to %@", startTimeStr, endTimeStr);

    self.quietTime = @{UAPushQuietTimeStartKey : startTimeStr,
                       UAPushQuietTimeEndKey : endTimeStr };
}

#pragma mark Badges

- (NSInteger)badgeNumber {
    return [self.application applicationIconBadgeNumber];
}

- (void)setBadgeNumber:(NSInteger)badgeNumber {
    if ([self.application applicationIconBadgeNumber] == badgeNumber) {
        return;
    }

    UA_LDEBUG(@"Change Badge from %ld to %ld", (long)[self.application applicationIconBadgeNumber], (long)badgeNumber);

    [self.application setApplicationIconBadgeNumber:badgeNumber];

    // if the device token has already been set then
    // we are post-registration and will need to make
    // an update call
    if (self.autobadgeEnabled && (self.deviceToken || self.channel.identifier)) {
        UA_LDEBUG(@"Sending autobadge update to Airship server.");
        [self.channel updateRegistrationForcefully:YES];
    }
}

- (void)resetBadge {
    [self setBadgeNumber:0];
}

#pragma mark -
#pragma mark App State Observation

- (void)applicationDidTransitionToForeground {
    if ([self.privacyManager isEnabled:UAFeaturesPush]) {
        [self updateAuthorizedNotificationTypes];
    }
}

- (void)applicationDidEnterBackground {
    self.launchNotificationResponse = nil;

    if ([self.privacyManager isEnabled:UAFeaturesPush]) {
        UA_LTRACE(@"Application entered the background. Updating authorization.");
        [self updateAuthorizedNotificationTypes];
    }
}

- (void)applicationBackgroundRefreshStatusChanged {
    if ([self.privacyManager isEnabled:UAFeaturesPush]) {
        UA_LTRACE(@"Background refresh status changed.");

        if (self.application.backgroundRefreshStatus == UIBackgroundRefreshStatusAvailable) {
            [self.application registerForRemoteNotifications];
        } else {
            [self.channel updateRegistration];
        }
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        return;
    }

    self.deviceToken = [UAUtils deviceTokenStringFromDeviceToken:deviceToken];

    if (self.appStateTracker.state == UAApplicationStateBackground && self.channel.identifier) {
        UA_LDEBUG(@"Skipping channel registration. The app is currently backgrounded and we already have a channel ID.");
    } else {
        [self.channel updateRegistration];
    }

    [self.registrationDelegateWrapper apnsRegistrationSucceededWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        return;
    }

    [self.registrationDelegateWrapper apnsRegistrationFailedWithError:error];
}

#pragma mark -
#pragma mark Airship Registration Methods

- (BOOL)isRegisteredForRemoteNotifications {
    __block BOOL registered;

    UA_WEAKIFY(self)
    [self.dispatcher doSync:^{
        UA_STRONGIFY(self)
        registered = self.application.isRegisteredForRemoteNotifications;
    }];

    return registered;
}

- (BOOL)isBackgroundRefreshStatusAvailable {
    __block BOOL available = NO;

    UA_WEAKIFY(self)
    [self.dispatcher doSync:^{
        UA_STRONGIFY(self)
        available = self.application.backgroundRefreshStatus == UIBackgroundRefreshStatusAvailable;
    }];

    return available;
}

- (BOOL)userPushNotificationsAllowed {
    BOOL allowed = YES;
    if (!self.deviceToken) {
        UA_LTRACE(@"Opted out: missing device token");
        allowed = NO;
    }

    if (!self.userPushNotificationsEnabled) {
        UA_LTRACE(@"Opted out: user push notifications disabled");
        allowed = NO;
    }

    if (!self.authorizedNotificationSettings) {
        UA_LTRACE(@"Opted out: no authorized notification settings");
        allowed = NO;
    }

    if (!self.isRegisteredForRemoteNotifications) {
        UA_LTRACE(@"Opted out: not registered for remote notifications");
        allowed = NO;
    }

    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        UA_LTRACE(@"Opted out: push is disabled");
        allowed = NO;
    }

    return allowed;
}

- (BOOL)backgroundPushNotificationsAllowed {
    if (!self.deviceToken
        || !self.backgroundPushNotificationsEnabled
        || ![UAirship shared].remoteNotificationBackgroundModeEnabled
        || ![self.privacyManager isEnabled:UAFeaturesPush]) {
        return NO;
    }

    BOOL backgroundPushAllowed = self.isRegisteredForRemoteNotifications;

    if (!self.isBackgroundRefreshStatusAvailable) {
        backgroundPushAllowed = NO;
    }

    return backgroundPushAllowed;
}

- (void)updateRegistration {
    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        return;
    }

    if (self.shouldUpdateAPNSRegistration) {
        UA_LDEBUG(@"APNS registration is out of date, updating.");
        UA_WEAKIFY(self)
        [self updateAPNSRegistration:^(BOOL result){
            UA_STRONGIFY(self)
            [self.channel updateRegistration];
        }];
    } else {
        [self.channel updateRegistration];
    }
}

- (void)onComponentEnableChange {
    [self updatePushEnablement];
}

- (void)updateAPNSRegistration:(nonnull void(^)(BOOL success))completionHandler {
    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        completionHandler(NO);
        return;
    }

    self.shouldUpdateAPNSRegistration = NO;

    [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings,
                                                                        UAAuthorizationStatus status) {

        UANotificationOptions options = UANotificationOptionNone;
        NSSet *categories = nil;

        if (self.userPushNotificationsEnabled) {
            options = self.notificationOptions;
            categories = self.combinedCategories;
        }

        if (!self.config.requestAuthorizationToUseNotifications) {
            // The app is handling notification authorization
            [self notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings status:status];
            completionHandler(YES);
        } else if (authorizedSettings == UAAuthorizedNotificationSettingsNone && options == UANotificationOptionNone) {
            completionHandler(NO);
        } else if (status == UAAuthorizationStatusEphemeral && !self.extendedPushNotificationPermissionEnabled) {
            [self notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings status:status];
            completionHandler(YES);
        } else {
            [self.pushRegistration updateRegistrationWithOptions:options
                                                      categories:categories
                                               completionHandler:^(BOOL result,
                                                                   UAAuthorizedNotificationSettings authorizedSettings,
                                                                   UAAuthorizationStatus status) {
                [self notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings status:status];
                completionHandler(result);
            }];
        }
    }];
}

- (UANotificationOptions)legacyOptionsForAuthorizedSettings:(UAAuthorizedNotificationSettings)authorizedSettings {
    UANotificationOptions options = UANotificationOptionNone;

    if (!self.userPushNotificationsEnabled) {
        return options;
    }

    if (authorizedSettings & UAAuthorizedNotificationSettingsBadge) {
        options |= UANotificationOptionBadge;
    }

#if !TARGET_OS_TV   // Only badges available on tvOS
    if (authorizedSettings & UAAuthorizedNotificationSettingsSound) {
        options |= UANotificationOptionSound;
    }

    if (authorizedSettings & UAAuthorizedNotificationSettingsAlert) {
        options |= UANotificationOptionAlert;
    }

    if (authorizedSettings & UAAuthorizedNotificationSettingsCarPlay) {
        options |= UANotificationOptionCarPlay;
    }

    if (authorizedSettings & UAAuthorizedNotificationSettingsAnnouncement) {
        options |= UANotificationOptionAnnouncement;
    }
#endif

    return options;
}

- (void)notificationRegistrationFinishedWithAuthorizedSettings:(UAAuthorizedNotificationSettings)authorizedSettings status:(UAAuthorizationStatus)status {
    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        return;
    }

    if (!self.deviceToken) {
        UA_WEAKIFY(self)
        [self.dispatcher dispatchAsync:^{
            UA_STRONGIFY(self)
            [self.application registerForRemoteNotifications];
        }];
    };

    self.userPromptedForNotifications = YES;
    self.authorizedNotificationSettings = authorizedSettings;
    self.authorizationStatus = status;

    [self.registrationDelegateWrapper notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings
                                                                               legacyOptions:[self legacyOptionsForAuthorizedSettings:authorizedSettings]
                                                                                  categories:self.combinedCategories
                                                                                      status:status];
}

#pragma mark -
#pragma mark Analytics

- (NSDictionary<NSString *, NSString *> *)analyticsHeaders {
    if ([self.privacyManager isEnabled:UAFeaturesPush]) {
        NSMutableDictionary *headers = [NSMutableDictionary dictionary];
        [headers setValue:self.userPushNotificationsAllowed ? @"true" : @"false" forKey:@"X-UA-Channel-Opted-In"];
        [headers setValue:self.userPromptedForNotifications ? @"true" : @"false" forKey:@"X-UA-Notification-Prompted"];
        [headers setValue:self.backgroundPushNotificationsAllowed ? @"true" : @"false" forKey:@"X-UA-Channel-Background-Enabled"];
        [headers setValue:self.deviceToken forKey:@"X-UA-Push-Address"];
        return headers;
    } else {
        return @{
            @"X-UA-Channel-Opted-In": @"false",
            @"X-UA-Channel-Background-Enabled": @"false"
        };
    }
}

#pragma mark -
#pragma mark Channel Registration Events

- (void)channelUpdated:(NSNotification *)notification {
    NSString *channelID = notification.userInfo[UAChannelUpdatedEventChannelKey];
    [self.registrationDelegateWrapper registrationSucceededForChannelID:channelID deviceToken:self.deviceToken];
}

- (void)channelRegistrationFailed {
    [self.registrationDelegateWrapper registrationFailed];
}

- (void)extendChannelRegistrationPayload:(UAChannelRegistrationPayload *)payload
                       completionHandler:(UAChannelRegistrationExtenderCompletionHandler)completionHandler {

    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        completionHandler(payload);
        return;
    }

    UA_WEAKIFY(self);
    [self waitForDeviceTokenRegistration:^{
        UA_STRONGIFY(self);

        if ([self.privacyManager isEnabled:UAFeaturesPush]) {
            payload.pushAddress = self.deviceToken;
            payload.optedIn = self.userPushNotificationsAllowed;
            payload.backgroundEnabled = self.backgroundPushNotificationsAllowed;

            if (self.autobadgeEnabled) {
                payload.badge = @(self.badgeNumber);
            }

            if (self.timeZone.name && self.quietTime && self.isQuietTimeEnabled) {
                payload.quietTime = self.quietTime;
                payload.quietTimeTimeZone = self.timeZone.name;
            }
        }
        completionHandler(payload);
    }];
}

- (void)waitForDeviceTokenRegistration:(void (^)(void))completionHandler {
    UA_WEAKIFY(self);
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self);
        if (self.waitForDeviceToken && [self.privacyManager isEnabled:UAFeaturesPush] && !self.deviceToken && self.application.isRegisteredForRemoteNotifications) {
            UASemaphore *semaphore = [UASemaphore semaphore];
            self.waitForDeviceToken = NO;
            __block UADisposable *disposable = [self observeAtKeyPath:@"deviceToken" withBlock:^(id  _Nonnull value) {
                [semaphore signal];
                [disposable dispose];
            }];

            [[UADispatcher globalDispatcher] dispatchAsync:^{
                UA_STRONGIFY(self);
                [semaphore wait:UADeviceTokenRegistrationWaitTime];
                [self.dispatcher dispatchAsync:completionHandler];
            }];
        } else {
            completionHandler();
        }
    }];
}

#pragma mark -
#pragma mark Push handling

- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification {
    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        return UNNotificationPresentationOptionNone;
    }

    UNNotificationPresentationOptions options = UNNotificationPresentationOptionNone;

    //Get foreground presentation options defined from the push API/dashboard
    NSArray *payloadPresentationOptions = [self foregroundPresentationOptionsForNotification:notification];
    if (payloadPresentationOptions.count) {
        // build the options bitmask from the array
        for (id presentationOption in payloadPresentationOptions) {
            if ([UAPresentationOptionBadge isEqualToString:presentationOption]) {
                options |= UNNotificationPresentationOptionBadge;
            } else if ([UAPresentationOptionAlert isEqualToString:presentationOption]) {
                options |= UNNotificationPresentationOptionAlert;
            } else if ([UAPresentationOptionSound isEqualToString:presentationOption]) {
                options |= UNNotificationPresentationOptionSound;
            }
#if !TARGET_OS_MACCATALYST
            if (@available(iOS 14.0, tvOS 14.0, *)) {
                if ([UAPresentationOptionList isEqualToString:presentationOption]) {
                    options |= UNNotificationPresentationOptionList;
                } else if ([UAPresentationOptionBanner isEqualToString:presentationOption]) {
                    options |= UNNotificationPresentationOptionBanner;
                }
            }
#endif
        }
    } else {
        options = self.defaultPresentationOptions;
    }

    id pushDelegate = self.pushNotificationDelegate;
    if ([pushDelegate respondsToSelector:@selector(extendPresentationOptions:notification:)]) {
        options = [pushDelegate extendPresentationOptions:options notification:notification];
    } else if ([pushDelegate respondsToSelector:@selector(presentationOptionsForNotification:)]) {
        options = [pushDelegate presentationOptionsForNotification:notification];
    }

    return options;
}

- (NSArray *)foregroundPresentationOptionsForNotification:(UNNotification *)notification {

    NSArray *presentationOptions = nil;
#if !TARGET_OS_TV   // UNNotificationContent.userInfo not available on tvOS
    // get the presentation options from the the notification
    presentationOptions = [notification.request.content.userInfo objectForKey:UAForegroundPresentationkey];

    if (!presentationOptions) {
        presentationOptions = [notification.request.content.userInfo objectForKey:UAForegroundPresentationLegacykey];
    }
#endif
    return presentationOptions;
}

- (void)handleNotificationResponse:(UANotificationResponse *)response completionHandler:(void (^)(void))handler {
    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        handler();
        return;
    }

    if ([response.actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier]) {
        self.launchNotificationResponse = response;
    }

    [self.notificationCenter postNotificationName:UAReceivedNotificationResponseEvent
                                           object:self
                                         userInfo:response.notificationContent.notificationInfo];

    id delegate = self.pushNotificationDelegate;
    if ([delegate respondsToSelector:@selector(receivedNotificationResponse:completionHandler:)]) {
        [delegate receivedNotificationResponse:response completionHandler:handler];
    } else {
        handler();
    }
}

- (void)handleRemoteNotification:(UANotificationContent *)notification foreground:(BOOL)foreground completionHandler:(void (^)(UIBackgroundFetchResult))handler {
    if (![self.privacyManager isEnabled:UAFeaturesPush]) {
        handler(UIBackgroundFetchResultNoData);
        return;
    }

    BOOL delegateCalled = NO;
    id delegate = self.pushNotificationDelegate;

    if (foreground) {

        if (self.autobadgeEnabled) {
            [self.application setApplicationIconBadgeNumber:notification.badge.integerValue];
        }

        [self.notificationCenter postNotificationName:UAReceivedForegroundNotificationEvent
                                               object:self
                                             userInfo:notification.notificationInfo];

        if ([delegate respondsToSelector:@selector(receivedForegroundNotification:completionHandler:)]) {
            delegateCalled = YES;
            [delegate receivedForegroundNotification:notification completionHandler:^{
                handler(UIBackgroundFetchResultNoData);
            }];
        }
    } else {
        [self.notificationCenter postNotificationName:UAReceivedBackgroundNotificationEvent
                                               object:self
                                             userInfo:notification.notificationInfo];

        if ([delegate respondsToSelector:@selector(receivedBackgroundNotification:completionHandler:)]) {
            delegateCalled = YES;
            [delegate receivedBackgroundNotification:notification completionHandler:^(UIBackgroundFetchResult fetchResult) {
                handler(fetchResult);
            }];
        }
    }

    if (!delegateCalled) {
        handler(UIBackgroundFetchResultNoData);
    }
}

#pragma mark -
#pragma mark Default Values

- (void)setBackgroundPushNotificationsEnabledByDefault:(BOOL)enabled {
    _backgroundPushNotificationsEnabledByDefault = enabled;
}

- (void)setUserPushNotificationsEnabledByDefault:(BOOL)enabled {
    _userPushNotificationsEnabledByDefault = enabled;
}

- (void)migratePushTagsToChannelTags {
    if (![self.dataStore keyExists:UAPushLegacyTagsSettingsKey]) {
        // Nothing to migrate
        return;
    }

    if ([self.dataStore boolForKey:UAPushTagsMigratedToChannelTagsKey]) {
        // Already migrated tags
        return;
    }

    // Normalize tags for older SDK versions, and migrate to UAChannel as necessary
    NSArray *existingPushTags = [self.dataStore objectForKey:UAPushLegacyTagsSettingsKey];

    if (existingPushTags) {
        NSArray *existingChannelTags = self.channel.tags;
        if (existingChannelTags) {
            NSSet *combinedTagsSet = [NSMutableSet setWithArray:existingPushTags];
            combinedTagsSet = [combinedTagsSet setByAddingObjectsFromArray:existingChannelTags];
            self.channel.tags = combinedTagsSet.allObjects;
        } else {
            self.channel.tags = [UATagUtils normalizeTags:existingPushTags];
        }
    }

    [self.dataStore setBool:YES forKey:UAPushTagsMigratedToChannelTagsKey];
    [self.dataStore removeObjectForKey:UAPushLegacyTagsSettingsKey];
}

@end
