/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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
#import "UANamedUser+Internal.h"
#import "UAirship+Internal.h"
#import "UAAnalytics.h"
#import "UADeviceRegistrationEvent+Internal.h"

#import "UAUtils.h"
#import "UAActionRegistry+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAUser.h"
#import "UAInteractiveNotificationEvent+Internal.h"
#import "UAUserNotificationCategories+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAConfig.h"
#import "UAUserNotificationCategory+Internal.h"
#import "UAInboxUtils.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UATagUtils.h"
#import "UAHTTPConnection+Internal.h"

#define kUANotificationActionKey @"com.urbanairship.interactive_actions"

NSString *const UAUserPushNotificationsEnabledKey = @"UAUserPushNotificationsEnabled";
NSString *const UABackgroundPushNotificationsEnabledKey = @"UABackgroundPushNotificationsEnabled";
NSString *const UAPushTokenRegistrationEnabledKey = @"UAPushTokenRegistrationEnabled";

NSString *const UAPushAliasSettingsKey = @"UAPushAlias";
NSString *const UAPushTagsSettingsKey = @"UAPushTags";
NSString *const UAPushBadgeSettingsKey = @"UAPushBadge";
NSString *const UAPushChannelIDKey = @"UAChannelID";
NSString *const UAPushChannelLocationKey = @"UAChannelLocation";
NSString *const UAPushDeviceTokenKey = @"UADeviceToken";

NSString *const UAPushQuietTimeSettingsKey = @"UAPushQuietTime";
NSString *const UAPushQuietTimeEnabledSettingsKey = @"UAPushQuietTimeEnabled";
NSString *const UAPushTimeZoneSettingsKey = @"UAPushTimeZone";

NSString *const UAPushChannelCreationOnForeground = @"UAPushChannelCreationOnForeground";
NSString *const UAPushEnabledSettingsMigratedKey = @"UAPushEnabledSettingsMigrated";

// Old push enabled key
NSString *const UAPushEnabledKey = @"UAPushEnabled";

// Quiet time dictionary keys
NSString *const UAPushQuietTimeStartKey = @"start";
NSString *const UAPushQuietTimeEndKey = @"end";

// Channel tag group keys
NSString *const UAPushAddTagGroupsSettingsKey = @"UAPushAddTagGroups";
NSString *const UAPushRemoveTagGroupsSettingsKey = @"UAPushRemoveTagGroups";

// The default device tag group.
NSString *const UAPushDefaultDeviceTagGroup = @"device";

@implementation UAPush

// Both getter and setter are custom here, so give the compiler a hand with the synthesizing
@synthesize requireSettingsAppToDisableUserNotifications = _requireSettingsAppToDisableUserNotifications;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;

        self.channelTagRegistrationEnabled = YES;
        self.requireAuthorizationForDefaultCategories = YES;
        self.backgroundPushNotificationsEnabledByDefault = YES;
        self.pushTokenRegistrationEnabled = YES;

        // Require use of the settings app to change push settings
        // but allow the app to unregister to keep things in sync
        self.requireSettingsAppToDisableUserNotifications = YES;
        self.allowUnregisteringUserNotificationTypes = YES;

        self.userNotificationTypes = UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound;
        self.allUserNotificationCategories = [UAUserNotificationCategories defaultCategoriesWithRequireAuth:self.requireAuthorizationForDefaultCategories];
        self.registrationBackgroundTask = UIBackgroundTaskInvalid;
        self.namedUser = [[UANamedUser alloc] initWithConfig:config dataStore:dataStore];

        self.channelRegistrar = [UAChannelRegistrar channelRegistrarWithConfig:config];
        self.channelRegistrar.delegate = self;

        self.tagGroupsAPIClient = [UATagGroupsAPIClient clientWithConfig:config];

        // Check config to see if user wants to delay channel creation
        // If channel ID is nil then channelCreationEnabled
        self.channelCreationEnabled = self.channelID || !config.channelCreationDelayEnabled;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:[UIApplication sharedApplication]];

        // Only for observing the first call to app background
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationBackgroundRefreshStatusChanged)
                                                     name:UIApplicationBackgroundRefreshStatusDidChangeNotification
                                                   object:[UIApplication sharedApplication]];


        // Do not remove migratePushSettings call from init. It needs to be run
        // prior to allowing the application to set defaults.
        [self migratePushSettings];

        // Log the channel ID at error level, but without logging
        // it as an error.
        if (self.channelID && uaLogLevel >= UALogLevelError) {
            NSLog(@"Channel ID: %@", self.channelID);
        }

        // Register for remote notifications on iOS8 right away if the background mode is enabled. This does not prompt for
        // permissions to show notifications, but starts the device token registration.
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotifications)] && [UAirship shared].remoteNotificationBackgroundModeEnabled) {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        }

        // Update the named user if necessary.
        [self.namedUser update];
    }

    return self;
}

