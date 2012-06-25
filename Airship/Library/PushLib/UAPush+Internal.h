
//
//  UAPush_UAPush_Internal.h
//  PushLib
//
//  Created by Matt Hooge on 5/31/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UAPush.h"

typedef NSString UAPushStorageKey;
UAPushStorageKey *const UAPushTimeZoneNameKey = @"UAPushTimeZoneName";
UAPushStorageKey *const UAPushTimeZoneOffesetKey = @"UAPushTimeZoneOffset";
UAPushStorageKey *const UAPushTimeZoneIsDaylightSavingsKey = @"UAPushTimeZoneIsDaylightSavings";

typedef NSString UAPushSettingsKey;
UAPushSettingsKey *const UAPushEnabledSettingsKey = @"UAPushEnabled";
UAPushSettingsKey *const UAPushAliasSettingsKey = @"UAPushAlias";
UAPushSettingsKey *const UAPushTagsSettingsKey = @"UAPushTags";
UAPushSettingsKey *const UAPushBadgeSettingsKey = @"UAPushBadge";
UAPushSettingsKey *const UAPushQuietTimeSettingsKey = @"UAPushQuietTime";
UAPushSettingsKey *const UAPushTimeZoneSettingsKey = @"UAPushTimeZone";
UAPushSettingsKey *const UAPushDeviceTokenSettingsKey = @"UAPushDeviceToken";

typedef NSString UAPushJSONKey;
UAPushJSONKey *const UAPushMultipleTagsJSONKey = @"tags";
UAPushJSONKey *const UAPushSingleTagJSONKey = @"tag";
UAPushJSONKey *const UAPushAliasJSONKey = @"alias";
UAPushJSONKey *const UAPushQuietTimeJSONKey = @"quiettime";
UAPushJSONKey *const UAPushQuietTimeStartJSONKey = @"start";
UAPushJSONKey *const UAPushQuietTimeEndJSONKey = @"end";
UAPushJSONKey *const UAPushTimeZoneJSONKey = @"tz";
UAPushJSONKey *const UAPushBadgeJSONKey = @"badge";

@interface UAPush ()

@property (nonatomic, assign) NSUserDefaults *standardUserDefaults;
@property (nonatomic, assign) UIRemoteNotificationType notificationTypes;

/* Set quite time */
- (void)setQuietTime:(NSMutableDictionary *)quietTime;

/* Get the local time zone, considered the default */
- (NSTimeZone *)defaultTimeZoneForPush;

/* Get a dictionary with the necessary info for tags, alias, autobadge, and
 timezone */
- (NSMutableDictionary *)registrationPayload; 

/* Parse a device token string out of the NSData string representation
 @param tokenStr NSString returned from [NSData* description]
 */
- (NSString*)parseDeviceToken:(NSString*)tokenStr;

/* Build a http request with an optional JSON body 
 @praram info NSDictionary or nil for no body
 */
- (UA_ASIHTTPRequest*)requestToRegisterDeviceTokenWithInfo:(NSDictionary*)info;

/* Build a http reqeust to delete the device token from the UA API */
- (UA_ASIHTTPRequest*)requestToDeleteDeviceToken;

/* Build an NSURL object that can be used to update a single tag. Combine this
 with a PUT or DELETE request to add or remove a tag for this device from the
 UA server. The tag cannot be nil
 @param tag Tag to perform manipulation with.
 @return NSURL with the correct URL 
 */
- (NSURL*)URLForTagManipulationWithTag:(NSString*)tag;

/* Returns a request populated with the proper method (POST OR DELETE)
 succeed/fail selectors, and a user info dictionary with the tag being edited
 @param tag Tag to work with
 @param method UAHTTPMethod, use the typedef declared in the header
 @return UA_ASIHTTPRequest to perform the operation
 */
- (UA_ASIHTTPRequest*)requestToManipulateTag:(NSString*)tag withHTTPMethod:(NSString*)method;

@end
