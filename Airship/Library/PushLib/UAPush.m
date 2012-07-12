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




UA_VERSION_IMPLEMENTATION(UAPushVersion, UA_VERSION)

@implementation UAPush 
//Internal
@synthesize registrationQueue;
@synthesize standardUserDefaults;
@synthesize defaultPushHandler;
@synthesize connectionAttempts;
@synthesize registrationCache;
@synthesize isRegistering;


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
@synthesize retryOnServerError;


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
    RELEASE_SAFELY(registrationCache);
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
                                                 selector:@selector(applicationDidBecomeActiveNotification) 
                                                     name:UIApplicationDidBecomeActiveNotification 
                                                   object:[UIApplication sharedApplication]];
        registrationQueue = dispatch_queue_create("com.urbanairship.registration", DISPATCH_QUEUE_SERIAL);
        dispatch_retain(registrationQueue);
        connectionAttempts = 0;
    }
    return self;
}

#pragma mark -
#pragma mark Device Token Get/Set Methods

// TODO: Remove deviceTokenHasChanged calls when LIB-353 has been completed
- (void)setDeviceToken:(NSString*)deviceToken{
    [_deviceToken autorelease];
    _deviceToken = [deviceToken copy];
    UALOG(@"Device token: %@", deviceToken);    
    //---------------------------------------------------------------------------------------------//
    // *DEPRECATED *The following workflow is deprecated, it is only used to identify if the token //
    // has changed                                                                                 //
    //---------------------------------------------------------------------------------------------//
    NSString* oldToken = [standardUserDefaults stringForKey:UAPushDeviceTokenDeprecatedSettingsKey];
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
    return [standardUserDefaults stringForKey:UAPushAliasJSONKey];
}

- (void)setAlias:(NSString *)alias {
    [standardUserDefaults setObject:alias forKey:UAPushAliasJSONKey];
}

- (BOOL)canEditTagsFromDevice {
   return [standardUserDefaults boolForKey:UAPushDeviceCanEditTagsKey];
}

- (void)setCanEditTagsFromDevice:(BOOL)canEditTagsFromDevice {
    [standardUserDefaults setBool:canEditTagsFromDevice forKey:UAPushDeviceCanEditTagsKey];
}

- (NSArray *)tags {
    return [standardUserDefaults objectForKey:UAPushTagsSettingsKey];
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

- (void)setPushEnabled:(BOOL)pushEnabled {
    [standardUserDefaults setBool:pushEnabled forKey:UAPushEnabledSettingsKey];
}

- (NSDictionary *)quietTime {
    return [standardUserDefaults dictionaryForKey:UAPushQuietTimeSettingsKey];
}

- (void)setQuietTime:(NSMutableDictionary *)quietTime {
    if (!quietTime) {
        [standardUserDefaults removeObjectForKey:UAPushQuietTimeSettingsKey];
    }
    [standardUserDefaults setObject:quietTime forKey:UAPushQuietTimeSettingsKey];
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
    if (tz != nil && quietTime != nil && [quietTime count] > 0) {
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
    [self updateRegistration];
}

- (void)disableQuietTime {
    self.quietTime = nil;
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
#pragma mark UA Registration Methods

- (void)applicationDidBecomeActiveNotification {
    connectionAttempts = 0;    
}

/* There is not way to compare old vs. new payloads without
 * creating a dictionary, so might as well do both
 * @param isStale BOOL pointer that gets filled in with stale value
 * @return NSDictionary of current push values that would be sent to the server
 */
- (NSDictionary*)registrationState:(BOOL*)isStale {
    NSDictionary *payload = [self registrationPayload];
    BOOL stalePayload = [payload isEqualToDictionary:[registrationCache valueForKey:cacheKeyRegstrationPayload]];
    BOOL staleEnabled = self.pushEnabled == [[registrationCache valueForKey:cacheKeyPushEnabled] boolValue];
    *isStale = stalePayload || staleEnabled;
    return payload;
}

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
    dispatch_async(registrationQueue, ^{
        [standardUserDefaults synchronize];
        BOOL isStale = YES;
        NSDictionary *registrationPayload = [self registrationState:&isStale];
        if (!isStale) {
            UALOG(@"Registration is current, no update scheduled");
            return;
        }
        
        // if the application is backgrounded, do not send a registration
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            UALOG(@"Skipping DT registration. The app is currently backgrounded.");
            return;
        }
        
        if (self.pushEnabled) {
            // If there is no device token, register for one, and wait for the application delegate
            // to update with a device token.
            if (!self.deviceToken) {
                [self registerForRemoteNotificationTypes:notificationTypes];
                return;
            }
            UA_ASIHTTPRequest *putRequest = [self requestToRegisterDeviceTokenWithInfo:registrationPayload];
            [putRequest startAsynchronous];
        }
        else {
            UA_ASIHTTPRequest *deleteRequest = [self requestToDeleteDeviceToken];
            [deleteRequest startAsynchronous];
        }
    });
}

//The new token to register, or nil if updating the existing token 
- (void)registerDeviceToken:(NSData *)token {
    self.deviceToken = [self parseDeviceToken:[token description]];
    [self updateRegistration];
}

// Deprecated method, disables auto retry, sends JSON with no error checking
// dev is responsible for everything. Still uses registrationQueue to prevent
// multiple requests running simultaneously.
- (void)registerDeviceTokenWithExtraInfo:(NSDictionary *)info {
    dispatch_async(registrationQueue, ^{
        self.retryOnServerError = NO;
        UA_ASIHTTPRequest *putRequest = [self requestToRegisterDeviceTokenWithInfo:info];
        [putRequest startAsynchronous];
    });
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
        NSDictionary* userInfo = [[info copy] autorelease];
        [request setUserInfo:userInfo];
    }   
    return request;
}