+ (instancetype)pushWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAPush alloc] initWithConfig:config dataStore:dataStore];
}

#pragma mark -
#pragma mark Device Token Get/Set Methods

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

- (void)setChannelID:(NSString *)channelID {
    [self.dataStore setValue:channelID forKey:UAPushChannelIDKey];
    // Log the channel ID at error level, but without logging
    // it as an error.
    if (uaLogLevel >= UALogLevelError) {
        NSLog(@"Channel ID: %@", channelID);
    }
}

- (NSString *)channelID {
    // Get the channel location from data store instead of
    // the channelLocation property, because that may cause an infinite loop.
    if ([self.dataStore stringForKey:UAPushChannelLocationKey]) {
        return [self.dataStore stringForKey:UAPushChannelIDKey];
    } else {
        return nil;
    }
}

- (void)setChannelLocation:(NSString *)channelLocation {
    [self.dataStore setValue:channelLocation forKey:UAPushChannelLocationKey];
}

- (NSString *)channelLocation {
    // Get the channel ID from data store instead of
    // the channelID property, because that may cause an infinite loop.
    if ([self.dataStore stringForKey:UAPushChannelIDKey]) {
        return [self.dataStore stringForKey:UAPushChannelLocationKey];
    } else {
        return nil;
    }
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

    NSArray *normalizedTags = [UATagUtils normalizeTags:currentTags];

    //sync tags to prevent the tags property invocation from constantly logging tag set failure
    if ([currentTags count] != [normalizedTags count]) {
        [self setTags:normalizedTags];
    }

    return currentTags;
}

- (void)setTags:(NSArray *)tags {
    [self.dataStore setObject:[UATagUtils normalizeTags:tags] forKey:UAPushTagsSettingsKey];
}

- (NSDictionary *)pendingAddTags {
    return [self.dataStore objectForKey:UAPushAddTagGroupsSettingsKey];
}

- (void)setPendingAddTags:(NSDictionary *)addTagGroups {
    [self.dataStore setObject:addTagGroups forKey:UAPushAddTagGroupsSettingsKey];
}

- (NSDictionary *)pendingRemoveTags {
    return [self.dataStore objectForKey:UAPushRemoveTagGroupsSettingsKey];
}

- (void)setPendingRemoveTags:(NSDictionary *)removeTagGroups {
    [self.dataStore setObject:removeTagGroups forKey:UAPushRemoveTagGroupsSettingsKey];
}

- (void)enableChannelCreation {
    if (!self.channelCreationEnabled) {
        self.channelCreationEnabled = YES;
        [self updateRegistration];
    }
}

- (BOOL)userPushNotificationsEnabled {
    if (![self.dataStore objectForKey:UAUserPushNotificationsEnabledKey]) {
        return self.userPushNotificationsEnabledByDefault;
    }

    return [self.dataStore boolForKey:UAUserPushNotificationsEnabledKey];
}

