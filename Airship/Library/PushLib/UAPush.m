/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

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

#import "UAPush.h"
#import "UAPush+Internal.h"

#import "UAirship.h"
#import "UAViewUtils.h"
#import "UAUtils.h"
#import "UAAnalytics.h"
#import "UAEvent.h"
#import "UAPushNotificationHandler.h"

#import "UA_SBJsonWriter.h"
#import "UA_ASIHTTPRequest.h"


#define kUAPushRetryTimeInitialDelay 60
#define kUAPushRetryTimeMultiplier 2
#define kUAPushRetryTimeMaxDelay 300

UA_VERSION_IMPLEMENTATION(UAPushVersion, UA_VERSION)

@implementation UAPush 
//Internal
@synthesize registrationQueue;
@synthesize standardUserDefaults;
@synthesize defaultPushHandler;
@synthesize registrationRetryDelay;
@synthesize registrationPayloadCache;
@synthesize pushEnabledPayloadCache;
@synthesize isRegistering;
@synthesize hasEnteredBackground;

//Public
@synthesize delegate;
@synthesize notificationTypes;
@synthesize autobadgeEnabled = autobadgeEnabled_;

// Public - UserDefaults
@dynamic pushEnabled;
@synthesize deviceToken = _deviceToken;
@synthesize deviceTokenHasChanged;
@dynamic alias;
@dynamic tags;
@dynamic quietTime;
@dynamic timeZone;
@dynamic quietTimeEnabled;
@synthesize retryOnConnectionError;


SINGLETON_IMPLEMENTATION(UAPush)

static Class _uiClass;

+ (void)initialize {
    [self registerNSUserDefaults];
}

-(void)dealloc {
    RELEASE_SAFELY(defaultPushHandler);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    dispatch_release(registrationQueue);
    registrationQueue = nil;
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        //init with default delegate implementation
        // released when replaced
        defaultPushHandler = [[NSClassFromString(PUSH_DELEGATE_CLASS) alloc] init];
        delegate = defaultPushHandler;
        standardUserDefaults = [NSUserDefaults standardUserDefaults];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(applicationDidBecomeActive) 
                                                     name:UIApplicationDidBecomeActiveNotification 
                                                   object:[UIApplication sharedApplication]];
        // Only for observing the first call to app background
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                              selector:@selector(applicationDidEnterBackground) 
                                                  name:UIApplicationDidEnterBackgroundNotification 
                                                object:[UIApplication sharedApplication]];
        registrationQueue = dispatch_queue_create("com.urbanairship.registration", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark -
#pragma mark Device Token Get/Set Methods

// TODO: Remove deviceTokenHasChanged calls when LIB-353 has been completed
- (void)setDeviceToken:(NSString*)deviceToken {
    [_deviceToken autorelease];
    _deviceToken = [deviceToken copy];
    UALOG(@"Device token: %@", deviceToken);    
    //---------------------------------------------------------------------------------------------//
    // *DEPRECATED *The following workflow is deprecated, it is only used to identify if the token //
    // has changed                                                                                 //
    //---------------------------------------------------------------------------------------------//
    NSString *oldToken = [standardUserDefaults stringForKey:UAPushDeviceTokenDeprecatedSettingsKey];
    if ([_deviceToken isEqualToString:oldToken]) {
        deviceTokenHasChanged = NO;
    }
    else {
        deviceTokenHasChanged = YES;
    }
    [standardUserDefaults setObject:deviceToken forKey:UAPushDeviceTokenDeprecatedSettingsKey];
    // *DEPRECATED CODE END* // 
}

- (NSString*)parseDeviceToken:(NSString*)tokenStr {
    return [[[tokenStr stringByReplacingOccurrencesOfString:@"<" withString:@""]
             stringByReplacingOccurrencesOfString:@">" withString:@""]
            stringByReplacingOccurrencesOfString:@" " withString:@""];
}

#pragma mark -
#pragma mark Get/Set Methods

- (BOOL)autobadgeEnabled {
    return [standardUserDefaults boolForKey:UAPushBadgeSettingsKey];
}

- (void)setAutobadgeEnabled:(BOOL)autobadgeEnabled {
    [standardUserDefaults setBool:autobadgeEnabled forKey:UAPushBadgeSettingsKey];
}


- (NSString *)alias {
    return [standardUserDefaults stringForKey:UAPushAliasSettingsKey];
}

- (void)setAlias:(NSString *)alias {
    [standardUserDefaults setObject:alias forKey:UAPushAliasSettingsKey];
}

- (BOOL)canEditTagsFromDevice {
   return [standardUserDefaults boolForKey:UAPushDeviceCanEditTagsKey];
}

- (void)setCanEditTagsFromDevice:(BOOL)canEditTagsFromDevice {
    [standardUserDefaults setBool:canEditTagsFromDevice forKey:UAPushDeviceCanEditTagsKey];
}

- (NSArray *)tags {
    NSArray *currentTags = [standardUserDefaults objectForKey:UAPushTagsSettingsKey];
    if (!currentTags) {
        currentTags = [NSArray array];
    }
    return currentTags;
}

- (void)setTags:(NSArray *)tags {
    [standardUserDefaults setObject:tags forKey:UAPushTagsSettingsKey];
}

- (void)addTagsToCurrentDevice:(NSArray *)tags {
    NSMutableSet *updatedTags = [NSMutableSet setWithArray:[self tags]];
    [updatedTags addObjectsFromArray:tags];
    [self setTags:[updatedTags allObjects]];
}

- (BOOL)pushEnabled {
    return [standardUserDefaults boolForKey:UAPushEnabledSettingsKey];
}

- (void)setPushEnabled:(BOOL)enabled {
    //if the value has actually changed
    if (enabled != self.pushEnabled) {
        [standardUserDefaults setBool:enabled forKey:UAPushEnabledSettingsKey];
        // Set the flag to indicate that an unRegistration (DELETE)call is needed. This
        // flag is checked on updateRegistration calls, and is used to prevent
        // API calls on every app init when the device is already unregistered.
        // It is cleared on successful unregistration

        if (enabled) {
            UALOG(@"registering for remote notifcations");
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:notificationTypes];
        } else {
            [standardUserDefaults setBool:YES forKey:UAPushNeedsUnregistering];
            //note: we don't want to use the wrapper method here, because otherwise it will blow away the existing notificationTypes
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeNone];
            [self updateRegistration];
        }
    }
}