// Deprecated method call. Device token is saved to local ivar, info
// is passed to another deprecated method, no error checking, request
// is enqueued on registration queue.
- (void)registerDeviceToken:(NSData *)token withExtraInfo:(NSDictionary *)info {
    self.retryOnServerError = NO;
    self.deviceToken = [self parseDeviceToken:[token description]];
    [self registerDeviceTokenWithExtraInfo:info];
    
}

// Deprecated method call. Works out fine, but complicates support
// Disables server error
- (void)registerDeviceToken:(NSData *)token withAlias:(NSString *)alias {
    self.retryOnServerError = NO;
    self.deviceToken = [self parseDeviceToken:[token description]];
    self.alias = alias;
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
    return request;
}

#pragma mark -
#pragma mark UA API Registration callbacks

- (void)registerDeviceTokenFailed:(UA_ASIHTTPRequest *)request {
    [UAUtils requestWentWrong:request keyword:@"registering device token"];
    if (request.responseStatusCode >= 500 && request.responseStatusCode <= 599 && retryOnServerError) {
        int delayInSeconds = 5 * connectionAttempts;
        if (delayInSeconds > 60) {
            delayInSeconds = 60;
        }
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        UALOG(@"Will attempt to reconnect in %i seconds", delayInSeconds);
        UALOG(@"Connection Attempt %i", connectionAttempts);
        connectionAttempts++;
        dispatch_after(popTime, registrationQueue, ^(void){
            [self updateRegistration];
        });
        // Updating outside the dispatch block is safe because of the delay
        self.isRegistering = NO;
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
        [self cacheRegisrationState:request];
        self.isRegistering = NO;
        [self notifyObservers:@selector(registerDeviceTokenSucceeded)];
    }
}

/* This method caches the current state of device registration. Outside of the actual registration
 * payload, it records the BOOL of pushEnabled, which allows the isStale comparison to accurately
 * reflect the case where push is disabled/enabled without tracking the device token value. 
 */
- (void)cacheRegisrationState:(UA_ASIHTTPRequest*)request {
    // This will not work if there are requests that no longer require the device token
    // as the last component of the URL
    NSArray* pathComponents = [request.url pathComponents];
    [standardUserDefaults setValue:[pathComponents lastObject] forKey:UAPushSettingsCachedDeviceToken];
    NSNumber *pushEnabled = [NSNumber numberWithBool:self.pushEnabled];
    NSDictionary *registrationPayload = request.userInfo;
    self.registrationCache = [NSDictionary dictionaryWithObjectsAndKeys:
                              pushEnabled, cacheKeyPushEnabled, 
                              registrationPayload, cacheKeyRegstrationPayload, nil];
}

- (void)unRegisterDeviceTokenFailed:(UA_ASIHTTPRequest *)request {
    self.isRegistering = NO;
    [UAUtils requestWentWrong:request keyword:@"unRegistering device token"];
    [self notifyObservers:@selector(unRegisterDeviceTokenFailed:)
               withObject:request];
}

- (void)unRegisterDeviceTokenSucceeded:(UA_ASIHTTPRequest *)request {
    if (request.responseStatusCode != 204){
        [self unRegisterDeviceTokenFailed:request];
    } else {
        self.isRegistering = NO;
        UALOG(@"Device token unregistered on Urban Airship successfully.");
        [self notifyObservers:@selector(unRegisterDeviceTokenSucceeded)];
    }
}

#pragma mark -
#pragma mark NSUserDefaults

+ (void)registerNSUserDefaults {
    NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithCapacity:2];
    [defaults setValue:[NSNumber numberWithBool:YES] forKey:UAPushEnabledSettingsKey];
    [defaults setValue:[NSNumber numberWithBool:YES] forKey:UAPushDeviceCanEditTagsKey];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


@end
