/* Copyright Airship and Contributors */

#import "UARegistrationDelegateWrapper+Internal.h"
#import "UADispatcher+Internal.h"

@implementation UARegistrationDelegateWrapper


- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(NSString *)deviceToken {
    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(registrationSucceededForChannelID:deviceToken:)]) {
        [strongDelegate registrationSucceededForChannelID:channelID deviceToken:deviceToken];
    }
}

- (void)registrationFailed {
    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(registrationFailed)]) {
        [strongDelegate registrationFailed];
    }
}

- (void)notificationRegistrationFinishedWithAuthorizedSettings:(UAAuthorizedNotificationSettings)authorizedSettings
                                                 legacyOptions:(UANotificationOptions)legacyOptions
                                                    categories:(NSSet<UANotificationCategory *> *)categories
                                                        status:(UAAuthorizationStatus)status {

    id strongDelegate = self.delegate;

    SEL newSelector = @selector(notificationRegistrationFinishedWithAuthorizedSettings:categories:);
    SEL newSelectorWithStatus = @selector(notificationRegistrationFinishedWithAuthorizedSettings:categories:status:);

    if ([strongDelegate respondsToSelector:newSelector]) {
        [[UADispatcher mainDispatcher] dispatchAsync:^{
            [strongDelegate notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings categories:categories];
        }];
    }

    if ([strongDelegate respondsToSelector:newSelectorWithStatus]) {
        [[UADispatcher mainDispatcher] dispatchAsync:^{
            [strongDelegate notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings
                                                                        categories:categories
                                                                            status:status];
        }];
    }
}

- (void)notificationAuthorizedSettingsDidChange:(UAAuthorizedNotificationSettings)authorizedSettings
                                  legacyOptions:(UANotificationOptions)legacyOptions {

    id strongDelegate = self.delegate;

    SEL newSelector = @selector(notificationAuthorizedSettingsDidChange:);

    if ([strongDelegate respondsToSelector:newSelector]) {
        [strongDelegate notificationAuthorizedSettingsDidChange:authorizedSettings];
    }
}

- (void)apnsRegistrationSucceededWithDeviceToken:(NSData *)deviceToken {
    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(apnsRegistrationSucceededWithDeviceToken:)]) {
        [strongDelegate apnsRegistrationSucceededWithDeviceToken:deviceToken];
    }
}

- (void)apnsRegistrationFailedWithError:(NSError *)error {
    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(apnsRegistrationFailedWithError:)]) {
        [strongDelegate apnsRegistrationFailedWithError:error];
    }
}

@end