- (void)setUserPushNotificationsEnabled:(BOOL)enabled {
    BOOL previousValue = self.userPushNotificationsEnabled;

    // Do not allow disabling if the settings app is required,
    // requireSettingsAppToDisableUserNotifications can only return YES for iOS 8+
    if (!enabled && self.requireSettingsAppToDisableUserNotifications) {
        UA_LWARN(@"User notifications must be disabled via the iOS Settings app.");
        return;
    }

    [self.dataStore setBool:enabled forKey:UAUserPushNotificationsEnabledKey];

    if (enabled != previousValue) {
        self.shouldUpdateAPNSRegistration = YES;
        [self updateRegistration];
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
    return [self.dataStore boolForKey:UAPushTokenRegistrationEnabledKey];
}

- (void)setPushTokenRegistrationEnabled:(BOOL)enabled {
    BOOL previousValue = self.pushTokenRegistrationEnabled;
    [self.dataStore setBool:enabled forKey:UAPushTokenRegistrationEnabledKey];

    if (enabled != previousValue) {
        [self updateRegistration];
    }
}

- (BOOL)shouldUseUIUserNotificationCategories {
    return [UIUserNotificationCategory class] != nil;
}

/**
 * Converts UAUserNotificationCategory to UIUserNotificationCategory on iOS 8
 */
- (NSSet *)normalizeCategories:(NSSet *)categories {
    if ([self shouldUseUIUserNotificationCategories]) {
        NSMutableSet *newSet = [NSMutableSet set];
        for (id category in categories) {
            if ([category isKindOfClass:[UAUserNotificationCategory class]]) {
                UIUserNotificationCategory *uiCategory = [category asUIUserNotificationCategory];
                [newSet addObject:uiCategory];
            } else {
                [newSet addObject:category];
            }
        }

        return newSet;
    }
    return categories;
}

- (void)setUserNotificationCategories:(NSSet *)categories {

    categories = [self normalizeCategories:categories];

    _userNotificationCategories = [categories filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        if ([self shouldUseUIUserNotificationCategories] && ![evaluatedObject isKindOfClass:[UIUserNotificationCategory class]]) {
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

    [self updateAllUserNotificationCategories];
}

- (void)setRequireAuthorizationForDefaultCategories:(BOOL)requireAuthorizationForDefaultCategories {
    _requireAuthorizationForDefaultCategories = requireAuthorizationForDefaultCategories;
    [self updateAllUserNotificationCategories];
}

- (void)setAllUserNotificationCategories:(NSSet *)allUserNotificationCategories {
    NSSet *normalizedCategories = [self normalizeCategories:allUserNotificationCategories];
    _allUserNotificationCategories = normalizedCategories;
}

/**
 * Caches a set of user notification categories based on the the current developer-supplied set and our default set with authorization settings.
 * Call this method whenever either changes to update the cache.
 */
- (void)updateAllUserNotificationCategories {
    NSMutableSet *allCategories = [NSMutableSet setWithSet:[UAUserNotificationCategories defaultCategoriesWithRequireAuth:self.requireAuthorizationForDefaultCategories]];
    [allCategories unionSet:self.userNotificationCategories];
    self.allUserNotificationCategories = allCategories;
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

- (void)setUserNotificationTypes:(UIUserNotificationType)userNotificationTypes {
    if (userNotificationTypes == UIUserNotificationTypeNone) {
        UA_LWARN(@"Registering for UIUserNotificationTypeNone may disable the ability to register for other types without restarting the device first.");
    }

    _userNotificationTypes = userNotificationTypes;

    self.shouldUpdateAPNSRegistration = YES;
}

- (void)setRequireSettingsAppToDisableUserNotifications:(BOOL)requireSettingsAppToDisableUserNotifications {
    if (!requireSettingsAppToDisableUserNotifications) {
        UA_LWARN(@"Allowing the application to disable notifications in iOS 8+ will prevent your application from properly "
                 "opt-ing out of notifications that include \"content-available\" background components in "
                 "notifications that also include a user-visible component. Instead, direct users to the iOS "
                 "settings app using the UIApplicationOpenSettingsURLString URL constant.");
    }
    _requireSettingsAppToDisableUserNotifications = requireSettingsAppToDisableUserNotifications;
}

- (BOOL)requireSettingsAppToDisableUserNotifications {
    return _requireSettingsAppToDisableUserNotifications;
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

    NSArray *normalizedTags = [UATagUtils normalizeTags:tags];

    if (![UATagUtils isValid:normalizedTags group:tagGroupID]) {
        return;
    }

    // Check if remove tags contain any tags to add.
    [self setPendingRemoveTags:[UATagUtils removePendingTags:normalizedTags group:tagGroupID pendingTagsDictionary:self.pendingRemoveTags]];

    // Combine the tags to be added with pendingAddTags.
    [self setPendingAddTags:[UATagUtils addPendingTags:normalizedTags group:tagGroupID pendingTagsDictionary:self.pendingAddTags]];
}

- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {

    if (self.channelTagRegistrationEnabled && [UAPushDefaultDeviceTagGroup isEqualToString:tagGroupID]) {
        UA_LERR(@"Unable to remove tags %@ from device tag group when channelTagRegistrationEnabled is true.", [tags description]);
        return;
    }

    NSArray *normalizedTags = [UATagUtils normalizeTags:tags];

    if (![UATagUtils isValid:normalizedTags group:tagGroupID]) {
        return;
    }

    // Check if add tags contain any tags to be removed.
    [self setPendingAddTags:[UATagUtils removePendingTags:normalizedTags group:tagGroupID pendingTagsDictionary:self.pendingAddTags]];

    // Combine the tags to be removed with pendingRemoveTags.
    [self setPendingRemoveTags:[UATagUtils addPendingTags:normalizedTags group:tagGroupID pendingTagsDictionary:self.pendingRemoveTags]];
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
        [self updateChannelRegistrationForcefully:YES];
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

            if ([UAUtils isBackgroundPush:notification]) {
                situation = UASituationBackgroundPush;
            } else {
                situation = UASituationLaunchedFromPush;
                self.launchNotification = notification;
            }
            break;

        case UIApplicationStateBackground:
            UA_LTRACE(@"Received a notification when application state is UIApplicationStateBackground");
            situation = UASituationBackgroundPush;
            break;
    }


    // Create the action payload
    NSMutableDictionary *actionsPayload = [NSMutableDictionary dictionaryWithDictionary:notification];

    // Add incoming push action
    actionsPayload[kUAIncomingPushActionRegistryName] = notification;

    // If we have a messageID make sure we run an inbox action
    NSString *messageID = [UAInboxUtils inboxMessageIDFromNotification:notification];
    if (messageID) {
        NSSet *inboxActionNames = [NSSet setWithArray:@[kUADisplayInboxActionDefaultRegistryAlias,
                                                        kUADisplayInboxActionDefaultRegistryName,
                                                        kUAOverlayInboxMessageActionDefaultRegistryAlias,
                                                        kUAOverlayInboxMessageActionDefaultRegistryName]];

        NSSet *actionNames = [NSSet setWithArray:[actionsPayload allKeys]];

        if (![actionNames intersectsSet:inboxActionNames]) {
            actionsPayload[kUADisplayInboxActionDefaultRegistryAlias] = messageID;
        }
    }

    // Action metadata
    NSDictionary *metadata = @{ UAActionMetadataPushPayloadKey:notification };

    // Run the actions
    [UAActionRunner runActionsWithActionValues:actionsPayload
                                     situation:situation
                                      metadata:metadata
                             completionHandler:^(UAActionResult *result) {
                                 if (completionHandler) {
                                     completionHandler((UIBackgroundFetchResult)[result fetchResult]);
                                 }
                             }];
}

- (void)appReceivedActionWithIdentifier:(NSString *)identifier
                           notification:(NSDictionary *)notification
                       applicationState:(UIApplicationState)state
                      completionHandler:(void (^)())completionHandler {

    [self appReceivedActionWithIdentifier:identifier notification:notification responseInfo:nil applicationState:state completionHandler:completionHandler];

}

- (void)appReceivedActionWithIdentifier:(NSString *)identifier
                           notification:(NSDictionary *)notification
                           responseInfo:(NSDictionary *)responseInfo
                       applicationState:(UIApplicationState)state
                      completionHandler:(void (^)())completionHandler {

    if (responseInfo) {
        UA_LINFO(@"Received remote notification interaction: %@ notification: %@, response info: %@", identifier, notification, responseInfo);
    } else {
        UA_LINFO(@"Received remote notification interaction: %@ notification: %@", identifier, notification);
    }

    [[UAirship shared].analytics handleNotification:notification inApplicationState:state];

    NSString *categoryID = notification[@"aps"][@"category"];
    NSSet *categories = [[UIApplication sharedApplication] currentUserNotificationSettings].categories;

    UIUserNotificationCategory *notificationCategory;
    UIUserNotificationAction *notificationAction;

    for (UIUserNotificationCategory *possibleCategory in categories) {
        if ([possibleCategory.identifier isEqualToString:categoryID]) {
            notificationCategory = possibleCategory;
            break;
        }
    }

    if (!notificationCategory) {
        UA_LERR(@"Unknown notification category identifier %@", categoryID);
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
                                                                                           categoryID:categoryID
                                                                                         notification:notification
                                                                                         responseInfo:responseInfo]];

    NSMutableDictionary *actionsPayload = [NSMutableDictionary dictionaryWithDictionary:notification[kUANotificationActionKey][identifier]];

    // Add incoming push action
    actionsPayload[kUAIncomingPushActionRegistryName] = notification;

    // Situation for the actions
    UASituation situation = notificationAction.activationMode == UIUserNotificationActivationModeBackground ?
    UASituationBackgroundInteractiveButton : UASituationForegroundInteractiveButton;

    // Action metadata
    NSMutableDictionary *metadata = [@{ UAActionMetadataUserNotificationActionIDKey: identifier,
                                                     UAActionMetadataPushPayloadKey: notification } mutableCopy];
    // Add the text response to the metadata if it's available
    [metadata setValue:responseInfo forKey:UAActionMetadataResponseInfoKey];

    // Run the actions
    [UAActionRunner runActionsWithActionValues:actionsPayload
                                     situation:situation
                                      metadata:metadata
                             completionHandler:^(UAActionResult *result) {
                                 if (completionHandler) {
                                     completionHandler();
                                 }
                             }];

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

    if ([self.dataStore boolForKey:UAPushChannelCreationOnForeground]) {
        UA_LTRACE(@"Application did become active. Updating registration.");
        [self updateChannelRegistrationForcefully:NO];
    }
}

- (void)applicationDidEnterBackground {
    self.launchNotification = nil;

    // Set the UAPushChannelCreationOnForeground after first run
    [self.dataStore setBool:YES forKey:UAPushChannelCreationOnForeground];

    // Create a channel if we do not have a channel ID
    if (!self.channelID) {
        [self updateChannelRegistrationForcefully:NO];
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
    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    payload.deviceID = [UAUtils deviceID];
    payload.userID = [UAirship inboxUser].username;

    if (self.pushTokenRegistrationEnabled) {
        payload.pushAddress = self.deviceToken;
    }

    payload.optedIn = [self userPushNotificationsAllowed];
    payload.backgroundEnabled = [self backgroundPushNotificationsAllowed];

    payload.setTags = self.channelTagRegistrationEnabled;
    payload.tags = self.channelTagRegistrationEnabled ? [self.tags copy]: nil;

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

    return self.deviceToken
    && self.userPushNotificationsEnabled
    && [app currentUserNotificationSettings].types != UIUserNotificationTypeNone
    && app.isRegisteredForRemoteNotifications
    && self.pushTokenRegistrationEnabled;
}

- (BOOL)backgroundPushNotificationsAllowed {
    if (!self.deviceToken
        || !self.backgroundPushNotificationsEnabled
        || ![UAirship shared].remoteNotificationBackgroundModeEnabled
        || !self.pushTokenRegistrationEnabled) {
        return NO;
    }

    UIApplication *app = [UIApplication sharedApplication];
    if (app.backgroundRefreshStatus != UIBackgroundRefreshStatusAvailable) {
        return NO;
    }

    return app.isRegisteredForRemoteNotifications;
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
    // Only cancel in flight requests if the channel is already created
    if (!self.channelCreationEnabled) {
        UA_LDEBUG(@"Channel registration is currently disabled.");
        return;
    }

    if (![self beginRegistrationBackgroundTask]) {
        UA_LDEBUG(@"Unable to perform registration, background task not granted.");
        return;
    }

    [self.channelRegistrar registerWithChannelID:self.channelID
                                 channelLocation:self.channelLocation
                                     withPayload:[self createChannelPayload]
                                      forcefully:forcefully];
}

- (void)resetPendingTagsWithAddTags:(NSMutableDictionary *)addTags removeTags:(NSMutableDictionary *)removeTags {
    // If there are new pendingRemoveTags since last request,
    // check if addTags contain any tags to be removed.
    if (self.pendingRemoveTags.count) {
        for (NSString *group in self.pendingRemoveTags) {
            if (group && addTags[group]) {
                NSArray *pendingRemoveTagsArray = [NSArray arrayWithArray:self.pendingRemoveTags[group]];
                [addTags removeObjectsForKeys:pendingRemoveTagsArray];
            }
        }
    }

    // If there are new pendingAddTags since last request,
    // check if removeTags contain any tags to add.
    if (self.pendingAddTags.count) {
        for (NSString *group in self.pendingAddTags) {
            if (group && removeTags[group]) {
                NSArray *pendingAddTagsArray = [NSArray arrayWithArray:self.pendingAddTags[group]];
                [removeTags removeObjectsForKeys:pendingAddTagsArray];
            }
        }
    }

    // If there are new pendingRemoveTags since last request,
    // combine the new pendingRemoveTags with removeTags.
    if (self.pendingRemoveTags.count) {
        [removeTags addEntriesFromDictionary:self.pendingRemoveTags];
    }

    // If there are new pendingAddTags since last request,
    // combine the new pendingAddTags with addTags.
    if (self.pendingAddTags.count) {
        [addTags addEntriesFromDictionary:self.pendingAddTags];
    }

    // Set self.pendingAddTags as addTags
    self.pendingAddTags = addTags;

    // Set self.pendingRemoveTags as removeTags
    self.pendingRemoveTags = removeTags;
}

- (void)updateChannelTagGroups {
    if (!self.pendingAddTags.count && !self.pendingRemoveTags.count) {
        return;
    }

    // Get a copy of the current add and remove pending tags
    NSMutableDictionary *addTags = [self.pendingAddTags mutableCopy];
    NSMutableDictionary *removeTags = [self.pendingRemoveTags mutableCopy];

    // On failure or background task expiration we need to reset the pending tags
    void (^resetPendingTags)() = ^{
        [self resetPendingTagsWithAddTags:addTags removeTags:removeTags];
    };

    __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        UA_LTRACE(@"Tag groups background task expired.");
        if (resetPendingTags) {
            resetPendingTags();
        }
        @synchronized(self) {
            [self.tagGroupsAPIClient cancelAllRequests];
        }
        if (backgroundTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
            backgroundTask = UIBackgroundTaskInvalid;
        }
    }];

    if (backgroundTask == UIBackgroundTaskInvalid) {
        UA_LTRACE("Background task unavailable, skipping tag groups update.");
        return;
    }

    // Clear the add and remove pending tags
    self.pendingAddTags = nil;
    self.pendingRemoveTags = nil;

    UATagGroupsAPIClientSuccessBlock successBlock = ^{
        // End background task
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
    };

    UATagGroupsAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        if (status != 400 && status != 403) {
            resetPendingTags();
        }

        // End background task
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
    };

    [self.tagGroupsAPIClient updateChannelTags:self.channelID
                                           add:addTags
                                        remove:removeTags
                                     onSuccess:successBlock
                                     onFailure:failureBlock];
}