- (NSDictionary *)quietTime {
    return [standardUserDefaults dictionaryForKey:UAPushQuietTimeSettingsKey];
}

- (void)setQuietTime:(NSMutableDictionary *)quietTime {
    [standardUserDefaults setObject:quietTime forKey:UAPushQuietTimeSettingsKey];
}

- (BOOL)quietTimeEnabled {
    return [standardUserDefaults boolForKey:UAPushQuietTimeEnabledSettingsKey];
}

- (void)setQuietTimeEnabled:(BOOL)quietTimeEnabled {
    [standardUserDefaults setBool:quietTimeEnabled forKey:UAPushQuietTimeEnabledSettingsKey];
}

- (NSString *)tz {
    return [[self timeZone] name];
}

- (void)setTz:(NSString *)tz {
    NSTimeZone* timeZone = [NSTimeZone timeZoneWithName:tz];
    self.timeZone = timeZone;
}

- (NSTimeZone *)timeZone {
    NSString* timeZoneName = [standardUserDefaults stringForKey:UAPushTimeZoneSettingsKey];
    return [NSTimeZone timeZoneWithName:timeZoneName];
}

- (void)setTimeZone:(NSTimeZone *)timeZone {
    [standardUserDefaults setObject:[timeZone name] forKey:UAPushTimeZoneSettingsKey];
}

- (NSTimeZone *)defaultTimeZoneForQuietTime {
    return [NSTimeZone localTimeZone];
}


#pragma mark -
#pragma mark Private methods

- (Class)uiClass {
    if (!_uiClass) {
        _uiClass = NSClassFromString(PUSH_UI_CLASS);
    }
    
    if (_uiClass == nil) {
        UALOG(@"Push UI class not found.");
    }
    
    return _uiClass;
}

- (NSString *)getTagFromUrl:(NSURL *)url {
    return [[url.relativePath componentsSeparatedByString:@"/"] lastObject];
}

