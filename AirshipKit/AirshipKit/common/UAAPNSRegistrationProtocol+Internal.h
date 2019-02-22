/* Copyright Urban Airship and Contributors */

#import "UAPush.h"
#import "UANotificationCategory.h"

NS_ASSUME_NONNULL_BEGIN

//---------------------------------------------------------------------------------------
// UAAPNSRegistrationProtocol Protocol
//---------------------------------------------------------------------------------------

@protocol UAAPNSRegistrationDelegate <NSObject>

@required

- (void)notificationRegistrationFinishedWithAuthorizedSettings:(UAAuthorizedNotificationSettings)authorizedSettings
                                                        status:(UAAuthorizationStatus)status;
@end

/**
 * Protocol to be implemented by internal APNS registration instances. All methods are optional.
 */
@protocol UAAPNSRegistrationProtocol<NSObject>

///---------------------------------------------------------------------------------------
/// @name APNS Registration Protocol Internal Methods
///---------------------------------------------------------------------------------------

@required

@property (nonatomic, weak, nullable) id<UAAPNSRegistrationDelegate> registrationDelegate;

/**
 * Get authorized notification settings from iOS.
 *
 * @param completionHandler A completion handler that will be called with the current authorized notification settings, and the authorization
 * status
 */
-(void)getAuthorizedSettingsWithCompletionHandler:(void (^)(UAAuthorizedNotificationSettings, UAAuthorizationStatus))completionHandler;

/**
 * Updates APNS registration.
 *
 * @param options The notification options to register.
 * @param categories The categories to register
 * @param completionHandler The completion handler. Success parameter is `YES` if permissions granted, `NO` otherwise.
 */
-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories
                   completionHandler:(nullable void(^)(BOOL success))completionHandler;

@end

NS_ASSUME_NONNULL_END
