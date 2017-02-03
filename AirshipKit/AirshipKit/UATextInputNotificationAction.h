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

#import "UANotificationAction.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Clone of UNTextInputNotificationAction for iOS 8-10 support.
 *
 * Note that in iOS 8, UATextInputNotificationAction actions will not be registered 
 * as custom actions with the operating system, as text input notification actions 
 * are not supported in iOS 8.
 */
@interface UATextInputNotificationAction : UANotificationAction

/**
 * The localized string to use as the title of the text input button.
 */
@property(nonatomic, copy, readonly) NSString *textInputButtonTitle;

/**
 * The localized string to display in the text input field.
 */
@property(nonatomic, copy, readonly) NSString *textInputPlaceholder;

/**
 * Note: There appears to be a bug in iOS 9 that prevents the return 
 * of the user's response when the UIUserNotificationActivationMode
 * is UIUserNotificationActivationModeForeground.  
 *
 * If forceBackgroundActivationModeInIOS9 is YES (which is the default), 
 * the UIUserNotificationActivationMode will be forced to
 * UIUserNotificationActivationModeBackground.
 *
 * Set forceBackgroundActivationModeInIOS9 to NO to use 
 * UIUserNotificationActivationModeForeground.
 */
@property(nonatomic, assign) BOOL forceBackgroundActivationModeInIOS9;

/**
 * Init method.
 *
 * @param identifier The action's identifier.
 * @param title The action's title.
 * @param textInputButtonTitle The title of the text input button.
 * @param textInputPlaceholder The text to display in the text input field.
 * @param options The action's options.
 */
- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
              textInputButtonTitle:(NSString *)textInputButtonTitle
              textInputPlaceholder:(NSString *)textInputPlaceholder
                           options:(UANotificationActionOptions)options;

/**
 * Creates an action with the specified title and options.
 * 
 * @param identifier The unique string that you use internally to identify the action. 
 *        When the user selects the action, the system passes this string to your
 *        app and asks you to perform the related task. This parameter must not be nil.
 * @param title The localized string to display to the user.
 *        This string is displayed in interface elements such as buttons that are
 *        used to represent actions. This parameter must not be nil.
 * @param textInputButtonTitle The localized title of the text input button that is
 *        displayed to the user.
 * @param textInputPlaceholder The localized placeholder text to display in the text
 *        input field.
 * @param options Additional options for how the action should be performed. Add options
 *        sparingly and only when you require the related behavior. For a list of
 *        possible values, see UANotificationActionOptions.
 */
+ (instancetype)actionWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                textInputButtonTitle:(NSString *)textInputButtonTitle
                textInputPlaceholder:(NSString *)textInputPlaceholder
                             options:(UANotificationActionOptions)options;

@end

NS_ASSUME_NONNULL_END
