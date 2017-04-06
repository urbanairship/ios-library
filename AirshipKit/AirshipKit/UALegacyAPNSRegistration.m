/* Copyright 2017 Urban Airship and Contributors */

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
