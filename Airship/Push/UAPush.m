/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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
#import "UAEvent.h"
#import "UADeviceRegistrationPayload.h"
#import "UAPushNotificationHandler.h"
#import "UAUtils.h"
#import "UAActionRegistrar+Internal.h"
#import "UAPushActionArguments.h"
#import "UAActionRunner.h"
#import "UAChannelRegistrationPayload.h"
#import "UAUser.h"

UAPushSettingsKey *const UAPushEnabledSettingsKey = @"UAPushEnabled";
UAPushSettingsKey *const UAPushAliasSettingsKey = @"UAPushAlias";
UAPushSettingsKey *const UAPushTagsSettingsKey = @"UAPushTags";
UAPushSettingsKey *const UAPushBadgeSettingsKey = @"UAPushBadge";
UAPushSettingsKey *const UAPushChannelIDKey = @"UAChannelID";

UAPushSettingsKey *const UAPushQuietTimeSettingsKey = @"UAPushQuietTime";
UAPushSettingsKey *const UAPushQuietTimeEnabledSettingsKey = @"UAPushQuietTimeEnabled";
UAPushSettingsKey *const UAPushTimeZoneSettingsKey = @"UAPushTimeZone";
UAPushSettingsKey *const UAPushDeviceCanEditTagsKey = @"UAPushDeviceCanEditTags";

UAPushUserInfoKey *const UAPushUserInfoRegistration = @"Registration";
UAPushUserInfoKey *const UAPushUserInfoPushEnabled = @"PushEnabled";

UAPushUserInfoKey *const UAPushChannelCreationOnForeground = @"UAPushChannelCreationOnForeground";


NSString *const UAPushQuietTimeStartKey = @"start";
NSString *const UAPushQuietTimeEndKey = @"end";

@implementation UAPush 

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
SINGLETON_IMPLEMENTATION(UAPush)
#pragma clang diagnostic pop

static Class _uiClass;

// Self refers to the class at this point in execution
// The self == check is because that a sublcass that does not implement this method
// forwards it up the chain. It will only be called once by this class
+ (void)initialize {
    if (self == [UAPush class]) {
        [self registerNSUserDefaults];
    }
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init {
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

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(channelIDCreated:)
                                                     name:UAChannelCreatedNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(registrationFinished)
                                                     name:UADeviceRegistrationFinishedNotification
                                                   object:nil];

        self.deviceRegistrar = [[UADeviceRegistrar alloc] init];
        self.deviceTagsEnabled = YES;
        self.notificationTypes = (UIRemoteNotificationTypeAlert
                                  |UIRemoteNotificationTypeBadge
                                  |UIRemoteNotificationTypeSound);

        self.registrationBackgroundTask = UIBackgroundTaskInvalid;
    }
    
    return self;
}

#pragma mark -
#pragma mark Device Token Get/Set Methods

- (void)setDeviceToken:(NSString *)deviceToken {
    if (deviceToken == nil) {
        _deviceToken = deviceToken;
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

    _deviceToken = deviceToken;

    // Log the device token at error level, but without logging
    // it as an error.
    if (uaLogLevel >= UALogLevelError) {
        NSLog(@"Device token: %@", deviceToken);
    }
}

#pragma mark -
#pragma mark Get/Set Methods

- (id<UARegistrationDelegate>)registrationDelegate {
    return self.deviceRegistrar.registrationDelegate;
}

- (void)setRegistrationDelegate:(id<UARegistrationDelegate>)registrationDelegate {
    self.deviceRegistrar.registrationDelegate = registrationDelegate;
}

- (void)setChannelID:(NSString *)channelID {
    [[NSUserDefaults standardUserDefaults] setValue:channelID forKey:UAPushChannelIDKey];
}

- (NSString *)channelID {
    return [[NSUserDefaults standardUserDefaults] stringForKey:UAPushChannelIDKey];
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
    [[NSUserDefaults standardUserDefaults] setObject:alias forKey:UAPushAliasSettingsKey];
}

- (NSArray *)tags {
    NSArray *currentTags = [[NSUserDefaults standardUserDefaults] objectForKey:UAPushTagsSettingsKey];
    if (!currentTags) {
        currentTags = [NSArray array];
    }
    return currentTags;
}

- (void)setTags:(NSArray *)tags {
    [[NSUserDefaults standardUserDefaults] setObject:tags forKey:UAPushTagsSettingsKey];
}

- (void)addTagsToCurrentDevice:(NSArray *)tags {
    NSMutableSet *updatedTags = [NSMutableSet setWithArray:[self tags]];
    [updatedTags addObjectsFromArray:tags];
    [self setTags:[updatedTags allObjects]];
}

- (BOOL)pushEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey];
}

