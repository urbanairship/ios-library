/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAPNSRegistrationProtocol+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Adapter that implements APNS registration using the legacy (<iOS10) registration flow.
 */
@interface UALegacyAPNSRegistration : NSObject <UAAPNSRegistrationProtocol>

///---------------------------------------------------------------------------------------
/// @name Legacy APNS Registration Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Updates APNS registration.
 *
 * @param completionHandler A completion handler that will be called with the current authorization options.
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