#pragma mark -
#pragma mark APNS wrapper
- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types {
    self.notificationTypes = types;
    
    if (self.pushEnabled) {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:notificationTypes];
    }
}

#pragma mark -
#pragma mark UA API JSON Payload

- (NSMutableDictionary *)registrationPayload {
    
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    NSString* alias =  self.alias;

    [body setValue:alias forKey:UAPushAliasJSONKey];
    
    if (self.canEditTagsFromDevice) {
        NSArray *tags = [self tags];
        // If there are no tags, and tags are editable, send an 
        // empty array
        if (!tags) {
            tags = [NSArray array];
        }
        [body setValue:tags forKey:UAPushMultipleTagsJSONKey];
    }
    
    NSString* tz = self.timeZone.name;
    NSDictionary *quietTime = self.quietTime;
    if (tz != nil && self.quietTimeEnabled) {
        [body setValue:tz forKey:UAPushTimeZoneJSONKey];
        [body setValue:quietTime forKey:UAPushQuietTimeJSONKey];
    }
    if ([self autobadgeEnabled]) {
        [body setValue:[NSNumber numberWithInteger:[[UIApplication sharedApplication] applicationIconBadgeNumber]] 
                forKey:UAPushBadgeJSONKey];
    }
    return body;
}

#pragma mark -
#pragma mark Open APIs - Property Setters

- (void)updateAlias:(NSString *)value {
    self.alias = value;
    [self updateRegistration];
}

- (void)updateTags:(NSMutableArray *)value {
    self.tags = value;
    [self updateRegistration];
}

- (void)setQuietTimeFrom:(NSDate *)from to:(NSDate *)to withTimeZone:(NSTimeZone *)timezone {
    if (!from || !to) {
        UALOG(@"Set Quiet Time - parameter is nil. from: %@ to: %@", from, to);
        return;
    }
    if(!timezone){
        timezone = [self defaultTimeZoneForQuietTime];
    }
    NSCalendar *cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    NSString *fromStr = [NSString stringWithFormat:@"%d:%02d",
                         [cal components:NSHourCalendarUnit fromDate:from].hour,
                         [cal components:NSMinuteCalendarUnit fromDate:from].minute];
    
    NSString *toStr = [NSString stringWithFormat:@"%d:%02d",
                       [cal components:NSHourCalendarUnit fromDate:to].hour,
                       [cal components:NSMinuteCalendarUnit fromDate:to].minute];
    
    self.quietTime = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      fromStr, UAPushQuietTimeStartJSONKey,
                      toStr, UAPushQuietTimeEndJSONKey, nil];
    
    self.timeZone = timezone;
}

- (void)disableQuietTime {
    self.quietTimeEnabled = NO;
    [self updateRegistration];
}

#pragma mark -
#pragma mark Open APIs