- (void)setPushEnabled:(BOOL)enabled {
    //if the value has actually changed
    if (enabled != self.pushEnabled) {
        [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:UAPushEnabledSettingsKey];
        // Set the flag to indicate that an unRegistration (DELETE)call is needed. This
        // flag is checked on updateRegistration calls, and is used to prevent
        // API calls on every app init when the device is already unregistered.
        // It is cleared on successful unregistration

        if (enabled) {
            UA_LDEBUG(@"Registering for remote notifications.");
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:self.notificationTypes];
        } else {
            //note: we don't want to use the wrapper method here, because otherwise it will blow away the existing notificationTypes
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeNone];
            [self updateRegistration];
        }
    }
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
    return [NSTimeZone timeZoneWithName:timeZoneName];
}

- (void)setTimeZone:(NSTimeZone *)timeZone {
    [[NSUserDefaults standardUserDefaults] setObject:[timeZone name] forKey:UAPushTimeZoneSettingsKey];
}

- (NSTimeZone *)defaultTimeZoneForQuietTime {
    return [NSTimeZone localTimeZone];
}

- (id<UAPushNotificationDelegate>)getDelegate {
    return self.pushNotificationDelegate;
}

- (void)setDelegate:(id<UAPushNotificationDelegate>)delegate {
    self.pushNotificationDelegate = delegate;
}

#pragma mark -
#pragma mark Private methods

- (Class)uiClass {
    if (!_uiClass) {
        _uiClass = NSClassFromString(PUSH_UI_CLASS);
    }
    
    if (!_uiClass) {
        UA_LDEBUG(@"Push UI class not found.");
    }
    
    return _uiClass;
}

#pragma mark -
#pragma mark APNS wrapper
- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types {
    self.notificationTypes = types;
    [self registerForRemoteNotifications];
}

- (void)registerForRemoteNotifications {
    if (self.pushEnabled && self.notificationTypes != UIRemoteNotificationTypeNone) {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:self.notificationTypes];
    }
}

#pragma mark -
#pragma mark Open APIs - Property Setters


- (void)setQuietTimeFrom:(NSDate *)from to:(NSDate *)to withTimeZone:(NSTimeZone *)timezone {
    if (!from || !to) {
        UA_LERR(@"Unable to set quiet time, parameter is nil. From: %@ To: %@", from, to);
        return;
    }

    if (!timezone) {
        timezone = [self defaultTimeZoneForQuietTime];
    }

    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    [cal setTimeZone:timezone];
    
    NSString *startTimeStr = [NSString stringWithFormat:@"%ld:%02ld",
                              (long)[cal components:NSHourCalendarUnit fromDate:from].hour,
                              (long)[cal components:NSMinuteCalendarUnit fromDate:from].minute];
    
    NSString *endTimeStr = [NSString stringWithFormat:@"%ld:%02ld",
                            (long)[cal components:NSHourCalendarUnit fromDate:to].hour,
                            (long)[cal components:NSMinuteCalendarUnit fromDate:to].minute];

    UA_LDEBUG("Setting quiet time: (%@) %@ to %@", [timezone name], startTimeStr, endTimeStr);

    self.quietTime = @{UAPushQuietTimeStartKey : startTimeStr,
                       UAPushQuietTimeEndKey : endTimeStr };

    self.timeZone = timezone;

}


