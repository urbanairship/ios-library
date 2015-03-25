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

#import "UAUserNotificationAction.h"

/**
 * Clone of UIMutableUserNotificationAction for iOS 7 support.
 */
@interface UAMutableUserNotificationAction : UAUserNotificationAction

/**
 * Factory method for creating a UAMutableUserNotificationAction out of a UIUserNotificationAction. 
 * @param uiAction An instance of UIUserNotificationAction.
 * @return An instance of UAUserNotificationAction.
 */
+ (instancetype)actionWithUIUserNotificationAction:(UIUserNotificationAction *)uiAction;

/**
 * The string that you use internally to identify the action.
 */
@property(nonatomic, copy) NSString *identifier;

/**
 * The localized string to use as the button title for the action.
 */
@property(nonatomic, copy) NSString *title;

/**
 * The mode in which to run the app when the action is performed.
 */
@property(nonatomic, assign) UIUserNotificationActivationMode activationMode;

/**
 * A Boolean value indicating whether the user must unlock the device before the action is performed.
 */
@property(nonatomic, assign, getter=isAuthenticationRequired) BOOL authenticationRequired;

/**
 * A Boolean value indicating whether the action is destructive
 */
@property(nonatomic, assign, getter=isDestructive) BOOL destructive;

@end
