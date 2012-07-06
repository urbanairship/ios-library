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
UAPushSettingsKey *const UAPushDeviceTokenSettingsKey = @"UAPushDeviceToken";
UAPushSettingsKey *const UAPushDeviceCanEditTagsKey = @"UAPushDeviceCanEditTags";
UAPushSettingsKey *const UAPushSettingsCachedRegistrationPayload = @"UAPushCachedPayload";
UAPushSettingsKey *const UAPushSettingsCachedDeviceToken = @"UAPushCachedDeviceToken";

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

/* Convenience pointer for getting to user defaults. */
@property (nonatomic, assign) NSUserDefaults *standardUserDefaults;
@property (nonatomic, assign) UIRemoteNotificationType notificationTypes;

/* Default push handler. */
@property (nonatomic, retain) NSObject <UAPushNotificationDelegate> *defaultPushHandler;


/* Set quiet time. */
- (void)setQuietTime:(NSMutableDictionary *)quietTime;

/* Get the local time zone, considered the default. */
- (NSTimeZone *)defaultTimeZoneForQuietTime;

/* 
 * Build a dictionary with the necessary info for tags, alias, autobadge and quiet time.
 */
- (NSMutableDictionary *)registrationPayload; 

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

/* Register the user defaults for this class. You should not need to call this method
 unless you are bypassing UAirship
 */
+ (void)registerNSUserDefaults;

@end
