/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>

#import "UAPush+Internal.h"

#import "UAirship.h"
#import "UAAnalytics.h"
#import "UAEventDeviceRegistration.h"

#import "UADeviceRegistrationPayload.h"
#import "UAUtils.h"
#import "UAActionRegistry+Internal.h"
#import "UAActionRunner.h"
#import "UAChannelRegistrationPayload.h"
#import "UAUser.h"
#import "UAInteractiveNotificationEvent.h"
#import "UAUserNotificationCategories+Internal.h"

#define kUAMinTagLength 1
#define kUAMaxTagLength 127
#define kUANotificationActionKey @"com.urbanairship.interactive_actions"

UAPushSettingsKey *const UAUserPushNotificationsEnabledKey = @"UAUserPushNotificationsEnabled";
UAPushSettingsKey *const UABackgroundPushNotificationsEnabledKey = @"UABackgroundPushNotificationsEnabled";

UAPushSettingsKey *const UAPushAliasSettingsKey = @"UAPushAlias";
UAPushSettingsKey *const UAPushTagsSettingsKey = @"UAPushTags";
UAPushSettingsKey *const UAPushBadgeSettingsKey = @"UAPushBadge";
UAPushSettingsKey *const UAPushChannelIDKey = @"UAChannelID";
UAPushSettingsKey *const UAPushChannelLocationKey = @"UAChannelLocation";
UAPushSettingsKey *const UAPushDeviceTokenKey = @"UADeviceToken";

UAPushSettingsKey *const UAPushQuietTimeSettingsKey = @"UAPushQuietTime";
UAPushSettingsKey *const UAPushQuietTimeEnabledSettingsKey = @"UAPushQuietTimeEnabled";
UAPushSettingsKey *const UAPushTimeZoneSettingsKey = @"UAPushTimeZone";
UAPushSettingsKey *const UAPushDeviceCanEditTagsKey = @"UAPushDeviceCanEditTags";

UAPushUserInfoKey *const UAPushUserInfoRegistration = @"Registration";
UAPushUserInfoKey *const UAPushUserInfoPushEnabled = @"PushEnabled";

UAPushUserInfoKey *const UAPushChannelCreationOnForeground = @"UAPushChannelCreationOnForeground";

UAPushUserInfoKey *const UAPushEnabledSettingsMigratedKey = @"UAPushEnabledSettingsMigrated";

// Old push enabled key
UAPushUserInfoKey *const UAPushEnabledKey = @"UAPushEnabled";

NSString *const UAPushQuietTimeStartKey = @"start";
NSString *const UAPushQuietTimeEndKey = @"end";

@implementation UAPush 

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
SINGLETON_IMPLEMENTATION(UAPush)
#pragma clang diagnostic pop

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        //init with default delegate implementation
        // released when replaced
        self.defaultPushHandler = [[NSClassFromString(PUSH_DELEGATE_CLASS) alloc] init];
        self.pushNotificationDelegate = _defaultPushHandler;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive) 
                                                     name:UIApplicationDidBecomeActiveNotification 
                                                   object:[UIApplication sharedApplication]];

        // Only for observing the first call to app background
        [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(applicationDidEnterBackground) 
                                                  name:UIApplicationDidEnterBackgroundNotification 
                                                object:[UIApplication sharedApplication]];

        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(applicationBackgroundRefreshStatusChanged)
                                                         name:UIApplicationBackgroundRefreshStatusDidChangeNotification
                                                       object:[UIApplication sharedApplication]];
        }

        // Do not remove migratePushSettings call from init. It needs to be run
        // prior to allowing the application to set defaults.
        [self migratePushSettings];
        
        self.deviceRegistrar = [[UADeviceRegistrar alloc] init];
        self.deviceRegistrar.delegate = self;

        self.deviceTagsEnabled = YES;
        self.requireAuthorizationForDefaultCategories = YES;
        self.backgroundPushNotificationsEnabledByDefault = YES;

        self.userNotificationTypes = UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound;

        // Log the channel ID at error level, but without logging
        // it as an error.
        if (self.channelID && uaLogLevel >= UALogLevelError) {
            NSLog(@"Channel ID: %@", self.channelID);
        }

        self.registrationBackgroundTask = UIBackgroundTaskInvalid;

        // Register for remote notifications on iOS8 right away if the background mode is enabled. This does not prompt for
        // permissions to show notifications, but starts the device token registration.
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotifications)] && [UAirship shared].remoteNotificationBackgroundModeEnabled) {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        }
    }

    return self;
}

