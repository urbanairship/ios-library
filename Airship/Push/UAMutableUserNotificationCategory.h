/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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
#import "UAUserNotificationCategory.h"

/**
 * Clone of UIMutableUserNotificationCategory for iOS 7 support.
 */
@interface UAMutableUserNotificationCategory : UAUserNotificationCategory

/**
 * Factory method for creating a UAMutableUserNotificationCategory out of a UIUserNotificationCategory.
 * @param uiCategory An instance of UIUserNotificationCategory.
 * @return An instance of UAUserNotificationCategory.
 */
+ (instancetype)categoryWithUIUserNotificationCategory:(UIUserNotificationCategory *)uiCategory;

/**
 * Sets the actions to display for different alert styles.
 *
 * @param actions An array of UAUserNotificationAction objects representing the actions to display for the given context.
 * @param context The context in which the alert is displayed.
 */
- (void)setActions:(NSArray *)actions
        forContext:(UIUserNotificationActionContext)context;

/**
 * The name of the action group.
 */
@property(nonatomic, copy) NSString *identifier;

@end