#pragma mark -
#pragma mark Open APIs

+ (void)land {
    
    // not much teardown to do here, but implement anyway for the future
    if (g_sharedUAPush) {
        g_sharedUAPush = nil;
    }
}

#pragma mark -
#pragma mark Open APIs - Custom UI

+ (void)useCustomUI:(Class)customUIClass {
    _uiClass = customUIClass;
}

#pragma mark -
#pragma mark Open APIs - UI Display

+ (void)openApnsSettings:(UIViewController *)viewController
                animated:(BOOL)animated {
    [[[UAPush shared] uiClass] openApnsSettings:viewController animated:animated];
}

+ (void)closeApnsSettingsAnimated:(BOOL)animated {
    [[[UAPush shared] uiClass] closeApnsSettingsAnimated:animated];
}

#pragma mark -
#pragma mark Open APIs - UA Registration Tags APIs

- (void)addTagToCurrentDevice:(NSString *)tag {
    [self addTagsToCurrentDevice:[NSArray arrayWithObject:tag]];
}

- (void)removeTagFromCurrentDevice:(NSString *)tag {
    [self removeTagsFromCurrentDevice:[NSArray arrayWithObject:tag]];
}

- (void)removeTagsFromCurrentDevice:(NSArray *)tags {
    NSMutableArray *mutableTags = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:UAPushTagsSettingsKey]];
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
    // and update call
    if (self.autobadgeEnabled && self.deviceToken) {
        UA_LDEBUG(@"Sending autobadge update to UA server.");
        [self updateRegistrationForcefully:YES];
    }
}

- (void)resetBadge {
    [self setBadgeNumber:0];
}

- (void)handleNotification:(NSDictionary *)notification applicationState:(UIApplicationState)state {
    [self handleNotification:notification applicationState:state fetchCompletionHandler:nil];
  }

- (void)handleNotification:(NSDictionary *)notification
          applicationState:(UIApplicationState)state
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {


    [[UAirship shared].analytics handleNotification:notification inApplicationState:state];

    NSString *situation = nil;
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
    NSMutableDictionary *actions = [self createActionsFromNotification:notification
                                                         withSituation:situation];


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

- (NSMutableDictionary *)createActionsFromNotification:(NSDictionary *)notification
                                         withSituation:(NSString *)situation{

    NSMutableDictionary *actions = [NSMutableDictionary dictionary];

    for (NSString *possibleActionName in notification) {
        UAPushActionArguments *args = [UAPushActionArguments argumentsWithValue:[notification valueForKey:possibleActionName]
                                                                  withSituation:situation
                                                                       withName:possibleActionName
                                                                    withPayload:notification];

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
    if (![[NSUserDefaults standardUserDefaults] boolForKey:UAPushChannelCreationOnForeground]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushChannelCreationOnForeground];
    } else if (!self.channelID) {
        UA_LTRACE(@"Channel ID not created, Updating registration.");
        [self updateRegistration];
    } else if (self.hasEnteredBackground) {
        UA_LTRACE(@"App transitioning from background to foreground.  Updating registration.");
        [self updateRegistration];
    }

    if (!self.launchNotification) {
        NSDictionary *springBoardActions = [UAActionArguments pendingSpringBoardPushActionArguments];
        [UAActionArguments clearSpringBoardActionArguments];
        [UAActionRunner runActions:springBoardActions withCompletionHandler:^(UAActionResult *result){
            UA_LDEBUG(@"Finished performing springboard actions");
        }];
    }
}

- (void)applicationDidEnterBackground {
    self.hasEnteredBackground = YES;
    self.launchNotification = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:UIApplicationDidEnterBackgroundNotification 
                                                  object:[UIApplication sharedApplication]];

    if (!self.channelID) {
        self.registrationBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [self.deviceRegistrar cancelAllRequests];
        }];

        [self updateRegistrationForcefully:NO];
    }
}