#pragma mark -
#pragma mark Device Token Get/Set Methods

- (void)setDeviceToken:(NSString *)deviceToken {
    if (deviceToken == nil) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushDeviceTokenKey];
        return;
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^0-9a-fA-F]"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:NULL];

    if ([regex numberOfMatchesInString:deviceToken options:0 range:NSMakeRange(0, [deviceToken length])]) {
        UA_LERR(@"Device token %@ contains invalid characters.  Only hex characters are allowed", deviceToken);
        return;
    }

    // 64 - device tokens are 32 bytes long, each byte is 2 characters
    if ([deviceToken length] != 64) {
        UA_LWARN(@"Device token %@ should be only 32 bytes (64 characters) long", deviceToken);
    }

    [[NSUserDefaults standardUserDefaults] setObject:deviceToken forKey:UAPushDeviceTokenKey];

    // Log the device token at error level, but without logging
    // it as an error.
    if (uaLogLevel >= UALogLevelError) {
        NSLog(@"Device token: %@", deviceToken);
    }
}

- (NSString *)deviceToken {
    return [[NSUserDefaults standardUserDefaults] stringForKey:UAPushDeviceTokenKey];
}

#pragma mark -
#pragma mark Get/Set Methods

- (void)setChannelID:(NSString *)channelID {
    [[NSUserDefaults standardUserDefaults] setValue:channelID forKey:UAPushChannelIDKey];
    // Log the channel ID at error level, but without logging
    // it as an error.
    if (uaLogLevel >= UALogLevelError) {
        NSLog(@"Channel ID: %@", channelID);
    }
}

- (NSString *)channelID {
    // Get the channel location from standardUserDefaults instead of
    // the channelLocation property, because that may cause an infinite loop.
    if ([[NSUserDefaults standardUserDefaults] stringForKey:UAPushChannelLocationKey]) {
        return [[NSUserDefaults standardUserDefaults] stringForKey:UAPushChannelIDKey];
    } else {
        return nil;
    }
}

- (void)setChannelLocation:(NSString *)channelLocation {
    [[NSUserDefaults standardUserDefaults] setValue:channelLocation forKey:UAPushChannelLocationKey];
}

- (NSString *)channelLocation {
    // Get the channel ID from standardUserDefaults instead of
    // the channelID property, because that may cause an infinite loop.
    if ([[NSUserDefaults standardUserDefaults] stringForKey:UAPushChannelIDKey]) {
        return [[NSUserDefaults standardUserDefaults] stringForKey:UAPushChannelLocationKey];
    } else {
        return nil;
    }
}

- (BOOL)autobadgeEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:UAPushBadgeSettingsKey];
}

- (void)setAutobadgeEnabled:(BOOL)autobadgeEnabled {
    [[NSUserDefaults standardUserDefaults] setBool:autobadgeEnabled forKey:UAPushBadgeSettingsKey];
}

- (NSString *)alias {
    return [[NSUserDefaults standardUserDefaults] stringForKey:UAPushAliasSettingsKey];
}

- (void)setAlias:(NSString *)alias {
    NSString * trimmedAlias = [alias stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [[NSUserDefaults standardUserDefaults] setObject:trimmedAlias forKey:UAPushAliasSettingsKey];
}

- (NSArray *)tags {
    NSArray *currentTags = [[NSUserDefaults standardUserDefaults] objectForKey:UAPushTagsSettingsKey];
    if (!currentTags) {
        currentTags = [NSArray array];
    }
    
    NSArray *normalizedTags = [self normalizeTags:currentTags];
    
    //sync tags to prevent the tags property invocation from constantly logging tag set failure
    if ([currentTags count] != [normalizedTags count]) {
        [self setTags:normalizedTags];
    }

    return currentTags;
}

- (void)setTags:(NSArray *)tags {
    [[NSUserDefaults standardUserDefaults] setObject:[self normalizeTags:tags] forKey:UAPushTagsSettingsKey];
}

-(NSArray *)normalizeTags:(NSArray *)tags {
    NSMutableArray *normalizedTags = [[NSMutableArray alloc] init];

    for (NSString *tag in tags) {
        
        NSString *trimmedTag = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if ([trimmedTag length] >= kUAMinTagLength && [trimmedTag length] <= kUAMaxTagLength) {
            [normalizedTags addObject:trimmedTag];
        } else {
            UA_LERR(@"Tags must be > 0 and < 128 characters in length, tag %@ has been removed from the tag set", tag);
        }
    }
    
    return [NSArray arrayWithArray:normalizedTags];
}

- (BOOL)userPushNotificationsEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:UAUserPushNotificationsEnabledKey];
}