+ (void)land {
    
    // not much teardown to do here, but implement anyway for the future
    if (g_sharedUAPush) {
        RELEASE_SAFELY(g_sharedUAPush);
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

+ (void)openTokenSettings:(UIViewController *)viewController
                 animated:(BOOL)animated {
    [[[UAPush shared] uiClass] openTokenSettings:viewController animated:animated];
}

+ (void)closeApnsSettingsAnimated:(BOOL)animated {
    [[[UAPush shared] uiClass] closeApnsSettingsAnimated:animated];
}

+ (void)closeTokenSettingsAnimated:(BOOL)animated {
    [[[UAPush shared] uiClass] closeTokenSettingsAnimated:animated];
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
    NSMutableArray *mutableTags = [NSMutableArray arrayWithArray:[standardUserDefaults objectForKey:UAPushTagsSettingsKey]];
    [mutableTags removeObjectsInArray:tags];
    [standardUserDefaults setObject:mutableTags forKey:UAPushTagsSettingsKey];
}

- (void)enableAutobadge:(BOOL)autobadge {
    self.autobadgeEnabled = autobadge;
}

- (void)setBadgeNumber:(NSInteger)badgeNumber {

    if ([[UIApplication sharedApplication] applicationIconBadgeNumber] == badgeNumber) {
        return;
    }

    UALOG(@"Change Badge from %d to %d", [[UIApplication sharedApplication] applicationIconBadgeNumber], badgeNumber);

    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:badgeNumber];

    // if the device token has already been set then
    // we are post-registration and will need to make
    // and update call
    if (self.autobadgeEnabled && self.deviceToken) {
        //clear the registration payload cache so we can synchronize with the server
        self.registrationPayloadCache = nil;
        UALOG(@"Sending autobadge update to UA server");
        [self updateRegistration];
    }
}

- (void)resetBadge {
    [self setBadgeNumber:0];
}

- (void)handleNotification:(NSDictionary *)notification applicationState:(UIApplicationState)state {
    
    [[UAirship shared].analytics handleNotification:notification];
        
    if (state != UIApplicationStateActive) {
        UALOG(@"Received a notification for an inactive application state.");
        
        if ([delegate respondsToSelector:@selector(handleBackgroundNotification:)])
            [delegate handleBackgroundNotification:notification];
        return;
    }
    
    // Please refer to the following Apple documentation for full details on handling the userInfo payloads
	// http://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/ApplePushService/ApplePushService.html#//apple_ref/doc/uid/TP40008194-CH100-SW1
	
	if ([[notification allKeys] containsObject:@"aps"]) { 
		
        NSDictionary *apsDict = [notification objectForKey:@"aps"];
        
		if ([[apsDict allKeys] containsObject:@"alert"]) {

			if ([[apsDict objectForKey:@"alert"] isKindOfClass:[NSString class]] &&
                [delegate respondsToSelector:@selector(displayNotificationAlert:)]) {
                
				// The alert is a single string message so we can display it
                [delegate displayNotificationAlert:[apsDict valueForKey:@"alert"]];

			} else if ([delegate respondsToSelector:@selector(displayLocalizedNotificationAlert:)]) {
				// The alert is a a dictionary with more localization details
				// This should be customized to fit your message details or usage scenario
                [delegate displayLocalizedNotificationAlert:[apsDict valueForKey:@"alert"]];
			}
			
		}
        
        //badge
        NSString *badgeNumber = [apsDict valueForKey:@"badge"];
        if (badgeNumber) {
            
			if(self.autobadgeEnabled) {
				[[UIApplication sharedApplication] setApplicationIconBadgeNumber:[badgeNumber intValue]];
			} else if ([delegate respondsToSelector:@selector(handleBadgeUpdate:)]) {
				[delegate handleBadgeUpdate:[badgeNumber intValue]];
			}
        }
		
        //sound
		NSString *soundName = [apsDict valueForKey:@"sound"];
		if (soundName && [delegate respondsToSelector:@selector(playNotificationSound:)]) {
			[delegate playNotificationSound:[apsDict objectForKey:@"sound"]];
		}
        
	}//aps
    
	// Now remove all the UA and Apple payload items
	NSMutableDictionary *customPayload = [[notification mutableCopy] autorelease];
	
	if([[customPayload allKeys] containsObject:@"aps"]) {
		[customPayload removeObjectForKey:@"aps"];
	}
	if([[customPayload allKeys] containsObject:@"_uamid"]) {
		[customPayload removeObjectForKey:@"_uamid"];
	}
	if([[customPayload allKeys] containsObject:@"_"]) {
		[customPayload removeObjectForKey:@"_"];
	}
	
	// If any top level items remain, those are custom payload, pass it to the handler
	// Note: There is some convenience built into this check, if for some reason there's a key collision
	//	and we're stripping yours above, it's safe to remove this conditional
	if([[customPayload allKeys] count] > 0 && [delegate respondsToSelector:@selector(handleNotification:withCustomPayload:)]) {
		[delegate handleNotification:notification withCustomPayload:customPayload];
    }
}

+ (NSString *)pushTypeString:(UIRemoteNotificationType)types {
    
    //TODO: Localize
    
    //UIRemoteNotificationType types = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    
    NSMutableArray *typeArray = [NSMutableArray arrayWithCapacity:3];

    //Use the same order as the Settings->Notifications panel
    if (types & UIRemoteNotificationTypeBadge) {
        [typeArray addObject:@"Badges"];
    }
    
    if (types & UIRemoteNotificationTypeAlert) {
        [typeArray addObject:@"Alerts"];
    }
    
    if (types & UIRemoteNotificationTypeSound) {
        [typeArray addObject:@"Sounds"];
    }
    
    if ([typeArray count] > 0) {
        return [typeArray componentsJoinedByString:@", "];
    }
    
    return @"None";
}

#pragma mark -
#pragma mark UIApplication State Observation

- (void)applicationDidBecomeActive {
    UALOG(@"Checking registration status after foreground notification");
    if (hasEnteredBackground) {
        registrationRetryDelay = 0;
        [self updateRegistration];
    }
    else {
        UALOG(@"Checking registration on app foreground disabled on app initialization");
    }
}

- (void)applicationDidEnterBackground {
    hasEnteredBackground = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:UIApplicationDidEnterBackgroundNotification 
                                                  object:[UIApplication sharedApplication]];
}

