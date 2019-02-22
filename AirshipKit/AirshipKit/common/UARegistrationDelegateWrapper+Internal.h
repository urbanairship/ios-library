/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPush+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Wraps the registration delegate and handles calling deprecated methods.
 */
@interface UARegistrationDelegateWrapper : NSObject

/**
 * The registration delegate.
 */
@property (nonatomic, weak, nullable) id<UARegistrationDelegate> delegate;

/**
 * Notifies the delegate for registration updates.
 *
 * @param channelID The channel ID string.
 * @param deviceToken The device token string.
 */
- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(nullable NSString *)deviceToken;

/**
 * Notifies the delegate when the registration fails.
 */
- (void)registrationFailed;

/**
 * Notifies the delegate when APNS registration completes.
 *
 * @param authorizedSettings The settings that were authorized at the time of registration.
 * @param legacyOptions The legacy authorized options.
 * @param categories NSSet of the categories that were most recently registered.
 * @param status The authorization status.
 */
- (void)notificationRegistrationFinishedWithAuthorizedSettings:(UAAuthorizedNotificationSettings)authorizedSettings
                                                 legacyOptions:(UANotificationOptions)legacyOptions
                                                    categories:(NSSet<UANotificationCategory *> *)categories
                                                        status:(UAAuthorizationStatus)status;

/**
 * Notifies the delegate when notification authentication changes with the new authorized settings.
 *
 * @param authorizedSettings UAAuthorizedNotificationSettings The newly changed authorized settings.
 * @param legacyOptions The legacy authorized options.
 */
- (void)notificationAuthorizedSettingsDidChange:(UAAuthorizedNotificationSettings)authorizedSettings
                                  legacyOptions:(UANotificationOptions)legacyOptions;


/**
 * Notifies the delegate when APNS registration updates.
 *
 * @param deviceToken The APNS device token.
 */
- (void)apnsRegistrationSucceededWithDeviceToken:(NSData *)deviceToken;

/**
 * Notifies the delegate when APNS registration fails to update
 *
 * @param error An NSError object that encapsulates information why registration did not succeed.
 */
- (void)apnsRegistrationFailedWithError:(NSError *)error;


@end

NS_ASSUME_NONNULL_END