- (void)updateAPNSRegistration {
    UIApplication *application = [UIApplication sharedApplication];

    // Push Enabled
    if (self.userPushNotificationsEnabled) {

        // Store the default value if as the user notificaiton enabled value
        if (![self.dataStore objectForKey:UAUserPushNotificationsEnabledKey]) {
            [self.dataStore setBool:YES forKey:UAUserPushNotificationsEnabledKey];
        }

        NSSet *categories = [self allUserNotificationCategories];
        UA_LDEBUG(@"Registering for user notification types %ld.", (long)self.userNotificationTypes);
        [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:self.userNotificationTypes
                                                                                        categories:categories]];
    } else if (!self.allowUnregisteringUserNotificationTypes) {
        UA_LDEBUG(@"Skipping unregistered for user notification types.");
        [self updateChannelRegistrationForcefully:NO];
    } else if ([application currentUserNotificationSettings].types != UIUserNotificationTypeNone) {
        UA_LDEBUG(@"Unregistering for user notification types.");

        // This is likely a case where an SDK 5.0 user has been updated to SDK 6.0, so notify the developer.
        if (self.requireSettingsAppToDisableUserNotifications) {
            UA_LDEBUG(@"To re-register for push, userPushNotificationsEnabled must be set to YES and the user must use the iOS Settings app to enable notifications.");
        }
        [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeNone
                                                                                        categories:nil]];
    } else {
        UA_LDEBUG(@"Already unregistered for user notification types. To re-register, set userPushNotificationsEnabled to YES and/or modify iOS Settings.");
        [self updateChannelRegistrationForcefully:NO];
    }

    self.shouldUpdateAPNSRegistration = NO;
}