#pragma mark -
#pragma mark UA Registration    Methods

/* 
 * Checks the current state of the cache.
 * Checks the current application state, bails if in the background with the
 * assumption that next app init or isActive notif will call update.
 * Dispatches either a PUT or DELETE request to the server if necessary on
 * the registration queue. PushEnabled -> PUT, !PushEnabled -> DELETE.
 */
- (void)updateRegistration {
    if (isRegistering) {
        UALOG(@"Currently registering, will check cache state when current registration is complete");
        return;
    }
    self.isRegistering = YES;
    
    UALOG(@"Checking registration state");
    // if the application is backgrounded, do not send a registration
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        UALOG(@"Skipping DT registration. The app is currently backgrounded.");
        self.isRegistering = NO;
        return;
    }
    
    [standardUserDefaults synchronize];
    NSDictionary *currentRegistrationPayload = [self registrationPayload];;
    if ([registrationPayloadCache isEqualToDictionary:currentRegistrationPayload] 
        && self.pushEnabled == self.pushEnabledPayloadCache) {
        UALOG(@"Registration is current, no update scheduled");
        self.isRegistering = NO;
        return;
    }
    
    if (self.pushEnabled) {
        // If there is no device token, wait for the application delegate to update with one.
        if (!self.deviceToken) {
            self.isRegistering = NO;
            return;
        }
        UA_ASIHTTPRequest *putRequest = [self requestToRegisterDeviceTokenWithInfo:currentRegistrationPayload];
        UALOG(@"Starting registration PUT request");
        [putRequest startAsynchronous];
    }
    else {
        // Don't unregister more than once
        if ([standardUserDefaults boolForKey:UAPushNeedsUnregistering]) {
            UA_ASIHTTPRequest *deleteRequest = [self requestToDeleteDeviceToken];
            UALOG(@"Starting registration DELETE request (unregistering)");
            [deleteRequest startAsynchronous];
        }
        else {
            UALOG(@"Device has already been unregistered, no update scheduled");
        }
    }
}

//The new token to register, or nil if updating the existing token 
- (void)registerDeviceToken:(NSData *)token {
    self.deviceToken = [self parseDeviceToken:[token description]];
    UAEventDeviceRegistration *regEvent = [UAEventDeviceRegistration eventWithContext:nil];
    [[UAirship shared].analytics addEvent:regEvent];
    [self updateRegistration];
}

// Deprecated method, disables auto retry, sends JSON with no error checking
// dev is responsible for everything. 
- (void)registerDeviceTokenWithExtraInfo:(NSDictionary *)info {
    self.retryOnConnectionError = NO;
    self.isRegistering = YES;
    UAEventDeviceRegistration *regEvent = [UAEventDeviceRegistration eventWithContext:nil];
    [[UAirship shared].analytics addEvent:regEvent];
    UA_ASIHTTPRequest *putRequest = [self requestToRegisterDeviceTokenWithInfo:info];
    UALOG(@"Starting deprecated registration request");
    [putRequest startAsynchronous];
}

