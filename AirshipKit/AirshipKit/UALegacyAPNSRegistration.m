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

#import "UALegacyAPNSRegistration+Internal.h"
#import "UANotificationCategory+Internal.h"

@interface UALegacyAPNSRegistration ()

@end

@implementation UALegacyAPNSRegistration

-(void)getCurrentAuthorizationOptionsWithCompletionHandler:(void (^)(UANotificationOptions))completionHandler {
    completionHandler((UANotificationOptions)[[UIApplication sharedApplication] currentUserNotificationSettings].types);
}

-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories
                   completionHandler:(void (^)())completionHandler {

    NSMutableSet *normalizedCategories;

    if (categories) {
        normalizedCategories = [NSMutableSet set];
        // Normalize our abstract categories to iOS-appropriate type
        for (UANotificationCategory *category in categories) {
            [normalizedCategories addObject:[category asUIUserNotificationCategory]];
        }
    }

    // Only allow alert, badge, and sound
    NSUInteger filteredOptions = options & (UANotificationOptionAlert | UANotificationOptionBadge | UANotificationOptionSound);

    if (filteredOptions == UIUserNotificationTypeNone && [[UIApplication sharedApplication] currentUserNotificationSettings].types == UIUserNotificationTypeNone) {
        UA_LDEBUG(@"Already unregistered for user notification types.");
        completionHandler();
        return;
    }

    [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:filteredOptions
                                                                                                              categories:normalizedCategories]];
    UA_LDEBUG(@"Registering for user notification types %ld.", (unsigned long)filteredOptions);
    completionHandler(filteredOptions);
}

@end