// The new token to register, or nil if updating the existing token
- (void)appRegisteredForRemoteNotificationsWithDeviceToken:(NSData *)token {
    // Convert device deviceToken to a hex string
    NSMutableString *deviceToken = [NSMutableString stringWithCapacity:([token length] * 2)];
    const unsigned char *bytes = (const unsigned char *)[token bytes];

    for (NSUInteger i = 0; i < [token length]; i++) {
        [deviceToken appendFormat:@"%02X", bytes[i]];
    }

    self.deviceToken = [deviceToken lowercaseString];
    UA_LINFO(@"Application registered device token: %@", self.deviceToken);

    [[UAirship shared].analytics addEvent:[UADeviceRegistrationEvent event]];

    BOOL inBackground = [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;

    // Only allow new registrations to happen in the background if we are creating a channel ID
    if (inBackground && self.channelID) {
        UA_LDEBUG(@"Skipping device registration. The app is currently backgrounded.");
    } else {
        [self updateChannelRegistrationForcefully:NO];
    }
}

- (void)appRegisteredUserNotificationSettings {
    UA_LINFO(@"Application did register with user notification types %ld.", (unsigned long)[[UIApplication sharedApplication] currentUserNotificationSettings].types);
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

- (void)registrationSucceededWithPayload:(UAChannelRegistrationPayload *)payload {

    UA_LINFO(@"Channel registration updated successfully.");

    id strongDelegate = self.registrationDelegate;
    if ([strongDelegate respondsToSelector:@selector(registrationSucceededForChannelID:deviceToken:)]) {
        [strongDelegate registrationSucceededForChannelID:self.channelID deviceToken:self.deviceToken];
    }

    if (![payload isEqualToPayload:[self createChannelPayload]]) {
        [self updateChannelRegistrationForcefully:NO];
    } else {
        [self endRegistrationBackgroundTask];
    }
}

- (void)registrationFailedWithPayload:(UAChannelRegistrationPayload *)payload {

    UA_LINFO(@"Channel registration failed.");

    id strongDelegate = self.registrationDelegate;
    if ([strongDelegate respondsToSelector:@selector(registrationFailed)]) {
        [strongDelegate registrationFailed];
    }

    [self endRegistrationBackgroundTask];
}

- (void)channelCreated:(NSString *)channelID
       channelLocation:(NSString *)channelLocation
              existing:(BOOL)existing {

    if (channelID && channelLocation) {
        // WARNING: Order matters here. Some things observe channelID being changed,
        // and if we do not have a channel location set, the channelID will return nil.
        self.channelLocation = channelLocation;
        self.channelID = channelID;

        if (uaLogLevel >= UALogLevelError) {
            NSLog(@"Created channel with ID: %@", self.channelID);
        }

        // If this channel previously existed, a named user may be associated to it.
        if (existing && [UAirship shared].config.clearNamedUserOnAppRestore) {
            [self.namedUser disassociateNamedUserIfNil];
        } else {
            // Once we get a channel, update the named user if necessary.
            [self.namedUser update];
        }

    } else {
        UA_LERR(@"Channel creation failed. Missing channelID: %@ or channelLocation: %@",
                channelID, channelLocation);
    }
}

-(void)channelPreviouslyExisted {
    // If this channel previously existed, a named user may be associated to it.
    if ([UAirship shared].config.clearNamedUserOnAppRestore) {
        [self.namedUser disassociateNamedUserIfNil];
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

- (BOOL)beginRegistrationBackgroundTask {
    if (self.registrationBackgroundTask == UIBackgroundTaskInvalid) {
        self.registrationBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [self.channelRegistrar cancelAllRequests];
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
            UA_LDEBUG(@"Migrating userPushNotificationEnabled to %@ from previous pushEnabledValue.", previousValue ? @"YES" : @"NO");
            [self.dataStore setBool:previousValue forKey:UAUserPushNotificationsEnabledKey];
            [self.dataStore removeObjectForKey:UAPushEnabledKey];
        } else {
            BOOL registeredForUserNotificationTypes;

            registeredForUserNotificationTypes = [[UIApplication sharedApplication] currentUserNotificationSettings].types != UIUserNotificationTypeNone;

            if (registeredForUserNotificationTypes) {
                UA_LDEBUG(@"Migrating userPushNotificationEnabled to YES because application has user notification types.");
                [self.dataStore setBool:YES forKey:UAUserPushNotificationsEnabledKey];
            }
        }
    }

    [self.dataStore setBool:YES forKey:UAPushEnabledSettingsMigratedKey];
}

- (UIUserNotificationType)currentEnabledNotificationTypes {
    if (!self.userPushNotificationsEnabled) {
        return UIUserNotificationTypeNone;
    }

    return [[UIApplication sharedApplication] currentUserNotificationSettings].types;
}

@end
