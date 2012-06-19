
//
//  UAPush_UAPush_Internal.h
//  PushLib
//
//  Created by Matt Hooge on 5/31/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UAPush.h"

typedef NSString UAPushStorageKey;
extern UAPushStorageKey *const UAPushTimeZoneNameKey;
extern UAPushStorageKey *const UAPushTimeZoneOffesetKey;
extern UAPushStorageKey *const UAPushTimeZoneIsDaylightSavingsKey;

@interface UAPush () {

    id<UAPushNotificationDelegate> delegate_; /* Push notification delegate. Handles incoming notifications */
    NSObject<UAPushNotificationDelegate> *defaultPushHandler; /* A default implementation of the push notification delegate */
    BOOL autobadgeEnabled_;
    UIRemoteNotificationType notificationTypes_; /* Requested notification types */
    NSUserDefaults *standardUserDefaults_;
    NSString* deviceToken_;
    BOOL deviceTokenHasChanged_;
}

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
@end
