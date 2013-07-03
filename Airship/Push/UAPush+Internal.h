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

#import "UAPush.h"
#import "UADeviceAPIClient.h"
#import "UADeviceRegistrationPayload.h"

#define PUSH_UI_CLASS @"UAPushUI"
#define PUSH_DELEGATE_CLASS @"UAPushNotificationHandler"

typedef NSString UAPushSettingsKey;
extern UAPushSettingsKey *const UAPushEnabledSettingsKey;
extern UAPushSettingsKey *const UAPushAliasSettingsKey;
extern UAPushSettingsKey *const UAPushTagsSettingsKey;
extern UAPushSettingsKey *const UAPushBadgeSettingsKey;
extern UAPushSettingsKey *const UAPushQuietTimeSettingsKey;
extern UAPushSettingsKey *const UAPushQuietTimeEnabledSettingsKey;
extern UAPushSettingsKey *const UAPushTimeZoneSettingsKey;
extern UAPushSettingsKey *const UAPushDeviceTokenDeprecatedSettingsKey;
extern UAPushSettingsKey *const UAPushDeviceCanEditTagsKey;
extern UAPushSettingsKey *const UAPushNeedsUnregistering;

extern NSString *const UAPushQuietTimeStartKey;
extern NSString *const UAPushQuietTimeEndKey;

// Keys for the userInfo object on request objects
typedef NSString UAPushUserInfoKey;
extern UAPushUserInfoKey *const UAPushUserInfoRegistration;
extern UAPushUserInfoKey *const UAPushUserInfoPushEnabled;

@interface UAPush ()

/**
 * Default push handler.
 */
@property (nonatomic, retain) NSObject <UAPushNotificationDelegate> *defaultPushHandler;

/**
 * Device token as a string.
 */
@property (nonatomic, copy) NSString *deviceToken;

/**
 * Indicates that the app has entered the background once
 * Controls the appDidBecomeActive updateRegistration call
 */
@property (nonatomic, assign) BOOL hasEnteredBackground;

/**
 * The client for the Urban Airship device registration API.
 */
@property (nonatomic, retain) UADeviceAPIClient *deviceAPIClient;

/**
 * Get the local time zone, considered the default.
 */
- (NSTimeZone *)defaultTimeZoneForQuietTime;

/**
 * Parse a device token string from the NSData string representation.
 * @param tokenStr NSString returned from [NSData description]
 *
 * @return The device token as a hex-encoded string without dashes or spaces.
 */
- (NSString *)parseDeviceToken:(NSString *)tokenStr;

/**
 * Generate a payload object for the current push settings.
 *
 * @return The current push settings as a UADeviceRegistrationPayload.
 */
- (UADeviceRegistrationPayload *)registrationPayload;

/**
 * Called on active NSNotificationCenter notifications (on "active" rather than "foreground" so that we
 * can capture the push ID sent with a converting push). Triggers an updateRegistration.
 */
- (void)applicationDidBecomeActive;

/**
 * Used to clear a flag set on foreground to prevent double registration on
 * app init.
 */
- (void)applicationDidEnterBackground;

/**
 * Register the user defaults for this class. You should not need to call this method
 * unless you are bypassing UAirship
 */
+ (void)registerNSUserDefaults;

/**
 * Clean up when app is terminated. You should not ordinarily call this method as it is called
 * during [UAirship land].
 */
+ (void)land;

@end