- (void)setUserPushNotificationsEnabled:(BOOL)enabled {
    BOOL previousValue = self.userPushNotificationsEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:UAUserPushNotificationsEnabledKey];

    if (enabled != previousValue) {
        self.shouldUpdateAPNSRegistration = YES;
        [self updateRegistration];
    }
}

- (BOOL)backgroundPushNotificationsEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:UABackgroundPushNotificationsEnabledKey];
}

- (void)setBackgroundPushNotificationsEnabled:(BOOL)enabled {
    BOOL previousValue = self.backgroundPushNotificationsEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:UABackgroundPushNotificationsEnabledKey];

    if (enabled != previousValue) {
        [self updateRegistration];
    }
}

- (void)setUserNotificationCategories:(NSSet *)categories {
    _userNotificationCategories = [categories filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        if (![evaluatedObject isKindOfClass:[UIUserNotificationCategory class]]) {
            return NO;
        }

        UIUserNotificationCategory *category = evaluatedObject;
        if ([category.identifier hasPrefix:@"ua_"]) {
            UA_LERR(@"Ignoring category %@, only Urban Airship user notification categories are allowed to have prefix ua_.", category.identifier);
            return NO;
        }

        return YES;
    }]];

    self.shouldUpdateAPNSRegistration = YES;
}

- (NSDictionary *)quietTime {
    return [[NSUserDefaults standardUserDefaults] dictionaryForKey:UAPushQuietTimeSettingsKey];
}

- (void)setQuietTime:(NSDictionary *)quietTime {
    [[NSUserDefaults standardUserDefaults] setObject:quietTime forKey:UAPushQuietTimeSettingsKey];
}

- (BOOL)quietTimeEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:UAPushQuietTimeEnabledSettingsKey];
}

- (void)setQuietTimeEnabled:(BOOL)quietTimeEnabled {
    [[NSUserDefaults standardUserDefaults] setBool:quietTimeEnabled forKey:UAPushQuietTimeEnabledSettingsKey];
}

- (NSTimeZone *)timeZone {
    NSString *timeZoneName = [[NSUserDefaults standardUserDefaults] stringForKey:UAPushTimeZoneSettingsKey];
    return [NSTimeZone timeZoneWithName:timeZoneName] ?: [self defaultTimeZoneForQuietTime];
}

- (void)setTimeZone:(NSTimeZone *)timeZone {
    [[NSUserDefaults standardUserDefaults] setObject:[timeZone name] forKey:UAPushTimeZoneSettingsKey];
}

- (NSTimeZone *)defaultTimeZoneForQuietTime {
    return [NSTimeZone localTimeZone];
}

- (void)setNotificationTypes:(UIRemoteNotificationType)notificationTypes {
    if ([UIUserNotificationSettings class]) {
        UA_LWARN(@"Remote notification types are deprecated, use userNotificationTypes instead.");

        if (notificationTypes == UIRemoteNotificationTypeNone) {
            UA_LWARN(@"Registering for UIRemoteNotificationTypeNone may disable the ability to register for other types without restarting the device first.");
        }

        UIUserNotificationType all = UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound;
        _userNotificationTypes = all & notificationTypes;
    }
    _notificationTypes = notificationTypes;

    self.shouldUpdateAPNSRegistration = YES;
}

- (void)setUserNotificationTypes:(UIUserNotificationType)userNotificationTypes {
    if (userNotificationTypes == UIUserNotificationTypeNone && [UIUserNotificationSettings class]) {
        UA_LWARN(@"Registering for UIUserNotificationTypeNone may disable the ability to register for other types without restarting the device first.");
    }

    _userNotificationTypes = userNotificationTypes;
    _notificationTypes = (UIRemoteNotificationType) userNotificationTypes;

    self.shouldUpdateAPNSRegistration = YES;
}


- (void)setAllowUnregisteringUserNotificationTypes:(BOOL)allowUnregisteringUserNotificationTypes {
    if (allowUnregisteringUserNotificationTypes) {
        UA_LWARN(@"Allowing UAPush to unregister for notification types may disable the ability to register for other types without restarting the device first.");
    }
    _allowUnregisteringUserNotificationTypes = allowUnregisteringUserNotificationTypes;
}

#pragma mark -
#pragma mark Open APIs - Property Setters

