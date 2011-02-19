/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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

#import "UAGlobal.h"
#import "UAirship.h"
#import "UAObservable.h"

#define kEnabled @"UAPushEnabled"
#define kAlias @"UAPushAlias"
#define kTags @"UAPushTags"
#define kBadge @"UAPushBadge"
#define kQuietTime @"UAPushQuietTime"
#define kTimeZone @"UAPushTimeZone"

#define PUSH_UI_CLASS @"UAPushUI"
#define PUSH_DELEGATE_CLASS @"UAPushNotificationHandler"

UA_VERSION_INTERFACE(UAPushVersion)

/**
 * 
 *
 */
@protocol UAPushUIProtocol
+ (void)openApnsSettings:(UIViewController *)viewController
                   animated:(BOOL)animated;
+ (void)openTokenSettings:(UIViewController *)viewController //TODO: remove from lib - it's a demo feature
                   animated:(BOOL)animated;
+ (void)closeApnsSettingsAnimated:(BOOL)animated;
+ (void)closeTokenSettingsAnimated:(BOOL)animated;//TODO: remove from lib - it's a demo feature
@end

/**
 *
 *
 */
@protocol UAPushNotificationDelegate
- (void)displayNotificationAlert:(NSString *)alertMessage;
- (void)displayLocalizedNotificationAlert:(NSDictionary *)alertDict;
- (void)playNotificationSound:(NSString *)sound;
- (void)handleCustomPayload:(NSDictionary *)notification :(NSDictionary *)customPayload;
- (void)handleBadgeUpdate:(int)badgeNumber;
- (void)handleBackgroundNotification:(NSDictionary *)notification;
@end


/**
 * 
 */
@interface UAPush : UAObservable<UARegistrationObserver> {
    
    id<UAPushNotificationDelegate> delegate; /**< Push notification delegate. Handles incoming notifications */
    NSObject<UAPushNotificationDelegate> *defaultPushHandler; /**< A default implementation of the push notification delegate **/
    
  @private
    BOOL pushEnabled; /**< Push enabled flag. */
    BOOL autobadgeEnabled;
    UIRemoteNotificationType notificationTypes; /**< Requested notification types */
    NSString *alias; /**< Device token alias. */
    NSMutableArray *tags; /**< Device token tags */
    NSMutableDictionary *quietTime; /**< Quiet time period. */
    NSString *tz; /**< Timezone, for quiet time */
}

@property (nonatomic, assign) id<UAPushNotificationDelegate> delegate;
@property (nonatomic, assign) BOOL pushEnabled;
@property (nonatomic, retain) NSString *alias;
@property (nonatomic, retain) NSMutableArray *tags;
@property (nonatomic, retain) NSMutableDictionary *quietTime;
@property (nonatomic, retain) NSString *tz;
@property (nonatomic, readonly) UIRemoteNotificationType notificationTypes;

SINGLETON_INTERFACE(UAPush);

/**
 * Use a custom UI implementation.
 * Replaces the default push UI, defined in UAPushUI, with
 * a custom implementation.
 *
 * @see UAPushUIProtocol
 * @see UAPushUI
 *
 * @param customUIClass An implementation of UAPushUIProtocol
 */
+ (void)useCustomUI:(Class)customUIClass;
+ (void)openApnsSettings:(UIViewController *)viewController
                animated:(BOOL)animated;
+ (void)openTokenSettings:(UIViewController *)viewController
                 animated:(BOOL)animated;
+ (void)closeApnsSettingsAnimated:(BOOL)animated;
+ (void)closeTokenSettingsAnimated:(BOOL)animated;

- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types;
- (void)registerDeviceToken:(NSData *)token;
- (void)updateRegistration;

// Change tags for current device token
- (void)addTagToCurrentDevice:(NSString *)tag;
- (void)removeTagFromCurrentDevice:(NSString *)tag;

// Update (replace) token attributes
- (void)updateAlias:(NSString *)value;
- (void)updateTags:(NSMutableArray *)value;

// Change quiet time for current device token, only take hh:mm into account
- (void)setQuietTimeFrom:(NSDate *)from to:(NSDate *)to withTimeZone:(NSTimeZone *)tz;
- (void)disableQuietTime;

- (void)enableAutobadge:(BOOL)enabled;
- (void)setBadgeNumber:(NSInteger)badgeNumber;
- (void)resetBadge;

//Handle incoming push notifications
- (void)handleNotification:(NSDictionary *)notification applicationState:(UIApplicationState)state;

+ (NSString *)pushTypeString:(UIRemoteNotificationType)types;

@end
