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

#import "UANotificationAction.h"
#import "UANotificationAction+Internal.h"

@interface UANotificationAction ()

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign) UANotificationActionOptions options;

@end

@implementation UANotificationAction

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                           options:(UANotificationActionOptions)options {
    self = [super init];

    if (self) {
        self.identifier = identifier;
        self.title = title;
        self.options = options;
    }
    return self;
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                             options:(UANotificationActionOptions)options {
    return [[self alloc] initWithIdentifier:identifier title:title options:options];
}

- (UIUserNotificationAction *)asUIUserNotificationAction {
    UIMutableUserNotificationAction *uiAction = [[UIMutableUserNotificationAction alloc] init];
    uiAction.identifier = self.identifier;
    uiAction.title = self.title;

    if (self.options & UNNotificationActionOptionAuthenticationRequired) {
        uiAction.authenticationRequired = YES;
    }

    uiAction.authenticationRequired = self.options & UNNotificationActionOptionAuthenticationRequired ? YES : NO;
    uiAction.activationMode = self.options & UNNotificationActionOptionForeground ? UIUserNotificationActivationModeForeground : UIUserNotificationActivationModeBackground;
    uiAction.destructive = self.options & UNNotificationActionOptionDestructive ? YES : NO;

    return uiAction;
}

- (UNNotificationAction *)asUNNotificationAction {
    return [UNNotificationAction actionWithIdentifier:self.identifier
                                                title:self.title
                                              options:(UNNotificationActionOptions)self.options];
}

- (BOOL)isEqualToUIUserNotificationAction:(UIUserNotificationAction *)notificationAction {
    BOOL equalIdentifier = [self.identifier isEqualToString:notificationAction.identifier];
    BOOL equalTitle = [self.title isEqualToString:notificationAction.title];
    BOOL equalAuth = (self.options & UNNotificationActionOptionAuthenticationRequired) > 0 == notificationAction.authenticationRequired;
    BOOL equalActivationMode = (self.options & UNNotificationActionOptionForeground) > 0 == (notificationAction.activationMode == UIUserNotificationActivationModeForeground);
    BOOL equalDestructive = (self.options & UNNotificationActionOptionDestructive) > 0 == notificationAction.destructive;

    return equalIdentifier && equalTitle && equalAuth && equalActivationMode && equalDestructive;
}

- (BOOL)isEqualToUNNotificationAction:(UNNotificationAction *)notificationAction {
    BOOL equalIdentifier = [self.identifier isEqualToString:notificationAction.identifier];
    BOOL equalTitle = [self.title isEqualToString:notificationAction.title];
    BOOL equalOptions = (NSUInteger)self.options == (NSUInteger)notificationAction.options;

    return equalIdentifier && equalTitle && equalOptions;
}

@end