-(void)setQuietTimeStartHour:(NSUInteger)startHour startMinute:(NSUInteger)startMinute
                     endHour:(NSUInteger)endHour endMinute:(NSUInteger)endMinute {

    if (startHour >= 24 || startMinute >= 60) {
        UA_LWARN(@"Unable to set quiet time, invalid start time: %ld:%02ld", (unsigned long)startHour, (unsigned long)startMinute);
        return;
    }

    if (endHour >= 24 || endMinute >= 60) {
        UA_LWARN(@"Unable to set quiet time, invalid end time: %ld:%02ld", (unsigned long)endHour, (unsigned long)endMinute);
        return;
    }

    NSString *startTimeStr = [NSString stringWithFormat:@"%ld:%02ld",(unsigned long)startHour, (unsigned long)startMinute];
    NSString *endTimeStr = [NSString stringWithFormat:@"%ld:%02ld",(unsigned long)endHour, (unsigned long)endMinute];

    UA_LDEBUG("Setting quiet time: %@ to %@", startTimeStr, endTimeStr);

    self.quietTime = @{UAPushQuietTimeStartKey : startTimeStr,
                       UAPushQuietTimeEndKey : endTimeStr };
}


#pragma mark -
#pragma mark Open APIs

+ (void)land {
    
    // not much teardown to do here, but implement anyway for the future
    if (g_sharedUAPush) {
        g_sharedUAPush = nil;
        allocOncePredicateUAPush = 0;
        sharedOncePredicateUAPush = 0;
    }
}

#pragma mark -
#pragma mark Open APIs - UA Registration Tags APIs

- (void)addTagToCurrentDevice:(NSString *)tag {
    [self addTag:tag];
}

- (void)addTagsToCurrentDevice:(NSArray *)tags {
    [self addTags:tags];
}


- (void)removeTagFromCurrentDevice:(NSString *)tag {
    [self removeTags:[NSArray arrayWithObject:tag]];
}

- (void)removeTagsFromCurrentDevice:(NSArray *)tags {
    NSMutableArray *mutableTags = [NSMutableArray arrayWithArray:self.tags];
    [mutableTags removeObjectsInArray:tags];
    [[NSUserDefaults standardUserDefaults] setObject:mutableTags forKey:UAPushTagsSettingsKey];
}

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
    [[NSUserDefaults standardUserDefaults] setObject:mutableTags forKey:UAPushTagsSettingsKey];
}

- (void)setBadgeNumber:(NSInteger)badgeNumber {

    if ([[UIApplication sharedApplication] applicationIconBadgeNumber] == badgeNumber) {
        return;
    }

    UA_LDEBUG(@"Change Badge from %ld to %ld", (long)[[UIApplication sharedApplication] applicationIconBadgeNumber], (long)badgeNumber);

    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:badgeNumber];

    // if the device token has already been set then
    // we are post-registration and will need to make
    // an update call
    if (self.autobadgeEnabled && (self.deviceToken || self.channelID)) {
        UA_LDEBUG(@"Sending autobadge update to UA server.");
        [self updateRegistrationForcefully:YES];
    }
}

- (void)resetBadge {
    [self setBadgeNumber:0];
}

- (void)appReceivedRemoteNotification:(NSDictionary *)notification applicationState:(UIApplicationState)state {
    [self appReceivedRemoteNotification:notification applicationState:state fetchCompletionHandler:nil];
  }

- (void)appReceivedRemoteNotification:(NSDictionary *)notification
          applicationState:(UIApplicationState)state
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    UA_LINFO(@"Application received remote notification: %@", notification);

    [[UAirship shared].analytics handleNotification:notification inApplicationState:state];

    UASituation situation;
    switch(state) {
        case UIApplicationStateActive:
            UA_LTRACE(@"Received a notification when application state is UIApplicationStateActive");
            situation = UASituationForegroundPush;

            if (self.autobadgeEnabled) {
                [self updateBadgeFromNotification:notification];
            }
            break;

        case UIApplicationStateInactive:
            UA_LTRACE(@"Received a notification when application state is UIApplicationStateInactive");
            situation = UASituationLaunchedFromPush;
            self.launchNotification = notification;
            break;

        case UIApplicationStateBackground:
            UA_LTRACE(@"Received a notification when application state is UIApplicationStateBackground");
            situation = UASituationBackgroundPush;
            break;
    }

    // Create dictionary of actions inside the push notification
    NSMutableDictionary *actions = [self createActionsFromPayload:notification
                                                        situation:situation
                                                         metadata:@{UAActionMetadataPushPayloadKey:notification}];

    // Add incoming push action
    UAActionArguments *incomingPushArgs = [UAActionArguments argumentsWithValue:notification
                                                                  withSituation:situation];
    [actions setValue:incomingPushArgs forKey:kUAIncomingPushActionRegistryName];

    //Run the actions
    [UAActionRunner runActions:actions withCompletionHandler:^(UAActionResult *result) {
        if (completionHandler) {
            completionHandler((UIBackgroundFetchResult)[result fetchResult]);
        }
    }];
}