- (UA_ASIHTTPRequest*)requestToRegisterDeviceTokenWithInfo:(NSDictionary*)info {
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@/",
                           [UAirship shared].server, @"/api/device_tokens/",
                           self.deviceToken];
    NSURL *url = [NSURL URLWithString:urlString];
    UA_ASIHTTPRequest *request = [UAUtils requestWithURL:url
                                                  method:@"PUT"
                                                delegate:self
                                                  finish:@selector(registerDeviceTokenSucceeded:)
                                                    fail:@selector(registerDeviceTokenFailed:)];
    if (info != nil) {
        [request addRequestHeader: @"Content-Type" value: @"application/json"];
        UA_SBJsonWriter *writer = [[[UA_SBJsonWriter alloc] init] autorelease];
        [request appendPostData:[[writer stringWithObject:info] dataUsingEncoding:NSUTF8StringEncoding]];
        // add the registration payload as the userInfo object to cache on upload success
        // two values, the registration payload and the pushEnabled value
        NSDictionary *userInfo = [self cacheForRequestUserInfoDictionaryUsing:info];
        request.userInfo = userInfo;
    }   
    return request;
}

// Mean to be called right after successful registration to make
// sure state has not been changed
- (BOOL)cacheHasChangedComparedToUserInfo:(NSDictionary*)userInfo {
    NSDictionary *justRegisteredPayload = [userInfo valueForKey:UAPushUserInfoRegistration];
    NSNumber *justRegisteredPushEnabled = [userInfo valueForKey:UAPushUserInfoPushEnabled];
    BOOL equalRegistration = [justRegisteredPayload isEqualToDictionary:[self registrationPayload]];
    BOOL equalPushEnabled = [justRegisteredPushEnabled boolValue] == self.pushEnabled;
    return !(equalRegistration && equalPushEnabled);
}

// Meant to be called from any request, returns an NSDictionary with 
// the passed in info and an NSNumber for pushEnabled state
- (NSMutableDictionary*)cacheForRequestUserInfoDictionaryUsing:(NSDictionary*)info {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:2];
    [userInfo setValue:[NSNumber numberWithBool:self.pushEnabled] forKey:UAPushUserInfoPushEnabled];
    [userInfo setValue:info forKey:UAPushUserInfoRegistration];
    return userInfo;
}

// Called after a successful request, after the cache has been checked for 
// stale data, caches data
- (void)cacheSuccessfulUserInfo:(NSDictionary*)userInfo {
    self.registrationPayloadCache = [userInfo valueForKey:UAPushUserInfoRegistration];
    self.pushEnabledPayloadCache = [[userInfo valueForKey:UAPushUserInfoPushEnabled] boolValue];
}

// Deprecated method call. Device token is saved to local ivar, info
// is passed to another deprecated method.
- (void)registerDeviceToken:(NSData *)token withExtraInfo:(NSDictionary *)info {
    self.retryOnConnectionError = NO;
    self.deviceToken = [self parseDeviceToken:[token description]];
    // Device token event trigger in registerDeviceTokenWithExtraInfo:
    [self registerDeviceTokenWithExtraInfo:info];
    
}

// Deprecated method call. Works out fine, but complicates support
// Disables server error
- (void)registerDeviceToken:(NSData *)token withAlias:(NSString *)alias {
    self.retryOnConnectionError = NO;
    self.deviceToken = [self parseDeviceToken:[token description]];
    self.alias = alias;
    UAEventDeviceRegistration *regEvent = [UAEventDeviceRegistration eventWithContext:nil];
    [[UAirship shared].analytics addEvent:regEvent];
    [self updateRegistration];
}


- (void)unRegisterDeviceToken {
    self.pushEnabled = NO;
    [self updateRegistration];
}

- (UA_ASIHTTPRequest*)requestToDeleteDeviceToken {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/device_tokens/%@/",
                           [UAirship shared].server,
                           self.deviceToken];
    NSURL *url = [NSURL URLWithString:urlString];
    UALOG(@"Request to unregister device token.");
    UA_ASIHTTPRequest *request = [UAUtils requestWithURL:url
                                                  method:@"DELETE"
                                                delegate:self
                                                  finish:@selector(unRegisterDeviceTokenSucceeded:)
                                                    fail:@selector(unRegisterDeviceTokenFailed:)];
    // add the registration payload as the userInfo object to cache on upload success
    // two values, the registration payload and the pushEnabled value
    NSMutableDictionary *userInfo = [self cacheForRequestUserInfoDictionaryUsing:[self registrationPayload]];
    request.userInfo = userInfo;
    return request;
}

#pragma mark -
#pragma mark UA API Registration callbacks