#pragma mark -
#pragma mark UA Registration Methods

- (void)updateRegistrationForcefully:(BOOL)forcefully {
    [[NSUserDefaults standardUserDefaults] synchronize];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    payload.deviceID = [UAUtils deviceID];
    payload.userID = [UAUser defaultUser].username;
    payload.pushAddress = self.deviceToken;

    payload.optedIn = [UIApplication sharedApplication].enabledRemoteNotificationTypes != UIRemoteNotificationTypeNone && self.pushEnabled;

    payload.setTags = self.deviceTagsEnabled;
    payload.tags = self.deviceTagsEnabled ? [self.tags copy]: nil;

    payload.alias = self.alias;

    payload.badge = self.autobadgeEnabled ? [NSNumber numberWithInteger:[[UIApplication sharedApplication] applicationIconBadgeNumber]] : nil;

    if (self.timeZone.name && self.quietTimeEnabled) {
        payload.timeZone = self.timeZone.name;
        payload.quietTime = [self.quietTime copy];
    }

    if (self.pushEnabled) {
        [self.deviceRegistrar registerWithChannelID:self.channelID
                                        withPayload:payload
                                         forcefully:forcefully];
    } else {
        [self.deviceRegistrar registerPushDisabledWithChannelID:self.channelID
                                                    withPayload:payload
                                                     forcefully:forcefully];
    }
}

- (void)updateRegistration {
    [self updateRegistrationForcefully:NO];
}

//The new token to register, or nil if updating the existing token 
- (void)registerDeviceToken:(NSData *)token {
    if (!self.notificationTypes) {
        UA_LERR(@"Attempted to register device token with no notificationTypes set!  \
                Please use [[UAPush shared] registerForRemoteNotificationTypes:] instead of the equivalent method on UIApplication.");
        return;
    }

    // Convert device token to a hex string
    NSMutableString *deviceToken = [NSMutableString stringWithCapacity:([token length] * 2)];
    const unsigned char *bytes = (const unsigned char *)[token bytes];

    for (NSUInteger i = 0; i < [token length]; i++) {
        [deviceToken appendFormat:@"%02X", bytes[i]];
    }

    self.deviceToken = [deviceToken lowercaseString];

    UAEventDeviceRegistration *regEvent = [UAEventDeviceRegistration eventWithContext:nil];
    [[UAirship shared].analytics addEvent:regEvent];
    [self updateRegistration];
}

- (void)channelIDCreated:(NSNotification *)channelNotification {
    self.channelID = [channelNotification.userInfo valueForKey:UAChannelCreatedNotificationKey];
}

- (void)registrationFinished {
    // Finish the background task if we have one
    if (self.registrationBackgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.registrationBackgroundTask];
        self.registrationBackgroundTask = UIBackgroundTaskInvalid;
    }
}

#pragma mark -
#pragma mark Default Values

// Change the default push enabled value in the registered user defaults
+ (void)setDefaultPushEnabledValue:(BOOL)enabled {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithBool:enabled] forKey:UAPushEnabledSettingsKey];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
}

#pragma mark -
#pragma mark NSUserDefaults

+ (void)registerNSUserDefaults {
    // Migration for pre 1.3.0 library quiet time settings
    // This pulls an object, instead of a BOOL
    id quietTimeEnabled = [[NSUserDefaults standardUserDefaults] valueForKey:UAPushQuietTimeEnabledSettingsKey];
    NSDictionary *currentQuietTime = [[NSUserDefaults standardUserDefaults] valueForKey:UAPushQuietTimeSettingsKey];

    if (!quietTimeEnabled && currentQuietTime) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushQuietTimeEnabledSettingsKey];
    } else {
         [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushQuietTimeEnabledSettingsKey];
    }

    NSDictionary *defaults = @{ UAPushEnabledSettingsKey: [NSNumber numberWithBool:YES] };

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


@end