- (void)appReceivedActionWithIdentifier:(NSString *)identifier
                         notification:(NSDictionary *)notification
                     applicationState:(UIApplicationState)state
                    completionHandler:(void (^)())completionHandler {

    UA_LINFO(@"Received remote notification button interaction: %@ notification: %@", identifier, notification);

    [[UAirship shared].analytics handleNotification:notification inApplicationState:state];


    NSString *categoryId = notification[@"aps"][@"category"];
    NSSet *categories = [[UIApplication sharedApplication] currentUserNotificationSettings].categories;

    UIUserNotificationCategory *notificationCategory;
    UIUserNotificationAction *notificationAction;

    for (UIUserNotificationCategory *possibleCategory in categories) {
        if ([possibleCategory.identifier isEqualToString:categoryId]) {
            notificationCategory = possibleCategory;
            break;
        }
    }

    if (!notificationCategory) {
        UA_LERR(@"Unknown notification category identifier %@", categoryId);
        completionHandler();
        return;
    }

    NSMutableArray *possibleActions = [NSMutableArray arrayWithArray:[notificationCategory actionsForContext:UIUserNotificationActionContextMinimal]];
    [possibleActions addObjectsFromArray:[notificationCategory actionsForContext:UIUserNotificationActionContextDefault]];

    for (UIUserNotificationAction *possibleAction in possibleActions) {
        if ([possibleAction.identifier isEqualToString:identifier]) {
            notificationAction = possibleAction;
            break;
        }
    }

    if (!notificationAction) {
        UA_LERR(@"Unknown notification action identifier %@", identifier);
        completionHandler();
        return;
    }

    [[UAirship shared].analytics addEvent:[UAInteractiveNotificationEvent eventWithNotificationAction:notificationAction
                                                                                           categoryId:categoryId
                                                                                         notification:notification]];


    // Pull the action payload for the button identifier
    NSDictionary *actionsPayload = notification[kUANotificationActionKey][identifier];

    UASituation situation;
    if (notificationAction.activationMode == UIUserNotificationActivationModeBackground) {
        situation = UASituationBackgroundInteractiveButton;
    } else {
        situation = UASituationForegoundInteractiveButton;
    }

    // Create dictionary of actions inside the push notification
    NSMutableDictionary *actions = [self createActionsFromPayload:actionsPayload
                                                         situation:situation
                                                         metadata:@{UAActionMetadataUserNotificationActionIDKey:identifier,
                                                                    UAActionMetadataPushPayloadKey:notification}];

    // Add incoming push action
    UAActionArguments *incomingPushArgs = [UAActionArguments argumentsWithValue:notification
                                                                  withSituation:situation
                                                                       metadata:@{UAActionMetadataUserNotificationActionIDKey:identifier}];

    [actions setValue:incomingPushArgs forKey:kUAIncomingPushActionRegistryName];


    // Run the actions
    [UAActionRunner runActions:actions withCompletionHandler:^(UAActionResult *result) {
        if (completionHandler) {
            completionHandler();
        }
    }];
}

- (NSMutableDictionary *)createActionsFromPayload:(NSDictionary *)payload
                                        situation:(UASituation)situation
                                         metadata:(NSDictionary *)metadata{

    NSMutableDictionary *actions = [NSMutableDictionary dictionary];

    for (NSString *possibleActionName in payload) {
        UAActionArguments *args = [UAActionArguments argumentsWithValue:[payload valueForKey:possibleActionName]
                                                          withSituation:situation
                                                               metadata:metadata];

        [actions setValue:args forKey:possibleActionName];
    }

    return actions;
}

- (void)updateBadgeFromNotification:(NSDictionary *)notification {
    NSDictionary *apsDict = [notification objectForKey:@"aps"];
    NSString *badgeNumber = [apsDict valueForKey:@"badge"];
    if (badgeNumber) {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[badgeNumber intValue]];
    }
}

BOOL deferChannelCreationOnForeground = false;

#pragma mark -
#pragma mark UIApplication State Observation

