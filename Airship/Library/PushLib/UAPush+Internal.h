
//
//  UAPush_UAPush_Internal.h
//  PushLib
//
//  Created by Matt Hooge on 5/31/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UAPush.h"

typedef NSString UAPushStorageKey;

@interface UAPush () {

    id<UAPushNotificationDelegate> delegate_; /* Push notification delegate. Handles incoming notifications */
    NSObject<UAPushNotificationDelegate> *defaultPushHandler; /* A default implementation of the push notification delegate */
    BOOL autobadgeEnabled_;
    UIRemoteNotificationType notificationTypes; /* Requested notification types */
    NSUserDefaults *standardUserDefaults_;
    NSString* deviceToken_;
    BOOL deviceTokenHasChanged_;
}

@property (nonatomic, assign) NSUserDefaults *standardUserDefaults;

/* Set quite time */
- (void)setQuietTime:(NSMutableDictionary *)quietTime;

/* Get the local time zone, considered the default */
- (NSTimeZone *)defaultTimeZoneForPush;

/* Set the device token. Has the side effect of copying the token
 to user defaults, and updating the deviceTokenHasChanged BOOL */
- (void)setDeviceToken:(NSString *)deviceToken;

/* Get a dictionary with the necessary info for tags, alias, autobadge, and
 timezone */
- (NSMutableDictionary *)registrationPayload; 
@end
