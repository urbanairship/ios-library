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

NS_ASSUME_NONNULL_BEGIN

@class UNNotification;

/**
 * Clone of UNNotificationContent for iOS 8-9 support. Contains convenient accessors
 * to the notification's content.
 */
@interface UANotificationContent : NSObject

/**
 * Alert title
 */
@property (nonatomic, copy, nullable, readonly) NSString *alertTitle;

/**
 * Alert body
 */
@property (nonatomic, copy, nullable, readonly) NSString *alertBody;

/**
 * Sound file name
 */
@property (nonatomic, copy, nullable, readonly) NSString *sound;

/**
 * Badge number
 */
@property (nonatomic, assign, nullable, readonly) NSNumber *badge;

/**
 * Content available
 */
@property (nonatomic, strong, nullable, readonly) NSNumber *contentAvailable;

/**
 * Category
 */
@property (nonatomic, copy, nullable, readonly) NSString *categoryIdentifier;

/**
 * Launch image file name
 */
@property (nonatomic, copy, nullable, readonly) NSString *launchImage;

/**
 * Localization keys
 */
@property (nonatomic, copy, nullable, readonly) NSDictionary *localizationKeys;

/**
 * Notification info dictionary used to generate the UANotification.
 */
@property (nonatomic, copy, readonly) NSDictionary *notificationInfo;

/**
 * UNNotification used to generate the UANotification.
 */
@property (nonatomic, strong, nullable, readonly) UNNotification *notification;


/**
 * Parses the raw notification dictionary into a UANotification.
 *
 * @param notificationInfo The raw notification dictionary.
 *
 * @return UANotification instance
 */
+ (instancetype)notificationWithNotificationInfo:(NSDictionary *)notificationInfo;

/**
 * Converts a UNNotification into a UANotification.
 *
 * @param notification the UNNotification instance to be converted.
 *
 * @return UANotification instance
 */
+ (instancetype)notificationWithUNNotification:(UNNotification *)notification;

@end

NS_ASSUME_NONNULL_END