- (void)applicationDidBecomeActive {

    // If this is the first run, skip creating the channel ID.
    if ([[NSUserDefaults standardUserDefaults] boolForKey:UAPushChannelCreationOnForeground]) {
        if (!self.channelID && self.deviceRegistrar.isUsingChannelRegistration) {
            UA_LTRACE(@"Channel ID not created, Updating registration.");
            [self updateRegistrationForcefully:NO];
        } else if (self.hasEnteredBackground) {
            UA_LTRACE(@"App transitioning from background to foreground. Updating registration.");
            [self updateRegistrationForcefully:NO];
        }
    }
}

- (void)applicationDidEnterBackground {
    self.hasEnteredBackground = YES;
    self.launchNotification = nil;

    // Set the UAPushChannelCreationOnForeground after first run
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushChannelCreationOnForeground];

    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:UIApplicationDidEnterBackgroundNotification 
                                                  object:[UIApplication sharedApplication]];

    // Create a channel if we do not have a channel id and we are using channel registration
    if (!self.channelID && self.deviceRegistrar.isUsingChannelRegistration) {
        [self updateRegistrationForcefully:NO];
    }
}

- (void)applicationBackgroundRefreshStatusChanged {
    UA_LTRACE(@"Background refresh status changed.");

    if ([UIApplication sharedApplication].backgroundRefreshStatus == UIBackgroundRefreshStatusAvailable) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotifications)]) {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        }
    } else {
        [self updateRegistration];
    }
}

#pragma mark -
#pragma mark UA Registration Methods

- (UAChannelRegistrationPayload *)createChannelPayload {
    [[NSUserDefaults standardUserDefaults] synchronize];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    payload.deviceID = [UAUtils deviceID];
    payload.userID = [UAUser defaultUser].username;
    payload.pushAddress = self.deviceToken;

    payload.optedIn = [self userPushNotificationsAllowed];
    payload.backgroundEnabled = [self backgroundPushNotificationsAllowed];

    payload.setTags = self.deviceTagsEnabled;
    payload.tags = self.deviceTagsEnabled ? [self.tags copy]: nil;

    payload.alias = self.alias;

    payload.badge = self.autobadgeEnabled ? [NSNumber numberWithInteger:[[UIApplication sharedApplication] applicationIconBadgeNumber]] : nil;

    if (self.timeZone.name && self.quietTimeEnabled) {
        payload.timeZone = self.timeZone.name;
        payload.quietTime = [self.quietTime copy];
    }

    return payload;
}

- (BOOL)userPushNotificationsAllowed {
    UIApplication *app = [UIApplication sharedApplication];

    if ([UIUserNotificationSettings class]) {
        return self.deviceToken
            && self.userPushNotificationsEnabled
            && [app currentUserNotificationSettings].types != UIUserNotificationTypeNone
            && app.isRegisteredForRemoteNotifications;

    } else {
        return self.deviceToken
            && self.userPushNotificationsEnabled
            && app.enabledRemoteNotificationTypes != UIRemoteNotificationTypeNone;
    }
}

- (BOOL)backgroundPushNotificationsAllowed {
    if (!self.deviceToken || !self.backgroundPushNotificationsEnabled || ![UAirship shared].remoteNotificationBackgroundModeEnabled) {
        return NO;
    }

    UIApplication *app = [UIApplication sharedApplication];
    if (app.backgroundRefreshStatus != UIBackgroundRefreshStatusAvailable) {
        return NO;
    }

    if ([UIUserNotificationSettings class]) {
        return app.isRegisteredForRemoteNotifications;
    } else {
        // iOS 7 requires user notifications.
        return [self userPushNotificationsEnabled];
    }
}

- (void)updateRegistrationForcefully:(BOOL)forcefully {
    // If we have a channel ID or we are not doing channel registration, cancel all requests.
    if (self.channelID || !self.deviceRegistrar.isUsingChannelRegistration) {
        [self.deviceRegistrar cancelAllRequests];
    }

    if (![self beginRegistrationBackgroundTask]) {
        UA_LDEBUG(@"Unable to perform registration, background task not granted.");
        return;
    }

    if (self.userPushNotificationsEnabled) {
        [self.deviceRegistrar registerWithChannelID:self.channelID
                                    channelLocation:self.channelLocation
                                        withPayload:[self createChannelPayload]
                                         forcefully:forcefully];
    } else {
        [self.deviceRegistrar registerPushDisabledWithChannelID:self.channelID
                                                channelLocation:self.channelLocation
                                                    withPayload:[self createChannelPayload]
                                                     forcefully:forcefully];
    }
}

