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
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

@class UANotificationAction;

NS_ASSUME_NONNULL_BEGIN

/**
 * Category options for UANotificationCategory. All options only affects iOS 10+.
 */
typedef NS_OPTIONS(NSUInteger, UANotificationCategoryOptions) {
    /**
     * No options.
     */
    UANotificationCategoryOptionNone = (0),

    /**
     * Category will notify the app on dismissal.
     */
    UANotificationCategoryOptionCustomDismissAction = (1 << 0),

    /**
     * Category is allowed in Car Play.
     */
    UANotificationCategoryOptionAllowInCarPlay = (2 << 0),
};


/**
 * Clone of UNNotificationCategory for iOS 8-9 support.
 */
@interface UANotificationCategory : NSObject

/**
 * The name of the action group.
 */
@property(readonly, copy, nonatomic) NSString *identifier;

/**
 * The actions to display when a notification of this type is presented.
 */
@property(readonly, copy, nonatomic) NSArray<UANotificationAction *> *actions;

/**
 * The intents supported by notifications of this category.
 *
 * Note: This property is only applicable on iOS 10 and above.
 */
@property(readonly, copy, nonatomic) NSArray<NSString *> *intentIdentifiers;

/**
 * Options for how to handle notifications of this type.
 */
@property(readonly, assign, nonatomic) UANotificationCategoryOptions options;

+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
                               options:(UANotificationCategoryOptions)options;

@end

NS_ASSUME_NONNULL_END
