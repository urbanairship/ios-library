/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>

#import "UAPush+Internal.h"
#import "UAirship+Internal.h"
#import "UAAnalytics+Internal.h"
#import "UADeviceRegistrationEvent+Internal.h"

#import "UAUtils+Internal.h"
#import "UAActionRegistry+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAUser+Internal.h"
#import "UAInteractiveNotificationEvent+Internal.h"
#import "UANotificationCategories+Internal.h"
#import "UANotificationCategory.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAConfig.h"
#import "UANotificationCategory.h"
#import "UATagUtils+Internal.h"
#import "UAPushReceivedEvent+Internal.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UARegistrationDelegateWrapper+Internal.h"
#import "UADispatcher+Internal.h"

#if !TARGET_OS_TV
#import "UAInboxUtils.h"
#endif

NSString *const UAUserPushNotificationsEnabledKey = @"UAUserPushNotificationsEnabled";
NSString *const UABackgroundPushNotificationsEnabledKey = @"UABackgroundPushNotificationsEnabled";
NSString *const UAPushTokenRegistrationEnabledKey = @"UAPushTokenRegistrationEnabled";

NSString *const UAPushAliasSettingsKey = @"UAPushAlias";
NSString *const UAPushTagsSettingsKey = @"UAPushTags";
NSString *const UAPushBadgeSettingsKey = @"UAPushBadge";
NSString *const UAPushDeviceTokenKey = @"UADeviceToken";

NSString *const UAPushQuietTimeSettingsKey = @"UAPushQuietTime";
NSString *const UAPushQuietTimeEnabledSettingsKey = @"UAPushQuietTimeEnabled";
NSString *const UAPushTimeZoneSettingsKey = @"UAPushTimeZone";

NSString *const UAPushChannelCreationOnForeground = @"UAPushChannelCreationOnForeground";
NSString *const UAPushEnabledSettingsMigratedKey = @"UAPushEnabledSettingsMigrated";

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

NSString *const UAChannelCreatedEvent = @"com.urbanairship.push.channel_created";
NSString *const UAChannelUpdatedEvent = @"com.urbanairship.push.channel_updated";

NSString *const UAReceivedNotificationResponseEvent = @"com.urbanairship.push.received_notification_response";
NSString *const UAReceivedForegroundNotificationEvent = @"com.urbanairship.push.received_foreground_notification";
NSString *const UAReceivedBackgroundNotificationEvent = @"com.urbanairship.push.received_background_notification";

NSString *const UAChannelCreatedEventChannelKey = @"com.urbanairship.push.channel_id";
NSString *const UAChannelCreatedEventExistingKey = @"com.urbanairship.push.existing";

NSString *const UAChannelUpdatedEventChannelKey = @"com.urbanairship.push.channel_id";

@interface UAPush()
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) UIApplication *application;
@property (nonatomic, strong) UATagGroupsRegistrar *tagGroupsRegistrar;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UARegistrationDelegateWrapper *registrationDelegateWrapper;
@property (nonatomic, readonly) BOOL isRegisteredForRemoteNotifications;
@property (nonatomic, readonly) BOOL isBackgroundRefreshStatusAvailable;
@property (nonatomic, strong) UAConfig *config;

@end

@implementation UAPush

- (instancetype)initWithConfig:(UAConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
            tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar
            notificationCenter:(NSNotificationCenter *)notificationCenter
              pushRegistration:(id<UAAPNSRegistrationProtocol>)pushRegistration
                   application:(UIApplication *)application
                    dispatcher:(UADispatcher *)dispatcher {

    self = [super initWithDataStore:dataStore];
    if (self) {
        self.config = config;
        self.application = application;
        self.dispatcher = dispatcher;
        self.dataStore = dataStore;
        self.notificationCenter = notificationCenter;
        self.registrationDelegateWrapper = [[UARegistrationDelegateWrapper alloc] init];

        self.pushRegistration = pushRegistration;
        self.pushRegistration.registrationDelegate = self;

        self.channelTagRegistrationEnabled = YES;
        self.requireAuthorizationForDefaultCategories = YES;
        self.backgroundPushNotificationsEnabledByDefault = YES;

        self.isForegrounded = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;

        self.notificationOptions = UANotificationOptionBadge;
#if !TARGET_OS_TV
        self.notificationOptions = self.notificationOptions|UANotificationOptionSound|UANotificationOptionAlert;
#endif

        self.channelRegistrar = [UAChannelRegistrar channelRegistrarWithConfig:config dataStore:dataStore delegate:self];

        self.tagGroupsRegistrar = tagGroupsRegistrar;

        // Check config to see if user wants to delay channel creation
        // If channel ID exists or channel creation delay is disabled then channelCreationEnabled
        if (self.channelID || !config.isChannelCreationDelayEnabled) {
            self.channelCreationEnabled = YES;
        } else {
            UA_LDEBUG(@"Channel creation disabled.");
            self.channelCreationEnabled = NO;
        }

        // Only for observing the first call to app foreground
        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationDidBecomeActive)
                                        name:UIApplicationDidBecomeActiveNotification
                                      object:nil];

        // Only for observing the first call to app background
        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationDidEnterBackground)
                                        name:UIApplicationDidEnterBackgroundNotification
                                      object:nil];

