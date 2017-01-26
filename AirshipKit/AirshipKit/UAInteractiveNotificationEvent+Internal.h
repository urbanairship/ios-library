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
#import "UAEvent.h"

@class UANotificationAction;

NS_ASSUME_NONNULL_BEGIN

/**
 * A UAInteractiveNotificationEvent captures information regarding an interactive
 * notification event for UAAnalytics.
 */
@interface UAInteractiveNotificationEvent : UAEvent

/**
 * Factory method for creating an interactive notification event.
 *
 * @param action The triggered UANotificationAction.
 * @param category The category in the notification.
 * @param notification The notification.
 */
+ (instancetype)eventWithNotificationAction:(UANotificationAction *)action
                                 categoryID:(NSString *)category
                               notification:(NSDictionary *)notification;

/**
 * Factory method for creating an interactive notification event.
 *
 * @param action The triggered UANotificationAction.
 * @param category The category in the notification.
 * @param notification The notification.
 * @param responseText The response text, as passed to the application delegate or notification center delegate.
 */
+ (instancetype)eventWithNotificationAction:(UANotificationAction *)action
                                 categoryID:(NSString *)category
                               notification:(NSDictionary *)notification
                               responseText:(nullable NSString *)responseText;

@end

NS_ASSUME_NONNULL_END
