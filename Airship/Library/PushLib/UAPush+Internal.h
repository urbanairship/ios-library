/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
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

#import "UAPush.h"


typedef NSString UAPushSettingsKey;
UAPushSettingsKey *const UAPushEnabledSettingsKey = @"UAPushEnabled";
UAPushSettingsKey *const UAPushAliasSettingsKey = @"UAPushAlias";
UAPushSettingsKey *const UAPushTagsSettingsKey = @"UAPushTags";
UAPushSettingsKey *const UAPushBadgeSettingsKey = @"UAPushBadge";
UAPushSettingsKey *const UAPushQuietTimeSettingsKey = @"UAPushQuietTime";
UAPushSettingsKey *const UAPushTimeZoneSettingsKey = @"UAPushTimeZone";
UAPushSettingsKey *const UAPushDeviceTokenDeprecatedSettingsKey = @"UAPushDeviceToken";
UAPushSettingsKey *const UAPushDeviceCanEditTagsKey = @"UAPushDeviceCanEditTags";
UAPushSettingsKey *const UAPushNeedsUnregistering = @"UAPushNeedsUnregistering";

// Keys for the userInfo object on UA_ASIHTTPRequest objects
typedef NSString UAPushUserInfoKey;
UAPushUserInfoKey *const UAPushUserInfoRegistration = @"Registration";
UAPushUserInfoKey *const UAPushUserInfoPushEnabled = @"PushEnabled";

typedef NSString UAPushJSONKey;
UAPushJSONKey *const UAPushMultipleTagsJSONKey = @"tags";
UAPushJSONKey *const UAPushSingleTagJSONKey = @"tag";
UAPushJSONKey *const UAPushAliasJSONKey = @"alias";
UAPushJSONKey *const UAPushQuietTimeJSONKey = @"quiettime";
UAPushJSONKey *const UAPushQuietTimeStartJSONKey = @"start";
UAPushJSONKey *const UAPushQuietTimeEndJSONKey = @"end";
UAPushJSONKey *const UAPushTimeZoneJSONKey = @"tz";
UAPushJSONKey *const UAPushBadgeJSONKey = @"badge";



@interface UAPush () {
    dispatch_queue_t registrationQueue;
}

/* Serial queue for registration requests */
@property (nonatomic, assign) dispatch_queue_t registrationQueue;

/* Delay in seconds between retry attempts. Initial value is
 * kUAPushRetryTimeInitialDelay, max value is kUAPushRetryTimeMaxDelay
 */
@property (nonatomic, assign) int registrationRetryDelay;

/* Convenience pointer for getting to user defaults. */
@property (nonatomic, assign) NSUserDefaults *standardUserDefaults;
@property (nonatomic, assign) UIRemoteNotificationType notificationTypes;

/* Default push handler. */
@property (nonatomic, retain) NSObject <UAPushNotificationDelegate> *defaultPushHandler;

/* Sets the device token string */
- (void)setDeviceToken:(NSString*)deviceToken;

/* Cache of the last successful registration */
@property (nonatomic, retain) NSDictionary *registrationPayloadCache;

/* Last push enabled value sent to the server */
@property (nonatomic, assign) BOOL pushEnabledPayloadCache;

/* Indicator that a registration attempt is under way, and
 * that another should not begin. BOOL is reset on a completed connection
 */
@property (nonatomic, assign) BOOL isRegistering;

/* Indicates that the app has entered the background once
 * Controls the appDidBecomeActive updateRegistration call
 */
@property (nonatomic, assign) BOOL hasEnteredBackground;

/* Set quiet time. */
- (void)setQuietTime:(NSMutableDictionary *)quietTime;

/* Get the local time zone, considered the default. */
- (NSTimeZone *)defaultTimeZoneForQuietTime;

/*
 * Parse a device token string out of the NSData string representation.
 * @param tokenStr NSString returned from [NSData* description]
 */
- (NSString *)parseDeviceToken:(NSString *)tokenStr;

/* Build a http request with an optional JSON body.
 * @praram info NSDictionary or nil for no body
 */
- (UA_ASIHTTPRequest *)requestToRegisterDeviceTokenWithInfo:(NSDictionary *)info;

/* Build a http reqeust to delete the device token from the UA API. */
- (UA_ASIHTTPRequest *)requestToDeleteDeviceToken;

/* Retry connection on any network layer error, or any 
 * server 500 if retryOnConnectionError is YES
 @param reqeust The request that has failed
 @return YES if the request will be scheduled for retry, NO otherwise
 */
- (BOOL)shouldRetryRequest:(UA_ASIHTTPRequest*)request;

/* Schedules the request again after a delay of n seconds,
 * configurable with kUAPushRetryTimeInitialDelay, kUAPushRetryTimeMultiplier, and
 * kUAPushRetryTimeMaxDelay
 * @param reqeust The request to reschedule
 */
- (void)scheduleRetryForRequest:(UA_ASIHTTPRequest*)request;

/* Return a dictionary representing the JSON payload of Push settings. */
- (NSMutableDictionary*)registrationPayload;

/* Takes a user info dictionary (expected to be a registrationPayload) adds 
 * the current state of pushEnabled as a NSNumber
 * @param info The info object passed in to the method, it is expected
 * that this will be a registration payload, and that it will used to
 * store and compare registration state (alias, tags, pushEnabled, etc)
 * @return A mutable dictionary with all of the info values, as well as 
 * an NSNumber indicating pushEnabled state. 
 */
- (NSMutableDictionary*)cacheForRequestUserInfoDictionaryUsing:(NSDictionary*)info;

/* Caches relevant values after a successful registration reqeust
 * @param userInfo The userInfo dictionary of the successful request
 */
- (void)cacheSuccessfulUserInfo:(NSDictionary*)userInfo;

/* Compares the userInfo cached values against the current state of 
 * UAPush values. Intended to be called after a request succeeds. Compares registrationPayloadCache and 
 * pushEnabledPayloadCache against the current registrationPayload and pushEnabled values.
 * @param userInfo The userInfo NSDictionary attached to the request
 * @return YES if the cache is stale compared to the uploaded data, NO if it is current
 */
- (BOOL)cacheHasChangedComparedToUserInfo:(NSDictionary*)userInfo;

/* Called on foreground notifications, triggers an updateRegistration
 */
- (void)applicationDidBecomeActive;

/* Called to set a flag on foreground to prevent double registration on 
 * app init
 */
- (void)applicationDidEnterBackground;

/* Register the user defaults for this class. You should not need to call this method
 unless you are bypassing UAirship
 */
+ (void)registerNSUserDefaults;

@end