#if !TARGET_OS_TV    // UIApplicationBackgroundRefreshStatusDidChangeNotification not available on tvOS
        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationBackgroundRefreshStatusChanged)
                                        name:UIApplicationBackgroundRefreshStatusDidChangeNotification
                                      object:nil];
#endif

        // Do not remove migratePushSettings call from init. It needs to be run
        // prior to allowing the application to set defaults.
        [self migratePushSettings];

        // Log the channel ID at error level, but without logging
        // it as an error.
        if (self.channelID && uaLogLevel >= UALogLevelError) {
            NSLog(@"Channel ID: %@", self.channelID);
        }

        // Register for remote notifications right away. This does not prompt for permissions to show notifications,
        // but starts the device token registration.
        [self.application registerForRemoteNotifications];

        [self updateAuthorizedNotificationTypes];
        self.defaultPresentationOptions = UNNotificationPresentationOptionNone;
    }

    return self;
}

+ (instancetype)pushWithConfig:(UAConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
            tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar {
    return [[self alloc] initWithConfig:config
                                dataStore:dataStore
                       tagGroupsRegistrar:tagGroupsRegistrar
                       notificationCenter:[NSNotificationCenter defaultCenter]
                         pushRegistration:[[UAAPNSRegistration alloc] init]
                            application:[UIApplication sharedApplication]
                             dispatcher:[UADispatcher mainDispatcher]];
}

+ (instancetype)pushWithConfig:(UAConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
            tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar
            notificationCenter:(NSNotificationCenter *)notificationCenter
              pushRegistration:(id<UAAPNSRegistrationProtocol>)pushRegistration
                   application:(UIApplication *)application
                    dispatcher:(UADispatcher *)dispatcher {

    return [[self alloc] initWithConfig:config
                                dataStore:dataStore
                       tagGroupsRegistrar:tagGroupsRegistrar
                       notificationCenter:notificationCenter
                         pushRegistration:pushRegistration
                            application:application
                             dispatcher:dispatcher];
}

- (void)updateAuthorizedNotificationTypes {
    [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
        if (self.userPromptedForNotifications || authorizedSettings != UAAuthorizedNotificationSettingsNone) {
            self.userPromptedForNotifications = YES;
            self.authorizedNotificationSettings = authorizedSettings;
        }

        self.authorizationStatus = status;

        if (!self.config.requestAuthorizationToUseNotifications) {
            // if app is managing notification authorization update channel
            // registration in case notification authorization has changed
            [self updateChannelRegistrationForcefully:NO];
        }

    }];
}

#pragma mark -
#pragma mark Device Token Get/Set Methods

- (UAAuthorizedNotificationSettings)authorizedNotificationSettings {
    return (UAAuthorizedNotificationSettings) [self.dataStore integerForKey:UAPushTypesAuthorizedKey];
}

- (UANotificationOptions)authorizedNotificationOptions {
    UANotificationOptions legacyOptions = [self legacyOptionsForAuthorizedSettings:self.authorizedNotificationSettings];

    // iOS 10 does not disable the types if they are already authorized. Hide any types
    // that are authorized but are no longer requested
    return legacyOptions & self.notificationOptions;
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
        [self.dataStore removeObjectForKey:UAPushDeviceTokenKey];
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

    [self.dataStore setObject:deviceToken forKey:UAPushDeviceTokenKey];

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

- (NSString *)channelID {
    return self.channelRegistrar.channelID;
}

- (BOOL)isAutobadgeEnabled {
    return [self.dataStore boolForKey:UAPushBadgeSettingsKey];
}

- (void)setAutobadgeEnabled:(BOOL)autobadgeEnabled {
    [self.dataStore setBool:autobadgeEnabled forKey:UAPushBadgeSettingsKey];
}

- (NSString *)alias {
    return [self.dataStore stringForKey:UAPushAliasSettingsKey];
}

- (void)setAlias:(NSString *)alias {
    NSString * trimmedAlias = [alias stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self.dataStore setObject:trimmedAlias forKey:UAPushAliasSettingsKey];
}

- (NSArray *)tags {
    NSArray *currentTags = [self.dataStore objectForKey:UAPushTagsSettingsKey];
    if (!currentTags) {
        currentTags = [NSArray array];
    }
    return currentTags;
}

- (void)setTags:(NSArray *)tags {
    [self.dataStore setObject:[UATagUtils normalizeTags:tags] forKey:UAPushTagsSettingsKey];
}

- (void)enableChannelCreation {
    if (!self.channelCreationEnabled) {
        self.channelCreationEnabled = YES;
        [self updateRegistration];
    }
}

- (BOOL)userPushNotificationsEnabled {
    if (![self.dataStore objectForKey:UAUserPushNotificationsEnabledKey]) {
        if ([self.dataStore boolForKey:UAPushEnabledSettingsMigratedKey]) {
            [self.dataStore setBool:self.userPushNotificationsEnabledByDefault forKey:UAUserPushNotificationsEnabledKey];
        }
        return self.userPushNotificationsEnabledByDefault;
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

- (void)enableUserPushNotifications:(void(^)(BOOL success))completionHandler {
    [self.dataStore setBool:YES forKey:UAUserPushNotificationsEnabledKey];
    [self updateAPNSRegistration:completionHandler];
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
        return self.backgroundPushNotificationsEnabledByDefault;
    }

    return [self.dataStore boolForKey:UABackgroundPushNotificationsEnabledKey];
}

- (void)setBackgroundPushNotificationsEnabled:(BOOL)enabled {
    BOOL previousValue = self.backgroundPushNotificationsEnabled;
    [self.dataStore setBool:enabled forKey:UABackgroundPushNotificationsEnabledKey];

    if (enabled != previousValue) {
        [self updateRegistration];
    }
}

- (BOOL)pushTokenRegistrationEnabled {
    if (![self.dataStore objectForKey:UAPushTokenRegistrationEnabledKey]) {
        return YES;
    }

    return [self.dataStore boolForKey:UAPushTokenRegistrationEnabledKey];
}

- (void)setPushTokenRegistrationEnabled:(BOOL)enabled {
    BOOL previousValue = self.pushTokenRegistrationEnabled;
    [self.dataStore setBool:enabled forKey:UAPushTokenRegistrationEnabledKey];

    if (enabled != previousValue) {
        [self updateRegistration];
    }
}

- (void)setCustomCategories:(NSSet<UANotificationCategory *> *)categories {
    _customCategories = [categories filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        UANotificationCategory *category = evaluatedObject;
        if ([category.identifier hasPrefix:@"ua_"]) {
            UA_LWARN(@"Ignoring category %@, only Urban Airship notification categories are allowed to have prefix ua_.", category.identifier);
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
    return [NSTimeZone localTimeZone];
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


#pragma mark -
#pragma mark Open APIs - UA Registration Tags APIs

- (void)addTag:(NSString *)tag {
    [self addTags:[NSArray arrayWithObject:tag]];
}

- (void)addTags:(NSArray *)tags {
    NSMutableSet *updatedTags = [NSMutableSet setWithArray:self.tags];
    [updatedTags addObjectsFromArray:tags];
    [self setTags:[updatedTags allObjects]];
}

- (void)removeTag:(NSString *)tag {
    [self removeTags:[NSArray arrayWithObject:tag]];
}

- (void)removeTags:(NSArray *)tags {
    NSMutableArray *mutableTags = [NSMutableArray arrayWithArray:self.tags];
    [mutableTags removeObjectsInArray:tags];
    [self.dataStore setObject:mutableTags forKey:UAPushTagsSettingsKey];
}

#pragma mark -
#pragma mark Open APIs - UA Tag Groups APIs

- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (self.channelTagRegistrationEnabled && [UAPushDefaultDeviceTagGroup isEqualToString:tagGroupID]) {
        UA_LERR(@"Unable to add tags %@ to device tag group when channelTagRegistrationEnabled is true.", [tags description]);
        return;
    }

    [self.tagGroupsRegistrar addTags:tags group:tagGroupID type:UATagGroupsTypeChannel];
}

- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (self.channelTagRegistrationEnabled && [UAPushDefaultDeviceTagGroup isEqualToString:tagGroupID]) {
        UA_LERR(@"Unable to remove tags %@ from device tag group when channelTagRegistrationEnabled is true.", [tags description]);
        return;
    }

    [self.tagGroupsRegistrar removeTags:tags group:tagGroupID type:UATagGroupsTypeChannel];
}

- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (self.channelTagRegistrationEnabled && [UAPushDefaultDeviceTagGroup isEqualToString:tagGroupID]) {
        UA_LERR(@"Unable to set tags %@ for device tag group when channelTagRegistrationEnabled is true.", [tags description]);
        return;
    }

    [self.tagGroupsRegistrar setTags:tags group:tagGroupID type:UATagGroupsTypeChannel];
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
    if (self.autobadgeEnabled && (self.deviceToken || self.channelID)) {
        UA_LDEBUG(@"Sending autobadge update to UA server.");
        [self updateChannelRegistrationForcefully:YES];
    }
}

- (void)resetBadge {
    [self setBadgeNumber:0];
}

#pragma mark -
#pragma mark UIApplication State Observation

- (void)applicationDidBecomeActive {
    if (self.isForegrounded && self.config.requestAuthorizationToUseNotifications) {
        // if the app is already in the foreground and the SDK is
        // managing notification authorization, nothing needs to be done.
        return;
    }

    // the app just moved into the foreground or the app is managing
    // notification authorization
    self.isForegrounded = YES;

    [self updateAuthorizedNotificationTypes];

    if ([self.dataStore boolForKey:UAPushChannelCreationOnForeground]) {
        UA_LTRACE(@"Application did become active. Updating registration.");
        [self updateChannelRegistrationForcefully:NO];
    }
}

- (void)applicationDidEnterBackground {
    self.isForegrounded = NO;
    
    self.launchNotificationResponse = nil;

    // Set the UAPushChannelCreationOnForeground after first run
    [self.dataStore setBool:YES forKey:UAPushChannelCreationOnForeground];

    // Create a channel if we do not have a channel ID
    if (!self.channelID) {
        UA_LTRACE(@"Application entered the background without a channelID. Updating registration.");
        [self updateChannelRegistrationForcefully:NO];
    }

    UA_LTRACE(@"Application entered the background. Updating authorization.");
    [self updateAuthorizedNotificationTypes];
}

#if !TARGET_OS_TV    // UIBackgroundRefreshStatusAvailable not available on tvOS
- (void)applicationBackgroundRefreshStatusChanged {
    UA_LTRACE(@"Background refresh status changed.");

    if (self.application.backgroundRefreshStatus == UIBackgroundRefreshStatusAvailable) {
        [self.application registerForRemoteNotifications];
    } else {
        [self updateRegistration];
    }
}
#endif

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    self.deviceToken = [UAUtils deviceTokenStringFromDeviceToken:deviceToken];

    if (application.applicationState == UIApplicationStateBackground && self.channelID) {
        UA_LDEBUG(@"Skipping channel registration. The app is currently backgrounded and we already have a channel ID.");
    } else {
        [self updateChannelRegistrationForcefully:NO];
    }

    [self.registrationDelegateWrapper apnsRegistrationSucceededWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    [self.registrationDelegateWrapper apnsRegistrationFailedWithError:error];

}

#pragma mark -
#pragma mark UA Registration Methods

#if !TARGET_OS_TV   // Inbox not supported on tvOS
- (void)addInboxUser:(UAChannelRegistrationPayload *)payload completionHandler:(void (^)(void))completionHandler {
    [[UAirship inboxUser] getUserData:^(UAUserData *userData) {
        payload.userID = userData.username;
        completionHandler();
    } dispatcher:[UADispatcher mainDispatcher]];
}
#endif

- (void)createChannelPayload:(void (^)(UAChannelRegistrationPayload *))completionHandler {
    UA_WEAKIFY(self)
    [UAUtils getDeviceID:^(NSString *deviceID) {
        UA_STRONGIFY(self)
        UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];

        payload.deviceID = deviceID;

        if (self.pushTokenRegistrationEnabled) {
            payload.pushAddress = self.deviceToken;
        }

        payload.optedIn = [self userPushNotificationsAllowed];
        payload.backgroundEnabled = [self backgroundPushNotificationsAllowed];

        payload.setTags = self.channelTagRegistrationEnabled;
        payload.tags = self.channelTagRegistrationEnabled ? [self.tags copy]: nil;

        if (self.autobadgeEnabled) {
            payload.badge = [NSNumber numberWithInteger:[self.application applicationIconBadgeNumber]];
        } else {
            payload.badge = nil;
        }

        if (self.timeZone.name && self.quietTimeEnabled) {
            payload.quietTime = [self.quietTime copy];
        }

        payload.timeZone = self.timeZone.name;
        payload.language = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode];
        payload.country = [[NSLocale autoupdatingCurrentLocale] objectForKey: NSLocaleCountryCode];

#if !TARGET_OS_TV   // Inbox not supported on tvOS
        [self addInboxUser:payload completionHandler:^{
            completionHandler(payload);
        }];
#else
        completionHandler(payload);
#endif


    } dispatcher:[UADispatcher mainDispatcher]];
}

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

#if !TARGET_OS_TV    // UIBackgroundRefreshStatusAvailable not available on tvOS
    UA_WEAKIFY(self)
    [self.dispatcher doSync:^{
        UA_STRONGIFY(self)
        available = self.application.backgroundRefreshStatus == UIBackgroundRefreshStatusAvailable;
    }];
#endif

    return available;
}

