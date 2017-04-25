/* Copyright 2017 Urban Airship and Contributors */

#import "UAPush.h"
#import "UANotificationCategory.h"

NS_ASSUME_NONNULL_BEGIN

//---------------------------------------------------------------------------------------
// UAAPNSRegistrationProtocol Protocol
//---------------------------------------------------------------------------------------

/**
 * Protocol to be implemented by internal APNS registration instances. All methods are optional.
 */
@protocol UAAPNSRegistrationProtocol<NSObject>

///---------------------------------------------------------------------------------------
/// @name APNS Registration Protocol Internal Methods
///---------------------------------------------------------------------------------------

@optional

/**
 * Updates APNS registration.
 *
 * @param completionHandler A completion handler that will be called with the current authorization options .
 */
-(void)getCurrentAuthorizationOptionsWithCompletionHandler:(void (^)(UANotificationOptions))completionHandler;

/**
 * Updates APNS registration.
 *
 * @param options The notification options to register.
 * @param categories The categories to register
 * @param completionHandler A completion handler that will be called when finished.
 */
-(void)updateRegistrationWithOptions:(UANotificationOptions)options categories:(NSSet<UANotificationCategory *> *)categories completionHandler:(void (^)())completionHandler;


@end

NS_ASSUME_NONNULL_END
