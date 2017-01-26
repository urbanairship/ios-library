/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

#import <Foundation/Foundation.h>
#import "UANotificationContent.h"

NS_ASSUME_NONNULL_BEGIN

@class UNNotificationResponse;

/**
 * Clone of UNNotificationResponse for iOS 8-9 support. Contains the
 * user's reponse to a notification.
 */
@interface UANotificationResponse : NSObject

/**
 * Action identifier representing an application launch via notification.
 */
extern NSString *const UANotificationDefaultActionIdentifier;

/**
 * Action identifier representing a notification dismissal.
 */
extern NSString *const UANotificationDismissActionIdentifier;

/**
 * Action identifier for the response.
 */
@property (nonatomic, copy, readonly) NSString *actionIdentifier;

/**
 * String populated with any response text provided by the user.
 */
@property (nonatomic, copy, readonly) NSString *responseText;

/**
 * The UANotificationContent instance associated with the response.
 */
@property (nonatomic, strong, readonly) UANotificationContent *notificationContent;

/**
 * The UNNotificationResponse that generated the UANotificationResponse.
 * Note: Only available on iOS 10+. Will be nil otherwise.
 */
@property (nonatomic, readonly, nullable, strong) UNNotificationResponse *response;


/**
 * UANotificationResponse factory method.
 *
 * @param notificationInfo The notification user info.
 * @param actionIdentifier The notification action ID.
 * @param responseText Optional response text.
 * @return A UANotificationResponse instance.
 */
+ (instancetype)notificationResponseWithNotificationInfo:(NSDictionary *)notificationInfo
                                        actionIdentifier:(NSString *)actionIdentifier
                                            responseText:(nullable NSString *)responseText;


/**
 * UANotificationResponse factory method.
 *
 * @param response The UNNotificationResponse.
 * @return A UANotificationResponse instance.
 */
+ (instancetype)notificationResponseWithUNNotificationResponse:(UNNotificationResponse *)response;


@end

NS_ASSUME_NONNULL_END