- (BOOL)userPushNotificationsAllowed {
    return self.deviceToken
    && self.userPushNotificationsEnabled
    && self.authorizedNotificationSettings
    && self.isRegisteredForRemoteNotifications
    && self.pushTokenRegistrationEnabled;
}

- (BOOL)backgroundPushNotificationsAllowed {
    if (!self.deviceToken
        || !self.backgroundPushNotificationsEnabled
        || ![UAirship shared].remoteNotificationBackgroundModeEnabled
        || !self.pushTokenRegistrationEnabled) {
        return NO;
    }

    BOOL backgroundPushAllowed = self.isRegisteredForRemoteNotifications;

#if !TARGET_OS_TV
    if (!self.isBackgroundRefreshStatusAvailable) {
        backgroundPushAllowed = NO;
    }
#endif
    return backgroundPushAllowed;
}

- (void)updateRegistration {
    // Update channel tag groups
    [self updateChannelTagGroups];

    // APNS registration will cause a channel registration
    if (self.shouldUpdateAPNSRegistration) {
        UA_LDEBUG(@"APNS registration is out of date, updating.");
        [self updateAPNSRegistration];
    } else if (self.userPushNotificationsEnabled && !self.channelID) {
        UA_LDEBUG(@"Push is enabled but we have not yet generated a channel ID. "
                  "Urban Airship registration will automatically run when the device token is registered, "
                  "the next time the app is backgrounded, or the next time the app is foregrounded.");
    } else {
        [self updateChannelRegistrationForcefully:NO];
    }
}

