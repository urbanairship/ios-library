/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UATextInputNotificationAction.h"
#import "UANotificationAction+Internal.h"

@interface UATextInputNotificationAction ()

@property(nonatomic, copy) NSString *textInputButtonTitle;
@property(nonatomic, copy) NSString *textInputPlaceholder;

@end

@implementation UATextInputNotificationAction

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
              textInputButtonTitle:(NSString *)textInputButtonTitle
              textInputPlaceholder:(NSString *)textInputPlaceholder
                           options:(UANotificationActionOptions)options {
    self = [super initWithIdentifier:identifier title:title options:options];

    if (self) {
        self.textInputButtonTitle = textInputButtonTitle;
        self.textInputPlaceholder = textInputPlaceholder;
        self.forceBackgroundActivationModeInIOS9 = YES;
    }
    return self;
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                textInputButtonTitle:(NSString *)textInputButtonTitle
                textInputPlaceholder:(NSString *)textInputPlaceholder
                             options:(UANotificationActionOptions)options {
    return [[self alloc] initWithIdentifier:identifier title:title textInputButtonTitle:textInputButtonTitle textInputPlaceholder:textInputPlaceholder options:options];
}

- (UIUserNotificationAction *)asUIUserNotificationAction {
    UIMutableUserNotificationAction *uiAction = [[super asUIUserNotificationAction] mutableCopy];
    
    // Text input is only supported in UIUserNotificationActions on iOS 9+
    if (![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9, 0, 0}]) {
        return nil;
    }

    // handle iOS 9 foreground activation problem (Note: iOS 10 doesn't use this method)
    if (self.forceBackgroundActivationModeInIOS9) {
        uiAction.activationMode = UIUserNotificationActivationModeBackground;
    }

    uiAction.behavior = UIUserNotificationActionBehaviorTextInput;
    uiAction.parameters = @{UIUserNotificationTextInputActionButtonTitleKey:self.textInputButtonTitle};

    return uiAction;
}

- (UNTextInputNotificationAction *)asUNNotificationAction {
    return [UNTextInputNotificationAction actionWithIdentifier:self.identifier
                                                title:self.title
                                              options:(UNNotificationActionOptions)self.options
                                          textInputButtonTitle:self.textInputButtonTitle
                                          textInputPlaceholder:self.textInputPlaceholder];
}

- (BOOL)isEqualToUIUserNotificationAction:(UIUserNotificationAction *)notificationAction {
    BOOL equalButtonTitle = [self.textInputButtonTitle isEqualToString:notificationAction.parameters[UIUserNotificationTextInputActionButtonTitleKey]];
    
    return equalButtonTitle && [super isEqualToUIUserNotificationAction:notificationAction];
}

- (BOOL)isEqualToUNNotificationAction:(UNNotificationAction *)notificationAction {
    if (![notificationAction isKindOfClass:[UNTextInputNotificationAction class]]) {
        return NO;
    }
    BOOL equalButtonTitle = [self.textInputButtonTitle isEqualToString:((UNTextInputNotificationAction *)notificationAction).textInputButtonTitle];
    BOOL equalButtonPlaceholder  = [self.textInputPlaceholder isEqualToString:((UNTextInputNotificationAction *)notificationAction).textInputPlaceholder];

    if (!(equalButtonTitle && equalButtonPlaceholder)) {
        return NO;
    }
    
    return [super isEqualToUNNotificationAction:notificationAction];
}

@end