- (void)updateRegistration {
    // APNS registration will cause a channel registration
    if (self.shouldUpdateAPNSRegistration) {
        UA_LDEBUG(@"APNS registration is out of date, updating.");
        [self updateAPNSRegistration];
        return;
    }

    if (self.userPushNotificationsEnabled && !self.channelID && self.deviceRegistrar.isUsingChannelRegistration) {
        UA_LDEBUG(@"Push is enabled but we have not yet tried to generate a channel ID. "
                  "Urban Airship registration will automatically run when the device token is registered,"
                  "the next time the app is backgrounded, or the next time the app is foregrounded.");
        return;
    }

    [self updateRegistrationForcefully:NO];
}


- (void)updateAPNSRegistration {
    UIApplication *application = [UIApplication sharedApplication];

    if ([UIUserNotificationSettings class]) {


        // Push Enabled
        if (self.userPushNotificationsEnabled) {
            NSMutableSet *categories = [NSMutableSet setWithSet:[UAUserNotificationCategories defaultCategoriesWithRequireAuth:self.requireAuthorizationForDefaultCategories]];
            [categories unionSet:self.userNotificationCategories];

            UA_LDEBUG(@"Registering for user notification types %ld.", (long)self.userNotificationTypes);
            [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:self.userNotificationTypes
                                                                                            categories:categories]];
        } else if (!self.allowUnregisteringUserNotificationTypes) {
            UA_LDEBUG(@"Skipping unregistered for user notification types.");
            [self updateRegistrationForcefully:NO];
        } else if ([application currentUserNotificationSettings].types != UIUserNotificationTypeNone) {
            UA_LDEBUG(@"Unregistering for user notification types.");
            [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeNone
                                                                                            categories:nil]];
        } else {
            UA_LDEBUG(@"Already unregistered for user notification types.");
            [self updateRegistrationForcefully:NO];
        }

    } else {
        if (self.userPushNotificationsEnabled) {
            UA_LDEBUG(@"Registering for remote notification types %ld.", (long)_notificationTypes);
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:_notificationTypes];
        } else {
            UA_LDEBUG(@"Unregistering for remote notifications.");
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeNone];

            // Registering for only UIRemoteNotificationTypeNone will not result in a
            // device token registration call. Instead update chanel registration directly.
            [self updateRegistrationForcefully:NO];
        }
    }

    self.shouldUpdateAPNSRegistration = NO;
}


//The new token to register, or nil if updating the existing token
- (void)appRegisteredForRemoteNotificationsWithDeviceToken:(NSData *)token {

    // Convert device deviceToken to a hex string
    NSMutableString *deviceToken = [NSMutableString stringWithCapacity:([token length] * 2)];
    const unsigned char *bytes = (const unsigned char *)[token bytes];

    for (NSUInteger i = 0; i < [token length]; i++) {
        [deviceToken appendFormat:@"%02X", bytes[i]];
    }

    self.deviceToken = [deviceToken lowercaseString];
    UA_LINFO(@"Application registered device token: %@", self.deviceToken);

    [[UAirship shared].analytics addEvent:[UAEventDeviceRegistration event]];

    BOOL inBackground = [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;

    // Only allow new registrations to happen in the background if we are creating a channel ID
    if (inBackground && (self.channelID || !self.deviceRegistrar.isUsingChannelRegistration)) {
        UA_LDEBUG(@"Skipping device registration. The app is currently backgrounded.");
    } else {
        [self updateRegistrationForcefully:NO];
    }
}

- (void)appRegisteredUserNotificationSettings {
    UA_LINFO(@"Application did register with user notification types %ld.", (unsigned long)[[UIApplication sharedApplication] currentUserNotificationSettings].types);
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

- (void)registrationSucceededWithPayload:(UAChannelRegistrationPayload *)payload {

    if (self.deviceRegistrar.isUsingChannelRegistration) {
        UA_LINFO(@"Channel registration updated successfully.");
    } else {
        UA_LINFO(@"Device registration updated successfully.");
    }

    id strongDelegate = self.registrationDelegate;
    if ([strongDelegate respondsToSelector:@selector(registrationSucceededForChannelID:deviceToken:)]) {
        [strongDelegate registrationSucceededForChannelID:self.channelID deviceToken:self.deviceToken];
    }

    // Register again if we are using old registration, and we have a deviceToken, and if the
    // device token does not match if push is enabled.
    if (!self.deviceRegistrar.isUsingChannelRegistration && self.deviceToken && self.userPushNotificationsEnabled != self.deviceRegistrar.isDeviceTokenRegistered) {
        [self updateRegistrationForcefully:NO];
    } else if (![payload isEqualToPayload:[self createChannelPayload]]) {
        [self updateRegistrationForcefully:NO];
    } else {
        [self endRegistrationBackgroundTask];
    }
}

- (void)registrationFailedWithPayload:(UAChannelRegistrationPayload *)payload {

    if (self.deviceRegistrar.isUsingChannelRegistration) {
        UA_LINFO(@"Channel registration failed.");
    } else {
        UA_LINFO(@"Device registration failed.");
    }

    id strongDelegate = self.registrationDelegate;
    if ([strongDelegate respondsToSelector:@selector(registrationFailed)]) {
        [strongDelegate registrationFailed];
    }

    [self endRegistrationBackgroundTask];
}

- (void)channelCreated:(NSString *)channelID channelLocation:(NSString *)channelLocation {
    if (channelID && channelLocation) {
        self.channelID = channelID;
        self.channelLocation = channelLocation;

        if (uaLogLevel >= UALogLevelError) {
            NSLog(@"Created channel with ID: %@", self.channelID);
        }
    } else {
        UA_LERR(@"Channel creation failed. Missing channelID: %@ or channelLocation: %@",
                channelID, channelLocation);
    }
}

#pragma mark -
#pragma mark Default Values

// Change the default push enabled value in the registered user defaults
- (void)setBackgroundPushNotificationsEnabledByDefault:(BOOL)enabled {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithBool:enabled] forKey:UABackgroundPushNotificationsEnabledKey];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    _backgroundPushNotificationsEnabledByDefault = enabled;
}