- (void)updateChannelRegistrationForcefully:(BOOL)forcefully {
    if (!self.componentEnabled) {
        return;
    }

    // Only cancel in flight requests if the channel is already created
    if (!self.channelCreationEnabled) {
        UA_LDEBUG(@"Channel creation is currently disabled.");
        return;
    }
    
    [self.channelRegistrar registerForcefully:forcefully];
}

- (void)updateChannelTagGroups {
    if (!self.componentEnabled) {
        return;
    }

    if (!self.channelID) {
        return;
    }

    [self.tagGroupsRegistrar updateTagGroupsForID:self.channelID type:UATagGroupsTypeChannel];
}

- (void)updateAPNSRegistration {
    [self updateAPNSRegistration:nil];
}

- (void)updateAPNSRegistration:(nullable void(^)(BOOL success))completionHandler {
    self.shouldUpdateAPNSRegistration = NO;

    UANotificationOptions options = UANotificationOptionNone;
    NSSet *categories = nil;

    if (self.userPushNotificationsEnabled) {
        options = self.notificationOptions;
        categories = self.combinedCategories;
    }

    [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
        if (!self.config.requestAuthorizationToUseNotifications) {
            // The app is handling notification authorization
            if (completionHandler) {
                completionHandler(YES);
            }
            [self notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings status:status];
            return;
        }
        if (authorizedSettings == UAAuthorizedNotificationSettingsNone && options == UANotificationOptionNone) {
            if (completionHandler) {
                completionHandler(NO);
            }
            // Skip updating registration to avoid prompting the user
            return;
        }

        [self.pushRegistration updateRegistrationWithOptions:options categories:categories completionHandler:completionHandler];
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
#endif

    return options;
}

- (void)notificationRegistrationFinishedWithAuthorizedSettings:(UAAuthorizedNotificationSettings)authorizedSettings status:(UAAuthorizationStatus)status {

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

- (void)registrationSucceeded {
    UA_LINFO(@"Channel registration updated successfully.");

    NSString *channelID = self.channelID;

    if (!channelID) {
        UA_LWARN(@"Channel ID is nil after successful registration.");
        return;
    }

    [self.notificationCenter postNotificationName:UAChannelUpdatedEvent
                                           object:self
                                         userInfo:@{UAChannelUpdatedEventChannelKey: channelID}];

    [self.registrationDelegateWrapper registrationSucceededForChannelID:self.channelID deviceToken:self.deviceToken];
}

- (void)registrationFailed {
    UA_LINFO(@"Channel registration failed.");
    [self.registrationDelegateWrapper registrationFailed];}

- (void)channelCreated:(NSString *)channelID
       channelLocation:(NSString *)channelLocation
              existing:(BOOL)existing {

    if (channelID && channelLocation) {
        if (uaLogLevel >= UALogLevelError) {
            NSLog(@"Created channel with ID: %@", channelID);
        }

        [self.notificationCenter postNotificationName:UAChannelCreatedEvent
                                               object:self
                                             userInfo:@{UAChannelCreatedEventChannelKey: channelID,
                                                        UAChannelCreatedEventExistingKey: @(existing)}];
    } else {
        UA_LERR(@"Channel creation failed. Missing channelID: %@ or channelLocation: %@",
                channelID, channelLocation);
    }
}

#pragma mark -
#pragma mark Push handling

- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification {
    UNNotificationPresentationOptions options = UNNotificationPresentationOptionNone;

    id pushDelegate = self.pushNotificationDelegate;
    if ([pushDelegate respondsToSelector:@selector(presentationOptionsForNotification:)]) {
        options = [pushDelegate presentationOptionsForNotification:notification];
    } else {
        options = self.defaultPresentationOptions;
    }

    return options;
}

- (void)handleNotificationResponse:(UANotificationResponse *)response completionHandler:(void (^)(void))handler {
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

- (void)migratePushSettings {
    [self.dataStore migrateUnprefixedKeys:@[UAUserPushNotificationsEnabledKey, UABackgroundPushNotificationsEnabledKey,
                                            UAPushAliasSettingsKey, UAPushTagsSettingsKey, UAPushBadgeSettingsKey,
                                            UAPushChannelIDKey, UAPushChannelLocationKey, UAPushDeviceTokenKey,
                                            UAPushQuietTimeSettingsKey, UAPushQuietTimeEnabledSettingsKey,
                                            UAPushChannelCreationOnForeground, UAPushEnabledSettingsMigratedKey,
                                            UAPushEnabledKey, UAPushTimeZoneSettingsKey]];

    if ([self.dataStore boolForKey:UAPushEnabledSettingsMigratedKey]) {
        // Already migrated
        return;
    }

    // Migrate userNotificationEnabled setting to YES if we are currently registered for notification types
    if (![self.dataStore objectForKey:UAUserPushNotificationsEnabledKey]) {

        // If the previous pushEnabled was set
        if ([self.dataStore objectForKey:UAPushEnabledKey]) {
            BOOL previousValue = [self.dataStore boolForKey:UAPushEnabledKey];
            UA_LTRACE(@"Migrating userPushNotificationEnabled to %@ from previous pushEnabledValue.", previousValue ? @"YES" : @"NO");
            [self.dataStore setBool:previousValue forKey:UAUserPushNotificationsEnabledKey];
            [self.dataStore removeObjectForKey:UAPushEnabledKey];
        } else {
            [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
                if (status == UAAuthorizationStatusAuthorized) {
                    UA_LTRACE(@"Migrating userPushNotificationEnabled to YES because application was authorized for notifications");
                    [self.dataStore setBool:YES forKey:UAUserPushNotificationsEnabledKey];
                }
            }];
        }
    }

    [self.dataStore setBool:YES forKey:UAPushEnabledSettingsMigratedKey];

    // Normalize tags for older SDK versions
    self.tags = [UATagUtils normalizeTags:self.tags];
}

- (void)onComponentEnableChange {
    self.tagGroupsRegistrar.componentEnabled = self.componentEnabled;
    if (self.componentEnabled) {
        // if component was disabled and is now enabled, register the channel
        [self updateRegistration];
    }
}

- (void)resetChannel {
    [self.channelRegistrar resetChannel];
}

@end
