/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "UAUserNotificationAction.h"
#import "UAUserNotificationAction+Internal.h"

@interface UAUserNotificationAction ()

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign) UIUserNotificationActivationMode activationMode;
@property(nonatomic, assign, getter=isAuthenticationRequired) BOOL authenticationRequired;
@property(nonatomic, assign, getter=isDestructive) BOOL destructive;

@end

@implementation UAUserNotificationAction

- (BOOL)isAuthenticationRequired {
    if (self.activationMode == UIUserNotificationActivationModeForeground) {
        return YES;
    }
    return _authenticationRequired;
}

- (BOOL)isDestructive {
    return _destructive;
}

- (UIUserNotificationAction *)asUIUserNotificationAction {
    UIMutableUserNotificationAction *uiAction = [[UIMutableUserNotificationAction alloc] init];
    uiAction.identifier = self.identifier;
    uiAction.title = self.title;
    uiAction.authenticationRequired = self.authenticationRequired;
    uiAction.activationMode = self.activationMode;
    uiAction.destructive = self.destructive;

    return uiAction;
}

- (BOOL)isEqualToAction:(UAUserNotificationAction *)notificationAction {
    BOOL equalIdentifier = [self.identifier isEqualToString:notificationAction.identifier];
    BOOL equalTitle = [self.title isEqualToString:notificationAction.title];
    BOOL equalAuth = self.authenticationRequired == notificationAction.authenticationRequired;
    BOOL equalActivationMode = self.activationMode == notificationAction.activationMode;
    BOOL equalDestructive = self.destructive == notificationAction.destructive;
    return equalIdentifier && equalTitle && equalAuth && equalActivationMode && equalDestructive;
}

@end