- (void)setUserPushNotificationsEnabledByDefault:(BOOL)enabled {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithBool:enabled] forKey:UAUserPushNotificationsEnabledKey];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    _userPushNotificationsEnabledByDefault = enabled;
}

- (BOOL)beginRegistrationBackgroundTask {
    if (self.registrationBackgroundTask == UIBackgroundTaskInvalid) {
        self.registrationBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [self.deviceRegistrar cancelAllRequests];
            [[UIApplication sharedApplication] endBackgroundTask:self.registrationBackgroundTask];
            self.registrationBackgroundTask = UIBackgroundTaskInvalid;
        }];
    }

    return (BOOL) self.registrationBackgroundTask != UIBackgroundTaskInvalid;
}

- (void)endRegistrationBackgroundTask {
    if (self.registrationBackgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.registrationBackgroundTask];
        self.registrationBackgroundTask = UIBackgroundTaskInvalid;
    }
}

- (void)migratePushSettings {

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    if ([userDefaults boolForKey:UAPushEnabledSettingsMigratedKey]) {
        // Already migrated
        return;
    }

    // Migrate userNotificationEnabled setting to YES if we are currently registered for notification types
    if (![userDefaults objectForKey:UAUserPushNotificationsEnabledKey]) {

        // If the previous pushEnabled was set
        if ([userDefaults objectForKey:UAPushEnabledKey]) {
            BOOL previousValue = [[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledKey];
            UA_LDEBUG(@"Migrating userPushNotificationEnabled to %@ from previous pushEnabledValue.", previousValue ? @"YES" : @"NO");
            [userDefaults setBool:previousValue forKey:UAUserPushNotificationsEnabledKey];
            [userDefaults removeObjectForKey:UAPushEnabledKey];
        } else {
            BOOL registeredForUserNotificationTypes;
            if ([UIUserNotificationSettings class]) {
                registeredForUserNotificationTypes = [[UIApplication sharedApplication] currentUserNotificationSettings].types != UIUserNotificationTypeNone;
            } else {
                registeredForUserNotificationTypes =[UIApplication sharedApplication].enabledRemoteNotificationTypes != UIRemoteNotificationTypeNone;
            }

            if (registeredForUserNotificationTypes) {
                UA_LDEBUG(@"Migrating userPushNotificationEnabled to YES because application has user notification types.");
                [userDefaults setBool:YES forKey:UAUserPushNotificationsEnabledKey];
            }
        }
    }

    [userDefaults setBool:YES forKey:UAPushEnabledSettingsMigratedKey];
}

- (UIUserNotificationType)currentEnabledNotificationTypes {
    if (![UAPush shared].userPushNotificationsEnabled) {
        return UIUserNotificationTypeNone;
    }

    if ([UIUserNotificationSettings class]) {
        return [[UIApplication sharedApplication] currentUserNotificationSettings].types;
    } else {
        UIUserNotificationType all = UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound;
        return [UIApplication sharedApplication].enabledRemoteNotificationTypes & all;
    }
}


@end
