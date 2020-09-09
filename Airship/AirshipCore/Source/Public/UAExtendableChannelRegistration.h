/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UANotificationResponse.h"
#import "UANotificationContent.h"
#import "UAChannelRegistrationPayload.h"

NS_ASSUME_NONNULL_BEGIN

/**.
* @note For internal use only. :nodoc:
*/
typedef void (^UAChannelRegistrationExtenderCompletionHandler)(UAChannelRegistrationPayload *);

/**
* @note For internal use only. :nodoc:
*/
typedef void (^UAChannelRegistrationExtenderBlock)(UAChannelRegistrationPayload *, UAChannelRegistrationExtenderCompletionHandler completionHandler);

/**
 * Internal protocol to extend Channel registration.
 * @note For internal use only. :nodoc:
 */
@protocol UAExtendableChannelRegistration<NSObject>

@required

/**
 * Adds a block to extend the Channel registration payload.
 * @param extender The channel extender block.
 */
- (void)addChannelExtenderBlock:(UAChannelRegistrationExtenderBlock)extender;

@end

NS_ASSUME_NONNULL_END