- (void)registerDeviceTokenFailed:(UA_ASIHTTPRequest *)request {
    [UAUtils requestWentWrong:request keyword:@"registering device token"];
    if ([self shouldRetryRequest:request]) {
        [self scheduleRetryForRequest:request];
        return;
    }
    self.isRegistering = NO;
    [self notifyObservers:@selector(registerDeviceTokenFailed:)
               withObject:request];
}

- (void)registerDeviceTokenSucceeded:(UA_ASIHTTPRequest *)request {
    if(request.responseStatusCode != 200 && request.responseStatusCode != 201) {
        [self registerDeviceTokenFailed:request];
    } else {
        UALOG(@"Device token registered on Urban Airship successfully.");
        // cache before setting isRegistering to NO
        [self cacheSuccessfulUserInfo:request.userInfo];
        self.isRegistering = NO;
        if ([self cacheHasChangedComparedToUserInfo:request.userInfo]) {
            [self updateRegistration];
            return;
        }
        [self notifyObservers:@selector(registerDeviceTokenSucceeded)];
    }
}

- (void)unRegisterDeviceTokenFailed:(UA_ASIHTTPRequest *)request {
    [UAUtils requestWentWrong:request keyword:@"unRegistering device token"];
    if ([self shouldRetryRequest:request]) {
        [self scheduleRetryForRequest:request];
        return;
    }
    self.isRegistering = NO;
    [self notifyObservers:@selector(unRegisterDeviceTokenFailed:)
               withObject:request];
}

- (void)unRegisterDeviceTokenSucceeded:(UA_ASIHTTPRequest *)request {
    if (request.responseStatusCode != 204){
        [self unRegisterDeviceTokenFailed:request];
    } else {
        // cache before setting isRegistering to NO
        [self cacheSuccessfulUserInfo:request.userInfo];
        // note that unregistration is no longer needed
        [standardUserDefaults setBool:NO forKey:UAPushNeedsUnregistering];
        self.isRegistering = NO;
        if ([self cacheHasChangedComparedToUserInfo:request.userInfo]) {
            [self updateRegistration];
            return;
        }
        UALOG(@"Device token unregistered on Urban Airship successfully.");
        [self notifyObservers:@selector(unRegisterDeviceTokenSucceeded)];
    }
}

- (BOOL)shouldRetryRequest:(UA_ASIHTTPRequest*)request {
    if (!self.retryOnConnectionError) {
        return NO;
    }
    if (request.error) {
        return YES;
    }
    if (request.responseStatusCode >= 500 && request.responseStatusCode <= 599) {
        return YES;
    }
    return NO;
}

- (void)scheduleRetryForRequest:(UA_ASIHTTPRequest*)request {
    if (registrationRetryDelay == 0) {
        registrationRetryDelay = kUAPushRetryTimeInitialDelay;
    }
    else {
        registrationRetryDelay = MIN(registrationRetryDelay * kUAPushRetryTimeMultiplier, kUAPushRetryTimeMaxDelay);
    }
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, self.registrationRetryDelay * NSEC_PER_SEC);
    UALOG(@"Will attempt to reconnect in %i seconds", registrationRetryDelay);
    self.isRegistering = NO;
    dispatch_after(popTime, registrationQueue, ^(void){
        [self updateRegistration];
    });
}

#pragma mark -
#pragma mark NSUserDefaults

+ (void)registerNSUserDefaults {
    // Migration for pre 1.3.0 library quiet time settings
    // This pulls an object, instead of a BOOL
    id quietTimeEnabled = [[NSUserDefaults standardUserDefaults] valueForKey:UAPushQuietTimeEnabledSettingsKey];
    NSDictionary* currentQuietTime = [[NSUserDefaults standardUserDefaults] valueForKey:UAPushQuietTimeSettingsKey];
    if (!quietTimeEnabled && currentQuietTime) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushQuietTimeEnabledSettingsKey];
    }
    NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithCapacity:2];
    [defaults setValue:[NSNumber numberWithBool:YES] forKey:UAPushEnabledSettingsKey];
    [defaults setValue:[NSNumber numberWithBool:YES] forKey:UAPushDeviceCanEditTagsKey];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


@end
